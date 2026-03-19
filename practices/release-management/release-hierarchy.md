# Release → Milestone → Issue Hierarchy

## The problem

Without a release plan, work happens at the issue level. Features get built, but nobody can answer: "When can users see this?" Scope creeps because there's no boundary — every good idea gets implemented immediately.

## The hierarchy

```
Strategy          Why you exist, who you serve, how you win
  └─ Releases     Business events — changes to what users see and can do
       └─ Milestones  Engineering targets that enable a release
            └─ Issues     Individual work items within a milestone
```

## Releases are not deploys

A deploy pushes code. A release changes what users experience. Multiple deploys happen between releases. A release has a **definition of done** that goes beyond "code merged."

## Each release needs

- **A name and version** (R0, R1, v1.0.0)
- **A business goal** (not an engineering goal)
- **A target date** (even if approximate)
- **A definition of done** (checklist, not vibes)
- **A list of milestones** that feed into it
- **A "NOT in this release" list** (equally important)

## Before starting any work

Ask: **"Which release is this for?"**

- If it's in the current release → do it
- If it's in the next release → log it as an issue, move on
- If it's a good idea but not in any release → log it, tag it, park it

## The discipline problem

AI-assisted development is fast. This makes scope creep worse, not better — you can build a "quick fix" in 10 minutes that wasn't in the plan. Those 10-minute diversions compound into days of unplanned work.

The release plan is the guardrail. Not every good idea should be implemented now.

## Example

```
Release: R0 — Collect Interest
  Milestone: Launch Readiness
    Issue: #1045 — Marketing page redesign
    Issue: #930 — Fix canonical URLs
    Issue: #927 — WCAG accessibility
  Milestone: R0 — Registration
    Issue: #1096 — Registration E2E tests
    Issue: #1084 — Email infrastructure
  NOT in R0:
    - Coach profile editing (R1)
    - Booking system (R1)
    - Payments (R2)
```

## GitHub setup

1. Create a milestone for each release
2. Every issue must have a milestone
3. PRs reference issues with `Closes #N`
4. Use `gh milestone list` to see progress
5. Add due dates to milestones — even approximate ones create accountability
