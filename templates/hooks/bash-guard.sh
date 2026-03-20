#!/bin/bash
# Claude Code bash guard — prevents destructive and undisciplined actions.
# Place in .claude/hooks/bash-guard.sh and register in .claude/settings.json.
#
# ADAPT: Review each rule and adjust to your workflow. Remove rules that
# don't apply. Add project-specific rules as needed.
#
# This hook fires on every Bash tool call. It reads the command from
# Claude's JSON input and blocks or warns based on pattern matching.

INPUT=$(cat 2>/dev/null) || true
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true
[ -z "$COMMAND" ] && exit 0

# Strip heredoc content to avoid false positives on commit messages
CMDS=$(printf '%s' "$COMMAND" | sed '/<<.*EOF/,/^EOF/d; /<<.*HEREDOC/,/^HEREDOC/d' 2>/dev/null) || CMDS="$COMMAND"

# ── Git safety ─────────────────────────────────────────────────

# Block push to main/master (use staging → main promotion workflow)
if echo "$CMDS" | grep -qE '\bgit push\b' 2>/dev/null; then
  if echo "$CMDS" | grep -qE 'git push.*(origin )?(main|master)\b' 2>/dev/null; then
    echo "BLOCKED: Never push directly to main/master. Use the promotion workflow." >&2
    exit 2
  fi
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

# ── PR discipline ──────────────────────────────────────────────

# ADAPT: Change 'staging' to your integration branch name
if echo "$CMDS" | grep -qE '\bgh pr create\b' 2>/dev/null; then
  if echo "$CMDS" | grep -qE '\-\-base (main|master)\b' 2>/dev/null; then
    echo "BLOCKED: PRs must target staging, not main." >&2
    exit 2
  fi
  if ! echo "$CMDS" | grep -qE '\-\-base staging' 2>/dev/null; then
    echo "BLOCKED: Missing --base staging." >&2
    exit 2
  fi
fi

# Block bypassing branch protection
if echo "$CMDS" | grep -qE '\bgh pr merge\b' 2>/dev/null; then
  if echo "$CMDS" | grep -qE '\-\-admin' 2>/dev/null; then
    echo "BLOCKED: Never use --admin to bypass branch protection. Use --auto to queue after CI." >&2
    exit 2
  fi
fi

# ── Release health gate ──────────────────────────────────────
# Block git tag if no sanitisation log exists with final measurements
if echo "$CMDS" | grep -qE '\bgit tag\b' 2>/dev/null; then
  if [ ! -f "SANITISATION_LOG.md" ]; then
    echo "WARNING: No SANITISATION_LOG.md found. Consider running /health-check before tagging a release." >&2
    # Note: This is a warning, not a block. Remove 'exit 2' below to make it a hard block.
    # exit 2
  fi
fi

exit 0
