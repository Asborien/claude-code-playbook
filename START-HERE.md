# Start Here

You have 2 minutes. Here's what this is and what to do.

## What is this?

A set of working practices for building software with [Claude Code](https://claude.com/claude-code). Not a tutorial — a playbook. Extracted from a production startup that ships daily.

These practices solve real problems:
- Claude forgetting decisions between sessions
- Scope creeping because there's no plan to reference
- Documentation drifting from code
- Context getting lost when conversations compress
- Work happening without traceability

## Who is this for?

Developers using Claude Code who want:
- Consistent, repeatable results across sessions
- Strategic context that survives conversation resets
- Git discipline that works with AI-assisted development
- A release → milestone → issue hierarchy that keeps work focused

## How to use it

### Option A: Guided setup (recommended)

1. Open your project in Claude Code
2. Copy the contents of `SETUP-PROMPT.md` from this repo
3. Paste it into Claude Code as your first message
4. Claude will read this playbook and configure your project

### Option B: Manual setup

1. Copy `templates/CLAUDE.md.template` to your repo root as `CLAUDE.md`
2. Create a `.claude/` directory for memory files
3. Read through `practices/` and adopt what fits your project
4. Set up git hooks from `templates/pre-commit.example`

## What's in the box

```
templates/          Starter files — copy and adapt
practices/          The playbook — process documentation
  memory/           How Claude's memory system works
  git-workflow/     Branch strategy, commits, PRs
  release-management/ Releases → milestones → issues
  testing/          E2E patterns, viewport testing
  docs-alongside-code/ Keep docs current with code
  quality/          Pre-push audits, observability
  founder-ops/      Operational dashboards (optional)
extras/             Power-user tools — screenshots, CI, MCP servers
```

## Principles

1. **CLAUDE.md is the constitution.** It loads every session. Put critical context there.
2. **Memory survives compression.** Strategic decisions go in memory files, not just conversation.
3. **Releases, not features.** Every piece of work belongs to a release. If it doesn't, it gets an issue.
4. **Docs alongside code.** If you change code, update the docs in the same commit.
5. **Enforce, don't remember.** Use hooks and automation, not willpower.
