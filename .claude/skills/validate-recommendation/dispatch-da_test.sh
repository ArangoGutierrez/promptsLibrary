#!/bin/bash
# dispatch-da_test.sh - test dispatch-da.sh HTTP wrapper.
# All tests use CLAUDE_PANEL_DA_MOCK_FILE to avoid real HTTP calls.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH="$SCRIPT_DIR/dispatch-da.sh"
FIX="$SCRIPT_DIR/fixtures"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -x "$DISPATCH" ]; then
    echo "FAIL: dispatch-da.sh missing or not executable"
    exit 1
fi

# Helper: create a dummy prompt file
PROMPT="$TMP/prompt.txt"
echo "Dummy prompt for tests; the mock file determines the response." > "$PROMPT"

# Helper: read three fields from a verdict file
verdict_field() {
    grep -m1 "^${2}: " "$1" 2>/dev/null | sed "s/^${2}: //"
}

# Test 1: NVIDIA_INFERENCE_API_KEY unset → ERROR verdict written
OUT="$TMP/test1.txt"
env -u NVIDIA_INFERENCE_API_KEY \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_hold_response.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT" >/dev/null 2>&1 || true
if [ ! -f "$OUT" ]; then
    echo "FAIL test1: output file not written when API key missing"
    exit 1
fi
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test1: expected VERDICT=ERROR when API key missing"
    cat "$OUT"
    exit 1
fi

# Test 2: mock HOLD response → HOLD verdict written
OUT="$TMP/test2.txt"
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_hold_response.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "HOLD" ]; then
    echo "FAIL test2: expected VERDICT=HOLD"
    cat "$OUT"
    exit 1
fi
RAT=$(verdict_field "$OUT" RATIONALE)
if [ -z "$RAT" ]; then
    echo "FAIL test2: RATIONALE empty for HOLD response"
    cat "$OUT"
    exit 1
fi
ALT=$(verdict_field "$OUT" ALTERNATIVE)
if [ "$ALT" != "n/a" ]; then
    echo "FAIL test2: expected ALTERNATIVE=n/a for HOLD; got '$ALT'"
    exit 1
fi

# Test 3: mock OVERTURN response → OVERTURN verdict, ALTERNATIVE=Option B
OUT="$TMP/test3.txt"
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_overturn_response.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "OVERTURN" ]; then
    echo "FAIL test3: expected VERDICT=OVERTURN"
    cat "$OUT"
    exit 1
fi
if [ "$(verdict_field "$OUT" ALTERNATIVE)" != "Option B" ]; then
    echo "FAIL test3: expected ALTERNATIVE='Option B', got '$(verdict_field "$OUT" ALTERNATIVE)'"
    exit 1
fi

# Test 4: malformed content (no VERDICT line in content) → ERROR
OUT="$TMP/test4.txt"
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_malformed_content.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test4: expected ERROR for malformed content"
    cat "$OUT"
    exit 1
fi

# Test 5: content is null (reasoning_content only) → ERROR; must NOT fall back to reasoning_content
OUT="$TMP/test5.txt"
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_null_content.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test5: expected ERROR when content is null"
    cat "$OUT"
    exit 1
fi

# Test 6: API error response (no .choices) → ERROR
OUT="$TMP/test6.txt"
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_api_error.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test6: expected ERROR for API error response"
    cat "$OUT"
    exit 1
fi

# Test 7: mock file doesn't exist → ERROR (script handles missing mock gracefully)
OUT="$TMP/test7.txt"
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="/nonexistent/path/$$.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test7: expected ERROR when mock file missing"
    cat "$OUT"
    exit 1
fi

# Test 8: missing --output arg → exit non-zero
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_hold_response.json" \
    "$DISPATCH" --prompt-file "$PROMPT" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$RC" = "0" ]; then
    echo "FAIL test8: expected non-zero exit when --output missing"
    exit 1
fi

# Test 9: missing --prompt-file arg → exit non-zero
NVIDIA_INFERENCE_API_KEY=test-key \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_hold_response.json" \
    "$DISPATCH" --output "$TMP/test9.txt" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$RC" = "0" ]; then
    echo "FAIL test9: expected non-zero exit when --prompt-file missing"
    exit 1
fi

# Test 10: API key is NOT leaked into the output verdict file
OUT="$TMP/test10.txt"
NVIDIA_INFERENCE_API_KEY=this-is-the-secret-key-do-not-leak \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/nemotron_hold_response.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if grep -q 'this-is-the-secret-key-do-not-leak' "$OUT"; then
    echo "FAIL test10: API key leaked into verdict file"
    exit 1
fi

echo "PASS"
