#!/bin/bash
# dispatch-da.sh - HTTP wrapper that calls an OpenAI-compatible chat
# completions endpoint with a devil's-advocate panelist prompt and writes
# the parsed verdict to an output file.
#
# Always writes a verdict file at --output (HOLD, OVERTURN, or ERROR).
# Exit 0 on any path that wrote the file; exit non-zero only on missing
# required CLI args (--prompt-file, --output).
#
# NEVER writes the API key to any file or log line.

set -o pipefail

# Tighten umask so files we create (verdict output, temp prompt copies,
# auth header file) are mode 0600. Defense in depth on shared /tmp.
umask 077

# Clean up the auth-header temp file on any exit path (even via write_error).
HDR_FILE=""
cleanup() {
    if [ -n "$HDR_FILE" ] && [ -f "$HDR_FILE" ]; then
        rm -f "$HDR_FILE"
    fi
}
trap cleanup EXIT

PROMPT_FILE=""
OUTPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --output)      OUTPUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 --prompt-file <path> --output <verdict-file>" >&2
            exit 1
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$PROMPT_FILE" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: $0 --prompt-file <path> --output <verdict-file>" >&2
    exit 1
fi

# Helper: write an ERROR verdict to $OUTPUT and exit 0. Reason text is
# sanitized to one line; never contains secrets.
write_error() {
    local reason="$1"
    # Collapse newlines and limit length defensively
    reason=$(printf '%s' "$reason" | tr '\n' ' ' | cut -c1-200)
    printf 'VERDICT: ERROR\nRATIONALE: %s\nALTERNATIVE: n/a\n' "$reason" > "$OUTPUT" 2>/dev/null || true
    exit 0
}

# Required env vars. No defaults — the DA backend is whatever the user
# configures. Use any OpenAI-compatible chat completions API:
#   PANEL_DA_API_KEY        bearer token
#   CLAUDE_PANEL_DA_ENDPOINT  full URL of /v1/chat/completions (or equivalent)
#   CLAUDE_PANEL_DA_MODEL     model identifier the endpoint expects
if [ -z "${PANEL_DA_API_KEY:-}" ]; then
    write_error "PANEL_DA_API_KEY env var unset"
fi
if [ -z "${CLAUDE_PANEL_DA_ENDPOINT:-}" ]; then
    write_error "CLAUDE_PANEL_DA_ENDPOINT env var unset"
fi
if [ -z "${CLAUDE_PANEL_DA_MODEL:-}" ]; then
    write_error "CLAUDE_PANEL_DA_MODEL env var unset"
fi

# Prompt file must exist
if [ ! -r "$PROMPT_FILE" ]; then
    write_error "prompt file unreadable: $PROMPT_FILE"
fi

PROMPT_TEXT=$(cat "$PROMPT_FILE")

MODEL="$CLAUDE_PANEL_DA_MODEL"
ENDPOINT="$CLAUDE_PANEL_DA_ENDPOINT"
TIMEOUT="${CLAUDE_PANEL_DA_TIMEOUT:-60}"

# Endpoint must be https:// (or http://localhost for local-only test setups).
# This is not an attacker-proof allowlist — anyone who can edit the env
# can change endpoint AND this check. It exists to catch typos and
# accidental http://prod redirects.
case "$ENDPOINT" in
    https://*) ;;
    http://localhost/*|http://localhost:*) ;;
    http://127.0.0.1/*|http://127.0.0.1:*) ;;
    *)
        write_error "endpoint must be https:// (or http://localhost for tests): $ENDPOINT"
        ;;
esac

# Build request payload via jq (escapes special chars in PROMPT_TEXT safely)
PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT_TEXT" \
    '{
        model: $model,
        messages: [
            {role: "user", content: $prompt}
        ],
        temperature: 0.3,
        max_tokens: 1024
    }' 2>/dev/null) || write_error "failed to build request payload"

# Get response: mock mode if CLAUDE_PANEL_DA_MOCK_FILE is set, else HTTP
if [ -n "${CLAUDE_PANEL_DA_MOCK_FILE:-}" ]; then
    if [ ! -r "$CLAUDE_PANEL_DA_MOCK_FILE" ]; then
        write_error "mock response file unreadable"
    fi
    RESPONSE=$(cat "$CLAUDE_PANEL_DA_MOCK_FILE")
else
    # Real HTTP call. Pass the Authorization header through a temp file
    # (umask 077) and curl's -H @<file> syntax so the secret never appears
    # in process argv (visible via ps auxe / /proc/<pid>/cmdline).
    # The cleanup trap removes the file on any exit path.
    # CURL is settable for tests that mock the binary with an argv recorder.
    HDR_FILE=$(umask 077 && mktemp "${TMPDIR:-/tmp}/dispatch-da-hdr.XXXXXX" 2>/dev/null)
    if [ -z "$HDR_FILE" ] || [ ! -f "$HDR_FILE" ]; then
        write_error "failed to create auth-header temp file"
    fi
    printf 'Authorization: Bearer %s\n' "$PANEL_DA_API_KEY" > "$HDR_FILE"

    # Redirect curl's stderr to /dev/null so its diagnostics (which may
    # include the URL) don't leak through the verdict file or trace logs.
    RESPONSE=$("${CURL:-curl}" --silent --max-time "$TIMEOUT" \
        -X POST "$ENDPOINT" \
        -H "@$HDR_FILE" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" 2>/dev/null)
    CURL_RC=$?
    rm -f "$HDR_FILE"
    HDR_FILE=""
    if [ "$CURL_RC" -ne 0 ]; then
        write_error "HTTP call failed (curl exit $CURL_RC)"
    fi
    if [ -z "$RESPONSE" ]; then
        write_error "API returned empty response"
    fi
fi

# Validate response is JSON
if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
    write_error "API response is not valid JSON"
fi

# Check for API error structure (no .choices array)
HAS_CHOICES=$(echo "$RESPONSE" | jq -r 'has("choices") and (.choices | type == "array") and (.choices | length > 0)' 2>/dev/null)
if [ "$HAS_CHOICES" != "true" ]; then
    ERR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "no choices in response"' 2>/dev/null)
    write_error "API returned error or empty choices: $ERR_MSG"
fi

# Extract content (ONLY from .choices[0].message.content). Reasoning
# models (those that put their visible answer in a separate
# reasoning_content field) are handled by the explicit ERROR-on-null
# check below — we do NOT fall back to reasoning_content because the
# format contract is for content.
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
    write_error "API response had null or empty content (likely token-limit hit during reasoning)"
fi

# Parse the strict VERDICT/RATIONALE/ALTERNATIVE format from content
parse_field() {
    local field="$1"
    printf '%s' "$CONTENT" | grep -m1 "^${field}: " | sed "s/^${field}: //"
}

VERDICT=$(parse_field "VERDICT")
RATIONALE=$(parse_field "RATIONALE")
ALTERNATIVE=$(parse_field "ALTERNATIVE")

if [ -z "$VERDICT" ]; then
    write_error "response content missing VERDICT line"
fi
if [ -z "$RATIONALE" ]; then
    write_error "response content missing RATIONALE line"
fi

case "$VERDICT" in
    HOLD|OVERTURN) ;;
    *) write_error "invalid VERDICT value: $VERDICT" ;;
esac

# Default ALTERNATIVE to n/a when absent (HOLD doesn't require it)
if [ -z "$ALTERNATIVE" ]; then
    ALTERNATIVE="n/a"
fi

# Write the verdict file. Using printf with explicit format to avoid any
# variable-expansion surprises if rationale contains $ or backticks.
printf 'VERDICT: %s\nRATIONALE: %s\nALTERNATIVE: %s\n' \
    "$VERDICT" "$RATIONALE" "$ALTERNATIVE" > "$OUTPUT" \
    || write_error "failed to write output file"

exit 0
