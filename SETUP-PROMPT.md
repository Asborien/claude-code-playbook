# Setup Prompt

Copy everything below the line and paste it into Claude Code.

**Requires Claude Code 2.1.83 or later** (uses `SessionStart` hook event).

---

I'd like you to set up a new project using the Claude Code Playbook at ~/claude-code-playbook

Work through these phases in order. Complete each phase before moving to the next. Ask me questions when you need my input. If anything fails, explain what went wrong and how to fix it.

## Phase 0: Environment check

Ask what programming language and framework the project uses. Then only check for the tools relevant to that stack (e.g., Node.js projects need node/pnpm, Python projects need python/pip, Go projects need go, etc.). Don't assume Node.js.

Check what's installed and set up anything missing:

1. **Claude Code:** Run `claude --version`. Must be 2.1.83 or later. If older, run `claude update`.
2. **Git:** Run `git --version`. If not installed, guide me through installing it for my OS.
3. **GitHub CLI:** Run `gh --version`. If not installed, guide me through:
   - Installing gh (brew install gh / apt install gh / etc.)
   - Authenticating: `gh auth login` (walk me through the prompts)
   - Verify: `gh auth status`
4. **jq:** Run `jq --version`. If not installed: `sudo apt install jq` or `brew install jq`. Required by all Claude Code hooks.
5. **Language runtime and package manager:** Based on the stack, check for the relevant tools (e.g., `node --version` and `pnpm --version` for Node.js, `python --version` and `pip --version` for Python, `go version` for Go). If not installed, guide me through installing them.
6. **Git config:** Check `git config user.name` and `git config user.email`. If not set, ask me for my name and email and configure them.

Report what was found and what was installed.

## Phase 1: Interview

Ask me these questions one at a time. Wait for my answer before moving on:

1. What is this project called? (one word or short name for the repo)
2. In one sentence, what does it do?
3. Who is it for? (the target users)
4. Public or private repo?
5. What tech stack? (if you're unsure, tell me what you're building and I'll recommend one)
6. Are you working solo or in a team?
7. Will this project ship releases to users, or is it internal/documentation/config-only?
8. Do you have existing documents to feed in? (strategy docs, feature lists, research, wireframes, business plans — anything)
9. What does "done" look like for the first version? What's the first thing users should be able to do?

## Phase 1b: Workflow profile

Based on the interview answers, determine which workflow profile fits this project. Present the two options, explain what each includes, and recommend one — but let me choose.

### Profile A: Structured delivery

**Use when:** The project ships releases, has multiple concerns in flight, or benefits from PR-based review — regardless of team size. A solo developer building a SaaS product needs this just as much as a team of five.

Includes:
- **Staging branch** — `feature/ → staging → main` promotion workflow
- **PR workflow** — all changes go through pull requests targeting staging
- **Full hook suite** — bash-guard, planning lifecycle, edit guard, PR guards, push/merge checklists
- **Milestones and labels** — release tracking via GitHub milestones
- **Issue templates, project board, and board automation**

### Profile B: Direct push

**Use when:** The project is simple enough that PRs add overhead without value — documentation repos, config-only repos, internal tools with no deployment pipeline, or early prototypes that haven't reached release cadence yet.

Includes:
- **Push to main** — no staging branch, no PR workflow
- **Reduced hook suite** — keeps destructive-action guards and health check skills, but removes staging/PR rules, dead-branch guard, planning lifecycle hooks, and edit guard
- **No milestones or labels** (optional — can add later)
- **No issue templates or project board** (optional — can add later)

**Note:** Profile B projects can upgrade to Profile A later. If the project grows in complexity or starts shipping releases, re-run the relevant Phase 2 steps to add staging, labels, and milestones.

### What both profiles share

- CLAUDE.md as the constitution
- Memory system
- Session-start hook (auto-runs on load)
- Engineering plan and roadmap
- All 8 health check skills (/health-check, /bloat-check, /dry-check, /security-check, /arch-check, /test-health, /startup, /sanitise)
- Commit message prefixes
- Context7 MCP server

### Solo vs team

If working in a team (Q6), PRs will require a reviewer before merge. If solo, PRs can be auto-merged after CI passes. This affects the `pre-pr-create.sh` hook configuration.

**Tell me which profile you recommend and why, then let me confirm before continuing.**

## Phase 2: GitHub setup

Based on my answers and chosen workflow profile:

1. **Initialise the repo:**
   ```bash
   git init
   ```

2. **Create the GitHub repo:**
   ```bash
   gh repo create [name] --[public/private] --source=. --push --description "[description]"
   ```

3. **Create staging branch** *(Profile A only — skip for Profile B):*
   ```bash
   git checkout -b staging
   git push -u origin staging
   ```

4. **Set up labels** *(Profile A only — skip for Profile B, can be added later):*
   Read `~/claude-code-playbook/templates/github/labels.json` and create each label:
   ```bash
   gh label create "[name]" --color "[color]" --description "[desc]"
   ```

5. **Copy templates** from the playbook to the project:
   - `~/claude-code-playbook/templates/github/workflows/ci.yml` → `.github/workflows/`
   - `~/claude-code-playbook/templates/github/workflows/hygiene.yml` → `.github/workflows/`
   - *(Profile A only)* `~/claude-code-playbook/templates/github/ISSUE_TEMPLATE/` → `.github/ISSUE_TEMPLATE/`
   - *(Profile A only)* `~/claude-code-playbook/templates/github/pull_request_template.md` → `.github/`

6. **Create milestones** *(Profile A only — skip for Profile B, can be added later):*
   ```bash
   gh api repos/[owner]/[repo]/milestones --method POST -f title="R0 — [first release name]" -f description="[from interview]"
   gh api repos/[owner]/[repo]/milestones --method POST -f title="R1 — [second release name]"
   gh api repos/[owner]/[repo]/milestones --method POST -f title="R2 — [third release name]"
   ```

7. **Create and configure project board** *(Profile A only — skip for Profile B):*

   Create a GitHub Project (V2):
   ```bash
   gh project create --owner [owner] --title "[project name]"
   ```

   Then auto-discover the board IDs needed for planning lifecycle hooks:
   ```bash
   # Get the project number
   gh project list --owner [owner] --format json --jq '.projects[-1].number'

   # Get field IDs (look for "Status" field)
   gh project field-list [PROJECT_NUMBER] --owner [owner] --format json

   # Get status option IDs (look for "In Progress")
   gh api graphql -f query='query($owner: String!, $number: Int!) {
     organization(login: $owner) {
       projectV2(number: $number) {
         id
         field(name: "Status") {
           ... on ProjectV2SingleSelectField {
             id
             options { id name }
           }
         }
       }
     }
   }' -f owner="[owner]" -F number=[PROJECT_NUMBER]
   ```

   If the owner is a user (not an org), use `user(login: $owner)` instead of `organization(login: $owner)`.

   Record these values — they'll be injected into the `pre-enter-plan.sh` hook in Phase 3:
   - **PROJECT_ID** — the `id` from the projectV2 query
   - **STATUS_FIELD_ID** — the `id` of the Status field
   - **IN_PROGRESS_ID** — the `id` of the "In Progress" option

   **Configure Status options** — expand from the default 3 to match the workflow:
   ```bash
   gh api graphql -f query='mutation($fieldId: ID!) {
     updateProjectV2Field(input: {
       fieldId: $fieldId
       singleSelectOptions: [
         {name: "Ready", color: GRAY, description: "Scoped and ready to start"}
         {name: "Todo", color: GREEN, description: "Not started"}
         {name: "In Progress", color: YELLOW, description: "Actively being worked on"}
         {name: "In Review", color: GRAY, description: "PR open, awaiting review"}
         {name: "Done", color: PURPLE, description: "Completed"}
         {name: "Blocked", color: RED, description: "Cannot proceed"}
       ]
     }) { clientMutationId }
   }' -f fieldId="[STATUS_FIELD_ID]"
   ```

   **Create custom fields** — based on interview answers, add fields for tracking:
   - **Priority** (single-select): P1 Critical Path, P2 Important, P3 Normal
   - **Release** (single-select): R0, R1, R2, etc. (one per milestone)
   - **Estimated Days** (number)
   - **Blocked By** (text)
   - **Start Date** (date)
   - **Target Date** (date)

   Use `createProjectV2Field` mutation for each:
   ```bash
   # Example: create a single-select field
   gh api graphql -f query='mutation($projectId: ID!, $name: String!) {
     createProjectV2Field(input: {
       projectId: $projectId
       dataType: SINGLE_SELECT
       name: $name
       singleSelectOptions: [
         {name: "P1 Critical Path", color: RED, description: ""}
         {name: "P2 Important", color: ORANGE, description: ""}
         {name: "P3 Normal", color: GRAY, description: ""}
       ]
     }) { clientMutationId }
   }' -f projectId="[PROJECT_ID]" -f name="Priority"

   # Example: create a number/text/date field
   gh api graphql -f query='mutation($projectId: ID!, $name: String!) {
     createProjectV2Field(input: {
       projectId: $projectId
       dataType: NUMBER
       name: $name
     }) { clientMutationId }
   }' -f projectId="[PROJECT_ID]" -f name="Estimated Days"
   ```

   **Link the project to the repo:**
   ```bash
   REPO_NODE_ID=$(gh api repos/[owner]/[repo] --jq '.node_id')
   gh api graphql -f query='mutation($projectId: ID!, $repoId: ID!) {
     linkProjectV2ToRepository(input: {
       projectId: $projectId
       repositoryId: $repoId
     }) { repository { id } }
   }' -f projectId="[PROJECT_ID]" -f repoId="$REPO_NODE_ID"
   ```

   **Add R0 issues to the board:**
   ```bash
   gh project item-add [PROJECT_NUMBER] --owner [owner] --url https://github.com/[owner]/[repo]/issues/[N]
   ```

   **Manual steps** (no API support — tell the user to do these in the GitHub UI):
   1. **Enable all 6 workflows:** Go to project Settings → Workflows → enable: Item closed, Pull request merged, Auto-close issue, Auto-add sub-issues, Pull request linked to issue, Item added to project
   2. **Create Board view:** Click "+ New view" → Board (groups by Status, shows the Kanban workflow)
   3. **Create Timeline view:** Click "+ New view" → Roadmap (uses Start Date / Target Date fields)

## Phase 3: Project files

1. **CLAUDE.md** — Read `~/claude-code-playbook/templates/CLAUDE.md.template` and create a CLAUDE.md in the repo root, filled in with everything from the interview. Include:
   - Operating mode
   - Current release and targets
   - Project identity
   - Tech stack (be specific — versions, package manager)
   - Key conventions for this stack
   - Plan lifecycle section (copied from template)
   - Code health cadence table (copied from template)
   - Pre-push audit (copied from template)
   - How to run the project (dev, build, test commands)
   - Starter trigger table (if touching X, read Y)

2. **Memory system:**
   - Create the memory directory for this project
   - Create `MEMORY.md` from `~/claude-code-playbook/templates/MEMORY.md.template`
   - Create `project_context.md` — save everything from the interview as a project memory
   - Create `user_profile.md` — ask me about my preferences (concise/verbose, emoji preference, how autonomous should Claude be)

3. **Documentation structure:**
   - Create `docs/design/` and `docs/system/`
   - Create `docs/plans/` — where plan lifecycle hooks commit plan files
   - Create an engineering plan from `~/claude-code-playbook/templates/engineering-plan.md` — fill in what we know
   - Create a roadmap from `~/claude-code-playbook/templates/roadmap.md` — fill in the releases

4. **Git hooks:**
   - Create `.githooks/pre-commit` with a basic check (adapt to the tech stack — lint, format, type check)
   - Run `git config core.hooksPath .githooks`
   - Make it executable: `chmod +x .githooks/pre-commit`

5. **Claude Code hooks (process enforcement):**

   Create `.claude/hooks/` directory and copy ALL hook templates:

   **Both profiles:**
   ```bash
   cp ~/claude-code-playbook/templates/hooks/bash-guard.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/session-start.sh .claude/hooks/
   chmod +x .claude/hooks/*.sh
   ```

   **Profile A only — also copy these:**
   ```bash
   cp ~/claude-code-playbook/templates/hooks/on-commit-check-planning.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/pre-pr-create.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/pre-enter-plan.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/on-enter-plan.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/on-exit-plan.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/pre-edit-write.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/mcp-pr-guard.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/pre-push.sh .claude/hooks/
   cp ~/claude-code-playbook/templates/hooks/pre-merge.sh .claude/hooks/
   chmod +x .claude/hooks/*.sh
   ```

   **Profile A — substitute variables in hooks:**
   - In `pre-enter-plan.sh`: replace `{{GITHUB_OWNER}}`, `{{GITHUB_REPO}}`, `{{PROJECT_ID}}`, `{{STATUS_FIELD_ID}}`, `{{IN_PROGRESS_ID}}` with the values from Phase 2. If no project board was created, leave the `PROJECT_ID` as empty string — the hook will skip board automation gracefully.

   **Profile A — configure solo vs team mode:**
   - If **solo**: leave `pre-pr-create.sh` as-is (offers both `--merge-now` and `--review`)
   - If **team**: edit `pre-pr-create.sh` to remove `--merge-now` from the allowed patterns, requiring `--review USER` on every PR

   **Profile B — strip staging rules from bash-guard.sh:**
   - Remove: "Block push to main/master" section (pushing to main is the workflow)
   - Remove: "Branch discipline" / dead-branch guard (no PRs to check)
   - Remove: "PR discipline" / `gh pr create` rules (no staging branch)
   - Remove: "Branch safety" / uncommitted-work-on-switch guard
   - Keep: force push block, destructive ops block, --no-verify block, specific file staging, release health gate

6. **Generate `.claude/settings.json`:**

   **Profile A** — copy the full settings.json template:
   ```bash
   cp ~/claude-code-playbook/templates/hooks/settings.json .claude/settings.json
   ```

   **Profile B** — create a reduced version with only:
   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [{ "type": "command", "command": ".claude/hooks/session-start.sh" }] }
       ],
       "PreToolUse": [
         { "matcher": "Bash", "hooks": [{ "type": "command", "command": ".claude/hooks/bash-guard.sh" }] }
       ]
     }
   }
   ```

   **Both profiles** — add Context7 MCP server to settings.json if not already in global settings:
   ```json
   "mcpServers": {
     "context7": {
       "type": "stdio",
       "command": "npx",
       "args": ["-y", "@upstash/context7-mcp"]
     }
   }
   ```

7. **Health check skills:**

   Copy ALL skill templates directly from the playbook (no generation needed):
   ```bash
   cp -r ~/claude-code-playbook/templates/skills/* .claude/skills/
   ```

   This installs 8 skills: `/health-check`, `/bloat-check`, `/dry-check`, `/security-check`, `/arch-check`, `/test-health`, `/startup`, `/sanitise`

8. **Screenshot tool:**
   - Install `cc-snap` for desktop screenshots: `cp ~/claude-code-playbook/extras/cc-snap.sh ~/.local/bin/cc-snap && chmod +x ~/.local/bin/cc-snap`
   - Verify `~/.local/bin` is on PATH (it usually is on Ubuntu/macOS; if not, add it)
   - This lets Claude take and view screenshots on macOS, WSL, Windows (Git Bash), and Linux

9. **Permissions — how autonomous should Claude be?**

   The bash-guard hook (step 5) is your safety net — it blocks destructive commands before they execute. With the guard in place, you can safely give Claude broader permissions so it doesn't prompt you for every command.

   Explain the three options and ask the user to choose:

   **Option 1: Guarded autonomy (recommended)**
   Claude can run any bash command and edit any file without prompting, but the bash-guard hook blocks dangerous operations. This is the best balance — fast iteration with mechanical safety.

   Add to `.claude/settings.json`:
   ```json
   "permissions": {
     "allow": [
       "Bash",
       "Read",
       "Edit",
       "Write",
       "WebFetch(domain:*)"
     ]
   }
   ```

   **Option 2: Selective permissions**
   Only pre-approve specific commands. Claude will still prompt for anything not listed. Good for teams that want tighter control.

   Add to `.claude/settings.json`:
   ```json
   "permissions": {
     "allow": [
       "Read",
       "Edit",
       "Bash(git *)",
       "Bash(npm *)",
       "Bash(pnpm *)",
       "Bash(cc-snap*)",
       "Bash(ls *)",
       "Bash(gh *)"
     ]
   }
   ```
   Adapt the list to the project's tech stack (e.g., `Bash(python *)`, `Bash(go *)`, `Bash(cargo *)`).

   **Option 3: Default (prompt for everything)**
   Claude asks permission for every bash command and file edit. Safe but slow. You can switch to Option 1 or 2 later by editing `.claude/settings.json`.

   **Important notes to share with the user:**
   - Permissions in `.claude/settings.json` are shared with the team (committed to git). Personal overrides go in `.claude/settings.local.json` (gitignored).
   - `deny` rules always win over `allow` rules, at any scope.
   - You can switch modes mid-session with `Shift+Tab`.
   - The bash-guard hook runs regardless of permission level — even with full Bash allowed, destructive operations are still blocked.

10. **Environment:**
    - Create `.gitignore` appropriate for the tech stack
    - Create `.env.example` listing any required environment variables
    - Create `.env` (ensure it's in .gitignore)

## Phase 4: Feed existing context

If the user said they have existing documents:

1. Ask them to paste or point to each document
2. For each document, extract:
   - Key decisions and rationale
   - Goals and success metrics
   - Constraints and dependencies
   - User personas or audience definitions
   - Feature lists or requirements
3. Save each as an appropriate memory file:
   - Decisions → `project_decisions.md`
   - Strategy → `project_strategy.md`
   - Feature list → use it to create GitHub issues in Phase 5
   - Personas → `project_personas.md`

## Phase 5: Initial backlog

1. Based on the interview and any existing documents, create 5-10 starter issues:
   ```bash
   gh issue create --title "FEAT: [title]" --body "[from template]" --label enhancement --milestone "R0 — [name]"
   ```

2. Create at least one issue for each category:
   - A feature issue (the first thing to build)
   - An engineering issue (project setup, CI configuration)
   - A documentation issue (if docs need writing)

3. *(Profile A only)* Add all issues to the project board.

4. Tell me which issue to start with and why.

## Phase 6: Project scaffold (if new project)

If this is a brand new project with no code:

1. Based on the tech stack, create the initial project scaffold:
   - `package.json` (or equivalent)
   - TypeScript config (if applicable)
   - Linter config
   - Test framework config
   - Basic folder structure

2. Install dependencies

3. Verify: `dev`, `build`, and `test` commands all work

## Phase 7: First commit

1. Stage everything: `git add -A`
2. Commit: `git commit -m "META: initialise project with Claude Code Playbook"`
3. Push:
   - **Profile A:** `git push origin staging`
   - **Profile B:** `git push origin main`

## Phase 8: Handover

1. Summarise everything that was created:
   - Files in the repo
   - GitHub milestones, issues, and project board
   - Hooks installed (list all by name and what they do)
   - Skills available (list all 8)
   - MCP servers configured

2. Explain the key workflows:
   - **Starting work:** Create an issue, create a branch from it (`git checkout -b <number>-<description>`), then code
   - **Planning:** Enter plan mode → hooks validate branch and update board → exit plan mode → plan committed to `docs/plans/` and posted to issue
   - **PR creation:** Claude will ask "auto-merge or manual review?" — this is enforced by the hook
   - **Health checks:** Run `/health-check` before releases, individual checks on cadence
   - **Sanitisation:** Run `/sanitise` for a full 7-pass codebase cleanup

3. Tell me: "Your project is set up. Here's what you can now ask me to do..."

4. Ask: "Ready to start building? Which issue shall we start with?"
