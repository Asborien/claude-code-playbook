#!/bin/bash
# GitHub project setup — run after creating your repo
# Usage: bash setup-github.sh owner/repo
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - repo already created on GitHub
#
# What this does:
#   1. Creates standard labels
#   2. Copies issue templates and PR template
#   3. Copies CI and hygiene workflows
#   4. Creates a staging branch
#   5. Creates initial milestones (R0, R1, R2)

set -e

REPO="${1:?Usage: bash setup-github.sh owner/repo}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Setting up GitHub project: $REPO"

# ── 1. Labels ──────────────────────────────────────────────────
echo ""
echo "Creating labels..."
while IFS= read -r label; do
  name=$(echo "$label" | jq -r '.name')
  color=$(echo "$label" | jq -r '.color')
  desc=$(echo "$label" | jq -r '.description')
  gh label create "$name" --color "$color" --description "$desc" --repo "$REPO" 2>/dev/null && echo "  ✓ $name" || echo "  - $name (exists)"
done < <(jq -c '.[]' "$SCRIPT_DIR/labels.json")

# ── 2. Copy templates ─────────────────────────────────────────
echo ""
echo "Copying issue and PR templates..."
mkdir -p .github/ISSUE_TEMPLATE .github/workflows
cp "$SCRIPT_DIR/ISSUE_TEMPLATE/"*.md .github/ISSUE_TEMPLATE/
cp "$SCRIPT_DIR/pull_request_template.md" .github/
echo "  ✓ Issue templates (feature, bug, engineering)"
echo "  ✓ PR template"

# ── 3. Copy workflows ─────────────────────────────────────────
echo ""
echo "Copying CI workflows..."
cp "$SCRIPT_DIR/workflows/"*.yml .github/workflows/
echo "  ✓ ci.yml (quality checks — edit to match your stack)"
echo "  ✓ hygiene.yml (auto-check issue/PR metadata)"

# ── 4. Staging branch ─────────────────────────────────────────
echo ""
echo "Creating staging branch..."
git checkout -b staging 2>/dev/null && echo "  ✓ staging branch created" || echo "  - staging branch exists"
git push -u origin staging 2>/dev/null && echo "  ✓ pushed to origin" || echo "  - already pushed"
git checkout staging

# ── 5. Initial milestones ─────────────────────────────────────
echo ""
echo "Creating milestones..."
for milestone in "R0 — Setup & Foundation" "R1 — First Release" "R2 — Growth"; do
  gh api "repos/$REPO/milestones" --method POST -f title="$milestone" 2>/dev/null && echo "  ✓ $milestone" || echo "  - $milestone (exists)"
done

echo ""
echo "Done! Next steps:"
echo "  1. Edit .github/workflows/ci.yml for your tech stack"
echo "  2. Create issues: gh issue create --title 'FEAT: ...' --label enhancement --milestone 'R0 — Setup & Foundation'"
echo "  3. Start building!"
