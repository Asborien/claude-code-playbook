# Setup Prompt

Copy everything below the line and paste it into Claude Code as your first message in a new project.

---

I'd like you to set up this project using the Claude Code Playbook. The playbook repo is at https://github.com/Certified-Coach/claude-code-playbook

Please:

1. Read the playbook's `START-HERE.md` and `templates/CLAUDE.md.template` from the repo
2. Create a `CLAUDE.md` in this repo's root, adapted for this project. Ask me:
   - What is this project? (name, description, tech stack)
   - Am I working solo or in a team?
   - What's the current state? (new project, existing codebase, etc.)
   - What are the immediate priorities?
3. Set up the memory system:
   - Create the memory directory at `.claude/projects/` (follow the playbook's memory guide)
   - Create an initial `MEMORY.md` index file
4. Set up git hooks:
   - Create `.githooks/pre-commit` based on the playbook's example
   - Run `git config core.hooksPath .githooks`
5. Review the practices in the playbook and recommend which ones apply to this project
6. Commit the setup files with the message: `META: initialise Claude Code playbook practices`

After setup, summarise what was created and what practices are now active.
