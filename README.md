# Claude Code Playbook

Opinionated working practices for building software with [Claude Code](https://claude.com/claude-code).

Not a tutorial. Not a boilerplate. A **playbook** — tested practices extracted from a production startup that ships daily.

## Quick start

1. Open your project in Claude Code
2. Copy the contents of [`SETUP-PROMPT.md`](SETUP-PROMPT.md)
3. Paste it as your first message
4. Claude configures your project using these practices

Or read [`START-HERE.md`](START-HERE.md) for the manual approach.

## What's in the box

### Core practices

| Practice | What it solves |
|---|---|
| [Memory system](practices/memory/how-memory-works.md) | Decisions lost between sessions |
| [Release hierarchy](practices/release-management/release-hierarchy.md) | Scope creep, no release plan |
| [Branch strategy](practices/git-workflow/branch-strategy.md) | Messy git history, no preview |
| [Pre-push audit](practices/quality/pre-push-audit.md) | Quality drift on each push |
| [Docs alongside code](practices/docs-alongside-code/pre-merge-doc-check.md) | Documentation that's always stale |

### Templates

| File | Purpose |
|---|---|
| [CLAUDE.md.template](templates/CLAUDE.md.template) | Starter CLAUDE.md — copy and adapt |
| [MEMORY.md.template](templates/MEMORY.md.template) | Memory index file |

### Extras (optional)

Power-user tools for screenshots, CI watching, responsive testing, and more. See [`extras/`](extras/).

## Principles

1. **CLAUDE.md is the constitution.** It loads every session. Critical context goes there.
2. **Memory survives compression.** Strategic decisions go in files, not just conversation.
3. **Releases, not features.** Every piece of work belongs to a release.
4. **Docs alongside code.** Change code → update docs. Same commit.
5. **Enforce, don't remember.** Hooks and automation over willpower.

## Origin

Extracted from [Certified Coach](https://www.certified-coach.com) — a sport-agnostic coaching credentials platform. 472+ commits, 250+ issues, used daily in production development.

## Contributing

This is an opinionated playbook, not a community framework. If you've found practices that work well with Claude Code, open an issue to discuss — but we're selective about what goes in. Every practice must be tested in production use.

## License

MIT
