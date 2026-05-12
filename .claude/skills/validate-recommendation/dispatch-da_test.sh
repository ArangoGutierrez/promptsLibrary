#!/bin/bash
# dispatch-da_test.sh - test dispatch-da.sh HTTP wrapper.
# All tests use CLAUDE_PANEL_DA_MOCK_FILE to avoid real HTTP calls,
# except the argv-leak test which uses a mock curl binary.
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

# Test 1: PANEL_DA_API_KEY unset → ERROR verdict written
OUT="$TMP/test1.txt"
env -u PANEL_DA_API_KEY \
    CLAUDE_PANEL_DA_ENDPOINT="https://example.test/v1/chat/completions" \
    CLAUDE_PANEL_DA_MODEL="test-model" \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
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

# Test 1b: CLAUDE_PANEL_DA_ENDPOINT unset → ERROR
OUT="$TMP/test1b.txt"
env -u CLAUDE_PANEL_DA_ENDPOINT \
    PANEL_DA_API_KEY=test-key \
    CLAUDE_PANEL_DA_MODEL="test-model" \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT" >/dev/null 2>&1 || true
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test1b: expected ERROR when CLAUDE_PANEL_DA_ENDPOINT missing"
    cat "$OUT"
    exit 1
fi

# Test 1c: CLAUDE_PANEL_DA_MODEL unset → ERROR
OUT="$TMP/test1c.txt"
env -u CLAUDE_PANEL_DA_MODEL \
    PANEL_DA_API_KEY=test-key \
    CLAUDE_PANEL_DA_ENDPOINT="https://example.test/v1/chat/completions" \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT" >/dev/null 2>&1 || true
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test1c: expected ERROR when CLAUDE_PANEL_DA_MODEL missing"
    cat "$OUT"
    exit 1
fi

# Default env for the rest of the tests (mock mode bypasses endpoint
# validation, but tests still need the three required vars set so the
# wrapper doesn't ERROR on missing-required-env before reaching the
# mock-mode branch).
export PANEL_DA_API_KEY=test-key
export CLAUDE_PANEL_DA_ENDPOINT="https://example.test/v1/chat/completions"
export CLAUDE_PANEL_DA_MODEL="test-model"

# Test 2: mock HOLD response → HOLD verdict written + mode 0600
OUT="$TMP/test2.txt"
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "HOLD" ]; then
    echo "FAIL test2: expected VERDICT=HOLD"
    cat "$OUT"
    exit 1
fi
# Verdict file must be mode 0600 (user-only). Defense-in-depth on shared /tmp.
MODE=$(stat -f '%Lp' "$OUT" 2>/dev/null) || MODE=$(stat -c '%a' "$OUT" 2>/dev/null)
if [ "$MODE" != "600" ]; then
    echo "FAIL test2: verdict file mode is $MODE, expected 600"
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
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_overturn.json" \
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
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_malformed.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test4: expected ERROR for malformed content"
    cat "$OUT"
    exit 1
fi

# Test 5: content is null → ERROR; must NOT fall back to any alternative field
OUT="$TMP/test5.txt"
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_null_content.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test5: expected ERROR when content is null"
    cat "$OUT"
    exit 1
fi

# Test 6: API error response (no .choices) → ERROR
OUT="$TMP/test6.txt"
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_api_error.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test6: expected ERROR for API error response"
    cat "$OUT"
    exit 1
fi

# Test 7: mock file doesn't exist → ERROR (script handles missing mock gracefully)
OUT="$TMP/test7.txt"
CLAUDE_PANEL_DA_MOCK_FILE="/nonexistent/path/$$.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test7: expected ERROR when mock file missing"
    cat "$OUT"
    exit 1
fi

# Test 8: missing --output arg → exit non-zero
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
    "$DISPATCH" --prompt-file "$PROMPT" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$RC" = "0" ]; then
    echo "FAIL test8: expected non-zero exit when --output missing"
    exit 1
fi

# Test 9: missing --prompt-file arg → exit non-zero
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
    "$DISPATCH" --output "$TMP/test9.txt" >/dev/null 2>&1 && RC=0 || RC=$?
if [ "$RC" = "0" ]; then
    echo "FAIL test9: expected non-zero exit when --prompt-file missing"
    exit 1
fi

# Test 10: API key is NOT leaked into the output verdict file
OUT="$TMP/test10.txt"
PANEL_DA_API_KEY=this-is-the-secret-key-do-not-leak \
    CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_hold.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if grep -q 'this-is-the-secret-key-do-not-leak' "$OUT"; then
    echo "FAIL test10: API key leaked into verdict file"
    exit 1
fi

# Test 11: API key NOT in curl argv (process-list leakage).
# Replace curl with a mock that records its argv to a file. Run dispatch-da
# in real-HTTP mode (no mock file), and verify the sentinel key value never
# appears anywhere in the recorded curl invocation.
ARGV_LOG="$TMP/curl_argv.log"
CURL_MOCK="$TMP/mock-curl.sh"
cat > "$CURL_MOCK" <<'MOCK_EOF'
#!/bin/bash
# Records every arg to $ARGV_LOG_PATH (one per line) then emits a synthetic
# OpenAI-compatible chat completions response so the dispatcher can proceed.
for a in "$@"; do
    printf '%s\n' "$a" >> "$ARGV_LOG_PATH"
done
cat <<'BODY'
{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"VERDICT: HOLD\nRATIONALE: argv-leak probe: rationale a. rationale b. rationale c.\nALTERNATIVE: n/a"}}]}
BODY
MOCK_EOF
chmod +x "$CURL_MOCK"

OUT="$TMP/test11.txt"
SENTINEL="sentinel-key-must-not-appear-in-argv-X9Y8Z7"
PANEL_DA_API_KEY="$SENTINEL" \
    CURL="$CURL_MOCK" \
    ARGV_LOG_PATH="$ARGV_LOG" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"

if [ ! -f "$ARGV_LOG" ]; then
    echo "FAIL test11: curl mock was not invoked"
    exit 1
fi
if grep -q "$SENTINEL" "$ARGV_LOG"; then
    echo "FAIL test11: API key appeared in curl argv"
    echo "ARGV: $(cat "$ARGV_LOG")"
    exit 1
fi
if [ "$(grep -c '^-H$' "$ARGV_LOG")" -lt 2 ]; then
    echo "FAIL test11: expected at least 2 -H flags in curl argv (auth via @file + content-type)"
    exit 1
fi
# Verify a verdict was produced (round-trip via the mock works).
if [ "$(grep -m1 '^VERDICT: ' "$OUT" | sed 's/^VERDICT: //')" != "HOLD" ]; then
    echo "FAIL test11: dispatcher did not produce HOLD from mock response"
    cat "$OUT"
    exit 1
fi

# Test 12: non-https endpoint → ERROR verdict, curl NEVER invoked.
# Defends against typos / accidental http://prod redirects. Not an
# attacker-proof allowlist: anyone who can edit the env can edit this
# check too. It catches misconfiguration, not adversarial redirection.
ARGV_LOG12="$TMP/curl_argv_12.log"
OUT="$TMP/test12.txt"
CLAUDE_PANEL_DA_ENDPOINT="http://example.com/capture" \
    CURL="$CURL_MOCK" \
    ARGV_LOG_PATH="$ARGV_LOG12" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test12: expected ERROR for non-https endpoint"
    cat "$OUT"
    exit 1
fi
if ! grep -qi 'https' "$OUT"; then
    echo "FAIL test12: ERROR rationale should mention 'https'"
    cat "$OUT"
    exit 1
fi
if [ -f "$ARGV_LOG12" ]; then
    echo "FAIL test12: curl was invoked despite non-https endpoint"
    exit 1
fi

# Test 13: http://localhost is allowed (offline test setups).
ARGV_LOG13="$TMP/curl_argv_13.log"
OUT="$TMP/test13.txt"
CLAUDE_PANEL_DA_ENDPOINT="http://localhost:8080/v1/chat/completions" \
    CURL="$CURL_MOCK" \
    ARGV_LOG_PATH="$ARGV_LOG13" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "HOLD" ]; then
    echo "FAIL test13: expected HOLD via http://localhost endpoint"
    cat "$OUT"
    exit 1
fi
if [ ! -f "$ARGV_LOG13" ]; then
    echo "FAIL test13: curl should have been invoked for http://localhost"
    exit 1
fi

echo "PASS"
