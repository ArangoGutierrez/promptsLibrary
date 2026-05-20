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

# Test 5: env.sh is sourced by the shim. Regression contract for the bug
# where Cursor IDE / non-interactive launches did not see env vars because
# ~/.zshrc was never sourced. We prove env.sh actually reaches the
# subprocess by routing NEMOTRON_APPROVE_PYTHON through env.sh to a marker
# script: if the shim sources env.sh, the marker runs and prints a known
# rationale; otherwise the shim falls back to system python3.12 and the
# marker is never observed.
TMP5=$(mktemp -d)
trap 'rm -rf "$TMP5"' EXIT
cat > "$TMP5/fake-python.sh" <<'FAKE_EOF'
#!/bin/bash
# Discard the JSON on stdin; the marker is the rationale we emit.
cat >/dev/null
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"nemotron: A:read:env_sh_sourced_marker"}}\n'
FAKE_EOF
chmod +x "$TMP5/fake-python.sh"
cat > "$TMP5/env.sh" <<EOF
export NEMOTRON_APPROVE_PYTHON="$TMP5/fake-python.sh"
EOF
INPUT='{"tool_name":"Bash","tool_input":{"command":"kubectl apply -f x.yaml"}}'
OUT=$(echo "$INPUT" | env -i HOME="$HOME" PATH="$PATH" NEMOTRON_APPROVE_SKILL_DIR="$TMP5" bash "$HOOK")
case "$OUT" in
    *env_sh_sourced_marker*)
        echo "PASS Test 5 (env.sh sourcing reaches python subprocess)"
        ;;
    *)
        echo "FAIL Test 5 (env.sh not sourced): expected output containing 'env_sh_sourced_marker', got: $OUT"
        exit 1
        ;;
esac

echo "---"
echo "ALL HOOK SHIM TESTS PASSED"
