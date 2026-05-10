#!/bin/bash
# Test validate-recommendation.sh hook behavior.
set -o pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-recommendation.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

if [ ! -x "$HOOK" ]; then
    echo "FAIL: hook missing or not executable: $HOOK"
    exit 1
fi

run_hook() {
    # $1: stdin JSON, $2: env vars (space-separated key=val), $3: optional session id
    local input="$1"; local envs="$2"; local sid="${3:-test-session}"
    env $envs TMPDIR="$TMP" CLAUDE_SESSION_ID="$sid" bash -c "echo '$input' | '$HOOK'" 2>&1
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

# Test 7: non-AskUserQuestion tool → exit 0 (no-op)
INPUT='{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"t7"}'
run_hook "$INPUT" "" "t7" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test7 wrong tool: expected exit 0, got $RC"
    exit 1
fi

echo "PASS"
