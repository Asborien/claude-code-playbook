# Branch Strategy

## The pattern

```
feature/xyz  →  staging  →  main
                   ↑           ↑
              all PRs go    promotion
              here first    only
```

- **`main`** — production. Only receives promotions from staging.
- **`staging`** — integration branch. All feature PRs target staging.
- **Feature branches** — short-lived. One concern per branch.

## Why staging?

1. **Preview deployments** — staging auto-deploys to a preview URL. Test before production.
2. **Batch promotions** — multiple features accumulate on staging, then promote together.
3. **Safety net** — if something breaks on staging, production is unaffected.

## Rules

1. **Never commit directly to main.** Emergency hotfixes are the only exception.
2. **Never delete staging.** It's permanent. If it disappears after a merge, recreate from main.
3. **All PRs target staging.** GitHub defaults to main — always explicitly set `--base staging`.
4. **Squash merge feature branches.** Clean history on staging.
5. **Merge (not squash) staging → main.** Preserves the promotion history.

## Promotion workflow

```bash
# Merge staging into main (preserves history)
git checkout main
git merge staging
git push origin main

# Tag the release
git tag v0.1.0
git push origin v0.1.0
```

Or automate with a bash function:
```bash
cc-promote() {
  git checkout main && git merge staging && git push origin main && git checkout staging
}
```

## Commit message format

Use prefixes for traceability:

| Prefix | Meaning |
|--------|---------|
| `FEAT:` | New feature |
| `FIX:` | Bug fix |
| `ENG:` | Engineering improvement (refactor, performance, tests) |
| `DOCS:` | Documentation only |
| `META:` | Project configuration, CI, tooling |

## PR discipline

Every PR must have:
- An assignee
- At least one label (`bug`, `enhancement`, `documentation`)
- A milestone
- A reference to the issue it addresses (`Closes #N`)

Missing any of these? Fix it before merging. Automate with CI checks where possible.
