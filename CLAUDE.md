# CLAUDE.md — Claude Code Playbook

This file is loaded automatically by Claude Code at the start of every session.
**Keep it accurate and concise.** Update it whenever significant state changes.

---

## Operating mode

Execute tasks fully and autonomously. Narrate steps and share output as normal.
Do not pause mid-task to ask for confirmation or approval — complete the task, then report back.

---

## Current release + targets

**Active release:** Tracked via platform-core milestones (this repo has no independent release cycle)

**Before starting ANY work, ask:** "Which release is this for? Is it on the critical path?"
If it's not in the current release scope, log it as an issue in platform-core, not here.

---

## Project identity

- **Repo:** claude-code-playbook
- **Product:** Public template for Claude Code working practices
- **Owner:** Martin Dean (martin@certified-coach.com)

---

## What this repo is

A documentation and template repository. There is no application, no build step, no dev server, no tests. All content is Markdown files organised into practices, templates, and context.

---

## Key conventions

- **Format:** Markdown files only — no code, no config beyond Claude Code's own
- **Headings:** Clear, scannable — frontload the noun, not the verb
- **Tone:** Direct, practical, no fluff — extracted from production use
- **Examples:** Generic, not project-specific — readers adapt to their own stack
- **Commit prefix:** Use descriptive commit messages (see git log for style)

---

## GitHub workflow

- **Push to main** — no staging branch, no PR workflow for this repo
- **This repo is maintained alongside platform-core** — no independent milestones, labels, or issue tracking here
- **Commit message format:** Descriptive, prefixed where useful (META:, DOCS:, etc.)

---

## Docs lookup — read BEFORE you act

| If you're touching... | Read first |
|----------------------|-----------|
| Practices | `practices/` folder — understand the existing structure |
| Templates | `templates/` folder — follow the established format |
| Setup flow | `START-HERE.md` and `SETUP-PROMPT.md` |
| Contributing | `CONTRIBUTING.md` |
