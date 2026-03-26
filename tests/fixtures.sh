#!/bin/bash
# Fixture data for bootstrap test.
# Auto-detects GitHub user; falls back to prompt.

# ── Auto-detect GitHub owner ──────────────────────────────
GITHUB_OWNER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$GITHUB_OWNER" ]; then
  echo "Could not detect GitHub user. Run: gh auth login"
  read -rp "GitHub owner (org or user): " GITHUB_OWNER
  [ -z "$GITHUB_OWNER" ] && { echo "No owner provided. Aborting."; exit 1; }
fi

GIT_USER_NAME=$(git config user.name 2>/dev/null || echo "")
GIT_USER_EMAIL=$(git config user.email 2>/dev/null || echo "")
if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
  echo "Git user not configured. Run: git config --global user.name / user.email"
  exit 1
fi

# ── Project fixture data ──────────────────────────────────
PROJECT_NAME="acme-api"
PROJECT_DESC="REST API for Acme Corp product catalog"
PROJECT_AUDIENCE="Internal engineering team"
PROJECT_VISIBILITY="private"
TECH_STACK="Node.js / TypeScript / Express / PostgreSQL"
WORKFLOW="solo"
PROFILE="A"
SHIPS_RELEASES="yes"
FIRST_VERSION_DONE="Users can browse and search the product catalog via REST endpoints"

# Build/test commands
DEV_CMD="npm run dev"
BUILD_CMD="npm run build"
TEST_CMD="npm test"
LINT_CMD="npm run lint"

# ── Milestones ────────────────────────────────────────────
MILESTONES=(
  "R0 — API Foundation|Core CRUD endpoints, auth, database schema, CI pipeline"
  "R1 — Search & Filters|Full-text search, category filters, pagination, rate limiting"
  "R2 — Production Ready|Monitoring, caching, load testing, API docs, deployment"
)

# ── Starter issues (per milestone) ────────────────────────
# Format: "milestone_index|label|title|body"
ISSUES=(
  "0|enhancement|FEAT: Set up Express server with TypeScript|Scaffold Express + TS config, health endpoint, dev/build scripts"
  "0|enhancement|FEAT: Add PostgreSQL with Prisma ORM|Schema for products, categories, users. Seed data."
  "0|enhancement|FEAT: Product catalog CRUD endpoints|GET /products, GET /products/:id, POST, PUT, DELETE"
  "0|enhancement|FEAT: JWT authentication middleware|Login, register, token refresh, route protection"
  "0|engineering|ENG: Configure CI pipeline|GitHub Actions: lint, typecheck, test on PR to staging"
  "0|documentation|DOCS: API documentation|OpenAPI spec, auth flow, setup instructions"
  "1|enhancement|FEAT: Full-text product search|PostgreSQL tsvector search on name + description"
  "1|enhancement|FEAT: Category filters and pagination|Filter by category, sort by price/name, cursor pagination"
  "1|engineering|ENG: Rate limiting|Express rate-limit middleware, per-IP and per-token limits"
  "2|enhancement|FEAT: Redis caching layer|Cache GET /products responses, 5-min TTL, invalidate on write"
  "2|engineering|ENG: Monitoring and health checks|Prometheus metrics, /health endpoint with DB check"
  "2|documentation|DOCS: Deployment runbook|Railway setup, env vars, DB migration, rollback procedure"
)
