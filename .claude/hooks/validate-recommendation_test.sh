#!/bin/bash
# Test validate-recommendation.sh hook behavior.
set -o pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-recommendation.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Isolate the trace log so tests don't pollute ~/.claude/debug/.
export CLAUDE_PANEL_TRACE_LOG="$TMP/panel-trace.log"

if [ ! -x "$HOOK" ]; then
    echo "FAIL: hook missing or not executable: $HOOK"
    exit 1
fi

run_hook() {
    # $1: stdin JSON, $2: env vars (space-separated key=val), $3: optional session id
    local input="$1"; local envs="$2"; local sid="${3:-test-session}"
    env $envs TMPDIR="$TMP" CLAUDE_SESSION_ID="$sid" CLAUDE_PANEL_TRACE_LOG="$CLAUDE_PANEL_TRACE_LOG" bash -c "echo '$input' | '$HOOK'" 2>&1
    return $?
}

# Test 1: marker present → exit 2 (block) + stderr mentions skill
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"the recommended choice"},{"label":"Option B","description":"alt"}]}]},"session_id":"t1"}'
OUT=$(run_hook "$INPUT" "" "t1") && RC=0 || RC=$?
if [ "$RC" != "2" ]; then
    echo "FAIL test1: expected exit 2 (block), got $RC"
    echo "OUT: $OUT"
    exit 1
fi
if ! echo "$OUT" | grep -qi 'validate-recommendation'; then
    echo "FAIL test1: stderr should mention skill name"
    echo "OUT: $OUT"
    exit 1
fi
if [ ! -f "$TMP/claude-panel-t1.json" ]; then
    echo "FAIL test1: state file not written"
    exit 1
fi

# Test 2: no marker → exit 0 (approve), no state file
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t2"}'
run_hook "$INPUT" "" "t2" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test2: expected exit 0, got $RC"
    exit 1
fi
if [ -f "$TMP/claude-panel-t2.json" ]; then
    echo "FAIL test2: state file should NOT exist"
    exit 1
fi

# Test 3: loop guard (Panel-flagged) → exit 0
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended; Panel-flagged)","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t3"}'
run_hook "$INPUT" "" "t3" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test3 loop guard: expected exit 0, got $RC"
    exit 1
fi
if [ -f "$TMP/claude-panel-t3.json" ]; then
    echo "FAIL test3: state file should NOT exist on loop guard"
    exit 1
fi

# Test 4: CLAUDE_PANEL=off bypasses panel even with marker
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"a"}]}]},"session_id":"t4"}'
run_hook "$INPUT" "CLAUDE_PANEL=off" "t4" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test4 CLAUDE_PANEL=off: expected exit 0, got $RC"
    exit 1
fi
if [ -f "$TMP/claude-panel-t4.json" ]; then
    echo "FAIL test4: state file should NOT exist when panel off"
    exit 1
fi

# Test 5: malformed JSON → exit 0 (fail-open) + stderr log
INPUT='not valid json'
OUT=$(run_hook "$INPUT" "" "t5") && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test5 malformed: expected exit 0 (fail-open), got $RC"
    exit 1
fi

# Test 6: state file has expected keys
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t6"}'
run_hook "$INPUT" "" "t6" >/dev/null 2>&1 || true
STATE="$TMP/claude-panel-t6.json"
if [ ! -f "$STATE" ]; then
    echo "FAIL test6: state file missing"
    exit 1
fi
for key in session_id tool_input recommended_label timeout_seconds created_at; do
    if ! jq -e --arg k "$key" 'has($k)' "$STATE" >/dev/null 2>&1; then
        echo "FAIL test6: state file missing key: $key"
        cat "$STATE"
        exit 1
    fi
done
# State file must be mode 0600 (user-only). Defense-in-depth on shared /tmp.
# stat differs between BSD (macOS) and GNU (Linux); try both.
MODE=$(stat -f '%Lp' "$STATE" 2>/dev/null) || MODE=$(stat -c '%a' "$STATE" 2>/dev/null)
if [ "$MODE" != "600" ]; then
    echo "FAIL test6: state file mode is $MODE, expected 600"
    exit 1
fi

# Test 7: non-AskUserQuestion tool → exit 0 (no-op)
INPUT='{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"t7"}'
run_hook "$INPUT" "" "t7" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test7 wrong tool: expected exit 0, got $RC"
    exit 1
fi

# After test 1+ the trace log should exist and contain a trigger line for
# session t1 (default-on telemetry; lets the operator detect silent decay).
if [ ! -f "$CLAUDE_PANEL_TRACE_LOG" ]; then
    echo "FAIL telemetry: trace log not created at $CLAUDE_PANEL_TRACE_LOG"
    exit 1
fi
if ! grep -q 'event=trigger session=t1' "$CLAUDE_PANEL_TRACE_LOG"; then
    echo "FAIL telemetry: missing 'event=trigger session=t1' in trace log"
    cat "$CLAUDE_PANEL_TRACE_LOG"
    exit 1
fi

# Test 8: re-entry guard — if state file already exists for the session,
# hook bypasses (exit 0) and removes the stale state. Models the scenario
# where the skill failed mid-flight and the assistant re-issued the same
# AskUserQuestion; we must not loop.
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t8"}'
# First call: hook blocks and writes state.
run_hook "$INPUT" "" "t8" >/dev/null 2>&1 || true
STATE8="$TMP/claude-panel-t8.json"
if [ ! -f "$STATE8" ]; then
    echo "FAIL test8 setup: state file not written by first call"
    exit 1
fi
# Second call (same session, same payload): re-entry path must approve.
run_hook "$INPUT" "" "t8" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test8 re-entry: expected exit 0 (bypass), got $RC"
    exit 1
fi
# Hook must remove the stale state file on bypass so the next legitimate
# session can start fresh.
if [ -f "$STATE8" ]; then
    echo "FAIL test8: hook must remove stale state file on re-entry bypass"
    exit 1
fi
# Third call after bypass: state is fresh, hook blocks again.
run_hook "$INPUT" "" "t8" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$RC" != "2" ]; then
    echo "FAIL test8 post-bypass: expected exit 2 on fresh call, got $RC"
    exit 1
fi

# Test 9: collision-proof state-file path when CLAUDE_SESSION_ID is unset.
# Two concurrent Claude Code sessions both resolving SID to "unknown" would
# share the same state-file path and corrupt each other's skill execution
# (session A's panel-skill cleanup deletes the file session B is mid-read
# on). The hook must fall back to a per-process identifier instead of the
# shared "unknown" sentinel.
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"a"}]}]}}'
env -u CLAUDE_SESSION_ID TMPDIR="$TMP" CLAUDE_PANEL_TRACE_LOG="$CLAUDE_PANEL_TRACE_LOG" \
    bash -c "echo '$INPUT' | '$HOOK'" >/dev/null 2>&1 || true
if [ -f "$TMP/claude-panel-unknown.json" ]; then
    echo "FAIL test9 collision: hook wrote to the shared 'unknown' state-file path when CLAUDE_SESSION_ID was unset. Two concurrent CC sessions would collide here. Hook must fall back to a per-process id (e.g. \$PPID)."
    exit 1
fi

echo "PASS"
