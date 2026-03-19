#!/bin/bash
# Claude Code bash guard — prevents destructive and undisciplined actions.
# Adapted for the playbook repo: no staging branch, push to main is allowed.

INPUT=$(cat 2>/dev/null) || true
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true
[ -z "$COMMAND" ] && exit 0

# Strip heredoc content to avoid false positives on commit messages
CMDS=$(printf '%s' "$COMMAND" | sed '/<<.*EOF/,/^EOF/d; /<<.*HEREDOC/,/^HEREDOC/d' 2>/dev/null) || CMDS="$COMMAND"

# ── Git safety ─────────────────────────────────────────────────

# Block force push (destroys history)
if echo "$CMDS" | grep -qE '\bgit push\b' 2>/dev/null; then
  if echo "$CMDS" | grep -qE 'git push.*(-f|--force)\b' 2>/dev/null; then
    echo "BLOCKED: Never force push. This destroys history." >&2
    exit 2
  fi
fi

# Block skipping pre-commit hooks
if echo "$CMDS" | grep -qE '\bgit commit\b' 2>/dev/null; then
  if echo "$CMDS" | grep -qE '\-\-no-verify' 2>/dev/null; then
    echo "BLOCKED: Never skip pre-commit hooks. Fix the issue instead." >&2
    exit 2
  fi
fi

# Block destructive git operations
if echo "$CMDS" | grep -qE '\bgit reset\s+--hard\b' 2>/dev/null; then
  echo "BLOCKED: git reset --hard destroys uncommitted work. Use git stash or targeted reset." >&2
  exit 2
fi
if echo "$CMDS" | grep -qE '\bgit (checkout|restore)\s+\.\s*$' 2>/dev/null; then
  echo "BLOCKED: This discards all local changes. Restore specific files instead." >&2
  exit 2
fi
if echo "$CMDS" | grep -qE '\bgit clean\s+-f' 2>/dev/null; then
  echo "BLOCKED: git clean -f deletes untracked files permanently." >&2
  exit 2
fi

# Force staging specific files (no git add -A or git add .)
if echo "$CMDS" | grep -qE '\bgit add\s+(-A|--all)\b' 2>/dev/null || \
   echo "$CMDS" | grep -qE '\bgit add \.$' 2>/dev/null || \
   echo "$CMDS" | grep -qE '\bgit add \. ' 2>/dev/null; then
  echo "BLOCKED: Stage specific files by name." >&2
  exit 2
fi

# Block bypassing branch protection
if echo "$CMDS" | grep -qE '\bgh pr merge\b' 2>/dev/null; then
  if echo "$CMDS" | grep -qE '\-\-admin' 2>/dev/null; then
    echo "BLOCKED: Never use --admin to bypass branch protection. Use --auto to queue after CI." >&2
    exit 2
  fi
fi

exit 0
