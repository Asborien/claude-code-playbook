# Pre-Push Audit

Before pushing any branch, verify these four things:

## 1. Library-first

Are you writing custom code where a maintained library, SDK, or GitHub Action already exists?

**If yes:** Use the library. Delete the custom code.

**Why:** Custom wrappers around APIs drift from the SDK. When the API changes, the SDK updates — your custom code doesn't.

## 2. Dependencies

Are new libraries added as explicit dependencies in `package.json`?

**Never rely on transitive dependencies.** If you `import` from a package, it must be in your `dependencies` or `devDependencies`. Transitive deps can disappear on the next `npm update`.

## 3. Documentation

Do pages in your docs exist for the files you changed?

**If yes:** Update the docs in the same commit.

A PR that adds a library must include its doc page. A PR that changes a component's API must update the component table. The cost of updating docs now is minutes. The cost of updating them later is hours (because you've forgotten the context).

## 4. Gotchas

Did you discover something non-obvious?

**If yes:** Add it to a "Lessons" or "Gotchas" section in the relevant doc.

Future you (or Claude) will hit the same issue. A one-line note saves hours of debugging.

## The audit applies to every push

Not just the final one before merge. Iterative fix-push-check cycles are where doc and quality drift happens. Each push is a checkpoint.

## Automate what you can

- Pre-commit hooks for linting and formatting
- CI checks for missing labels, milestones, assignees
- Doc generation scripts that detect drift
- Build checks before push (`pnpm build`)
