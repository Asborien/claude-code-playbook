# Setup Prompt

Copy everything below the line and paste it into Claude Code.

---

I'd like you to set up a new project using the Claude Code Playbook at ~/claude-code-playbook

Work through these phases in order. Complete each phase before moving to the next. Ask me questions when you need my input. If anything fails, explain what went wrong and how to fix it.

## Phase 0: Environment check

Check what's installed and set up anything missing:

1. **Git:** Run `git --version`. If not installed, guide me through installing it for my OS.
2. **GitHub CLI:** Run `gh --version`. If not installed, guide me through:
   - Installing gh (brew install gh / apt install gh / etc.)
   - Authenticating: `gh auth login` (walk me through the prompts)
   - Verify: `gh auth status`
3. **Node.js:** Run `node --version`. If not installed, recommend nvm and install LTS.
4. **Package manager:** Check for pnpm (`pnpm --version`). If not installed, recommend and install it.
5. **Git config:** Check `git config user.name` and `git config user.email`. If not set, ask me for my name and email and configure them.

Report what was found and what was installed.

## Phase 1: Interview

Ask me these questions one at a time. Wait for my answer before moving on:

1. What is this project called? (one word or short name for the repo)
2. In one sentence, what does it do?
3. Who is it for? (the target users)
4. Public or private repo?
5. What tech stack? (if you're unsure, tell me what you're building and I'll recommend one)
6. Are you working solo or in a team?
7. Do you have existing documents to feed in? (strategy docs, feature lists, research, wireframes, business plans — anything)
8. What does "done" look like for the first version? What's the first thing users should be able to do?

## Phase 2: GitHub setup

Based on my answers:

1. **Initialise the repo:**
   ```bash
   git init
   ```

2. **Create the GitHub repo:**
   ```bash
   gh repo create [name] --[public/private] --source=. --push --description "[description]"
   ```

3. **Create staging branch:**
   ```bash
   git checkout -b staging
   git push -u origin staging
   ```

4. **Set up labels** from the playbook:
   Read `~/claude-code-playbook/templates/github/labels.json` and create each label:
   ```bash
   gh label create "[name]" --color "[color]" --description "[desc]"
   ```

5. **Copy templates** from the playbook to the project:
   - `~/claude-code-playbook/templates/github/ISSUE_TEMPLATE/` → `.github/ISSUE_TEMPLATE/`
   - `~/claude-code-playbook/templates/github/pull_request_template.md` → `.github/`
   - `~/claude-code-playbook/templates/github/workflows/ci.yml` → `.github/workflows/`
   - `~/claude-code-playbook/templates/github/workflows/hygiene.yml` → `.github/workflows/`

6. **Create milestones:**
   ```bash
   gh api repos/[owner]/[repo]/milestones --method POST -f title="R0 — [first release name]" -f description="[from interview]"
   gh api repos/[owner]/[repo]/milestones --method POST -f title="R1 — [second release name]"
   gh api repos/[owner]/[repo]/milestones --method POST -f title="R2 — [third release name]"
   ```

7. **Create a project board:**
   Guide me through creating a GitHub Project (V2) via the UI if the API is complex, or create via API if possible.

## Phase 3: Project files

1. **CLAUDE.md** — Read `~/claude-code-playbook/templates/CLAUDE.md.template` and create a CLAUDE.md in the repo root, filled in with everything from the interview. Include:
   - Operating mode
   - Current release and targets
   - Project identity
   - Tech stack (be specific — versions, package manager)
   - Key conventions for this stack
   - How to run the project (dev, build, test commands)
   - Starter trigger table (if touching X, read Y)

2. **Memory system:**
   - Create the memory directory for this project
   - Create `MEMORY.md` from `~/claude-code-playbook/templates/MEMORY.md.template`
   - Create `project_context.md` — save everything from the interview as a project memory
   - Create `user_profile.md` — ask me about my preferences (concise/verbose, emoji preference, how autonomous should Claude be)

3. **Documentation structure:**
   - Create `docs/design/` and `docs/system/`
   - Create an engineering plan from `~/claude-code-playbook/templates/engineering-plan.md` — fill in what we know
   - Create a roadmap from `~/claude-code-playbook/templates/roadmap.md` — fill in the releases

4. **Git hooks:**
   - Create `.githooks/pre-commit` with a basic check (adapt to the tech stack — lint, format, type check)
   - Run `git config core.hooksPath .githooks`
   - Make it executable: `chmod +x .githooks/pre-commit`

5. **Claude Code hooks (process enforcement):**
   - Create `.claude/hooks/` directory
   - Copy `~/claude-code-playbook/templates/hooks/bash-guard.sh` → `.claude/hooks/bash-guard.sh`
   - Copy `~/claude-code-playbook/templates/hooks/session-start.sh` → `.claude/hooks/session-start.sh`
   - Copy `~/claude-code-playbook/templates/hooks/settings.json` → `.claude/settings.json`
   - Make hooks executable: `chmod +x .claude/hooks/*.sh`
   - These enforce: no push to main, no force push, no --admin bypass, no skipping hooks, release scope gate on every session

7. **Environment:**
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

3. Tell me which issue to start with and why.

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
3. Push: `git push origin staging`

## Phase 8: Handover

1. Read `~/claude-code-playbook/CHEAT-SHEET.md` and show me the highlights
2. Summarise everything that was created:
   - Files in the repo
   - GitHub milestones and issues
   - What to do next
3. Tell me: "Your project is set up. Here's what you can now ask me to do..."
4. Ask: "Ready to start building? Which issue shall we start with?"
