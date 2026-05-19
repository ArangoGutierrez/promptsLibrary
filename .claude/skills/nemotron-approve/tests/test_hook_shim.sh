#!/bin/bash
# Integration test for the hook shim. Pipes canned JSON inputs and asserts
# the stdout JSON shape. Runs against the worktree's copy of the shim and
# skill dir so it does not require deployment to $HOME.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$TEST_DIR/.." && pwd)"
HOOK="$(cd "$SKILL_DIR/../../hooks" && pwd)/nemotron-approve.sh"

if [ ! -x "$HOOK" ]; then
    echo "FAIL: hook shim not executable at $HOOK"
    exit 1
fi

export NEMOTRON_APPROVE_SKILL_DIR="$SKILL_DIR"

# Test 1: Lane A command → allow
INPUT='{"tool_name":"Bash","tool_input":{"command":"kubectl get pods"}}'
OUT=$(echo "$INPUT" | "$HOOK")
DECISION=$(echo "$OUT" | jq -r '.hookSpecificOutput.permissionDecision')
if [ "$DECISION" != "allow" ]; then
    echo "FAIL Test 1 (Lane A): expected allow, got '$DECISION'. Output: $OUT"
    exit 1
fi
echo "PASS Test 1 (Lane A allow)"

# Test 2: Lane B command → ask
INPUT='{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/foo"}}'
OUT=$(echo "$INPUT" | "$HOOK")
DECISION=$(echo "$OUT" | jq -r '.hookSpecificOutput.permissionDecision')
if [ "$DECISION" != "ask" ]; then
    echo "FAIL Test 2 (Lane B): expected ask, got '$DECISION'. Output: $OUT"
    exit 1
fi
echo "PASS Test 2 (Lane B ask)"

# Test 3: malformed JSON → ask (or empty stdout, both acceptable per design)
INPUT='not valid json'
OUT=$(echo "$INPUT" | "$HOOK")
if [ -n "$OUT" ]; then
    DECISION=$(echo "$OUT" | jq -r '.hookSpecificOutput.permissionDecision')
    if [ "$DECISION" != "ask" ]; then
        echo "FAIL Test 3 (malformed): expected ask or empty, got '$DECISION'"
        exit 1
    fi
fi
echo "PASS Test 3 (malformed input)"

# Test 4: disabled LLM lane → gray-zone command falls back to ask
INPUT='{"tool_name":"Bash","tool_input":{"command":"kubectl apply -f x.yaml"}}'
OUT=$(echo "$INPUT" | NEMOTRON_APPROVE_DISABLED=1 "$HOOK")
DECISION=$(echo "$OUT" | jq -r '.hookSpecificOutput.permissionDecision')
if [ "$DECISION" != "ask" ]; then
    echo "FAIL Test 4 (disabled gray-zone): expected ask, got '$DECISION'"
    exit 1
fi
echo "PASS Test 4 (disabled gray-zone falls back to ask)"

echo "---"
echo "ALL HOOK SHIM TESTS PASSED"
