# GitHub Releases

## Milestones vs Releases vs Labels

GitHub has three features that serve different purposes in release management:

| Feature | Purpose | When created | Example |
|---|---|---|---|
| **Milestones** | Group issues by engineering domain | At project start | "User Auth", "Payments", "Search" |
| **Release labels** | Tag which release an issue ships in | When triaging | `release:R0`, `release:R1`, `release:backlog` |
| **Releases** | Record what shipped (tied to git tags) | At promotion time | v0.1.0, v1.0.0 |

### Two dimensions

An issue has **one milestone** (engineering domain) and **one release label** (when it ships):

```
Issue #42: "User profile create/edit"
  Milestone: User Management (engineering domain)
  Label: release:R1 (ships in R1 release)
```

A milestone can span releases. A release pulls from multiple milestones.

## Creating releases

Releases are created when you promote code from staging to main:

```bash
# Promote staging → main
git checkout main
git merge staging
git push origin main

# Tag the release
git tag v0.1.0
git push origin v0.1.0

# Create GitHub Release with auto-generated notes
gh release create v0.1.0 --generate-notes --title "v0.1.0 — R0: Collect Interest"
```

The `--generate-notes` flag creates release notes from merged PRs since the last tag.

## Versioning

Use semantic versioning:
- **v0.x.x** — pre-launch (marked as pre-release)
- **v1.0.0** — first public launch
- **Patch** increments for each promotion (v0.1.0 → v0.1.1 → v0.1.2)
- **Minor** increments for feature releases (v0.1.x → v0.2.0)
- **Major** increments for breaking changes

## Release labels

Create these labels on your repo:

```bash
gh label create "release:R0" --color "0E8A16" --description "R0 — [first release name]"
gh label create "release:R1" --color "1D76DB" --description "R1 — [second release]"
gh label create "release:backlog" --color "CCCCCC" --description "Not assigned to a release"
```

Every open issue must have a release label. Zero unlabeled issues.

## The discipline

Before starting work: "Which release is this for?"
- If it's in the current release → do it
- If it's in a future release → it has a label, leave it
- If it's a new idea → create the issue, label it `release:backlog`, move on
