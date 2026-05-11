#!/bin/bash
# dispatch-da.sh - HTTP wrapper that calls the NVIDIA inference API
# (Nemotron-3 super) with a devil's-advocate panelist prompt and writes
# the parsed verdict to an output file.
#
# Always writes a verdict file at --output (HOLD, OVERTURN, or ERROR).
# Exit 0 on any path that wrote the file; exit non-zero only on missing
# required CLI args (--prompt-file, --output).
#
# NEVER writes the API key to any file or log line.

set -o pipefail

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

# Required env var
if [ -z "${NVIDIA_INFERENCE_API_KEY:-}" ]; then
    write_error "NVIDIA_INFERENCE_API_KEY env var unset"
fi

# Prompt file must exist
if [ ! -r "$PROMPT_FILE" ]; then
    write_error "prompt file unreadable: $PROMPT_FILE"
fi

PROMPT_TEXT=$(cat "$PROMPT_FILE")

MODEL="${CLAUDE_PANEL_DA_MODEL:-nvidia/nvidia/nemotron-3-super-v3}"
ENDPOINT="${CLAUDE_PANEL_DA_ENDPOINT:-https://inference-api.nvidia.com/v1/chat/completions}"
TIMEOUT="${CLAUDE_PANEL_DA_TIMEOUT:-60}"

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
    # Real HTTP call. Authorization header carries the secret — never echoed.
    # Redirect curl's stderr to /dev/null so its diagnostics (which may include
    # the URL) don't leak through the verdict file or trace logs.
    RESPONSE=$(curl --silent --max-time "$TIMEOUT" \
        -X POST "$ENDPOINT" \
        -H "Authorization: Bearer $NVIDIA_INFERENCE_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" 2>/dev/null)
    CURL_RC=$?
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

# Extract content (ONLY from .choices[0].message.content; never reasoning_content)
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
