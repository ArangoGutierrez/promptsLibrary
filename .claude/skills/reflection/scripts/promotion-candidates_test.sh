#!/bin/bash
# promotion-candidates_test.sh — lists Count>=3 entries not yet promoted.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/promotion-candidates.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

FIX="$TMP/learned-anti-patterns.md"
cat > "$FIX" <<'EOF'
# Learned Anti-Patterns
- **Pattern**: Eligible behavioral pattern | **Fix**: do x | **Severity**: warning | **Tags**: go | **Count**: 3 | **Since**: 2026-01-01
- **Pattern**: Too few observations | **Fix**: do y | **Severity**: info | **Tags**: go | **Count**: 2 | **Since**: 2026-01-01
- **Pattern**: Already promoted thing | **Fix**: do z | **Severity**: critical | **Tags**: testing | **Count**: 5 | **Since**: 2026-01-01 | **Promoted**: test-quality-lint.sh
EOF

OUT=$(bash "$SCRIPT" "$FIX" 2>/dev/null)

if echo "$OUT" | grep -q "Eligible behavioral pattern"; then echo "PASS: eligible listed"; PASS=$((PASS+1)); else echo "FAIL: eligible not listed"; echo "  got: $OUT"; FAIL=$((FAIL+1)); fi
if echo "$OUT" | grep -q "Too few observations"; then echo "FAIL: count<3 included"; FAIL=$((FAIL+1)); else echo "PASS: count<3 excluded"; PASS=$((PASS+1)); fi
if echo "$OUT" | grep -q "Already promoted thing"; then echo "FAIL: promoted included"; FAIL=$((FAIL+1)); else echo "PASS: promoted excluded"; PASS=$((PASS+1)); fi
bash "$SCRIPT" "$TMP/nope.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then echo "PASS: missing file exit 0"; PASS=$((PASS+1)); else echo "FAIL: missing file exit $rc"; FAIL=$((FAIL+1)); fi

echo "==== Results: $PASS passed, $FAIL failed ===="
[ "$FAIL" -eq 0 ]
