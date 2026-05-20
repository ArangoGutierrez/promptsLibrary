#!/bin/bash
# session-goal-init_test.sh — integration harness for session-goal-init.sh
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/session-goal-init.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

run_case() {
  local name="$1" input="$2" expected_exit="$3" expected_stderr_pattern="$4"
  shift 4
  local got_stderr
  got_stderr=$(echo "$input" | env "$@" bash "$HOOK" 2>&1 >/dev/null)
  local got_exit=$?
  if [ "$got_exit" -ne "$expected_exit" ]; then
    echo "FAIL: $name — expected exit $expected_exit, got $got_exit"
    FAIL=$((FAIL + 1)); return
  fi
  if [ -n "$expected_stderr_pattern" ] && ! echo "$got_stderr" | grep -q "$expected_stderr_pattern"; then
    echo "FAIL: $name — stderr did not match /$expected_stderr_pattern/"
    echo "  got: $got_stderr"
    FAIL=$((FAIL + 1)); return
  fi
  if [ -z "$expected_stderr_pattern" ] && [ -n "$got_stderr" ]; then
    echo "FAIL: $name — expected silent stderr, got: $got_stderr"
    FAIL=$((FAIL + 1)); return
  fi
  echo "PASS: $name"
  PASS=$((PASS + 1))
}

# Scenario 1: no goal file → prints nudge to stderr
FAKE_TRANSCRIPT="$TMP/abc12345-deadbeef.jsonl"
touch "$FAKE_TRANSCRIPT"
run_case "no goal file -> nudge" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "No session goal set" \
  HOME="$TMP"

# Scenario 2: goal file present → silent
mkdir -p "$TMP/.claude/audit/session-goals"
echo "## Initial 2026-05-18T00:00:00Z" > "$TMP/.claude/audit/session-goals/abc12345-deadbeef.md"
run_case "goal file present -> silent" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "" \
  HOME="$TMP"

# Scenario 3: session-goals/ dir missing → graceful (still exit 0, prints nudge since no file)
rm -rf "$TMP/.claude/audit/session-goals"
run_case "session-goals dir missing -> graceful nudge" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "No session goal set" \
  HOME="$TMP"

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
