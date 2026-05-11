#!/bin/bash
# aggregate.sh - parse panelist verdicts and emit final directive.
# Inputs: --da <verdict-file> --pe <verdict-file> --recommended-label <label>
# Output (stdout, one of):
#   PANEL_VERDICT: HOLD   (followed by one-line rationale summary)
#   PANEL_VERDICT: DISSENT (followed by augmented question JSON on next lines)
#   PANEL_VERDICT: ERROR  (followed by reason)
set -o pipefail

DA_FILE=""
PE_FILE=""
REC_LABEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --da) DA_FILE="$2"; shift 2 ;;
        --pe) PE_FILE="$2"; shift 2 ;;
        --recommended-label) REC_LABEL="$2"; shift 2 ;;
        *) echo "PANEL_VERDICT: ERROR"; echo "unknown arg: $1"; exit 0 ;;
    esac
done

if [ -z "$DA_FILE" ] || [ -z "$PE_FILE" ] || [ -z "$REC_LABEL" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "missing required args"
    exit 0
fi

if [ ! -r "$DA_FILE" ] || [ ! -r "$PE_FILE" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "verdict file unreadable"
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
    exit 0
    ;;
esac
case "$PE_VERDICT" in HOLD|OVERTURN) ;; *)
    echo "PANEL_VERDICT: ERROR"
    echo "PE verdict unparseable"
    exit 0
    ;;
esac

# Validate rationale present
if [ -z "$DA_RATIONALE" ] || [ -z "$PE_RATIONALE" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "rationale missing"
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
    exit 0
fi

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
exit 0
