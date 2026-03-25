---
name: startup
description: Session initialisation — workspace status, blockers, milestone progress, next task
user_invocable: true
---

# /startup — Session initialisation

Gather workspace state, milestone progress, blockers, and next task — then display a single compact status screen. Execute every data-gathering step, then render the output in the exact format specified.

---

## Step 1: Gather data (parallel where possible)

Run these in parallel:

**1a. Repo state** — current repository:

```bash
git branch --show-current
git status --porcelain | head -10
```

**1b. Active release** — read `CLAUDE.md` in the repo root, extract the `**Active release:**` and `**Target date:**` lines.

**1c. Milestone issues** — query all issues in the active milestone:

```bash
gh issue list --state all --milestone "<milestone>" --json number,title,state,labels --jq '.| sort_by(.number)'
```

**1d. Blockers** — query open blockers in the active milestone:

```bash
gh issue list --state open --label "blocked" --milestone "<milestone>" --json number,title,body --jq '.| sort_by(.number)'
```

**1e. Blocker + next issue details** — for each blocker and the next unblocked issue, fetch the issue body:

```bash
gh issue view <number> --json body,title --jq '.body'
```

## Step 2: Parse blocker dependencies

For each blocker, extract from the issue body:

- `## Blocks` section → parse issue references (`#N`) and/or `Blocks milestone:` lines
- Build a map: `blocker_number → [blocked_issue_numbers]`
- Build the reverse: `blocked_issue_number → blocker_number`

If a blocker has no `## Blocks` section, flag it as malformed.

## Step 3: Identify next task

1. **Blocker** — lowest-numbered open issue with `blocked` label
2. **Next** — lowest-numbered open issue NOT blocked by anything (not in the reverse dependency map, and not labelled `blocked`)

## Step 4: Render the status screen

Use the **exact format below**. This is the complete output — no additional headers, explanations, or markdown outside this format.

### Header

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 🚀 <release name>                    <done> of <total>  <bar>
 📅 <target date> (<N> days)           <repo state>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Progress bar**: Use `▓` for done and `░` for remaining, scaled to ~11 characters total.

**Repo state** (right-aligned):

- Clean on staging: `✅ staging clean`
- Dirty on staging: `⚠️ staging <N> dirty files`
- On an issue branch: `🔨 on <branch-name>`
- On issue branch + dirty: `🔨 on <branch-name> · <N> dirty`

### Issue table

```
   #    St   Dep    Title
  ───  ────  ────  ──────────────────────────────────────────
```

One row per milestone issue, sorted by issue number. Columns:

- **#**: right-aligned issue number
- **St**: status icon
  - `✅` — closed (done)
  - `○` — open, not blocked (todo)
  - `🔒` — open, blocked by another issue (dep column shows blocker)
  - `🚧` — open, IS a blocker (has `blocked` label)
- **Dep**: dependency reference
  - For blocked issues: `#<blocker_number>` (what blocks this)
  - For blockers: `→ #<blocked_number>` (what this blocks — comma-separated if multiple)
  - Empty for done/todo issues
- **Title**: issue title, truncated if needed to fit ~60 chars

### Blocker detail box (only if blockers exist)

```
┌─ 🚧 BLOCKER ───────────────────────────────────────────────┐
│ #<N>  <title>                                               │
│                                                             │
│ ⛓️  Blocks: #<X> (<title of X>)                             │
│                                                             │
│ <2-3 line summary extracted from issue body — first         │
│ paragraph or "What" section>                                │
└─────────────────────────────────────────────────────────────┘
```

Extract the summary from the issue body: use the `## What` section if present, otherwise the first non-empty paragraph. Keep to 2-3 lines max.

### Next task detail box

```
┌─ 👉 NEXT ──────────────────────────────────────────────────┐
│ #<M>  <title>                                              │
│                                                            │
│ <2-3 line summary from issue body>                         │
│                                                            │
│ ⏳ Waiting on: #<N> (blocker)      ← only if blocked       │
└────────────────────────────────────────────────────────────┘
```

If the next task is not blocked, omit the `⏳ Waiting on` line.

### Action prompt

If there is a blocker:

```
► Resolve blocker 🚧 #<N>, or override to 👉 #<M>?
```

If no blockers:

```
► Continue with 👉 #<M>?
```

---

## Rules (always enforced)

- **Task sequencing:** Lowest-numbered open issue is next. Blockers before the work they block — but user can override.
- **Ad-hoc requests:** If the user asks for work not in the milestone, ask: "Which release is this for? Is it on the critical path?" If out of scope, log it as a GitHub issue.
- **Before entering plan mode:** Create the issue branch first (`git checkout -b <number>-<description>`).
- **Before writing code:** Update the issue's acceptance criteria if planning evolved the scope.
- **Commit messages:** Prefix with `FEAT:`, `FIX:`, `DOCS:`, `ENG:`, `META:`. Titles are permanent changelog — be detailed.
- **Docs:** Update docs in the same PR as code changes.
- **No direct push** to main or staging. No force push. No `--no-verify`.

## Creating blockers

Any issue type can be a blocker. When adding the `blocked` label to an issue, you MUST also:

1. Assign it to the **milestone it blocks** (e.g. R0)
2. Add a `## Blocks` section to the issue body with tasklist references:

   ```markdown
   ## Blocks

   - [ ] #4
   - [ ] #5
   ```

   Or for milestone-wide blockers: `Blocks milestone: R0 — [release name]`

3. A blocker without a milestone and `## Blocks` section is malformed — hygiene CI will flag it
