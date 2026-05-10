#!/bin/bash
# aggregate_test.sh - test verdict aggregation rules per spec.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGG="$SCRIPT_DIR/aggregate.sh"
FIX="$SCRIPT_DIR/fixtures"
ERR_FILE=$(mktemp)
trap 'rm -f "$ERR_FILE"' EXIT

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

echo "PASS"
