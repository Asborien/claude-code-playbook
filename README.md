# Claude Code Playbook

Opinionated working practices for building software with [Claude Code](https://claude.com/claude-code).

## Getting started

**You need:** Claude Code installed. That's it.

```bash
# 1. Clone this playbook
git clone https://github.com/Certified-Coach/claude-code-playbook.git ~/claude-code-playbook

# 2. Create your project directory
mkdir my-project && cd my-project

# 3. Open Claude Code
claude
```

Then paste the setup prompt from [`SETUP-PROMPT.md`](SETUP-PROMPT.md). Claude will walk you through everything:

- Installing prerequisites (git, gh, node — whatever you're missing)
- Creating and configuring a GitHub repo
- Setting up branches, labels, milestones, issue templates
- Creating your CLAUDE.md, memory system, and documentation structure
- Building your first roadmap and issue backlog
- Making your first commit

If you prefer to set things up manually, see [`PREREQUISITES.md`](PREREQUISITES.md) then [`START-HERE.md`](START-HERE.md).

## What you get after setup

| Artifact | What it is |
|---|---|
| GitHub repo | Created, with staging branch and PR workflow |
| Project board | Kanban dashboard for issue tracking |
| Milestones | R0, R1, R2 with target dates |
| Labels | 10 standard labels (bug, enhancement, engineering, etc.) |
| Issue templates | Feature, bug, engineering — pre-formatted |
| PR template | Checklist: tests, docs, audit, issue reference |
| CI workflow | Quality checks on push/PR (adapted to your stack) |
| CLAUDE.md | Configured for your project — loaded every session |
| Memory system | Persistent decisions, context, and preferences |
| Git hooks | Pre-commit quality gate |
| Engineering plan | Current state, release mapping |
| Roadmap | Releases, timeline, audience rollout |
| Starter issues | 5-10 issues created in GitHub |

See [`CHEAT-SHEET.md`](CHEAT-SHEET.md) for what you can tell Claude after setup.

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

- [CLAUDE.md template](templates/CLAUDE.md.template) — starter project constitution
- [Engineering plan](templates/engineering-plan.md) — release mapping and tech decisions
- [Roadmap](templates/roadmap.md) — releases, timeline, audiences
- [GitHub templates](templates/github/) — issues, PRs, CI workflows, labels, setup script

### Extras

Power-user tools for screenshots, CI watching, responsive testing. See [`extras/`](extras/).

## Principles

1. **CLAUDE.md is the constitution.** It loads every session. Critical context goes there.
2. **Memory survives compression.** Strategic decisions go in files, not just conversation.
3. **Releases, not features.** Every piece of work belongs to a release.
4. **Docs alongside code.** Change code → update docs. Same commit.
5. **Enforce, don't remember.** Hooks and automation over willpower.

## Important notes

- **This is opinionated.** These practices work for us. They may not all work for you. Adopt what fits, ignore what doesn't.
- **Claude Code is required.** This playbook is designed specifically for [Claude Code](https://claude.com/claude-code) by Anthropic. It will not work with other AI coding tools without adaptation.
- **No warranty.** This is provided as-is. See [LICENSE](LICENSE).
- **Not affiliated with Anthropic.** This is a community resource, not an official Anthropic product.

## Author

Created and maintained by [Martin Dean](https://github.com/Asborien) ([@Asborien](https://github.com/Asborien)).

Extracted from [Certified Coach](https://www.certified-coach.com) — a sport-agnostic coaching credentials platform. 472+ commits, 250+ issues, built and shipped daily with Claude Code.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: open an issue first, practices must be production-tested.

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 Martin Dean / Certified Coach
