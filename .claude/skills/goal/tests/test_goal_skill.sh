#!/bin/bash
# test_goal_skill.sh — integration harness for the /goal skill
# Skill implementations vary; this harness exercises the skill's behavior
# via a thin shell wrapper at .claude/skills/goal/goal.sh (created in Task 12).
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOAL_BIN="$(cd "$SCRIPT_DIR/.." && pwd)/goal.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# Helper: run the goal binary with a fake HOME and a session-id file.
run_goal() {
  local home="$1"; shift
  local uuid="$1"; shift
  mkdir -p "$home/.claude/sessions"
  echo "{\"sessionId\":\"$uuid\"}" > "$home/.claude/sessions/$$.json"
  HOME="$home" CLAUDE_SESSION_ID="$uuid" bash "$GOAL_BIN" "$@"
}

UUID1="goalt001-aaaa-bbbb-cccc-000000000001"
HOME1="$TMP/h1"

# Scenario 1: empty session → /goal creates Initial stanza
INPUT1=$'Goal: ship X\nAcceptance:\n- one\n- two'
run_goal "$HOME1" "$UUID1" "$INPUT1" >/dev/null 2>&1
FILE1="$HOME1/.claude/audit/session-goals/$UUID1.md"
if [ ! -f "$FILE1" ]; then
  echo "FAIL: scenario 1 — goal file not created"; FAIL=$((FAIL+1))
elif ! grep -q "^## Initial " "$FILE1"; then
  echo "FAIL: scenario 1 — Initial stanza header missing"; FAIL=$((FAIL+1))
elif ! grep -q "Goal: ship X" "$FILE1"; then
  echo "FAIL: scenario 1 — Goal line missing"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 1 — Initial stanza written"; PASS=$((PASS+1))
fi

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
