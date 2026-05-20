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

# Scenario 2: goal file present, 3/3 acceptance bullets match recent bash log → LIKELY_MET
UUID2="22222222-aaaa-bbbb-cccc-000000000002"
HOME2="$TMP/home2"
setup_fake_home "$HOME2" "$UUID2"
TRANSCRIPT2=$(fake_transcript_path "$HOME2" "$UUID2")
mkdir -p "$(dirname "$TRANSCRIPT2")"; touch "$TRANSCRIPT2"

# Synthesize a goal file with 3 bullets
cat > "$HOME2/.claude/audit/session-goals/$UUID2.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
GOAL

# Synthesize a bash audit log with 3 matching commands
BASH_LOG="$HOME2/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
mkdir -p "$(dirname "$BASH_LOG")"
cat > "$BASH_LOG" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
2026-05-18T14:31:00Z	shellcheck ~/.claude/hooks/done-hook.sh	exit=0
2026-05-18T14:32:00Z	git commit -s -m "docs(specs): add design"	exit=0
LOG

# Fire the hook
echo "{\"transcript_path\":\"$TRANSCRIPT2\"}" | HOME="$HOME2" bash "$HOOK" 2>/dev/null

# Assert outcomes entry has LIKELY_MET + matched=3 + total=3
if ! assert_outcomes_entry "$HOME2" "$UUID2" "verdict" "LIKELY_MET"; then
  echo "FAIL: scenario 2 — heuristic.verdict != LIKELY_MET"; FAIL=$((FAIL+1))
elif ! grep -q "\"matched\":3" "$HOME2/.claude/audit/session-outcomes-"*.log; then
  echo "FAIL: scenario 2 — matched != 3"; FAIL=$((FAIL+1))
elif ! grep -q "\"total\":3" "$HOME2/.claude/audit/session-outcomes-"*.log; then
  echo "FAIL: scenario 2 — total != 3"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 2 — 3/3 matched -> LIKELY_MET"; PASS=$((PASS+1))
fi

# Scenario 3: 1/3 bullets match → PARTIAL
UUID3="33333333-aaaa-bbbb-cccc-000000000003"
HOME3="$TMP/home3"
setup_fake_home "$HOME3" "$UUID3"
TRANSCRIPT3=$(fake_transcript_path "$HOME3" "$UUID3")
mkdir -p "$(dirname "$TRANSCRIPT3")"; touch "$TRANSCRIPT3"
cat > "$HOME3/.claude/audit/session-goals/$UUID3.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
GOAL
mkdir -p "$HOME3/.claude/audit"
cat > "$HOME3/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
LOG
echo "{\"transcript_path\":\"$TRANSCRIPT3\"}" | HOME="$HOME3" bash "$HOOK" 2>/dev/null
if ! assert_outcomes_entry "$HOME3" "$UUID3" "verdict" "PARTIAL"; then
  echo "FAIL: scenario 3 — verdict != PARTIAL"; FAIL=$((FAIL+1))
elif ! grep -q "\"matched\":1" "$HOME3/.claude/audit/session-outcomes-"*.log; then
  echo "FAIL: scenario 3 — matched != 1"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 3 — 1/3 matched -> PARTIAL"; PASS=$((PASS+1))
fi

# Scenario 4: 0/3 bullets match → NO_EVIDENCE
UUID4="44444444-aaaa-bbbb-cccc-000000000004"
HOME4="$TMP/home4"
setup_fake_home "$HOME4" "$UUID4"
TRANSCRIPT4=$(fake_transcript_path "$HOME4" "$UUID4")
mkdir -p "$(dirname "$TRANSCRIPT4")"; touch "$TRANSCRIPT4"
cat > "$HOME4/.claude/audit/session-goals/$UUID4.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
GOAL
mkdir -p "$HOME4/.claude/audit"
# Empty bash log
: > "$HOME4/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
echo "{\"transcript_path\":\"$TRANSCRIPT4\"}" | HOME="$HOME4" bash "$HOOK" 2>/dev/null
if ! assert_outcomes_entry "$HOME4" "$UUID4" "verdict" "NO_EVIDENCE"; then
  echo "FAIL: scenario 4 — verdict != NO_EVIDENCE"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 4 — 0/3 matched -> NO_EVIDENCE"; PASS=$((PASS+1))
fi

# Scenario 5: state-change debounce
# Fire twice with same goal + same bash log → only one new entry (besides any NO_GOAL/etc)
UUID5="55555555-aaaa-bbbb-cccc-000000000005"
HOME5="$TMP/home5"
setup_fake_home "$HOME5" "$UUID5"
TRANSCRIPT5=$(fake_transcript_path "$HOME5" "$UUID5")
mkdir -p "$(dirname "$TRANSCRIPT5")"; touch "$TRANSCRIPT5"
cat > "$HOME5/.claude/audit/session-goals/$UUID5.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
GOAL
mkdir -p "$HOME5/.claude/audit"
cat > "$HOME5/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
LOG

# First fire
echo "{\"transcript_path\":\"$TRANSCRIPT5\"}" | HOME="$HOME5" bash "$HOOK" 2>/dev/null
COUNT1=$(grep -c "\"session\":\"$UUID5\"" "$HOME5/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)

# Second fire with identical state
echo "{\"transcript_path\":\"$TRANSCRIPT5\"}" | HOME="$HOME5" bash "$HOOK" 2>/dev/null
COUNT2=$(grep -c "\"session\":\"$UUID5\"" "$HOME5/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)

if [ "$COUNT1" -ne "$COUNT2" ]; then
  echo "FAIL: scenario 5 — debounce broken; entries grew $COUNT1 -> $COUNT2"; FAIL=$((FAIL+1))
elif [ "$COUNT1" -eq 0 ]; then
  echo "FAIL: scenario 5 — no entries written at all"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 5 — debounce holds entries at $COUNT1"; PASS=$((PASS+1))
fi

# Scenario 6: stderr evidence block on a state change
UUID6="66666666-aaaa-bbbb-cccc-000000000006"
HOME6="$TMP/home6"
setup_fake_home "$HOME6" "$UUID6"
TRANSCRIPT6=$(fake_transcript_path "$HOME6" "$UUID6")
mkdir -p "$(dirname "$TRANSCRIPT6")"; touch "$TRANSCRIPT6"
cat > "$HOME6/.claude/audit/session-goals/$UUID6.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
GOAL
mkdir -p "$HOME6/.claude/audit"
cat > "$HOME6/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
LOG
STDERR6=$(echo "{\"transcript_path\":\"$TRANSCRIPT6\"}" | HOME="$HOME6" bash "$HOOK" 2>&1 >/dev/null)

# Must surface evidence; must NOT claim "accomplished"
if ! echo "$STDERR6" | grep -q "Heuristic: LIKELY_MET"; then
  echo "FAIL: scenario 6 — missing 'Heuristic: LIKELY_MET' in stderr"; FAIL=$((FAIL+1))
elif echo "$STDERR6" | grep -qi "session goal accomplished"; then
  echo "FAIL: scenario 6 — hook claimed 'Session goal accomplished' (theater)"; FAIL=$((FAIL+1))
elif ! echo "$STDERR6" | grep -q "${UUID6:0:8}"; then
  echo "FAIL: scenario 6 — UUID prefix missing from header"; FAIL=$((FAIL+1))
elif ! echo "$STDERR6" | grep -q "ship done-hook v1"; then
  echo "FAIL: scenario 6 — goal name missing from header"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 6 — evidence block surfaced; no completion claim"; PASS=$((PASS+1))
fi

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
