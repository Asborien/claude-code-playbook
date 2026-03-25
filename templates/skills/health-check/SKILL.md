---
name: health-check
description: Run all 5 health checks and produce a combined summary report.
---

1. Run /bloat-check
2. Run /dry-check
3. Run /security-check
4. Run /arch-check
5. Run /test-health
6. Produce a combined summary with: total findings by severity, top 5 highest-priority items, and a recommended action plan.
