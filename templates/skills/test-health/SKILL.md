---
name: test-health
description: Assess test suite quality — coverage gaps, brittle tests, redundant tests.
---

1. Run the test suite. Report total, passing, failing, skipped.
2. Identify redundant tests — same code path tested with trivially different inputs.
3. List all exported functions and endpoints with ZERO test coverage.
4. List those with ONLY happy-path coverage (no error or boundary tests).
5. Find brittle tests — mock call count assertions, implementation detail testing, exact string matching on error messages.
6. Check all skipped tests — valid reason or neglected?
7. Present a risk-based prioritisation: highest-risk untested code. Do NOT auto-fix.
