# Minimum Document Set

The setup process creates these documents. The working practices depend on them. Without these, the process breaks.

## The 5 mandatory documents

### 1. `CLAUDE.md` (repo root)

**Created by:** Setup prompt
**Referenced by:** Every session (auto-loaded)
**Contains:** Operating mode, work discipline (permanent behaviours), current sprint (temporal), project identity, tech stack, conventions, trigger table
**Must have these sections:**
- Work discipline — "which release?" gate, document hierarchy
- Current sprint — active release, targets (marked UPDATE)
- Running the project — dev/build/test commands

### 2. `docs/roadmap.md` (or `docs/design/product/release-plan.md`)

**Created by:** Setup prompt (from interview answers about releases)
**Referenced by:** Session start hook, work discipline gate
**Contains:** Release definitions (R0, R1, etc.), what's in each release, what's NOT in each release, target dates, current status
**Must answer:** "What are we working on NOW and what's deferred?"

### 3. `docs/engineering-plan.md` (or `docs/system/engineering/platform-engineering-brief.md`)

**Created by:** Setup prompt (from interview answers about tech stack and current state)
**Referenced by:** Before starting any slice/feature work
**Contains:** What's built, what's not built, tech decisions log, infrastructure costs, critical path
**Must answer:** "What exists in the codebase today?"

### 4. `MEMORY.md` (in memory directory)

**Created by:** Setup prompt
**Referenced by:** Memory system
**Contains:** Index of all memory files — user preferences, project decisions, feedback
**Must exist** even if empty — it's the memory system's table of contents

### 5. `.claude/settings.json`

**Created by:** Setup prompt (from hooks templates)
**Referenced by:** Claude Code runtime
**Contains:** Hook configuration — session start, bash guard
**Must register:** session-start.sh (UserPromptSubmit), bash-guard.sh (PreToolUse:Bash)

## The relationship

```
CLAUDE.md (auto-loaded every session)
  → references roadmap.md ("read before starting work")
  → references engineering-plan.md ("read before touching code")
  → references MEMORY.md (via memory system)

settings.json (hooks)
  → session-start.sh fires → reminds Claude to read roadmap + CLAUDE.md
  → bash-guard.sh fires → blocks destructive git, enforces PR discipline

roadmap.md ← updated when releases ship or plan changes
engineering-plan.md ← updated alongside code changes
MEMORY.md ← updated as decisions are made
CLAUDE.md "Current sprint" ← updated when priorities shift
```

## What the process guarantees

If these 5 documents exist and are accurate:
- Every session starts with context (session-start hook)
- Every piece of work is scoped to a release (work discipline)
- Destructive actions are blocked (bash-guard)
- Decisions persist across sessions (memory)
- Docs stay current with code (pre-merge check in CLAUDE.md)

If ANY of these are missing or stale, the process degrades silently — Claude works without context, scope creeps, docs drift.

## What's NOT required (but recommended)

Everything else is optional enhancement:
- Trigger tables (useful, not mandatory)
- Slice briefs (useful for large projects)
- Persona definitions (useful for multi-user products)
- Ops dashboards (useful for founders)
- CI workflows (useful but stack-specific)
- Health check skills (recommended — installed during setup, see `practices/sanitisation/`)
