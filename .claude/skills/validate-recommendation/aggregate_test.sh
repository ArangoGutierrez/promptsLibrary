#!/bin/bash
# aggregate_test.sh - test verdict aggregation rules per spec.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGG="$SCRIPT_DIR/aggregate.sh"
FIX="$SCRIPT_DIR/fixtures"

if [ ! -x "$AGG" ]; then
    echo "FAIL: aggregate.sh missing or not executable"
    exit 1
fi

# Helper: run aggregator and capture stdout
run_agg() {
    "$AGG" --da "$1" --pe "$2" --recommended-label "Option A" 2>&1
}

# Test 1: both HOLD → PANEL_VERDICT: HOLD
OUT=$(run_agg "$FIX/da_hold.txt" "$FIX/pe_hold.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: HOLD$'; then
    echo "FAIL test1 both_hold: expected HOLD"
    echo "GOT: $OUT"
    exit 1
fi
# Hold output must include both rationales (one-line abbreviation acceptable)
if ! echo "$OUT" | grep -qi 'DA:'; then
    echo "FAIL test1: DA rationale missing from HOLD output"
    exit 1
fi
if ! echo "$OUT" | grep -qi 'PE:'; then
    echo "FAIL test1: PE rationale missing from HOLD output"
    exit 1
fi

# Test 2: DA overturn (B), PE hold → DISSENT, alternative=B
OUT=$(run_agg "$FIX/da_overturn_b.txt" "$FIX/pe_hold.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test2 da_overturn: expected DISSENT"
    echo "GOT: $OUT"
    exit 1
fi
if ! echo "$OUT" | grep -q 'Option B'; then
    echo "FAIL test2: alternative 'Option B' missing"
    exit 1
fi

# Test 3: DA hold, PE overturn (C) → DISSENT, alternative=C
OUT=$(run_agg "$FIX/da_hold.txt" "$FIX/pe_overturn_c.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test3 pe_overturn: expected DISSENT"
    exit 1
fi
if ! echo "$OUT" | grep -q 'Option C'; then
    echo "FAIL test3: alternative 'Option C' missing"
    exit 1
fi

# Test 4: both overturn with different alternatives → DISSENT, both listed
OUT=$(run_agg "$FIX/da_overturn_b.txt" "$FIX/pe_overturn_c.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: DISSENT$'; then
    echo "FAIL test4 both_overturn: expected DISSENT"
    exit 1
fi
if ! echo "$OUT" | grep -q 'Option B'; then
    echo "FAIL test4: 'Option B' missing"
    exit 1
fi
if ! echo "$OUT" | grep -q 'Option C'; then
    echo "FAIL test4: 'Option C' missing"
    exit 1
fi

# Test 5: malformed DA → ERROR
OUT=$(run_agg "$FIX/malformed.txt" "$FIX/pe_hold.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: ERROR$'; then
    echo "FAIL test5 malformed: expected ERROR"
    echo "GOT: $OUT"
    exit 1
fi

# Test 6: malformed PE → ERROR
OUT=$(run_agg "$FIX/da_hold.txt" "$FIX/malformed.txt")
if ! echo "$OUT" | grep -q '^PANEL_VERDICT: ERROR$'; then
    echo "FAIL test6 malformed_pe: expected ERROR"
    exit 1
fi

echo "PASS"
