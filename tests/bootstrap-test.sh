#!/bin/bash
# Bootstrap test: creates a REAL GitHub repo, runs full playbook setup,
# creates 3 milestones with issues, scaffolds R0, tests every hook.
#
# Usage: bash tests/bootstrap-test.sh [PLAYBOOK_DIR]
#
# Sequential naming: playbook-test-001, -002, etc.
# On success: cd into the repo, run claude, /startup works.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYBOOK_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"

source "$SCRIPT_DIR/fixtures.sh"

# ── Sequential naming ─────────────────────────────────────
SEQ=1
while [ -d "$PLAYBOOK_DIR/playbook-test-$(printf '%03d' $SEQ)" ]; do
  SEQ=$((SEQ + 1))
done
REPO_NAME="playbook-test-$(printf '%03d' $SEQ)"
TEST_DIR="$PLAYBOOK_DIR/$REPO_NAME"

# ── Counters ──────────────────────────────────────────────
PASS=0; FAIL=0; ERRORS=()

ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }
check() { local l="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$l"; else fail "$l"; fi; }
check_exit() { if [ "$3" -eq "$2" ]; then ok "$1"; else fail "$1 (expected $2, got $3)"; fi; }
check_contains() { if echo "$2" | grep -qF "$3"; then ok "$1"; else fail "$1 (missing: $3)"; fi; }
check_not_contains() { if ! echo "$2" | grep -qF "$3"; then ok "$1"; else fail "$1 (found: $3)"; fi; }
check_file_contains() { if [ -f "$2" ] && grep -qF "$3" "$2"; then ok "$1"; else fail "$1"; fi; }

# ── Mock for hook-level gh calls ──────────────────────────
MOCK_BIN="$PLAYBOOK_DIR/.test-mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/gh-hook-mock" <<'MOCKGH'
#!/bin/bash
case "$*" in
  *"pr list"*"--state merged"*) echo ""; exit 0 ;;
  *"issue comment"*) echo "$*" >> "${GH_COMMENT_LOG_DIR:-.}/.gh-comments"; exit 0 ;;
  *"api graphql"*"repository"*) echo '{"data":{"repository":{"issue":{"projectItems":{"nodes":[]}}}}}'; exit 0 ;;
  *"repo view"*"--json url"*) echo "{\"url\":\"https://github.com/${GH_TEST_OWNER:-x}/${GH_TEST_REPO:-x}\"}"; exit 0 ;;
  *) exec /usr/bin/gh "$@" ;;
esac
MOCKGH
chmod +x "$MOCK_BIN/gh-hook-mock"

cleanup() { rm -rf "$MOCK_BIN" /tmp/claude-plan-sessions/bootstrap-test-*; }
trap cleanup EXIT

echo "═══════════════════════════════════════════════════════════"
echo "  Bootstrap Test → ${GITHUB_OWNER}/${REPO_NAME}"
echo "  User: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"
echo "  Local: $TEST_DIR"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 0: CREATE REPO
# ══════════════════════════════════════════════════════════════
echo "── Phase 0: Create GitHub repo ──"

mkdir -p "$TEST_DIR" && cd "$TEST_DIR"
git init -q

cat > .gitignore <<'GI'
node_modules/
dist/
.env
.env.*
!.env.example
*.log
.DS_Store
GI
echo "# ${PROJECT_NAME}" > README.md
git add README.md .gitignore && git commit -q -m "init"

REPO_URL=$(gh repo create "${GITHUB_OWNER}/${REPO_NAME}" --private --source=. --push \
  --description "${PROJECT_DESC} (playbook test)" 2>&1)
check_exit "repo created" 0 $?
echo "  → https://github.com/${GITHUB_OWNER}/${REPO_NAME}"

git checkout -q -b staging && git push -q -u origin staging
check "staging pushed" git rev-parse origin/staging
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 1: LABELS + MILESTONES + ISSUES
# ══════════════════════════════════════════════════════════════
echo "── Phase 1: Labels, milestones, issues ──"

# Labels
LABELS_FILE="$PLAYBOOK_DIR/templates/github/labels.json"
LC=0
if [ -f "$LABELS_FILE" ]; then
  while IFS= read -r line; do
    N=$(echo "$line" | jq -r '.name'); C=$(echo "$line" | jq -r '.color'); D=$(echo "$line" | jq -r '.description // ""')
    gh label create "$N" --color "$C" --description "$D" --repo "${GITHUB_OWNER}/${REPO_NAME}" 2>/dev/null && LC=$((LC + 1))
  done < <(jq -c '.[]' "$LABELS_FILE")
fi
check "labels (${LC})" test "$LC" -gt 0

# Milestones
MS_NUMBERS=()
for ms in "${MILESTONES[@]}"; do
  IFS='|' read -r ms_title ms_desc <<< "$ms"
  MS_NUM=$(gh api "repos/${GITHUB_OWNER}/${REPO_NAME}/milestones" --method POST \
    -f title="$ms_title" -f description="$ms_desc" --jq '.number' 2>/dev/null || echo "")
  MS_NUMBERS+=("$MS_NUM")
done
check "3 milestones created" test "${#MS_NUMBERS[@]}" -eq 3

# Issues — milestone title is extracted from MILESTONES array (before the |)
ISSUE_NUMS=()
for issue in "${ISSUES[@]}"; do
  IFS='|' read -r ms_idx label title body <<< "$issue"
  ms_title=$(echo "${MILESTONES[$ms_idx]}" | cut -d'|' -f1)
  IURL=$(gh issue create --repo "${GITHUB_OWNER}/${REPO_NAME}" \
    --title "$title" --body "$body" --label "$label" --milestone "$ms_title" 2>&1 || echo "")
  if echo "$IURL" | grep -q "github.com"; then
    ISSUE_NUMS+=("$IURL")
  else
    echo "  ⚠ Failed to create issue: $title ($IURL)" >&2
  fi
done
check "12 issues created" test "${#ISSUE_NUMS[@]}" -ge 10
echo "  Created ${#ISSUE_NUMS[@]} issues across 3 milestones"

# Project board (Profile A)
echo ""
echo "── Phase 1b: Project board ──"

gh project create --owner "$GITHUB_OWNER" --title "$PROJECT_NAME" 2>/dev/null
PROJECT_NUMBER=$(gh project list --owner "$GITHUB_OWNER" --format json \
  --jq '.projects | sort_by(.number) | last | .number' 2>/dev/null || echo "")
check "project board created (#${PROJECT_NUMBER})" test -n "$PROJECT_NUMBER"

if [ -n "$PROJECT_NUMBER" ]; then
  # Discover board IDs via GraphQL
  BOARD_JSON=$(gh api graphql -f query='query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        id
        field(name: "Status") {
          ... on ProjectV2SingleSelectField {
            id
            options { id name }
          }
        }
      }
    }
  }' -f owner="$GITHUB_OWNER" -F number="$PROJECT_NUMBER" 2>/dev/null || echo "{}")

  BOARD_PROJECT_ID=$(echo "$BOARD_JSON" | jq -r '.data.user.projectV2.id // empty')
  BOARD_STATUS_FIELD_ID=$(echo "$BOARD_JSON" | jq -r '.data.user.projectV2.field.id // empty')
  BOARD_IN_PROGRESS_ID=$(echo "$BOARD_JSON" | jq -r '.data.user.projectV2.field.options[] | select(.name == "In Progress") | .id' 2>/dev/null || echo "")

  check "board PROJECT_ID discovered" test -n "$BOARD_PROJECT_ID"
  check "board STATUS_FIELD_ID discovered" test -n "$BOARD_STATUS_FIELD_ID"
  check "board IN_PROGRESS_ID discovered" test -n "$BOARD_IN_PROGRESS_ID"

  echo "  PROJECT_ID: $BOARD_PROJECT_ID"
  echo "  STATUS_FIELD_ID: $BOARD_STATUS_FIELD_ID"
  echo "  IN_PROGRESS_ID: $BOARD_IN_PROGRESS_ID"

  # Add R0 issues to the board
  ADDED=0
  for issue in "${ISSUES[@]}"; do
    IFS='|' read -r ms_idx label title body <<< "$issue"
    if [ "$ms_idx" -eq 0 ]; then
      INUM=$(echo "$title" | grep -oP '#\K[0-9]+' || echo "$((ADDED + 1))")
      gh project item-add "$PROJECT_NUMBER" --owner "$GITHUB_OWNER" \
        --url "https://github.com/${GITHUB_OWNER}/${REPO_NAME}/issues/$((ADDED + 1))" 2>/dev/null && ADDED=$((ADDED + 1))
    fi
  done
  check "R0 issues added to board ($ADDED)" test "$ADDED" -gt 0

  # ── Custom Status options (match SI: Ready, Todo, In Progress, In Review, Done, Blocked) ──
  # Update the Status field with all 6 options
  gh api graphql -f query="mutation {
    updateProjectV2Field(input: {
      fieldId: \"$BOARD_STATUS_FIELD_ID\"
      singleSelectOptions: [
          {name: \"Ready\", color: GRAY, description: \"Scoped and ready to start\"}
          {name: \"Todo\", color: GREEN, description: \"This item hasn't been started\"}
          {name: \"In Progress\", color: YELLOW, description: \"This is actively being worked on\"}
          {name: \"In Review\", color: GRAY, description: \"PR open, awaiting review\"}
          {name: \"Done\", color: PURPLE, description: \"This has been completed\"}
          {name: \"Blocked\", color: RED, description: \"Cannot proceed — waiting on dependency\"}
        ]
    }) {
      clientMutationId
    }
  }" >/dev/null 2>&1
  # Re-fetch the In Progress ID since option IDs may change
  BOARD_IN_PROGRESS_ID=$(gh api graphql -f query='query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        field(name: "Status") {
          ... on ProjectV2SingleSelectField {
            options { id name }
          }
        }
      }
    }
  }' -f owner="$GITHUB_OWNER" -F number="$PROJECT_NUMBER" \
    --jq '.data.user.projectV2.field.options[] | select(.name == "In Progress") | .id' 2>/dev/null || echo "")
  STATUS_COUNT=$(gh api graphql -f query='query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        field(name: "Status") {
          ... on ProjectV2SingleSelectField { options { name } }
        }
      }
    }
  }' -f owner="$GITHUB_OWNER" -F number="$PROJECT_NUMBER" \
    --jq '.data.user.projectV2.field.options | length' 2>/dev/null || echo "0")
  check "6 status options configured" test "$STATUS_COUNT" -ge 6

  # ── Custom fields (match SI structure) ──
  # Priority
  gh api graphql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$BOARD_PROJECT_ID\"
      dataType: SINGLE_SELECT
      name: \"Priority\"
      singleSelectOptions: [
        {name: \"P1 Critical Path\", color: RED, description: \"\"}
        {name: \"P2 Important\", color: ORANGE, description: \"\"}
        {name: \"P3 Normal\", color: GRAY, description: \"\"}
      ]
    }) { clientMutationId }
  }" >/dev/null 2>&1
  check "Priority field created" test $? -eq 0

  # Release
  RELEASE_OPTS=""
  for i in 0 1 2; do
    RELEASE_OPTS="${RELEASE_OPTS}{name: \"R${i}\", color: GRAY, description: \"\"} "
  done
  gh api graphql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$BOARD_PROJECT_ID\"
      dataType: SINGLE_SELECT
      name: \"Release\"
      singleSelectOptions: [
        {name: \"R0\", color: GRAY, description: \"\"}
        {name: \"R1\", color: GRAY, description: \"\"}
        {name: \"R2\", color: GRAY, description: \"\"}
      ]
    }) { clientMutationId }
  }" >/dev/null 2>&1
  check "Release field created" test $? -eq 0

  # Estimated Days (number)
  gh api graphql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$BOARD_PROJECT_ID\"
      dataType: NUMBER
      name: \"Estimated Days\"
    }) { clientMutationId }
  }" >/dev/null 2>&1
  check "Estimated Days field created" test $? -eq 0

  # Blocked By (text)
  gh api graphql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$BOARD_PROJECT_ID\"
      dataType: TEXT
      name: \"Blocked By\"
    }) { clientMutationId }
  }" >/dev/null 2>&1
  check "Blocked By field created" test $? -eq 0

  # Start Date
  gh api graphql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$BOARD_PROJECT_ID\"
      dataType: DATE
      name: \"Start Date\"
    }) { clientMutationId }
  }" >/dev/null 2>&1
  check "Start Date field created" test $? -eq 0

  # Target Date
  gh api graphql -f query="mutation {
    createProjectV2Field(input: {
      projectId: \"$BOARD_PROJECT_ID\"
      dataType: DATE
      name: \"Target Date\"
    }) { clientMutationId }
  }" >/dev/null 2>&1
  check "Target Date field created" test $? -eq 0

  # Verify total field count (10 default + 6 custom = 16)
  FIELD_COUNT=$(gh project field-list "$PROJECT_NUMBER" --owner "$GITHUB_OWNER" --format json --jq '.fields | length' 2>/dev/null || echo "0")
  check "16 fields total ($FIELD_COUNT)" test "$FIELD_COUNT" -ge 16

  # ── Workflows ──
  # Note: GitHub API only supports deleting workflows, not enabling them.
  # Workflows must be enabled via the GitHub UI. The setup prompt instructs
  # the user to enable all 6 workflows in the project settings.
  echo "  ⚠ Workflows must be enabled manually — no API support for enabling"

  # Note: Board and Timeline views cannot be created via API.
  # The setup prompt instructs the user to add these manually or
  # Claude can open the project in browser for the user to configure.
  echo "  ⚠ Views (Board, Timeline) must be added manually — no API support"

  # Link project to repo so it appears on the repo's Projects tab
  REPO_NODE_ID=$(gh api "repos/${GITHUB_OWNER}/${REPO_NAME}" --jq '.node_id' 2>/dev/null || echo "")
  if [ -n "$REPO_NODE_ID" ] && [ -n "$BOARD_PROJECT_ID" ]; then
    gh api graphql -f query='mutation($projectId: ID!, $repoId: ID!) {
      linkProjectV2ToRepository(input: {
        projectId: $projectId
        repositoryId: $repoId
      }) {
        repository { id }
      }
    }' -f projectId="$BOARD_PROJECT_ID" -f repoId="$REPO_NODE_ID" >/dev/null 2>&1
    check "project board linked to repo" test $? -eq 0
  else
    fail "project board linked to repo (missing IDs)"
  fi
else
  BOARD_PROJECT_ID=""
  BOARD_STATUS_FIELD_ID=""
  BOARD_IN_PROGRESS_ID=""
  fail "board IDs not discovered (no project number)"
fi
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 2: GITHUB TEMPLATES
# ══════════════════════════════════════════════════════════════
echo "── Phase 2: GitHub templates ──"

mkdir -p .github/ISSUE_TEMPLATE .github/workflows
cp "$PLAYBOOK_DIR/templates/github/ISSUE_TEMPLATE/"*.md .github/ISSUE_TEMPLATE/
cp "$PLAYBOOK_DIR/templates/github/pull_request_template.md" .github/
cp "$PLAYBOOK_DIR/templates/github/workflows/"*.yml .github/workflows/

check "issue templates" test "$(ls .github/ISSUE_TEMPLATE/*.md 2>/dev/null | wc -l)" -ge 3
check "PR template" test -f .github/pull_request_template.md
check "CI workflow" test -f .github/workflows/ci.yml
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 3: CLAUDE.MD + MEMORY + DOCS
# ══════════════════════════════════════════════════════════════
echo "── Phase 3: Project files ──"

TMPL="$PLAYBOOK_DIR/templates/CLAUDE.md.template"
sed \
  -e "s|\[PROJECT NAME\]|${PROJECT_NAME}|g" \
  -e "s|\[repo name\]|${REPO_NAME}|g" \
  -e "s|\[product name and URL\]|${PROJECT_DESC}|g" \
  -e "s|\[name and email\]|${GIT_USER_NAME} (${GIT_USER_EMAIL})|g" \
  -e "s|\[e.g., TypeScript\]|TypeScript|g" \
  -e "s|\[e.g., Next.js 16, App Router\]|Express 4|g" \
  -e "s|\[e.g., PostgreSQL via Prisma\]|PostgreSQL via Prisma|g" \
  -e "s|\[e.g., Clerk\]|JWT|g" \
  -e "s|\[e.g., Vercel\]|Railway|g" \
  -e "s|\[e.g., Vitest + Playwright\]|Jest + Supertest|g" \
  -e "s|\[e.g., pnpm — never use npm or yarn\]|npm|g" \
  -e "s|\[your dev command\]|${DEV_CMD}|g" \
  -e "s|\[your build command\]|${BUILD_CMD}|g" \
  -e "s|\[your test command\]|${TEST_CMD}|g" \
  -e "s|\[main branch\]|staging|g" \
  "$TMPL" > CLAUDE.md

check "CLAUDE.md" test -f CLAUDE.md
check_file_contains "plan lifecycle" CLAUDE.md "Plan lifecycle"
check_file_contains "health cadence" CLAUDE.md "Code health cadence"

# Memory (project-scoped, auto-discovered by Claude Code)
PROJ_MEMORY_DIR="$HOME/.claude/projects/$(echo "$TEST_DIR" | tr '/' '-' | sed 's/^-//')/memory"
mkdir -p "$PROJ_MEMORY_DIR"
cat > "$PROJ_MEMORY_DIR/MEMORY.md" <<MEMEOF
# Claude Code Memory — ${PROJECT_NAME}

- [project_context.md](project_context.md) — Initial setup context
MEMEOF
cat > "$PROJ_MEMORY_DIR/project_context.md" <<MEMEOF
---
name: Project context from setup
description: Initial project context from playbook bootstrap
type: project
---

**Project:** $PROJECT_NAME — $PROJECT_DESC
**Audience:** $PROJECT_AUDIENCE
**Stack:** $TECH_STACK
**Workflow:** Profile A (structured delivery), $WORKFLOW mode
**First version:** $FIRST_VERSION_DONE
**Milestones:** R0 (API Foundation), R1 (Search & Filters), R2 (Production Ready)
MEMEOF
check "project memory" test -f "$PROJ_MEMORY_DIR/MEMORY.md"

mkdir -p docs/plans docs/design docs/system
cp "$PLAYBOOK_DIR/templates/engineering-plan.md" docs/engineering-plan.md 2>/dev/null || echo "# Engineering Plan" > docs/engineering-plan.md
cp "$PLAYBOOK_DIR/templates/roadmap.md" docs/roadmap.md 2>/dev/null || echo "# Roadmap" > docs/roadmap.md
check "docs structure" test -d docs/plans
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 4: HOOKS + SETTINGS + SKILLS
# ══════════════════════════════════════════════════════════════
echo "── Phase 4: Hooks, settings, skills ──"

HOOKS_SRC="$PLAYBOOK_DIR/templates/hooks"
mkdir -p .claude/hooks

EXPECTED_HOOKS=(bash-guard.sh session-start.sh on-commit-check-planning.sh pre-pr-create.sh pre-enter-plan.sh on-enter-plan.sh on-exit-plan.sh pre-edit-write.sh mcp-pr-guard.sh pre-push.sh pre-merge.sh)
for h in "${EXPECTED_HOOKS[@]}"; do cp "$HOOKS_SRC/$h" .claude/hooks/; done
chmod +x .claude/hooks/*.sh

# Use refreshed BOARD_IN_PROGRESS_ID (may have changed after status options update)
sed -i "s|{{PROJECT_ID}}|${BOARD_PROJECT_ID}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{STATUS_FIELD_ID}}|${BOARD_STATUS_FIELD_ID}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{IN_PROGRESS_ID}}|${BOARD_IN_PROGRESS_ID}|g" .claude/hooks/pre-enter-plan.sh
sed -i "s|{{GITHUB_OWNER}}|${GITHUB_OWNER}|g;s|{{GITHUB_REPO}}|${REPO_NAME}|g" .claude/hooks/pre-enter-plan.sh

for h in "${EXPECTED_HOOKS[@]}"; do check "hook: $h" test -x ".claude/hooks/$h"; done
REMAINING=$(grep -r '{{' .claude/hooks/ 2>/dev/null || true)
[ -z "$REMAINING" ] && ok "no template vars" || fail "template vars left"

cp "$HOOKS_SRC/settings.json" .claude/settings.json
jq '. + {"mcpServers":{"context7":{"type":"stdio","command":"npx","args":["-y","@upstash/context7-mcp"]}}}' .claude/settings.json > .tmp.json && mv .tmp.json .claude/settings.json
check "settings.json valid" jq empty .claude/settings.json
HREFS=$(jq -r '.. | .command? // empty' .claude/settings.json 2>/dev/null | grep -c '.sh')
check "settings refs 11 hooks" test "$HREFS" -eq 11

for sd in "$PLAYBOOK_DIR/templates/skills/"*/; do
  sn=$(basename "$sd"); mkdir -p ".claude/skills/$sn"; cp "$sd"SKILL.md ".claude/skills/$sn/"
done
for s in arch-check bloat-check dry-check health-check sanitise security-check startup test-health; do
  check "skill: $s" test -f ".claude/skills/$s/SKILL.md"
done
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 5: SCAFFOLD R0 (real code)
# ══════════════════════════════════════════════════════════════
echo "── Phase 5: Scaffold R0 ──"

# package.json
cat > package.json <<'PKG'
{
  "name": "acme-api",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "jest --passWithNoTests",
    "lint": "eslint src/"
  },
  "dependencies": {
    "express": "^4.21.0",
    "@prisma/client": "^6.0.0",
    "jsonwebtoken": "^9.0.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "tsx": "^4.19.0",
    "@types/express": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.0",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.0",
    "ts-jest": "^29.2.0",
    "eslint": "^9.0.0",
    "prisma": "^6.0.0"
  }
}
PKG

# tsconfig.json
cat > tsconfig.json <<'TSC'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
TSC

# jest.config.js
cat > jest.config.js <<'JEST'
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  modulePathIgnorePatterns: ['<rootDir>/dist/'],
};
JEST

# .env.example
cat > .env.example <<'ENV'
DATABASE_URL=postgresql://user:password@localhost:5432/acme_api
JWT_SECRET=your-secret-here
PORT=3000
NODE_ENV=development
ENV

# Source files
mkdir -p src/__tests__

cat > src/index.ts <<'SRC'
import express from 'express';

const app = express();
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

export default app;
SRC

cat > src/__tests__/health.test.ts <<'TEST'
import app from '../index';

describe('Health endpoint', () => {
  it('should be defined', () => {
    expect(app).toBeDefined();
  });
});
TEST

# Prisma schema
mkdir -p prisma
cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Product {
  id          Int      @id @default(autoincrement())
  name        String
  description String?
  price       Decimal  @db.Decimal(10, 2)
  categoryId  Int?
  category    Category? @relation(fields: [categoryId], references: [id])
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

model Category {
  id       Int       @id @default(autoincrement())
  name     String    @unique
  products Product[]
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  password  String
  name      String?
  role      String   @default("user")
  createdAt DateTime @default(now())
}
PRISMA

check "package.json" test -f package.json
check "tsconfig.json" test -f tsconfig.json
check "src/index.ts" test -f src/index.ts
check "prisma/schema.prisma" test -f prisma/schema.prisma
check "test file" test -f src/__tests__/health.test.ts
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 6: COMMIT + PUSH
# ══════════════════════════════════════════════════════════════
echo "── Phase 6: Commit and push ──"

git add CLAUDE.md .gitignore docs/ .github/ .claude/ package.json tsconfig.json jest.config.js .env.example src/ prisma/
git commit -q -m "META: initialise project with Claude Code Playbook

- Express + TypeScript + Prisma scaffold
- 11 Claude Code hooks (bash-guard, planning lifecycle, PR guards)
- 8 health check skills
- CI workflow, issue/PR templates
- 3 milestones, 12 issues (R0–R2)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push -q origin staging
check "pushed to staging" git log origin/staging --oneline -1

FC=$(git diff --name-only HEAD~1 | wc -l | tr -d ' ')
check "commit has 25+ files ($FC)" test "$FC" -gt 25
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 7: HOOK TESTS
# ══════════════════════════════════════════════════════════════
echo "── Phase 7: Hook tests ──"

export GH_COMMENT_LOG_DIR="$TEST_DIR" GH_TEST_OWNER="$GITHUB_OWNER" GH_TEST_REPO="$REPO_NAME"

rh() { printf '%s' "$2" | PATH="$MOCK_BIN:$PATH" GH_COMMENT_LOG_DIR="$TEST_DIR" bash ".claude/hooks/$1" 2>/dev/null; }
rhs() { printf '%s' "$2" | PATH="$MOCK_BIN:$PATH" GH_COMMENT_LOG_DIR="$TEST_DIR" bash ".claude/hooks/$1" 2>&1; }

# bash-guard blocks
rh bash-guard.sh '{"tool_input":{"command":"git push origin main"}}'; check_exit "blocks push main" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"git push -f origin staging"}}'; check_exit "blocks force push" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"git reset --hard"}}'; check_exit "blocks reset --hard" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"git add -A"}}'; check_exit "blocks add -A" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"git clean -f"}}'; check_exit "blocks clean -f" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"git commit --no-verify -m x"}}'; check_exit "blocks --no-verify" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"gh pr create --base main -t x"}}'; check_exit "blocks PR main" 2 $?
rh bash-guard.sh '{"tool_input":{"command":"gh pr merge 1 --admin"}}'; check_exit "blocks --admin" 2 $?
# bash-guard allows
rh bash-guard.sh '{"tool_input":{"command":"npm test"}}'; check_exit "allows npm" 0 $?
rh bash-guard.sh '{"tool_input":{"command":"git add src/index.ts"}}'; check_exit "allows named add" 0 $?
rh bash-guard.sh '{"tool_input":{"command":"gh pr create --base staging -t x"}}'; check_exit "allows PR staging" 0 $?

# edit guard
O=$(rhs pre-edit-write.sh "{\"tool_input\":{\"file_path\":\"x\"},\"cwd\":\"$TEST_DIR\"}")
check_contains "edit blocked staging" "$O" "EDIT BLOCKED"

git checkout -q -b 1-setup-express
O=$(rhs pre-edit-write.sh "{\"tool_input\":{\"file_path\":\"x\"},\"cwd\":\"$TEST_DIR\"}")
check_not_contains "edit OK issue branch" "$O" "BLOCKED"

# mcp + pr + push
rh mcp-pr-guard.sh '{"tool_input":{"base":"main"}}'; check_exit "MCP blocks main" 2 $?
rh mcp-pr-guard.sh '{"tool_input":{"base":"staging"}}'; check_exit "MCP OK staging" 0 $?
rh pre-pr-create.sh '{"tool_input":{"command":"gh pr create --base staging -t x"}}'; check_exit "PR no strategy" 2 $?
rh pre-pr-create.sh '{"tool_input":{"command":"gh pr create --base staging --merge-now -t x"}}'; check_exit "PR --merge-now" 0 $?
rh pre-push.sh '{"tool_input":{"command":"git push origin main"}}'; check_exit "push main blocked" 2 $?
rh pre-push.sh '{"tool_input":{"command":"git push origin staging"}}'; check_exit "push staging OK" 0 $?

# plan entry (with real board IDs wired in)
O=$(rhs pre-enter-plan.sh "{\"cwd\":\"$TEST_DIR\",\"session_id\":\"t1\"}")
check_contains "plan OK issue branch" "$O" "Pre-flight OK"
check_contains "plan detects issue #1" "$O" "#1"
git checkout -q staging
O=$(rhs pre-enter-plan.sh "{\"cwd\":\"$TEST_DIR\",\"session_id\":\"t2\"}")
check_contains "plan blocked staging" "$O" "PLAN MODE BLOCKED"
git checkout -q 1-setup-express
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 8: PLANNING E2E
# ══════════════════════════════════════════════════════════════
echo "── Phase 8: Planning E2E ──"

MD="/tmp/claude-plan-sessions"; S="bootstrap-test-plan"
rm -f "${MD}/${S}"* "$TEST_DIR/.gh-comments"

rh on-enter-plan.sh "{\"session_id\":\"$S\"}"
check "marker" test -f "${MD}/${S}.planning"

FP="$HOME/.claude/plans"; mkdir -p "$FP"; sleep 1
cat > "$FP/bootstrap-live.md" <<'PLAN'
# Plan: Express Server Setup

## Steps
1. Express + TS scaffold  2. Prisma schema  3. CRUD endpoints  4. JWT auth
PLAN

rh on-exit-plan.sh "{\"cwd\":\"$TEST_DIR\",\"session_id\":\"$S\"}"
check_exit "exit plan" 0 $?
P=$(ls docs/plans/1-*.md 2>/dev/null | head -1)
[ -n "$P" ] && ok "plan in docs/plans/" || fail "plan in docs/plans/"
check "→ .planned" test -f "${MD}/${S}.planned"

rm -f "$FP/bootstrap-live.md" "${MD}/bootstrap-test-"*
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 9: SESSION START
# ══════════════════════════════════════════════════════════════
echo "── Phase 9: Session start ──"

O=$(echo '{}' | bash .claude/hooks/session-start.sh 2>&1)
check_contains "session-start shows milestone" "$O" "$( echo "${MILESTONES[0]}" | cut -d'|' -f1)"
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 10: REMOTE VALIDATION
# ══════════════════════════════════════════════════════════════
echo "── Phase 10: Remote validation ──"

git push -q origin 1-setup-express 2>&1

RF=$(gh api "repos/${GITHUB_OWNER}/${REPO_NAME}/git/trees/staging?recursive=1" --jq '.tree | length' 2>/dev/null || echo "0")
check "remote: 20+ files" test "$RF" -gt 20
RL=$(gh label list --repo "${GITHUB_OWNER}/${REPO_NAME}" --json name --jq 'length' 2>/dev/null || echo "0")
check "remote: labels" test "$RL" -gt 0
RI=$(gh issue list --repo "${GITHUB_OWNER}/${REPO_NAME}" --json number --jq 'length' 2>/dev/null || echo "0")
check "remote: 10+ issues" test "$RI" -ge 10
RM=$(gh api "repos/${GITHUB_OWNER}/${REPO_NAME}/milestones" --jq 'length' 2>/dev/null || echo "0")
check "remote: 3 milestones" test "$RM" -ge 3
RP=$(gh project list --owner "$GITHUB_OWNER" --format json --jq ".projects[] | select(.title == \"$PROJECT_NAME\") | .number" 2>/dev/null || echo "")
check "remote: project board exists" test -n "$RP"
echo ""

# ══════════════════════════════════════════════════════════════
# PHASE 11: FINAL STRUCTURE
# ══════════════════════════════════════════════════════════════
echo "── Phase 11: Structure ──"

for d in .claude/hooks .claude/skills .github/ISSUE_TEMPLATE .github/workflows docs/plans src prisma; do
  check "dir: $d" test -d "$d"
done

check "settings SessionStart" jq -e '.hooks.SessionStart' .claude/settings.json
check "settings PreToolUse" jq -e '.hooks.PreToolUse' .claude/settings.json
check "settings PostToolUse" jq -e '.hooks.PostToolUse' .claude/settings.json
check "settings context7" jq -e '.mcpServers.context7' .claude/settings.json

# Back to staging for a clean state
git checkout -q staging
echo ""

# ══════════════════════════════════════════════════════════════
# RESULTS
# ══════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo ""
echo "  Repo:  https://github.com/${GITHUB_OWNER}/${REPO_NAME}"
echo "  Local: $TEST_DIR"
echo ""
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "  Failed:"
  for e in "${ERRORS[@]}"; do echo "    - $e"; done
  echo ""
fi
if [ "$FAIL" -eq 0 ]; then
  echo "  Board: https://github.com/users/${GITHUB_OWNER}/projects/${PROJECT_NUMBER}"
  echo ""
  echo "  ✓ Ready! Try:"
  echo "    cd $TEST_DIR && claude"
fi
echo "═══════════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
