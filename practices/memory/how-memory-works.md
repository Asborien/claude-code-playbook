# How Claude Code Memory Works

## The problem

Claude Code conversations have a context window. When it fills, older messages are compressed or lost. Strategic decisions, user preferences, and project context disappear.

## The solution

A file-based memory system at `.claude/projects/<path>/memory/`. Claude reads and writes to these files, and they persist across conversations.

## Memory types

### User memories
Information about who you are — role, preferences, expertise, working style.

**When to save:** When Claude learns something about you that should change how it works with you.

**Example:** "Senior backend engineer, new to React. Frame frontend explanations in terms of backend analogues."

### Feedback memories
Corrections you've given Claude. The most important type — prevents repeating the same mistakes.

**When to save:** Any time you correct Claude's approach. These often start with "no, don't do that" or "actually, we should..."

**Format:**
```markdown
---
name: Don't mock the database in tests
description: Integration tests must use real database
type: feedback
---

Integration tests hit a real database, not mocks.

**Why:** Prior incident where mock/prod divergence masked a broken migration.

**How to apply:** When writing tests that touch data, always use the test database.
```

### Project memories
Current state of ongoing work — goals, decisions, deadlines.

**When to save:** When you learn about timelines, who's doing what, or why something was decided.

**Important:** Convert relative dates to absolute dates ("Thursday" → "2026-03-20") so the memory remains useful days later.

### Reference memories
Pointers to external systems — where to find things outside the codebase.

**When to save:** When you learn about dashboards, issue trackers, API endpoints, or external docs.

## MEMORY.md — the index

`MEMORY.md` is an index file that lists all memory files. It's loaded into conversation context automatically. Keep it under 200 lines — it's a table of contents, not a memory itself.

## What NOT to save

- Code patterns (derive from the codebase)
- Git history (use `git log`)
- Debugging solutions (the fix is in the code)
- Anything in CLAUDE.md (already auto-loaded)
- Ephemeral task details (use conversation, not memory)

## Session summaries

At the end of significant sessions, save a `session-YYYY-MM-DD.md` memory with:
- What was built/changed
- Decisions made
- What's next
- Any open questions

This gives the next session a running start.
