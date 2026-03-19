#!/bin/bash
# Claude Code hook: session start enforcement.
# Fires on first user message per day. Reminds Claude to check context
# before starting work.
#
# Uses a sentinel file to avoid repeating on every message.
set -euo pipefail

SENTINEL="/tmp/cc-session-playbook-$(date +%Y%m%d).stamp"

# If sentinel exists for today, exit silently
if [ -f "$SENTINEL" ]; then
  exit 0
fi

touch "$SENTINEL"

cat >&2 <<'CHECKLIST'
═══════════════════════════════════════════════════════════
  SESSION START — PLAYBOOK REPO CHECKS
═══════════════════════════════════════════════════════════

  BEFORE ANY WORK:

  1. Read CLAUDE.md
     → This is a docs/template repo, not an application.

  2. Check git status
     → What branch? Any uncommitted changes?

  3. For ANY work request, ask:
     "Which release is this for?"
     → If not in current scope, log in platform-core.

  4. Do NOT create GitHub milestones, labels, or issues here
     → This repo is tracked via platform-core.

═══════════════════════════════════════════════════════════
CHECKLIST

exit 0
