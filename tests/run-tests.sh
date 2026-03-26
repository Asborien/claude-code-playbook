#!/bin/bash
# Playbook self-test runner
# Usage: ./tests/run-tests.sh
# Runs all test-*.sh files in tests/, reports pass/fail summary.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
ERRORS=()

echo "═══════════════════════════════════════════════════"
echo "  Playbook Test Suite"
echo "═══════════════════════════════════════════════════"
echo ""

for TEST_FILE in "$SCRIPT_DIR"/test-*.sh; do
  [ -f "$TEST_FILE" ] || continue
  TEST_NAME="$(basename "$TEST_FILE" .sh)"
  echo "── ${TEST_NAME} ──"
  if bash "$TEST_FILE" "$REPO_DIR"; then
    echo "  ✓ PASSED"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAILED"
    FAIL=$((FAIL + 1))
    ERRORS+=("$TEST_NAME")
  fi
  echo ""
done

echo "═══════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "  Failed: ${ERRORS[*]}"
fi
echo "═══════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
