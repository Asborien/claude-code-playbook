#!/bin/bash
# Shared test helpers — sourced by each test file.

REPO_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
HOOKS_DIR="$REPO_DIR/templates/hooks"
SKILLS_DIR="$REPO_DIR/templates/skills"
TEST_TMPDIR=""

# Counters
_PASS=0
_FAIL=0
_ERRORS=()

setup_test_repo() {
  # Create a disposable git repo for tests that need git context
  TEST_TMPDIR=$(mktemp -d /tmp/playbook-test-XXXXXX)
  cd "$TEST_TMPDIR"
  git init -q
  git checkout -q -b staging
  echo "init" > README.md
  git add README.md
  git commit -q -m "init"
}

setup_mock_gh() {
  # Create a mock gh CLI that returns canned responses
  MOCK_BIN="$TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/gh" <<'MOCKGH'
#!/bin/bash
# Mock gh — returns success for everything, empty results for queries
case "$*" in
  *"pr list"*"--state merged"*)
    # No merged PRs by default
    echo "[]"
    exit 0
    ;;
  *"issue comment"*)
    exit 0
    ;;
  *"repo view"*)
    echo '{"url":"https://github.com/test-owner/test-repo"}'
    exit 0
    ;;
  *"project list"*)
    echo '{"projects":[]}'
    exit 0
    ;;
  *"api graphql"*)
    echo '{"data":{}}'
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
MOCKGH
  chmod +x "$MOCK_BIN/gh"
  export PATH="$MOCK_BIN:$PATH"
}

cleanup_test_repo() {
  [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# Feed JSON to a hook and capture exit code
run_hook() {
  local hook="$1"
  local json="$2"
  local exit_code
  printf '%s' "$json" | bash "$HOOKS_DIR/$hook" 2>/dev/null
  exit_code=$?
  return $exit_code
}

# Same but capture stderr too
run_hook_stderr() {
  local hook="$1"
  local json="$2"
  printf '%s' "$json" | bash "$HOOKS_DIR/$hook" 2>&1
}

assert_exit() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "    ✓ $label"
    _PASS=$((_PASS + 1))
  else
    echo "    ✗ $label (expected exit $expected, got $actual)"
    _FAIL=$((_FAIL + 1))
    _ERRORS+=("$label")
  fi
}

assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "    ✓ $label"
    _PASS=$((_PASS + 1))
  else
    echo "    ✗ $label (output missing: $needle)"
    _FAIL=$((_FAIL + 1))
    _ERRORS+=("$label")
  fi
}

assert_file_exists() {
  local label="$1"
  local path="$2"
  if [ -f "$path" ]; then
    echo "    ✓ $label"
    _PASS=$((_PASS + 1))
  else
    echo "    ✗ $label (file not found: $path)"
    _FAIL=$((_FAIL + 1))
    _ERRORS+=("$label")
  fi
}

assert_file_executable() {
  local label="$1"
  local path="$2"
  if [ -x "$path" ]; then
    echo "    ✓ $label"
    _PASS=$((_PASS + 1))
  else
    echo "    ✗ $label (not executable: $path)"
    _FAIL=$((_FAIL + 1))
    _ERRORS+=("$label")
  fi
}

report() {
  echo "  Assertions: ${_PASS} passed, ${_FAIL} failed"
  [ "$_FAIL" -eq 0 ]
}

# JSON builders for hook input
bash_input() {
  local cmd="$1"
  printf '{"tool_input":{"command":"%s"},"session_id":"test-session-001"}' "$cmd"
}

edit_input() {
  local cwd="$1"
  printf '{"tool_input":{"file_path":"test.md","old_string":"a","new_string":"b"},"cwd":"%s"}' "$cwd"
}

mcp_pr_input() {
  local base="$1"
  printf '{"tool_input":{"base":"%s","title":"test PR","body":"test"}}' "$base"
}

plan_input() {
  local cwd="$1"
  local session="${2:-test-session-001}"
  printf '{"cwd":"%s","session_id":"%s"}' "$cwd" "$session"
}
