#!/usr/bin/env bash
# day_test.sh — unit tests for day.sh pure decision logic.
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091  # day.sh sourced at runtime; functions defined there
source "$SCRIPT_DIR/day.sh"

PASS=0; FAIL=0
eq() { # eq <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; PASS=$((PASS+1));
  else echo "FAIL: $1 — expected '$2', got '$3'"; FAIL=$((FAIL+1)); fi
}
has() { # has <name> <needle> <haystack>
  if echo "$3" | grep -q "$2"; then echo "PASS: $1"; PASS=$((PASS+1));
  else echo "FAIL: $1 — '$3' lacks '$2'"; FAIL=$((FAIL+1)); fi
}

eq "no goal"            no-goal          "$(classify_stage 0 0 0 0 0)"
eq "goal, no spec"      needs-brainstorm "$(classify_stage 1 0 0 0 0)"
eq "spec, no plan"      needs-plan       "$(classify_stage 1 1 0 0 0)"
eq "plan, clean, fresh" ready-to-impl    "$(classify_stage 1 1 1 0 0)"
eq "dirty tree"         mid-impl         "$(classify_stage 1 1 1 1 0)"
eq "committed, clean"   needs-review     "$(classify_stage 1 1 1 0 1)"
# precedence: a dirty tree means mid-impl even if prior impl commits exist
eq "dirty beats commit" mid-impl         "$(classify_stage 1 1 1 1 1)"

has "rec no-goal"       "/goal"          "$(recommend no-goal)"
has "rec brainstorm"    "brainstorming"  "$(recommend needs-brainstorm)"
has "rec plan"          "writing-plans"  "$(recommend needs-plan)"
has "rec impl"          "test-driven"    "$(recommend ready-to-impl)"
has "rec review"        "finishing"      "$(recommend needs-review)"

echo; echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
