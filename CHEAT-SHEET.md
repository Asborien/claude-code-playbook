# Cheat Sheet — What You Can Now Tell Claude

After running the setup prompt, your project has CLAUDE.md, memory, and git hooks. Here's what you can say to Claude and what happens.

## Project management

### "Create issues for [feature area]"
Claude creates GitHub issues with proper labels, milestones, and descriptions using your issue templates.
```
Create 5 issues for the user authentication system. Assign them to the R1 milestone.
```

### "Create milestones for our releases"
Claude creates GitHub milestones matching your roadmap.
```
Create milestones for R0, R1, and R2 based on the roadmap in docs/roadmap.md
```

### "What should I work on next?"
Claude reads CLAUDE.md (current release targets), checks GitHub milestones, and recommends the highest-priority item on the critical path.

### "Update the engineering plan"
Claude updates the engineering plan doc to reflect current reality — what's built, what's remaining, what's blocked.

## Git workflow

### "Commit this work"
Claude stages changes, writes a commit message with the correct prefix, and references the issue.
```
Commit this to issue #12
```
Result: `FEAT: user login form (#12)` with co-authored-by tag.

### "Create a PR"
Claude creates a pull request targeting the correct branch, with labels, milestone, and assignee.

### "What's the status?"
Claude runs git status, checks the branch, shows recent commits, and reports staging vs main gap.

## Memory

### "Remember that..."
Claude saves a memory file for future sessions.
```
Remember that we decided to use Stripe for payments, not Paddle. The reason is marketplace support.
```
Result: Creates `memory/project_payment-decision.md` with the decision and rationale.

### "What do we know about [topic]?"
Claude checks memory files for relevant context.

## Documentation

### "Update the docs for what we just built"
Claude identifies which docs are affected by recent changes and updates them.

### "Are any docs stale?"
Claude cross-references docs against the codebase and reports inaccuracies.

## Planning

### "Let's plan [release/feature]"
Claude enters plan mode — researches the codebase, reads relevant docs, and proposes an implementation plan before writing code.

### "What's in R0? What's left?"
Claude reads the roadmap and engineering plan, checks GitHub milestones, and gives a status report.

### "I have a feature list — turn it into a plan"
Claude takes your feature list, organises it into releases and milestones, creates GitHub issues, and updates the engineering plan.
```
Here's my feature list: [paste list]
Organise this into R0, R1, R2 releases and create GitHub issues for each.
```

## Day-to-day development

### "Build [feature]"
Claude reads CLAUDE.md for conventions, checks the trigger table for relevant docs, and implements the feature following your project's patterns.

### "Review this for quality"
Claude runs the pre-push audit: library-first check, dependency check, docs check, gotcha check.

### "Run the tests"
Claude runs your test suite and reports results.

### "How does [system] work?"
Claude reads the relevant docs and codebase to explain how something works, grounded in your actual code — not generic answers.

## Code health

**"Run a health check"**
Claude runs all 6 health checks and produces a combined report with prioritised findings.

**/health-check**
Full check — bloat, duplication, security, architecture, test health. Run before releases.

**/bloat-check**
Find oversized files, long functions, unnecessary abstractions. Run after adding features.

**/dry-check**
Find code duplication, suggest shared modules. Run weekly during active development.

**/security-check**
CVEs, secrets, input validation, CSP headers. Run monthly.

**/arch-check**
Layer violations, N+1 queries, business logic placement. Run monthly.

**/test-health**
Coverage gaps, brittle tests, redundant tests. Run before releases.

**"Run a full sanitisation"**
Claude runs the complete 7-pass sanitisation process. See `practices/sanitisation/` for the full prompt sequence. Run before major releases or quarterly.

## Tips

1. **Start every session with context.** Claude reads CLAUDE.md automatically, but you can add: "We're working on R0 today. The priority is [X]."

2. **Save decisions immediately.** If you make a strategic choice in conversation, say "remember this decision" — Claude saves it to memory.

3. **Use the release gate.** If Claude starts building something that's not in the current release, say "is this in R0?" — it'll check and defer if not.

4. **End sessions with a summary.** Say "save a session summary" — Claude captures what was done, what's next, and any open questions.
