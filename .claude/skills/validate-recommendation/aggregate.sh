#!/bin/bash
# aggregate.sh - parse panelist verdicts and emit final directive.
# Inputs: --da <verdict-file> --pe <verdict-file> --recommended-label <label>
# Output (stdout, one of):
#   PANEL_VERDICT: HOLD   (followed by one-line rationale summary)
#   PANEL_VERDICT: DISSENT (followed by augmented question JSON on next lines)
#   PANEL_VERDICT: ERROR  (followed by reason)
set -o pipefail

# Tighten umask so any trace-log file we create is mode 0600.
umask 077

# Append a verdict line to the trace log. Default-on telemetry: without it,
# a silently-broken panel is invisible to the operator (every recommendation
# hits ERROR and the user sees no behavioral change). Override the path
# via $CLAUDE_PANEL_TRACE_LOG for tests or alternative log routing.
log_verdict() {
    local outcome="$1"
    local detail="$2"
    local trace_log="${CLAUDE_PANEL_TRACE_LOG:-$HOME/.claude/debug/panel-trace.log}"
    local trace_dir
    trace_dir=$(dirname "$trace_log")
    mkdir -p "$trace_dir" 2>/dev/null || return 0
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local sid="${CLAUDE_SESSION_ID:-unknown}"
    # Sanitize detail to a single line, limit length so logs stay greppable.
    detail=$(printf '%s' "$detail" | tr '\n' ' ' | cut -c1-160)
    echo "[$ts] event=verdict session=$sid outcome=$outcome detail=\"$detail\"" \
        >> "$trace_log" 2>/dev/null || true
}

DA_FILE=""
PE_FILE=""
REC_LABEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --da) DA_FILE="$2"; shift 2 ;;
        --pe) PE_FILE="$2"; shift 2 ;;
        --recommended-label) REC_LABEL="$2"; shift 2 ;;
        *) echo "PANEL_VERDICT: ERROR"; echo "unknown arg: $1"; log_verdict ERROR "unknown arg"; exit 0 ;;
    esac
done

if [ -z "$DA_FILE" ] || [ -z "$PE_FILE" ] || [ -z "$REC_LABEL" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "missing required args"
    log_verdict ERROR "missing required args"
    exit 0
fi

if [ ! -r "$DA_FILE" ] || [ ! -r "$PE_FILE" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "verdict file unreadable"
    log_verdict ERROR "verdict file unreadable"
    exit 0
fi

parse_field() {
    local file="$1"; local field="$2"
    grep -m1 "^${field}: " "$file" 2>/dev/null | sed "s/^${field}: //"
}

DA_VERDICT=$(parse_field "$DA_FILE" "VERDICT")
DA_RATIONALE=$(parse_field "$DA_FILE" "RATIONALE")
DA_ALT=$(parse_field "$DA_FILE" "ALTERNATIVE")
PE_VERDICT=$(parse_field "$PE_FILE" "VERDICT")
PE_RATIONALE=$(parse_field "$PE_FILE" "RATIONALE")
PE_ALT=$(parse_field "$PE_FILE" "ALTERNATIVE")

# Validate verdicts parsed
case "$DA_VERDICT" in HOLD|OVERTURN) ;; *)
    echo "PANEL_VERDICT: ERROR"
    echo "DA verdict unparseable"
    log_verdict ERROR "DA verdict unparseable"
    exit 0
    ;;
esac
case "$PE_VERDICT" in HOLD|OVERTURN) ;; *)
    echo "PANEL_VERDICT: ERROR"
    echo "PE verdict unparseable"
    log_verdict ERROR "PE verdict unparseable"
    exit 0
    ;;
esac

# Validate rationale present
if [ -z "$DA_RATIONALE" ] || [ -z "$PE_RATIONALE" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "rationale missing"
    log_verdict ERROR "rationale missing"
    exit 0
fi

# Both HOLD → HOLD
if [ "$DA_VERDICT" = "HOLD" ] && [ "$PE_VERDICT" = "HOLD" ]; then
    echo "PANEL_VERDICT: HOLD"
    # Abbreviate rationales to first sentence for the user-facing summary.
    # Require [.!?] followed by whitespace and an uppercase letter so the
    # regex doesn't misfire on dots inside file paths (~/.claude) or
    # abbreviations (e.g., i.e.). If no sentence boundary is found, the
    # whole rationale is kept (sed leaves the input unchanged on no match).
    DA_SHORT=$(echo "$DA_RATIONALE" | sed 's/\([.!?]\)[[:space:]]\{1,\}[[:upper:]].*/\1/')
    PE_SHORT=$(echo "$PE_RATIONALE" | sed 's/\([.!?]\)[[:space:]]\{1,\}[[:upper:]].*/\1/')
    echo "DA: $DA_SHORT"
    echo "PE: $PE_SHORT"
    log_verdict HOLD "DA: $DA_SHORT | PE: $PE_SHORT"
    exit 0
fi

# Sanitize panelist rationale before embedding it in the user-visible
# DISSENT summary. A prompt-injected DA backend response could otherwise
# inject markdown links / images / inline code into the augmented
# AskUserQuestion text the user sees. Strip:
#   - image syntax  ![alt](url)
#   - link syntax   [text](url)
#   - backticks     ` (inline code fence)
# This is defense in depth; format compliance is the first line of defense.
sanitize() {
    printf '%s' "$1" | sed -e 's/!\[[^]]*\]([^)]*)//g' \
                           -e 's/\[[^]]*\]([^)]*)//g' \
                           -e 's/`//g'
}

DA_RATIONALE=$(sanitize "$DA_RATIONALE")
PE_RATIONALE=$(sanitize "$PE_RATIONALE")
DA_ALT=$(sanitize "$DA_ALT")
PE_ALT=$(sanitize "$PE_ALT")

# Otherwise DISSENT
echo "PANEL_VERDICT: DISSENT"
SUMMARY="**Panel review:** "
if [ "$DA_VERDICT" = "OVERTURN" ]; then
    SUMMARY+="DA flagged ${REC_LABEL} → suggests ${DA_ALT}: ${DA_RATIONALE} "
else
    SUMMARY+="DA held ${REC_LABEL}: ${DA_RATIONALE} "
fi
if [ "$PE_VERDICT" = "OVERTURN" ]; then
    SUMMARY+="PE flagged ${REC_LABEL} → suggests ${PE_ALT}: ${PE_RATIONALE}"
else
    SUMMARY+="PE held ${REC_LABEL}: ${PE_RATIONALE}"
fi
echo "$SUMMARY"
log_verdict DISSENT "DA=$DA_VERDICT PE=$PE_VERDICT alts=${DA_ALT:-n/a}/${PE_ALT:-n/a}"
exit 0
