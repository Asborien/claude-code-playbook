#!/bin/bash
# Integration test: simulates Profile A setup with fixture data,
# then validates every hook with test scenarios.
#
# Usage: bash tests/integration-test.sh [REPO_DIR]
# No GitHub access needed — gh is mocked.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"

source "$SCRIPT_DIR/fixtures.sh"

# ── Counters ──────────────────────────────────────────────
PASS=0
FAIL=0
ERRORS=()

ok() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
  else
    fail "$label"
  fi
}

check_exit() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    ok "$label"
  else
    fail "$label (expected exit $expected, got $actual)"
  fi
}

check_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    ok "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

check_not_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    ok "$label"
  else
    fail "$label (unexpectedly found: $needle)"
  fi
}

# ── Setup: create test project directory ──────────────────
TEST_DIR=$(mktemp -d /tmp/playbook-integration-XXXXXX)
HOOKS_SRC="$REPO_DIR/templates/hooks"
SKILLS_SRC="$REPO_DIR/templates/skills"

cleanup() {
  rm -rf "$TEST_DIR"
  # Clean up any test plan session markers
  rm -rf /tmp/claude-plan-sessions/test-session-*
  # Remove daily sentinel if we created one
  rm -f "/tmp/cc-session-checklist-$(date +%Y%m%d).stamp.test"
}
trap cleanup EXIT

# Create mock gh
MOCK_BIN="$TEST_DIR/.mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/gh" <<'MOCKGH'
#!/bin/bash
# Mock gh CLI for integration tests
case "$*" in
  *"pr list"*"--state merged"*)
    # Default: no merged PRs
    if [ -f "/tmp/playbook-test-merged-pr" ]; then
      echo "42"
    fi
    ;;
  *"issue comment"*)
    # Record the comment for verification
    echo "$*" >> /tmp/playbook-test-gh-comments
    ;;
  *"repo view"*)
    echo '{"url":"https://github.com/test-owner/acme-api"}'
    ;;
  *"project list"*)
    echo '{"projects":[]}'
    ;;
  *"project item-add"*)
    echo "ok"
    ;;
  *"api graphql"*)
    echo '{"data":{"repository":{"issue":{"projectItems":{"nodes":[]}}}}}'
    ;;
  *"auth status"*)
    echo "Logged in to github.com"
    ;;
  *)
    ;;
esac
exit 0
MOCKGH
chmod +x "$MOCK_BIN/gh"
export PATH="$MOCK_BIN:$PATH"

# Clean up test artifacts
rm -f /tmp/playbook-test-merged-pr /tmp/playbook-test-gh-comments

echo "═══════════════════════════════════════════════════════════"
echo "  Playbook Integration Test"
echo "  Test dir: $TEST_DIR"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 1: TEMPLATE VALIDATION (before setup)
# ══════════════════════════════════════════════════════════════
echo "── Phase 1: Template validation ──"

# All expected hook files exist
EXPECTED_HOOKS=(
  bash-guard.sh session-start.sh on-commit-check-planning.sh
  pre-pr-create.sh pre-enter-plan.sh on-enter-plan.sh
  on-exit-plan.sh pre-edit-write.sh mcp-pr-guard.sh
  pre-push.sh pre-merge.sh
)
for hook in "${EXPECTED_HOOKS[@]}"; do
  check "hook template exists: $hook" test -f "$HOOKS_SRC/$hook"
  check "hook template executable: $hook" test -x "$HOOKS_SRC/$hook"
done

check "settings.json template exists" test -f "$HOOKS_SRC/settings.json"

# All expected skill dirs exist with SKILL.md
EXPECTED_SKILLS=(
  arch-check bloat-check dry-check health-check
  sanitise security-check startup test-health
)
for skill in "${EXPECTED_SKILLS[@]}"; do
  check "skill exists: $skill/SKILL.md" test -f "$SKILLS_SRC/$skill/SKILL.md"
done

# settings.json references all hooks
SETTINGS_CONTENT=$(cat "$HOOKS_SRC/settings.json")
for hook in "${EXPECTED_HOOKS[@]}"; do
  check_contains "settings.json references $hook" "$SETTINGS_CONTENT" "$hook"
done

# Template variables present in pre-enter-plan.sh
PRE_ENTER_CONTENT=$(cat "$HOOKS_SRC/pre-enter-plan.sh")
for var in '{{PROJECT_ID}}' '{{STATUS_FIELD_ID}}' '{{IN_PROGRESS_ID}}' '{{GITHUB_OWNER}}' '{{GITHUB_REPO}}'; do
  check_contains "pre-enter-plan.sh has $var" "$PRE_ENTER_CONTENT" "$var"
done

# Practice docs exist
check "planning-lifecycle.md exists" test -f "$REPO_DIR/practices/planning/planning-lifecycle.md"
check "scope-discipline.md exists" test -f "$REPO_DIR/practices/planning/scope-discipline.md"

# CLAUDE.md template exists
check "CLAUDE.md.template exists" test -f "$REPO_DIR/templates/CLAUDE.md.template"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 2: SIMULATE SETUP (Profile A, solo)
# ══════════════════════════════════════════════════════════════
echo "── Phase 2: Simulate Profile A setup ──"

cd "$TEST_DIR"
git init -q
git checkout -q -b staging
echo "# $PROJECT_NAME" > README.md
git add README.md
git commit -q -m "init"

# Create project structure
mkdir -p .claude/hooks .claude/skills docs/plans docs/design docs/system

# Copy hooks (Profile A = all hooks)
for hook in "${EXPECTED_HOOKS[@]}"; do
  cp "$HOOKS_SRC/$hook" .claude/hooks/
done
chmod +x .claude/hooks/*.sh

# Substitute template variables in pre-enter-plan.sh
sed -i "s|{{PROJECT_ID}}|${PROJECT_ID}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{STATUS_FIELD_ID}}|${STATUS_FIELD_ID}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{IN_PROGRESS_ID}}|${IN_PROGRESS_ID}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{GITHUB_OWNER}}|${GITHUB_OWNER}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" .claude/hooks/pre-enter-plan.sh

# Copy settings.json
cp "$HOOKS_SRC/settings.json" .claude/settings.json

# Copy skills
cp -r "$SKILLS_SRC"/* .claude/skills/

# Verify setup
check "hooks dir populated" test "$(ls .claude/hooks/*.sh | wc -l)" -eq 11
check "settings.json copied" test -f .claude/settings.json
check "skills copied (8 dirs)" test "$(ls -d .claude/skills/*/ | wc -l)" -eq 8
check "docs/plans/ created" test -d docs/plans
check "template vars substituted" grep -q "$PROJECT_ID" .claude/hooks/pre-enter-plan.sh
check_not_contains "no raw template vars left" "$(cat .claude/hooks/pre-enter-plan.sh)" "{{PROJECT_ID}}"

# Commit setup
git add -A
git commit -q -m "META: initial setup"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 3: HOOK TESTS — bash-guard.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 3: bash-guard.sh ──"

GUARD=".claude/hooks/bash-guard.sh"

run_guard() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$GUARD" 2>/dev/null
}

run_guard_stderr() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$GUARD" 2>&1
}

# Should BLOCK (exit 2)
run_guard "git push origin main"; check_exit "blocks: git push origin main" 2 $?
run_guard "git push origin master"; check_exit "blocks: git push origin master" 2 $?
run_guard "git push --force origin staging"; check_exit "blocks: git push --force" 2 $?
run_guard "git push -f origin staging"; check_exit "blocks: git push -f" 2 $?
run_guard "git commit -m 'test' --no-verify"; check_exit "blocks: --no-verify" 2 $?
run_guard "git reset --hard HEAD~1"; check_exit "blocks: git reset --hard" 2 $?
run_guard "git checkout ."; check_exit "blocks: git checkout ." 2 $?
run_guard "git restore ."; check_exit "blocks: git restore ." 2 $?
run_guard "git clean -f"; check_exit "blocks: git clean -f" 2 $?
run_guard "git add -A"; check_exit "blocks: git add -A" 2 $?
run_guard "git add --all"; check_exit "blocks: git add --all" 2 $?
run_guard "git add ."; check_exit "blocks: git add ." 2 $?
run_guard "gh pr create --base main --title test"; check_exit "blocks: PR to main" 2 $?
run_guard "gh pr create --title test"; check_exit "blocks: PR without --base staging" 2 $?
run_guard "gh pr merge 1 --admin"; check_exit "blocks: --admin merge" 2 $?

# Should PASS (exit 0)
run_guard "git add src/index.ts"; check_exit "allows: git add specific file" 0 $?
run_guard "git commit -m 'feat: add feature'"; check_exit "allows: normal commit" 0 $?
run_guard "git push origin staging"; check_exit "allows: push to staging" 0 $?
run_guard "npm test"; check_exit "allows: non-git command" 0 $?
run_guard "ls -la"; check_exit "allows: ls" 0 $?
run_guard "gh pr create --base staging --title test"; check_exit "allows: PR to staging" 0 $?
run_guard "gh pr merge 1 --auto"; check_exit "allows: --auto merge" 0 $?

# Heredoc stripping — commit message containing 'git push origin main' should NOT block
run_guard 'git commit -m "$(cat <<EOF
fix: resolve git push origin main issue
EOF
)"'
check_exit "allows: commit with 'push main' in heredoc message" 0 $?

# BLOCKED message content
OUTPUT=$(run_guard_stderr "git push origin main")
check_contains "block message mentions main" "$OUTPUT" "main"

# Dead branch guard — mock a merged PR
touch /tmp/playbook-test-merged-pr
git checkout -q -b 42-feature
run_guard "git commit -m 'more work'"; check_exit "blocks: commit on merged-PR branch" 2 $?
rm -f /tmp/playbook-test-merged-pr
run_guard "git commit -m 'more work'"; check_exit "allows: commit on non-merged branch" 0 $?
git checkout -q staging

# Branch safety — dirty work on issue branch
git checkout -q -b 99-dirty-test
echo "dirty" > dirty.txt
run_guard "git checkout staging"; check_exit "blocks: switch with dirty work" 2 $?
rm -f dirty.txt
git checkout -q staging
git branch -q -D 99-dirty-test

# Tag without SANITISATION_LOG.md (warning only, exit 0)
run_guard "git tag v1.0.0"; check_exit "warns but allows: tag without sanitisation log" 0 $?
OUTPUT=$(run_guard_stderr "git tag v1.0.0")
check_contains "tag warning mentions SANITISATION_LOG" "$OUTPUT" "SANITISATION_LOG"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 4: HOOK TESTS — pre-edit-write.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 4: pre-edit-write.sh ──"

EDIT_HOOK=".claude/hooks/pre-edit-write.sh"

run_edit() {
  local cwd="$1"
  printf '{"tool_input":{"file_path":"test.md","old_string":"a","new_string":"b"},"cwd":"%s"}' "$cwd" | bash "$EDIT_HOOK" 2>/dev/null
}

run_edit_output() {
  local cwd="$1"
  printf '{"tool_input":{"file_path":"test.md","old_string":"a","new_string":"b"},"cwd":"%s"}' "$cwd" | bash "$EDIT_HOOK" 2>&1
}

# On staging — should block
git checkout -q staging
run_edit "$TEST_DIR"; check_exit "blocks: edit on staging" 0 $?
OUTPUT=$(run_edit_output "$TEST_DIR")
check_contains "edit block mentions issue branch" "$OUTPUT" "issue branch"

# On main — should block
git checkout -q -b main 2>/dev/null || git checkout -q main
run_edit "$TEST_DIR"; check_exit "blocks: edit on main" 0 $?

# On issue branch — should pass
git checkout -q -b 42-feature 2>/dev/null || git checkout -q 42-feature
OUTPUT=$(run_edit_output "$TEST_DIR")
check_not_contains "allows: edit on issue branch" "$OUTPUT" "BLOCKED"

# Non-git dir — should pass
NONGIT=$(mktemp -d /tmp/playbook-nongit-XXXXXX)
run_edit "$NONGIT"; check_exit "allows: edit in non-git dir" 0 $?
rm -rf "$NONGIT"

git checkout -q staging

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 5: HOOK TESTS — mcp-pr-guard.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 5: mcp-pr-guard.sh ──"

MCP_GUARD=".claude/hooks/mcp-pr-guard.sh"

run_mcp() {
  local base="$1"
  printf '{"tool_input":{"base":"%s","title":"test PR"}}' "$base" | bash "$MCP_GUARD" 2>/dev/null
}

run_mcp_stderr() {
  local base="$1"
  printf '{"tool_input":{"base":"%s","title":"test PR"}}' "$base" | bash "$MCP_GUARD" 2>&1
}

run_mcp "main"; check_exit "blocks: MCP PR to main" 2 $?
run_mcp "master"; check_exit "blocks: MCP PR to master" 2 $?
run_mcp "staging"; check_exit "allows: MCP PR to staging" 0 $?

# Warn on unexpected base
OUTPUT=$(run_mcp_stderr "develop")
check_exit "allows: MCP PR to develop" 0 $?
check_contains "warns: unexpected base branch" "$OUTPUT" "expected 'staging'"

# Empty base — should pass
printf '{"tool_input":{"title":"test PR"}}' | bash "$MCP_GUARD" 2>/dev/null
check_exit "allows: MCP PR with no base" 0 $?

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 6: HOOK TESTS — pre-pr-create.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 6: pre-pr-create.sh ──"

PR_HOOK=".claude/hooks/pre-pr-create.sh"

run_pr() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$PR_HOOK" 2>/dev/null
}

# Not a PR command — pass through
run_pr "npm test"; check_exit "passes: non-PR command" 0 $?
run_pr "git commit -m test"; check_exit "passes: git commit" 0 $?

# PR without strategy — block
run_pr "gh pr create --base staging --title test"; check_exit "blocks: PR without strategy" 2 $?

# PR with --merge-now — allow
run_pr "gh pr create --base staging --title test --merge-now"; check_exit "allows: PR with --merge-now" 0 $?

# PR with --review — allow
run_pr "gh pr create --base staging --title test --review alice"; check_exit "allows: PR with --review" 0 $?

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 7: HOOK TESTS — pre-push.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 7: pre-push.sh ──"

PUSH_HOOK=".claude/hooks/pre-push.sh"

run_push() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$PUSH_HOOK" 2>/dev/null
}

run_push_stderr() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$PUSH_HOOK" 2>&1
}

# Not a push — pass
run_push "npm test"; check_exit "passes: non-push command" 0 $?

# Push to main — block
run_push "git push origin main"; check_exit "blocks: push to main" 2 $?
run_push "git push origin master"; check_exit "blocks: push to master" 2 $?

# Push to staging — pass with checklist
run_push "git push origin staging"; check_exit "allows: push to staging" 0 $?
OUTPUT=$(run_push_stderr "git push origin staging")
check_contains "push checklist shown" "$OUTPUT" "tests pass"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 8: HOOK TESTS — pre-merge.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 8: pre-merge.sh ──"

MERGE_HOOK=".claude/hooks/pre-merge.sh"

run_merge() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$MERGE_HOOK" 2>/dev/null
}

run_merge_stderr() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$MERGE_HOOK" 2>&1
}

# Not a merge — pass
run_merge "npm test"; check_exit "passes: non-merge command" 0 $?

# Merge command — pass with checklist (informational only)
run_merge "gh pr merge 1 --auto"; check_exit "allows: merge command" 0 $?
OUTPUT=$(run_merge_stderr "gh pr merge 1 --auto")
check_contains "merge checklist shown" "$OUTPUT" "CI passing"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 9: HOOK TESTS — session-start.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 9: session-start.sh ──"

SESSION_HOOK=".claude/hooks/session-start.sh"
# Remove today's sentinel so we get the checklist
# session-start.sh now gathers data and renders the table directly
# In the integration test (no real gh), it will fail to find a milestone and skip
OUTPUT=$(echo '{}' | bash "$SESSION_HOOK" 2>&1)
check_exit "session-start exits 0" 0 $?
check_contains "session-start produces output" "$OUTPUT" "milestone"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 10: HOOK TESTS — pre-enter-plan.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 10: pre-enter-plan.sh ──"

PLAN_HOOK=".claude/hooks/pre-enter-plan.sh"

run_plan() {
  printf '{"cwd":"%s","session_id":"test-session-plan"}' "$TEST_DIR" | bash "$PLAN_HOOK" 2>/dev/null
}

run_plan_stderr() {
  printf '{"cwd":"%s","session_id":"test-session-plan"}' "$TEST_DIR" | bash "$PLAN_HOOK" 2>&1
}

# On staging — should block
git checkout -q staging
OUTPUT=$(run_plan_stderr)
check_contains "blocks: plan on staging" "$OUTPUT" "PLAN MODE BLOCKED"

# On main — should block
git checkout -q main 2>/dev/null || (git checkout -q -b main && git checkout -q main)
OUTPUT=$(run_plan_stderr)
check_contains "blocks: plan on main" "$OUTPUT" "PLAN MODE BLOCKED"

# On issue branch — should pass
git checkout -q 42-feature
run_plan; check_exit "allows: plan on issue branch" 0 $?
OUTPUT=$(run_plan_stderr)
check_contains "reports issue number" "$OUTPUT" "#42"

# On non-issue branch — should warn
git checkout -q -b feature-no-number 2>/dev/null || git checkout -q feature-no-number
OUTPUT=$(run_plan_stderr)
check_contains "warns: no issue number in branch" "$OUTPUT" "does not start with an issue number"

git checkout -q staging

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 11: HOOK TESTS — on-enter-plan.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 11: on-enter-plan.sh ──"

ENTER_HOOK=".claude/hooks/on-enter-plan.sh"
MARKER_DIR="/tmp/claude-plan-sessions"

# Clean slate
rm -f "${MARKER_DIR}/test-session-enter.planning"

printf '{"session_id":"test-session-enter"}' | bash "$ENTER_HOOK" 2>/dev/null
check_exit "on-enter-plan exits 0" 0 $?
check "marker file created" test -f "${MARKER_DIR}/test-session-enter.planning"

# Verify marker content is a timestamp
MARKER_CONTENT=$(cat "${MARKER_DIR}/test-session-enter.planning")
check_contains "marker has UTC timestamp" "$MARKER_CONTENT" "T"

# Clean up
rm -f "${MARKER_DIR}/test-session-enter.planning"

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 12: HOOK TESTS — on-commit-check-planning.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 12: on-commit-check-planning.sh ──"

COMMIT_HOOK=".claude/hooks/on-commit-check-planning.sh"

# Clean gh comment log
rm -f /tmp/playbook-test-gh-comments

# On issue branch, no planning marker — should post comment
git checkout -q 42-feature
rm -f "${MARKER_DIR}/test-session-commit.planning" "${MARKER_DIR}/test-session-commit.planned" "${MARKER_DIR}/test-session-commit.no-plan-noted"
printf '{"tool_input":{"command":"git commit -m test"},"session_id":"test-session-commit"}' | bash "$COMMIT_HOOK" 2>/dev/null
check_exit "no-plan comment exits 0" 0 $?
check "gh issue comment was called" test -f /tmp/playbook-test-gh-comments
if [ -f /tmp/playbook-test-gh-comments ]; then
  check_contains "comment targets issue 42" "$(cat /tmp/playbook-test-gh-comments)" "42"
fi
check "no-plan-noted marker created" test -f "${MARKER_DIR}/test-session-commit.no-plan-noted"

# Second commit — should NOT post again
rm -f /tmp/playbook-test-gh-comments
printf '{"tool_input":{"command":"git commit -m test2"},"session_id":"test-session-commit"}' | bash "$COMMIT_HOOK" 2>/dev/null
if [ -f /tmp/playbook-test-gh-comments ]; then
  fail "no-plan: does not repeat comment"
else
  ok "no-plan: does not repeat comment"
fi

# With planning marker — should skip entirely
rm -f /tmp/playbook-test-gh-comments "${MARKER_DIR}/test-session-commit2.no-plan-noted"
mkdir -p "$MARKER_DIR"
echo "2026-01-01T00:00:00Z" > "${MARKER_DIR}/test-session-commit2.planned"
printf '{"tool_input":{"command":"git commit -m test3"},"session_id":"test-session-commit2"}' | bash "$COMMIT_HOOK" 2>/dev/null
if [ -f /tmp/playbook-test-gh-comments ]; then
  fail "with-plan: skips comment"
else
  ok "with-plan: skips comment"
fi

# Non-commit command — should pass through
rm -f /tmp/playbook-test-gh-comments
printf '{"tool_input":{"command":"npm test"},"session_id":"test-session-commit3"}' | bash "$COMMIT_HOOK" 2>/dev/null
check_exit "passes: non-commit command" 0 $?
if [ -f /tmp/playbook-test-gh-comments ]; then
  fail "non-commit: no gh call"
else
  ok "non-commit: no gh call"
fi

# Clean up
rm -f "${MARKER_DIR}/test-session-commit.no-plan-noted" "${MARKER_DIR}/test-session-commit2.planned"
rm -f /tmp/playbook-test-gh-comments

git checkout -q staging

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 13: HOOK TESTS — on-exit-plan.sh
# ══════════════════════════════════════════════════════════════
echo "── Phase 13: on-exit-plan.sh ──"

EXIT_HOOK=".claude/hooks/on-exit-plan.sh"

# Setup: create a plan file and planning marker
git checkout -q 42-feature
FAKE_PLANS="$HOME/.claude/plans"
mkdir -p "$FAKE_PLANS" "$MARKER_DIR"

# Create planning marker (simulates on-enter-plan)
echo "2026-01-01T00:00:00Z" > "${MARKER_DIR}/test-session-exit.planning"
sleep 1  # Ensure plan file is newer than marker

# Create a fake plan file
PLAN_FILE="$FAKE_PLANS/test-plan-for-exit.md"
cat > "$PLAN_FILE" <<'PLAN'
# Implementation Plan

## Goal
Test the exit plan hook

## Steps
1. Step one
2. Step two
PLAN

rm -f /tmp/playbook-test-gh-comments

printf '{"cwd":"%s","session_id":"test-session-exit"}' "$TEST_DIR" | bash "$EXIT_HOOK" 2>/dev/null
EXIT_CODE=$?
check_exit "on-exit-plan exits 0" 0 $EXIT_CODE

# Check plan was copied to docs/plans/
PLAN_COPIED=$(ls docs/plans/42-*.md 2>/dev/null | head -1)
if [ -n "$PLAN_COPIED" ]; then
  ok "plan file copied to docs/plans/"
else
  fail "plan file copied to docs/plans/"
fi

# Check plan was committed
PLAN_IN_GIT=$(git log --oneline -1 2>/dev/null)
check_contains "plan committed with DOCS prefix" "$PLAN_IN_GIT" "DOCS"

# Check issue comment was posted
check "gh issue comment was called" test -f /tmp/playbook-test-gh-comments
if [ -f /tmp/playbook-test-gh-comments ]; then
  check_contains "comment targets issue 42" "$(cat /tmp/playbook-test-gh-comments)" "42"
fi

# Check marker renamed to .planned
check "marker renamed to .planned" test -f "${MARKER_DIR}/test-session-exit.planned"
check "planning marker removed" test ! -f "${MARKER_DIR}/test-session-exit.planning"

# No plan file → should post "exited without plan"
rm -f /tmp/playbook-test-gh-comments "$PLAN_FILE"
rm -f "${MARKER_DIR}/test-session-exit2.planning"
echo "2026-01-01T00:00:00Z" > "${MARKER_DIR}/test-session-exit2.planning"
# Remove all recent plan files to force "no plan" path
find "$FAKE_PLANS" -name "*.md" -mmin -60 -delete 2>/dev/null
printf '{"cwd":"%s","session_id":"test-session-exit2"}' "$TEST_DIR" | bash "$EXIT_HOOK" 2>/dev/null
if [ -f /tmp/playbook-test-gh-comments ]; then
  check_contains "no-plan comment posted" "$(cat /tmp/playbook-test-gh-comments)" "without a plan"
else
  fail "no-plan comment posted"
fi

# Clean up
rm -f /tmp/playbook-test-gh-comments
rm -f "${MARKER_DIR}/test-session-exit.planned" "${MARKER_DIR}/test-session-exit2.planning"
rm -f "$FAKE_PLANS/test-plan-for-exit.md"
git checkout -q staging

echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 14: CROSS-HOOK INTEGRATION
# ══════════════════════════════════════════════════════════════
echo "── Phase 14: Cross-hook integration (full workflow) ──"

# Simulate: create issue branch → enter plan → exit plan → commit
git checkout -q -b 77-full-workflow 2>/dev/null || git checkout -q 77-full-workflow
rm -f "${MARKER_DIR}/test-session-full"*

# Step 1: pre-enter-plan — should pass on issue branch
printf '{"cwd":"%s","session_id":"test-session-full"}' "$TEST_DIR" | bash "$PLAN_HOOK" 2>/dev/null
check_exit "workflow: pre-enter-plan passes" 0 $?

# Step 2: on-enter-plan — creates marker
printf '{"session_id":"test-session-full"}' | bash "$ENTER_HOOK" 2>/dev/null
check "workflow: planning marker exists" test -f "${MARKER_DIR}/test-session-full.planning"

# Step 3: on-exit-plan — should find plan and commit
sleep 1
echo "# Workflow Plan" > "$FAKE_PLANS/workflow-test.md"
rm -f /tmp/playbook-test-gh-comments
printf '{"cwd":"%s","session_id":"test-session-full"}' "$TEST_DIR" | bash "$EXIT_HOOK" 2>/dev/null
check "workflow: marker renamed to .planned" test -f "${MARKER_DIR}/test-session-full.planned"

# Step 4: on-commit-check-planning — should see .planned marker and skip
rm -f /tmp/playbook-test-gh-comments
printf '{"tool_input":{"command":"git commit -m test"},"session_id":"test-session-full"}' | bash "$COMMIT_HOOK" 2>/dev/null
if [ -f /tmp/playbook-test-gh-comments ]; then
  fail "workflow: commit after planning skips no-plan comment"
else
  ok "workflow: commit after planning skips no-plan comment"
fi

# Clean up
rm -f "${MARKER_DIR}/test-session-full"* /tmp/playbook-test-gh-comments
rm -f "$FAKE_PLANS/workflow-test.md"
git checkout -q staging

echo ""

# ══════════════════════════════════════════════════════════════
# RESULTS
# ══════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "  Failed:"
  for err in "${ERRORS[@]}"; do
    echo "    - $err"
  done
fi
echo "═══════════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
