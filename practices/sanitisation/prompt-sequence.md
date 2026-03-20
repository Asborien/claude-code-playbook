# Prompt Sequence

30 prompts across 7 passes. Paste each into Claude Code in order. Use `/clear` between passes.

## Variables

Replace these before running. Use find-and-replace across all prompts:

| Variable | Example | Your value |
|---|---|---|
| `{package_manager}` | pnpm, npm, yarn, pip | |
| `{src_dir}` | src/, apps/web/src/, lib/ | |
| `{test_command}` | pnpm test, npm test, pytest | |
| `{build_command}` | pnpm build, npm run build, cargo build | |
| `{lint_command}` | pnpm lint, npm run lint, ruff check | |
| `{audit_command}` | pnpm audit, npm audit, pip-audit | |
| `{framework}` | Next.js, Django, Rails, Express | |
| `{branch_base}` | staging, develop, main | |

---

## Pass 0: Setup (Prompts 0-3)

### Prompt 0 — Set context

Before running the sequence, tell Claude Code your stack details in one message: language, framework, package manager, source directory, test/build/lint/audit commands, and integration branch name. This replaces the need to find-and-replace variables in every prompt — Claude Code will understand natural language references like "run the tests" from this context.

Example:

> This is a Python/Django project. Package manager: pip. Source directory: src/. Test command: pytest. Build command: python manage.py collectstatic. Lint command: ruff check. Audit command: pip-audit. Integration branch: staging.

### Prompt 1 — Install skills

See `skills-installer.md` for the single prompt that installs all 6 skills.

### Prompt 2 — Create branch and baseline

> Create branch release/sanitisation from {branch_base}.
>
> Take baseline measurements and record them in SANITISATION_LOG.md:
> 1. Lines of code by extension (find {src_dir})
> 2. Total file count
> 3. Dependency counts: production and dev from package manifest
> 4. Top 20 largest source files by line count
> 5. Total exports (grep for export patterns)
> 6. Code duplication percentage (use jscpd if available, or equivalent)
> 7. Run {audit_command} — record vulnerability count by severity
> 8. Run {test_command} — record total, passing, failing, skipped
>
> Create the log with a "Baseline Measurements" section and a "Final Measurements" placeholder.
>
> Commit with message "docs: create sanitisation log with baseline measurements"

### Prompt 3 — Add temporary rules

> Add a "SANITISATION MODE (TEMPORARY)" section to CLAUDE.md with these rules:
> - Currently on release/sanitisation branch
> - Every fix gets its own commit with AP-ID in the message
> - Run tests after every change
> - Do NOT auto-fix findings — present them for review first
> - Record all findings and decisions in SANITISATION_LOG.md
> - Deferred items get a GitHub issue
>
> Commit with message "docs: add temporary sanitisation rules to CLAUDE.md"

---

## Pass 1: Dead Code & Dependencies (Prompts 4-8)

### Prompt 4 — Find dead exports

> Find all unused exports in {src_dir}. For each export, check if it has any consumers:
> - grep for the export name across the codebase
> - Check for dynamic imports or framework-specific consumption patterns
> - Check test files (a function used only in tests is test infrastructure, not dead code)
>
> List every export with zero consumers. For each, state the file, line number, and your confidence that it's truly dead. Do NOT delete anything yet.

### Prompt 5 — Find dead files and commented-out code

> Find:
> 1. Files in {src_dir} with zero imports (orphan files). Exclude entry points consumed by the framework.
> 2. Commented-out code blocks longer than 3 lines. Exclude license headers and documentation comments.
> 3. Unreachable code after return/throw statements.
>
> For each finding, state the file, line number, and whether it should be deleted or kept with rationale.

### Prompt 6 — Audit dependencies

> Run {audit_command} and report all vulnerabilities by severity.
>
> Then check for unused dependencies:
> 1. For each production dependency, grep {src_dir} for imports from that package
> 2. Flag any with zero imports as candidates for removal
> 3. Check if apparently-unused deps are peer dependencies or framework requirements
>
> Also check for hallucinated dependencies — verify every declared dependency actually exists in the package registry.
>
> Present findings. Do NOT remove anything yet.

### Prompt 7 — Apply Pass 1 fixes

> Based on the findings from Prompts 4-6, apply the approved fixes:
> 1. Remove confirmed dead exports
> 2. Remove confirmed orphan files
> 3. Remove confirmed commented-out code blocks
> 4. Remove confirmed unused dependencies
>
> Commit each category separately with AP-ID format.
> Run {test_command} and {build_command} after all changes.
> Record Pass 1 results in SANITISATION_LOG.md.

### Prompt 8 — Create deferred issues

> For any dependency updates that were identified but too risky to apply now (major version bumps, breaking changes), create a single GitHub issue titled "chore: post-sanitisation dependency updates" listing all deferred updates with current and target versions.
>
> /clear

---

## Pass 2: Duplication (Prompts 9-12)

### Prompt 9 — Measure duplication

> Run duplication detection on {src_dir}. Use jscpd or equivalent with min-lines 5 and min-tokens 50.
>
> Report: total duplication percentage, number of clone pairs, total duplicated lines.
> List all clone pairs sorted by size (largest first).

### Prompt 10 — Analyse clone pairs

> For each clone pair from Prompt 9, classify it:
>
> Tier 1 — Extract now: Identical code that serves the same purpose. Safe to consolidate.
> Tier 2 — Extract later: Similar code that may diverge. Flag but don't consolidate now.
> Tier 3 — Acceptable: Intentional duplication (similar UI in different domains that will evolve independently).
>
> For Tier 1 items, propose specific shared modules with file paths and extraction boundaries.
> Present findings. Do NOT apply yet.

### Prompt 11 — Apply Pass 2 fixes

> Apply the approved Tier 1 extractions. For each shared module:
> 1. Create the shared file
> 2. Update all consumers to import from the shared file
> 3. Run {test_command} after each extraction
> 4. Commit each extraction separately
>
> Record Pass 2 results in SANITISATION_LOG.md including before/after duplication percentage.

### Prompt 12 — Track deferred duplication

> Create a GitHub issue for Tier 2 items titled "chore: deferred duplication consolidation" with the list of clone pairs and rationale for deferring each.
>
> /clear

---

## Pass 3: Security (Prompts 13-16)

### Prompt 13 — Fix CVEs

> Run {audit_command}. For each vulnerability:
> 1. Check if a patched version exists
> 2. Check if the patch introduces breaking changes
> 3. Apply the patch (version bump or override)
> 4. Run {test_command} after each patch
>
> Commit each fix separately with the CVE ID in the message.

### Prompt 14 — Check for secrets and crypto

> Search {src_dir} for:
> 1. Hardcoded strings that look like API keys, tokens, passwords, or connection strings
> 2. Uses of weak random number generation for security purposes
> 3. Missing or weak CSRF protection
> 4. Permissive CSP headers or missing security headers
>
> Report findings with file paths and line numbers. Do NOT auto-fix.

### Prompt 15 — Check input validation

> For every API route and server action in {src_dir}:
> 1. Is user input validated before use?
> 2. Are there length limits on string inputs?
> 3. Are there format checks on IDs, emails, URLs?
> 4. Is output properly escaped to prevent XSS?
>
> Report findings. Do NOT auto-fix.

### Prompt 16 — Apply Pass 3 fixes

> Apply the approved security fixes from Prompts 14-15. Commit each fix separately.
> Run {test_command} and {build_command}.
> Record Pass 3 results in SANITISATION_LOG.md.
>
> /clear

---

## Pass 4: Architecture (Prompts 17-19)

### Prompt 17 — Define and check layers

> Read CLAUDE.md for any existing architectural layer definitions.
>
> If layers are not defined, analyse the codebase and propose a layered architecture with import direction rules.
>
> Then check every import in {src_dir} for layer violations. Also check:
> 1. Database/ORM calls outside the data access layer
> 2. Business logic in API routes or UI components
> 3. N+1 query patterns (DB queries inside loops)
> 4. Pattern inconsistencies (same task done differently across features)
>
> Report all findings with file paths and line numbers. Do NOT auto-fix.

### Prompt 18 — Apply Pass 4 fixes

> Apply the approved architecture fixes. For each:
> 1. Fix the violation
> 2. Run {test_command}
> 3. Commit with AP-ID format
>
> Add the architectural layer definitions to CLAUDE.md as a permanent section.
> Record Pass 4 results in SANITISATION_LOG.md.

### Prompt 19 — Document architecture

> Add any architectural decisions discovered during this pass to CLAUDE.md:
> - Layer definitions and import direction rules
> - Data access patterns
> - Any intentional deviations with rationale
>
> Commit documentation separately.
>
> /clear

---

## Pass 5: Bloat (Prompts 20-21)

### Prompt 20 — Analyse bloat

> Find:
> 1. All files exceeding 300 lines — assess whether each can be split or is justified
> 2. All functions exceeding 30 lines — identify extractable sub-functions
> 3. Custom utility implementations that duplicate functionality in declared dependencies
> 4. Interfaces with exactly one implementation — justified or unnecessary?
> 5. Pass-through wrapper functions
> 6. Unnecessary intermediate variables (assigned once, used once on next line)
>
> Check whether any of the largest files are dead code before proposing refactoring.
>
> Present findings with specific recommended actions. Do NOT auto-fix.

### Prompt 21 — Apply Pass 5 fixes

> Apply the approved bloat fixes. For structural extractions (file splits):
> 1. Show me the proposed split before committing
> 2. Create the new files
> 3. Update all imports
> 4. Run {test_command} and {build_command}
> 5. Commit each extraction separately
>
> Record Pass 5 results in SANITISATION_LOG.md.
>
> /clear

---

## Pass 6: Test Health & Lint (Prompts 22-24)

### Prompt 22 — Resolve lint errors

> Run {lint_command}. For each error:
> 1. If it's a genuine fix needed — fix it
> 2. If it's a false positive — add a disable comment with a brief reason
> 3. If it's a misconfigured rule — flag it for config review
>
> Fix warnings too where trivial. Group all lint fixes into a single commit.
> Re-run {lint_command} and confirm zero errors.

### Prompt 23 — Assess test health

> Assess the test suite quality:
> 1. Run {test_command} — confirm all pass
> 2. Identify redundant tests (same code path, different names)
> 3. List all exported functions with ZERO test coverage at any level
> 4. List those with ONLY happy-path coverage
> 5. Find brittle tests (mock call counts, implementation detail assertions)
> 6. Assess integration test coverage
> 7. Assess E2E coverage if applicable
> 8. Check all skipped tests — valid reason or neglected?
>
> Present a risk-based prioritisation: highest-risk untested code, not just count of missing tests.
> Do NOT write tests yet.

### Prompt 24 — Apply Pass 6 fixes

> Write tests for the quick wins only — pure functions that are trivial to test.
> Create a GitHub issue titled "test: test maturity roadmap" with the full prioritised list.
>
> Important: When a test fails, ask whether the CODE is wrong or the TEST expectation is wrong before adjusting. Never blindly change test expectations to match current behaviour.
>
> Commit tests. Record Pass 6 results in SANITISATION_LOG.md.
>
> /clear

---

## Pass 7: Final (Prompts 25-30)

### Prompt 25 — Final measurements

> Take the same measurements as the baseline and record them in SANITISATION_LOG.md under "Final Measurements". Add a "Delta Summary" table comparing before and after for every metric.
>
> Commit with message "docs: record final measurements and delta summary"

### Prompt 26 — Validate

> Run the complete validation suite:
> 1. {test_command} — all pass
> 2. {lint_command} — zero errors
> 3. Type checker — zero errors (if applicable)
> 4. {audit_command} — zero vulnerabilities
> 5. {build_command} — compiles successfully
> 6. Verify no TODO/FIXME introduced without corresponding issues
>
> If anything fails, fix it. Report final validation status.

### Prompt 27 — Fix validation failures

> Fix any issues found in Prompt 26. Commit each fix separately.
> Re-run validation to confirm everything passes.

### Prompt 28 — Remove temporary rules

> Remove the "SANITISATION MODE (TEMPORARY)" section from CLAUDE.md. Keep all permanent additions (architectural layers, conventions, data access patterns).
>
> Commit with message "chore: remove temporary sanitisation rules from CLAUDE.md"

### Prompt 29 — Push and create PR

> Push all commits to origin. Create a PR from release/sanitisation to {branch_base} with:
> - Title: "Release: Codebase Sanitisation"
> - Description: Include the Delta Summary table from SANITISATION_LOG.md plus a one-paragraph summary of what was covered.

### Prompt 30 — Manual verification

This is a manual step — not a Claude Code prompt.

Before merging the PR:
1. Review the PR diff in GitHub
2. Deploy to a preview environment
3. Test critical user flows manually
4. Check browser console for errors (especially if CSP was changed)
5. Merge when satisfied
