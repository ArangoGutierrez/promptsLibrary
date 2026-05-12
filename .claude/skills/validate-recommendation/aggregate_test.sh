#!/bin/bash
# aggregate_test.sh - test verdict aggregation rules per spec.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGG="$SCRIPT_DIR/aggregate.sh"
FIX="$SCRIPT_DIR/fixtures"
ERR_FILE=$(mktemp)
TRACE_LOG=$(mktemp)
export CLAUDE_PANEL_TRACE_LOG="$TRACE_LOG"
trap 'rm -f "$ERR_FILE" "$TRACE_LOG"' EXIT

if [ ! -x "$AGG" ]; then
    echo "FAIL: aggregate.sh missing or not executable"
    exit 1
fi

# Helper: run aggregator; capture stdout in OUT, stderr in $ERR_FILE.
run_agg() {
    "$AGG" --da "$1" --pe "$2" --recommended-label "Option A" 2>"$ERR_FILE"
}

# Test 1: both HOLD → PANEL_VERDICT: HOLD with non-empty DA: and PE: lines.
OUT=$(run_agg "$FIX/da_hold.txt" "$FIX/pe_hold.txt")
ERR=$(cat "$ERR_FILE")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: HOLD$'; then
    echo "FAIL test1 both_hold: expected HOLD"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$OUT" | grep -qE '^DA: [^[:space:]].*'; then
    echo "FAIL test1: DA rationale must be present and non-empty"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$OUT" | grep -qE '^PE: [^[:space:]].*'; then
    echo "FAIL test1: PE rationale must be present and non-empty"
    echo "GOT: $OUT"
    exit 1
fi
# First-sentence abbreviation must keep paths and abbreviations intact.
# The pe_hold.txt fixture's first sentence contains "~/.claude/CLAUDE.md";
# a too-greedy regex like 's/\([.!?]\).*/\1/' would truncate at the dot
# in "~/" producing "PE: Option A aligns with YAGNI and atomicity per ~/."
# (broken). The fixed regex requires whitespace+uppercase after the
# punctuation, so the path is preserved.
PE_LINE=$(echo "$OUT" | grep -m1 '^PE: ')
if ! echo "$PE_LINE" | grep -q '~/\.claude/CLAUDE\.md'; then
    echo "FAIL test1: PE abbreviation lost the path '~/.claude/CLAUDE.md'"
    echo "GOT: $PE_LINE"
    exit 1
fi
if echo "$PE_LINE" | grep -qE 'per ~/\.$'; then
    echo "FAIL test1: PE abbreviation truncated at first '.' in path"
    echo "GOT: $PE_LINE"
    exit 1
fi
if [ -n "$ERR" ]; then
    echo "FAIL test1: expected empty stderr for HOLD case"
    echo "STDERR: $ERR"
    exit 1
fi

# Test 2: DA overturn (B), PE hold → DISSENT with structured Panel review line containing Option B.
OUT=$(run_agg "$FIX/da_overturn_b.txt" "$FIX/pe_hold.txt")
ERR=$(cat "$ERR_FILE")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test2 da_overturn: expected DISSENT"
    echo "GOT: $OUT"
    exit 1
fi
SUMMARY=$(echo "$OUT" | grep -F '**Panel review:**' | head -n1)
if [ -z "$SUMMARY" ]; then
    echo "FAIL test2: missing structural '**Panel review:**' summary line"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$SUMMARY" | grep -q 'Option B'; then
    echo "FAIL test2: 'Option B' must appear ON the Panel review line"
    echo "GOT: $OUT"
    exit 1
fi
if [ -n "$ERR" ]; then
    echo "FAIL test2: expected empty stderr for DISSENT case"
    echo "STDERR: $ERR"
    exit 1
fi

# Test 3: DA hold, PE overturn (C) → DISSENT with structured Panel review line containing Option C.
OUT=$(run_agg "$FIX/da_hold.txt" "$FIX/pe_overturn_c.txt")
ERR=$(cat "$ERR_FILE")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test3 pe_overturn: expected DISSENT"
    echo "GOT: $OUT"
    exit 1
fi
SUMMARY=$(echo "$OUT" | grep -F '**Panel review:**' | head -n1)
if [ -z "$SUMMARY" ]; then
    echo "FAIL test3: missing '**Panel review:**' summary line"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$SUMMARY" | grep -q 'Option C'; then
    echo "FAIL test3: 'Option C' must appear ON the Panel review line"
    echo "GOT: $OUT"
    exit 1
fi
if [ -n "$ERR" ]; then
    echo "FAIL test3: expected empty stderr"
    echo "STDERR: $ERR"
    exit 1
fi

# Test 4: both overturn with different alternatives → DISSENT, both alternatives in Panel review line.
OUT=$(run_agg "$FIX/da_overturn_b.txt" "$FIX/pe_overturn_c.txt")
ERR=$(cat "$ERR_FILE")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test4 both_overturn: expected DISSENT"
    echo "GOT: $OUT"
    exit 1
fi
SUMMARY=$(echo "$OUT" | grep -F '**Panel review:**' | head -n1)
if [ -z "$SUMMARY" ]; then
    echo "FAIL test4: missing '**Panel review:**' summary line"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$SUMMARY" | grep -q 'Option B'; then
    echo "FAIL test4: 'Option B' missing from Panel review line"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$SUMMARY" | grep -q 'Option C'; then
    echo "FAIL test4: 'Option C' missing from Panel review line"
    echo "GOT: $OUT"
    exit 1
fi
if [ -n "$ERR" ]; then
    echo "FAIL test4: expected empty stderr"
    echo "STDERR: $ERR"
    exit 1
fi

# Test 5: malformed DA → ERROR.
OUT=$(run_agg "$FIX/malformed.txt" "$FIX/pe_hold.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: ERROR$'; then
    echo "FAIL test5 malformed: expected ERROR"
    echo "GOT: $OUT"
    exit 1
fi

# Test 6: malformed PE → ERROR.
OUT=$(run_agg "$FIX/da_hold.txt" "$FIX/malformed.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: ERROR$'; then
    echo "FAIL test6 malformed_pe: expected ERROR"
    echo "GOT: $OUT"
    exit 1
fi

# After tests 1-6, the trace log must contain at least one HOLD verdict
# (test 1), at least one DISSENT verdict (tests 2-4), and at least one
# ERROR verdict (tests 5-6). Default-on telemetry is what makes silent
# decay detectable.
if [ ! -s "$TRACE_LOG" ]; then
    echo "FAIL telemetry: trace log was not appended to"
    exit 1
fi
if ! grep -q 'outcome=HOLD' "$TRACE_LOG"; then
    echo "FAIL telemetry: no HOLD verdict logged"
    cat "$TRACE_LOG"
    exit 1
fi
if ! grep -q 'outcome=DISSENT' "$TRACE_LOG"; then
    echo "FAIL telemetry: no DISSENT verdict logged"
    cat "$TRACE_LOG"
    exit 1
fi
if ! grep -q 'outcome=ERROR' "$TRACE_LOG"; then
    echo "FAIL telemetry: no ERROR verdict logged"
    cat "$TRACE_LOG"
    exit 1
fi

# Test 7: rationale containing markdown link/image/backtick is sanitized.
# Prompt-injected DA backend output should not be able to inject clickable
# links or inline code into the augmented question text the user sees.
TMP_TEST7=$(mktemp -d)
trap 'rm -rf "$TMP_TEST7"' EXIT
MALICIOUS="$TMP_TEST7/malicious_da.txt"
cat > "$MALICIOUS" <<'EOF'
VERDICT: OVERTURN
RATIONALE: This recommendation is wrong [click here](http://evil.example.com/steal) per ![pixel](http://evil.example.com/track.png) — also `rm -rf /` is what they want. Pick something else.
ALTERNATIVE: Option B
EOF
OUT=$(run_agg "$MALICIOUS" "$FIX/pe_hold.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test7: expected DISSENT for OVERTURN+HOLD"
    echo "GOT: $OUT"
    exit 1
fi
# Markdown link syntax must be stripped (the URL must not appear).
if echo "$OUT" | grep -q 'evil.example.com'; then
    echo "FAIL test7: URL leaked through sanitization"
    echo "GOT: $OUT"
    exit 1
fi
# Backticks must be stripped.
if echo "$OUT" | grep -q '`'; then
    echo "FAIL test7: backtick leaked through sanitization"
    echo "GOT: $OUT"
    exit 1
fi
# Bracket+paren markdown pattern should be gone.
if echo "$OUT" | grep -qE '\[[^]]+\]\([^)]+\)'; then
    echo "FAIL test7: markdown link pattern leaked through sanitization"
    echo "GOT: $OUT"
    exit 1
fi

echo "PASS"
