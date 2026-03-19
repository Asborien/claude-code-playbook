# Setup Prompt

Two options depending on your setup:

## Option A: If you have the playbook cloned locally

Clone this repo alongside your project:
```bash
git clone https://github.com/Certified-Coach/claude-code-playbook.git ~/claude-code-playbook
```

Then open your project in Claude Code and paste this:

---

I'd like you to set up this project using the Claude Code Playbook. The playbook is cloned locally at ~/claude-code-playbook

Please:

1. Read the playbook's `START-HERE.md`, `templates/CLAUDE.md.template`, and `practices/memory/how-memory-works.md`

2. Interview me to understand this project:
   - What is this project? (name, one-line description)
   - What problem does it solve? Who is it for?
   - What's the tech stack? (or should we choose one together?)
   - Am I working solo or in a team?
   - What's the current state — brand new, or do I have existing context (strategy docs, research, designs)?
   - What are the immediate priorities?
   - What does the first release look like?

3. Based on my answers, create these files:

   **CLAUDE.md** in the repo root — adapted from the playbook template. Include:
   - Operating mode
   - Current release + targets (even if the first release is "set up the project")
   - Project identity
   - Tech stack
   - Key conventions
   - A starter docs trigger table

   **Memory directory** at the appropriate path for this project. Create:
   - `MEMORY.md` index file (from the playbook template)
   - A `project_context.md` memory file capturing the project description, goals, and current state
   - A `user_profile.md` memory file capturing who I am and my preferences
   - If I have strategy documents or context to share, ask me to paste or point to them, then save the key decisions as project memory files

   **Git configuration:**
   - If this is a new repo, initialise it with `git init`
   - Create `.githooks/pre-commit` with a basic lint check (adapt to the tech stack)
   - Run `git config core.hooksPath .githooks`
   - Create an initial `.gitignore` appropriate for the tech stack

4. If this is a brand new project with no code:
   - Help me choose a tech stack (or validate my choice) based on the project requirements
   - Create the initial project scaffold (package.json, tsconfig, etc.)
   - Set up the dev environment so I can run `dev`, `build`, and `test`
   - Make the first commit: `META: initial project setup with Claude Code Playbook`

5. If I have existing context (strategy docs, market research, personas, wireframes):
   - Ask me to share them (paste text, point to files, or describe them)
   - Extract key decisions, goals, constraints, and personas
   - Save each as an appropriate memory file
   - Reference them in CLAUDE.md where relevant

6. Create the first release plan:
   - Ask me what the first milestone is
   - Create a simple release definition (even if it's just "R0: Project setup complete")
   - Log 3-5 initial issues as a starter backlog (use `gh issue create` if we have GitHub set up)

7. Summarise everything that was created and what to do next.

---

## Option B: If you don't have the playbook cloned

Paste this simpler version — Claude will work from the principles directly:

---

I'd like to set up my project with structured working practices for Claude Code. The practices I want to adopt:

1. **CLAUDE.md as the constitution** — a file in the repo root that loads every session with project context, conventions, and current priorities.

2. **Memory system** — a file-based memory at `.claude/projects/` that persists decisions, feedback, and project state across conversations.

3. **Release hierarchy** — Releases (business events) → Milestones (engineering targets) → Issues (work items). Every piece of work belongs to a release.

4. **Docs alongside code** — if code changes, docs update in the same commit.

5. **Pre-push audit** — before every push, verify: library-first, dependencies explicit, docs updated, gotchas captured.

Please interview me about my project and set up these practices. Start by asking:
- What is this project?
- What's the tech stack?
- What's the current state?
- What are the immediate priorities?
