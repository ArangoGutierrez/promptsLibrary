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

# Scenario 2: existing file → /goal appends Amendment stanza
INPUT2=$'Goal: ship Y\nAcceptance:\n- three'
run_goal "$HOME1" "$UUID1" "$INPUT2" >/dev/null 2>&1
if ! grep -q "^## Amendment " "$FILE1"; then
  echo "FAIL: scenario 2 — Amendment header missing"; FAIL=$((FAIL+1))
elif [ "$(grep -c '^## ' "$FILE1")" -ne 2 ]; then
  echo "FAIL: scenario 2 — expected exactly 2 stanzas, got $(grep -c '^## ' "$FILE1")"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 2 — Amendment stanza appended"; PASS=$((PASS+1))
fi

# Scenario 3: malformed input (no Goal: line) → warning but written
UUID3="goalt003-aaaa-bbbb-cccc-000000000003"
HOME3="$TMP/h3"
INPUT3="not-a-goal-format"
STDERR3=$(run_goal "$HOME3" "$UUID3" "$INPUT3" 2>&1 >/dev/null)
FILE3="$HOME3/.claude/audit/session-goals/$UUID3.md"
if ! echo "$STDERR3" | grep -q "missing 'Goal: '"; then
  echo "FAIL: scenario 3 — no warning emitted"; FAIL=$((FAIL+1))
elif [ ! -f "$FILE3" ]; then
  echo "FAIL: scenario 3 — file not written despite warning"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 3 — malformed input warns but writes"; PASS=$((PASS+1))
fi

# Scenario 4: 'amend' keyword stripped, behavior unchanged
UUID4="goalt004-aaaa-bbbb-cccc-000000000004"
HOME4="$TMP/h4"
INPUT4=$'amend Goal: stripped X\nAcceptance:\n- one'
run_goal "$HOME4" "$UUID4" "$INPUT4" >/dev/null 2>&1
FILE4="$HOME4/.claude/audit/session-goals/$UUID4.md"
if grep -q "^amend Goal:" "$FILE4"; then
  echo "FAIL: scenario 4 — 'amend' keyword leaked into stanza"; FAIL=$((FAIL+1))
elif ! grep -q "Goal: stripped X" "$FILE4"; then
  echo "FAIL: scenario 4 — Goal line missing after strip"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 4 — 'amend' keyword stripped"; PASS=$((PASS+1))
fi

# Scenario A: cwd has a git origin → stanza records 'Origin: <url>'
UUID_A="goalt00a-aaaa-bbbb-cccc-00000000000a"
HOME_A="$TMP/hA"
INPUT_A=$'Goal: scenario A\nAcceptance:\n- one'
WORK_A="$TMP/repoA"
mkdir -p "$WORK_A"
( cd "$WORK_A" && git init -q && git remote add origin git@example.com:foo/bar.git )
( cd "$WORK_A" && run_goal "$HOME_A" "$UUID_A" "$INPUT_A" >/dev/null 2>&1 )
FILE_A="$HOME_A/.claude/audit/session-goals/$UUID_A.md"
if [ ! -f "$FILE_A" ]; then
  echo "FAIL: scenario A — goal file not created"; FAIL=$((FAIL+1))
elif ! grep -q "^Origin: git@example.com:foo/bar.git$" "$FILE_A"; then
  echo "FAIL: scenario A — Origin line missing or wrong"
  echo "  got: $(grep -E '^(Goal|Origin):' "$FILE_A" | head -4)"
  FAIL=$((FAIL+1))
else
  echo "PASS: scenario A — Origin recorded from cwd's git remote"; PASS=$((PASS+1))
fi

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
