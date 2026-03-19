# Pre-Merge Documentation Check

## The rule

Before creating or merging any PR, answer these questions:

1. **Does a doc page exist for what you changed?** If yes, update it in the same PR.
2. **Did you change a public API (props, exports, endpoints)?** Update the relevant doc.
3. **Did you discover a non-obvious gotcha?** Add it to the "Lessons" section.
4. **If none apply:** No doc update needed — but confirm you checked.

## Why this matters

Documentation that's updated alongside code stays accurate. Documentation updated "later" never gets updated.

The cost of checking: 30 seconds.
The cost of stale docs: hours of confusion, wrong decisions, bugs from following outdated patterns.

## This applies to everything

- Direct code changes
- Work done by AI agents
- Background tasks
- Hotfixes

When spawning agents for code work, include this check in the agent's prompt.

## Trigger table pattern

In your CLAUDE.md, maintain a "read before you act" table:

```markdown
| If you're touching... | Read first |
|----------------------|-----------|
| Auth, middleware      | docs/system/auth.md |
| Database, migrations  | docs/system/database.md |
| UI components         | docs/system/components.md |
```

This prevents guessing when documentation exists. Claude reads the relevant doc before making changes, catches patterns and conventions, and stays consistent.
