#!/bin/bash
# done-hook_test.sh — integration harness for done-hook.sh
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/done-hook.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

setup_fake_home() {
  local home="$1" uuid="$2"
  mkdir -p "$home/.claude/audit/session-goals"
}

fake_transcript_path() {
  local home="$1" uuid="$2"
  echo "$home/projects/fake/$uuid.jsonl"
}

assert_outcomes_entry() {
  local home="$1" uuid="$2" want_field="$3" want_value="$4"
  local log
  # shellcheck disable=SC2012  # paths are internal/controlled; ls preserves plan pattern
  log=$(ls "$home/.claude/audit/session-outcomes-"*.log 2>/dev/null | tail -1)
  if [ -z "$log" ]; then
    echo "    (no outcomes log written)"
    return 1
  fi
  grep "\"session\":\"$uuid\"" "$log" | tail -1 | \
    grep -qE "\"$want_field\":\"?$want_value\"?" || {
      echo "    (expected $want_field=$want_value in last entry; got:)"
      grep "\"session\":\"$uuid\"" "$log" | tail -1
      return 1
    }
}

# Scenario 1: no goal file → single NO_GOAL outcomes entry, silent stderr
UUID1="11111111-aaaa-bbbb-cccc-000000000001"
HOME1="$TMP/home1"
setup_fake_home "$HOME1" "$UUID1"
TRANSCRIPT1=$(fake_transcript_path "$HOME1" "$UUID1")
mkdir -p "$(dirname "$TRANSCRIPT1")"; touch "$TRANSCRIPT1"

# First fire: writes NO_GOAL
STDERR=$(echo "{\"transcript_path\":\"$TRANSCRIPT1\"}" | HOME="$HOME1" bash "$HOOK" 2>&1 >/dev/null)
if [ -n "$STDERR" ]; then
  echo "FAIL: scenario 1 first fire — expected silent stderr, got: $STDERR"; FAIL=$((FAIL+1))
elif ! assert_outcomes_entry "$HOME1" "$UUID1" "verdict" "NO_GOAL"; then
  echo "FAIL: scenario 1 first fire — outcomes entry missing NO_GOAL"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 1a — NO_GOAL entry written on first fire"; PASS=$((PASS+1))
fi

# Second fire: NO new entry (debounce on existing NO_GOAL)
ENTRIES_BEFORE=$(grep -c "\"session\":\"$UUID1\"" "$HOME1/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)
echo "{\"transcript_path\":\"$TRANSCRIPT1\"}" | HOME="$HOME1" bash "$HOOK" 2>/dev/null
ENTRIES_AFTER=$(grep -c "\"session\":\"$UUID1\"" "$HOME1/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)
if [ "$ENTRIES_BEFORE" -ne "$ENTRIES_AFTER" ]; then
  echo "FAIL: scenario 1b — debounce broken; got $ENTRIES_AFTER entries (expected $ENTRIES_BEFORE)"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 1b — debounce keeps NO_GOAL to one entry"; PASS=$((PASS+1))
fi

# More scenarios added in later tasks (2 - 6)

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
