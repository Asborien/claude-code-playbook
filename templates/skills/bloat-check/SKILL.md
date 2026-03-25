---
name: bloat-check
description: Find oversized files, long functions, unnecessary abstractions, and reinvented wheels.
---

1. Find all source files exceeding 300 lines. Assess whether each can be split by responsibility.
2. Find all functions exceeding 30 lines. Identify extractable sub-functions.
3. Search for custom utility implementations that duplicate declared dependencies.
4. Find interfaces/abstract classes with exactly one implementation.
5. Find pass-through wrapper functions that add no logic.
6. Find unnecessary intermediate variables (assigned once, used once on next line).
7. Present findings with file paths, line numbers, and specific recommended action. Do NOT auto-fix.
