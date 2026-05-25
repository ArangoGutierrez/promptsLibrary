#!/bin/bash
# test_skill_integration.sh — end-to-end harness for the /done skill
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DONE_BIN="$(cd "$SCRIPT_DIR/.." && pwd)/done.sh"
HOOK="$(cd "$SCRIPT_DIR/../../../hooks" && pwd)/done-hook.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# Common setup
UUID="donesk01-aaaa-bbbb-cccc-000000000001"
HOME_DIR="$TMP/h1"
mkdir -p "$HOME_DIR/.claude/audit/session-goals" "$HOME_DIR/.claude/audit"
TRANSCRIPT="$HOME_DIR/projects/fake/$UUID.jsonl"
mkdir -p "$(dirname "$TRANSCRIPT")"; touch "$TRANSCRIPT"

cat > "$HOME_DIR/.claude/audit/session-goals/$UUID.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed
GOAL

cat > "$HOME_DIR/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
2026-05-18T14:31:00Z	shellcheck ~/.claude/hooks/done-hook.sh	exit=0
2026-05-18T14:32:00Z	git commit -s -m "docs(specs): add design"	exit=0
LOG

# Run the Stop hook first to seed the outcomes log
echo "{\"transcript_path\":\"$TRANSCRIPT\"}" | HOME="$HOME_DIR" bash "$HOOK" >/dev/null 2>&1

# Scenario 1: /done confirm with mocked NAT returning AGREE → user.verdict=MET written
DONE_FAKE_NAT_RESPONSE=$'VERDICT: AGREE\nRATIONALE: all three bullets supported.\nGAPS: n/a' \
  HOME="$HOME_DIR" CLAUDE_SESSION_ID="$UUID" \
  bash "$DONE_BIN" confirm >/dev/null 2>&1

LATEST=$(grep "\"session\":\"$UUID\"" "$HOME_DIR/.claude/audit/session-outcomes-"*.log | tail -1)
if echo "$LATEST" | grep -q '"verdict":"MET"' && \
   echo "$LATEST" | grep -q '"nat_verdict":"AGREE"' && \
   echo "$LATEST" | grep -q '"evaluator":"nat-goal-evaluator"'; then
  echo "PASS: /done confirm AGREE -> MET + nat-goal-evaluator"; PASS=$((PASS+1))
else
  echo "FAIL: /done confirm AGREE — latest entry missing expected fields"
  echo "  got: $LATEST"; FAIL=$((FAIL+1))
fi

# Scenario 2: /done abandon "blocked by Y" → user.verdict=ABANDONED, evaluator=user_only, no NAT
UUID2="donesk02-aaaa-bbbb-cccc-000000000002"
HOME_DIR2="$TMP/h2"
mkdir -p "$HOME_DIR2/.claude/audit/session-goals" "$HOME_DIR2/.claude/audit"
cp "$HOME_DIR/.claude/audit/session-goals/$UUID.md" "$HOME_DIR2/.claude/audit/session-goals/$UUID2.md"
TRANSCRIPT2="$HOME_DIR2/projects/fake/$UUID2.jsonl"
mkdir -p "$(dirname "$TRANSCRIPT2")"; touch "$TRANSCRIPT2"
echo "{\"transcript_path\":\"$TRANSCRIPT2\"}" | HOME="$HOME_DIR2" bash "$HOOK" >/dev/null 2>&1

# DONE_FAKE_NAT_RESPONSE unset — if NAT is accidentally called, it errors
HOME="$HOME_DIR2" CLAUDE_SESSION_ID="$UUID2" \
  bash "$DONE_BIN" abandon "blocked by Y" >/dev/null 2>&1

LATEST2=$(grep "\"session\":\"$UUID2\"" "$HOME_DIR2/.claude/audit/session-outcomes-"*.log | tail -1)
if echo "$LATEST2" | grep -q '"verdict":"ABANDONED"' && \
   echo "$LATEST2" | grep -q '"reason":"blocked by Y"' && \
   echo "$LATEST2" | grep -q '"evaluator":"user_only"'; then
  echo "PASS: /done abandon — ABANDONED + user_only + reason"; PASS=$((PASS+1))
else
  echo "FAIL: /done abandon — latest entry missing expected fields"
  echo "  got: $LATEST2"; FAIL=$((FAIL+1))
fi

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
