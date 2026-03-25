# Scope Discipline

AI makes scope creep worse, not better. Claude can implement a 10-minute idea in 30 seconds — which means unplanned work sneaks in faster than you can notice it. Release planning is the guardrail.

## The rule

Every piece of work must answer: **"Which release is this for? Is it on the critical path?"**

If the answer is "it's not in the current release" — log it as a GitHub issue and move on. Don't build it now, no matter how quick it seems.

## Task sequencing

Within a release:
1. **Blockers first** — lowest-numbered open issue with the `blocked` label
2. **Next task** — lowest-numbered open issue not blocked by anything
3. **User can override** — but the override is explicit, not accidental

The `/startup` skill surfaces this automatically at session start: it queries the milestone, identifies blockers and their dependencies, and recommends the next task.

## How it's enforced

### Mechanically (hooks)

| Hook | What it does |
|------|-------------|
| `session-start.sh` | Auto-runs on load. Shows milestone progress, blockers, next task. |
| `pre-edit-write.sh` | Blocks edits on staging/main — forces issue branch creation first |
| `pre-enter-plan.sh` | Blocks plan mode without an issue branch |
| `on-commit-check-planning.sh` | Records "scope accepted as-is" when committing without planning |

### Conversationally (CLAUDE.md)

The CLAUDE.md template includes:
- "Before starting ANY work, ask: Which release is this for?"
- "If it's not in the current release scope, log it as a GitHub issue and move on."
- The `/startup` skill enforces task sequencing by showing what's next

## Ad-hoc requests

When the user asks for work not in the current milestone:

1. Ask: "Which release is this for? Is it on the critical path?"
2. If out of scope: create a GitHub issue, assign to the correct milestone, move on
3. If on the critical path but not yet tracked: create the issue, add it to the milestone, then proceed

The goal is not to prevent work — it's to make sure every piece of work is tracked and scoped before it starts.

## Engineering work

Developer tooling, workflow improvements, and cross-cutting infrastructure (CI, linting, refactoring) don't belong in product milestones. Track them as GitHub issues with the `engineering` label and no milestone. They're merged independently.

## The "NOT included" list

Every release should have an explicit "NOT included" section in the roadmap. This is more valuable than the "included" list — it prevents the conversation about whether feature X belongs in this release. If it's on the NOT list, the decision is already made.
