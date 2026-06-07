#!/bin/bash
# config-audit-staleness_test.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/config-audit-staleness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
mkdir -p "$TMP/.claude/audit"

OUT=$(env HOME="$TMP" bash "$HOOK" 2>/dev/null)
if echo "$OUT" | grep -q "never been run"; then echo "PASS: missing -> reminder"; PASS=$((PASS+1)); else echo "FAIL: missing no reminder: $OUT"; FAIL=$((FAIL+1)); fi

date +%Y-%m-%d > "$TMP/.claude/audit/.last-config-audit"
OUT=$(env HOME="$TMP" bash "$HOOK" 2>/dev/null)
if [ -z "$OUT" ]; then echo "PASS: fresh -> silent"; PASS=$((PASS+1)); else echo "FAIL: fresh not silent: $OUT"; FAIL=$((FAIL+1)); fi

echo "2020-01-01" > "$TMP/.claude/audit/.last-config-audit"
OUT=$(env HOME="$TMP" bash "$HOOK" 2>/dev/null)
if echo "$OUT" | grep -q "last ran"; then echo "PASS: stale -> reminder"; PASS=$((PASS+1)); else echo "FAIL: stale no reminder: $OUT"; FAIL=$((FAIL+1)); fi

echo "==== Results: $PASS passed, $FAIL failed ===="
[ "$FAIL" -eq 0 ]
