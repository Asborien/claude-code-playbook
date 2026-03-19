#!/bin/bash
# Claude Code hook: session start enforcement.
# Fires on first user message per day. Reminds Claude to check context
# before starting work.
#
# Uses a sentinel file to avoid repeating on every message.
set -euo pipefail

SENTINEL="/tmp/cc-session-checklist-$(date +%Y%m%d).stamp"

# If sentinel exists for today, exit silently
if [ -f "$SENTINEL" ]; then
  exit 0
fi

touch "$SENTINEL"

cat >&2 <<'CHECKLIST'
═══════════════════════════════════════════════════════════
  SESSION START — MANDATORY CHECKS
═══════════════════════════════════════════════════════════

  BEFORE ANY WORK:

  1. Read the release plan (docs/roadmap.md or equivalent)
     → What release are we in? What's in scope?

  2. Read CLAUDE.md "Current sprint" section
     → What are the current targets?

  3. Check git status
     → What branch? Any uncommitted changes?

  4. For ANY work request, ask:
     "Which release is this for?"
     → If not in current release scope, log as issue.

═══════════════════════════════════════════════════════════
CHECKLIST

exit 0
