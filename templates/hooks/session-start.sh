#!/bin/bash
# Claude Code hook: SessionStart (fires once per session, 2.1.83+)
# Gathers workspace state and renders the startup status screen.
# stdout goes to Claude as context on the first user message.
set -euo pipefail

# ── Gather data ───────────────────────────────────────────
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Read active milestone from CLAUDE.md
CLAUDE_MD="CLAUDE.md"
MILESTONE=""
TARGET_DATE=""
if [ -f "$CLAUDE_MD" ]; then
  MILESTONE=$(grep -oP '(?<=\*\*Active release:\*\* ).*' "$CLAUDE_MD" 2>/dev/null | head -1 || echo "")
  TARGET_DATE=$(grep -oP '(?<=\*\*Target date:\*\* ).*' "$CLAUDE_MD" 2>/dev/null | head -1 || echo "")
fi

# If CLAUDE.md doesn't have a milestone, try the first open GitHub milestone
if [ -z "$MILESTONE" ] || echo "$MILESTONE" | grep -q '^\['; then
  MILESTONE=$(gh api repos/:owner/:repo/milestones --jq '.[0].title' 2>/dev/null || echo "")
  if [ -z "$TARGET_DATE" ] || echo "$TARGET_DATE" | grep -q '^\['; then
    TARGET_DATE=$(gh api repos/:owner/:repo/milestones --jq '.[0].due_on // "No target date"' 2>/dev/null || echo "No target date")
  fi
fi

[ -z "$MILESTONE" ] && { echo "No milestone found — skipping startup."; exit 0; }

# Discover repo and project board URLs
REPO_URL=$(gh repo view --json url --jq '.url' 2>/dev/null || echo "")
OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
OWNER_TYPE=$(gh repo view --json owner --jq '.owner.type' 2>/dev/null || echo "User")
REPO_NAME_SHORT=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")

# Find the project board linked to this repo
if [ "$OWNER_TYPE" = "Organization" ]; then
  BOARD_URL=$(gh project list --owner "$OWNER" --format json \
    --jq ".projects[] | select(.title | test(\"$REPO_NAME_SHORT\"; \"i\")) | .url" 2>/dev/null | head -1 || echo "")
else
  BOARD_URL=$(gh project list --owner "$OWNER" --format json \
    --jq ".projects[] | select(.title | test(\"$REPO_NAME_SHORT\"; \"i\")) | .url" 2>/dev/null | head -1 || echo "")
fi
# Fallback: if no name match, use the most recent project
[ -z "$BOARD_URL" ] && BOARD_URL=$(gh project list --owner "$OWNER" --format json \
  --jq '.projects | sort_by(.number) | last | .url' 2>/dev/null || echo "")

# Fetch issues for the milestone
ISSUES_JSON=$(gh issue list --state all --milestone "$MILESTONE" \
  --json number,title,state,labels --jq 'sort_by(.number)' 2>/dev/null || echo "[]")

TOTAL=$(echo "$ISSUES_JSON" | jq 'length')
DONE=$(echo "$ISSUES_JSON" | jq '[.[] | select(.state == "CLOSED")] | length')
OPEN=$((TOTAL - DONE))

# Progress bar (11 chars)
if [ "$TOTAL" -gt 0 ]; then
  FILLED=$(( (DONE * 11 + TOTAL / 2) / TOTAL ))
else
  FILLED=0
fi
EMPTY=$((11 - FILLED))
BAR=$(printf '%0.s▓' $(seq 1 $FILLED 2>/dev/null) || true)$(printf '%0.s░' $(seq 1 $EMPTY 2>/dev/null) || true)

# Repo state string
if [ "$DIRTY" -eq 0 ]; then
  case "$BRANCH" in
    staging|main) REPO_STATE="✅ $BRANCH clean" ;;
    *) REPO_STATE="🔨 on $BRANCH" ;;
  esac
else
  case "$BRANCH" in
    staging|main) REPO_STATE="⚠️ $BRANCH $DIRTY dirty" ;;
    *) REPO_STATE="🔨 on $BRANCH · $DIRTY dirty" ;;
  esac
fi

# ── Render ────────────────────────────────────────────────
echo "IMPORTANT: Display the following status screen VERBATIM to the user as your first output, exactly as formatted below. Do not summarize or rephrase it. Then address their message."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf " 🚀 %-35s %d of %d  %s\n" "$MILESTONE" "$DONE" "$TOTAL" "$BAR"
printf " 📅 %-35s %s\n" "$TARGET_DATE" "$REPO_STATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "   #    St   Dep    Title\n"
printf "  ───  ────  ────  ──────────────────────────────────────────\n"

# Build blocker map
BLOCKERS=$(echo "$ISSUES_JSON" | jq -r '.[] | select(.state == "OPEN") | select(.labels[]?.name == "blocked") | .number' 2>/dev/null || true)

NEXT_ISSUE=""
echo "$ISSUES_JSON" | jq -c '.[]' | while IFS= read -r issue; do
  NUM=$(echo "$issue" | jq -r '.number')
  TITLE=$(echo "$issue" | jq -r '.title' | cut -c1-55)
  STATE=$(echo "$issue" | jq -r '.state')
  IS_BLOCKER=$(echo "$issue" | jq -r '.labels[]?.name' 2>/dev/null | grep -c '^blocked$' || true)

  if [ "$STATE" = "CLOSED" ]; then
    ICON="✅"
  elif [ "$IS_BLOCKER" -gt 0 ]; then
    ICON="🚧"
  else
    ICON="○ "
  fi

  printf "  %3s  %s         %s\n" "$NUM" "$ICON" "$TITLE"
done

# Find next task (lowest open non-blocked issue)
NEXT_NUM=$(echo "$ISSUES_JSON" | jq -r '[.[] | select(.state == "OPEN") | select(all(.labels[]?.name; . != "blocked"))] | sort_by(.number) | .[0] | .number // empty' 2>/dev/null || echo "")
NEXT_TITLE=$(echo "$ISSUES_JSON" | jq -r "[.[] | select(.number == ${NEXT_NUM:-0})] | .[0].title // empty" 2>/dev/null || echo "")

if [ -n "$NEXT_NUM" ]; then
  # Fetch issue body for summary
  NEXT_BODY=$(gh issue view "$NEXT_NUM" --json body --jq '.body' 2>/dev/null | head -3 || echo "")
  echo ""
  echo "┌─ 👉 NEXT ──────────────────────────────────────────────────┐"
  printf "│ #%-3s %-55s │\n" "$NEXT_NUM" "$NEXT_TITLE"
  echo "│                                                            │"
  if [ -n "$NEXT_BODY" ]; then
    echo "$NEXT_BODY" | head -2 | while IFS= read -r line; do
      printf "│ %-58s │\n" "$(echo "$line" | cut -c1-58)"
    done
  fi
  echo "└────────────────────────────────────────────────────────────┘"
  echo ""
  echo "► Continue with 👉 #${NEXT_NUM}?"
fi

# Links
echo ""
[ -n "$REPO_URL" ] && echo "  Repo:  $REPO_URL"
[ -n "$BOARD_URL" ] && echo "  Board: $BOARD_URL"

echo ""
echo "After displaying the above status screen verbatim, address the user's message."
