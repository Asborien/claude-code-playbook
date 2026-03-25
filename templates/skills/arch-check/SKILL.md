---
name: arch-check
description: Validate architectural boundaries, find layer violations, N+1 queries, and logic leakage.
---

1. Read CLAUDE.md for architectural layer definitions. If none exist, analyse and propose layers.
2. Check every import for layer violations (imports crossing boundaries in wrong direction).
3. Find database/ORM calls outside the expected data access layer.
4. Find business logic in API routes, UI components, or utility files.
5. Find N+1 query patterns — database queries inside loops, sequential queries that could be parallel.
6. Find pattern inconsistencies — same task done different ways without justification.
7. Present findings with file paths, line numbers, and severity. Do NOT auto-fix.
