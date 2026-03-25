# Planning Lifecycle

Claude Code has a built-in plan mode (`EnterPlanMode` / `ExitPlanMode`). The playbook adds hooks that turn plan mode into an auditable workflow: every planning session is recorded, versioned, and linked from the GitHub issue it belongs to.

## How it works

### Entering plan mode

1. **`pre-enter-plan.sh`** fires before plan mode starts:
   - Checks you're on an issue branch (not staging/main) — blocks if not
   - If a GitHub Project board is configured: adds the issue to the board and moves it to "In Progress"
2. **`on-enter-plan.sh`** fires after plan mode starts:
   - Creates a marker file (`/tmp/claude-plan-sessions/{SESSION_ID}.planning`) to track that planning is active

### During plan mode

Claude explores the codebase, designs an approach, and writes a plan file. The plan file lives in `~/.claude/plans/` (Claude's internal directory). You discuss and refine the plan in conversation.

### Exiting plan mode

**`on-exit-plan.sh`** fires after plan mode ends:

1. Finds the plan file (newer than the planning marker, or most recent if no marker)
2. Copies it to `docs/plans/{issue-number}-{description}.md`
3. For v2+ plans: prepends an addendum header linking to the previous version
4. Commits the plan file to the repo
5. Posts a GitHub issue comment with a link to the plan on the branch

If no plan was produced (e.g., you entered and immediately exited), it posts an "exited without a plan" comment instead.

### Committing without planning

If code is committed without a planning session, **`on-commit-check-planning.sh`** posts a "scope accepted as-is" comment on the GitHub issue. This is informational — it doesn't block the commit. It creates an audit trail showing that the existing scope was accepted without further planning.

## Plan versioning

Re-entering plan mode for the same issue creates a new version:

- First plan: `42-auth-flow.md`
- Second plan: `42-auth-flow-v2.md` (with addendum header linking to v1)
- Third plan: `42-auth-flow-v3.md` (with addendum header linking to v2)

Each version is an immutable snapshot. Previous versions are never overwritten.

## Why this matters

Without this lifecycle:
- Plans exist only in Claude's context window and vanish when the session ends
- There's no record of what was planned vs what was built
- Scope changes happen silently — no one knows the plan evolved

With this lifecycle:
- Every plan is committed to the repo (survives session end, context compression)
- GitHub issues have a traceable history: plan → code → PR
- Scope changes are versioned — you can see how the plan evolved
- "No planning" is explicitly recorded, not invisible

## Dependencies

- **Required:** `gh` CLI, `jq`, `git`
- **Optional:** GitHub Project board (for automatic "In Progress" status moves)
- **Not required in v1:** `pandoc`, Chrome (PDF generation is a future module)
