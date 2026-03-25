---
name: dry-check
description: Find code duplication and suggest shared modules.
---

1. Detect code duplication (min 5 lines, 50 tokens).
2. Report total duplication percentage, clone count, duplicated line count.
3. List all clone pairs sorted by size (largest first).
4. Classify each: Tier 1 (extract now — identical, same purpose), Tier 2 (extract later — similar, may diverge), Tier 3 (acceptable — intentional).
5. For Tier 1, propose specific shared module with file path and extraction boundaries.
6. Present findings. Do NOT auto-fix.
