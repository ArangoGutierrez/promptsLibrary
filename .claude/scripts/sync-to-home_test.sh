#!/bin/bash
# sync-to-home_test.sh — allowlist copy, clobber guard, dry-run, settings safety.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC="$SCRIPT_DIR/sync-to-home.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

SRC="$TMP/src"; DST="$TMP/dst"
mkdir -p "$SRC/rules" "$SRC/skills/config-audit" "$SRC/skills/reflection/scripts" "$SRC/hooks"
echo defense > "$SRC/rules/prompt-defense.md"
echo skill   > "$SRC/skills/config-audit/SKILL.md"
echo skill   > "$SRC/skills/reflection/SKILL.md"
echo helper  > "$SRC/skills/reflection/scripts/promotion-candidates.sh"
echo hook    > "$SRC/hooks/config-audit-staleness.sh"
mkdir -p "$DST/skills/cfo"; echo PRIVATE > "$DST/skills/cfo/SKILL.md"   # home-only, must survive
echo '{}' > "$DST/settings.json"

SYNC_SRC="$SRC" SYNC_DST="$DST" bash "$SYNC" >/dev/null 2>&1
if [ ! -e "$DST/rules/prompt-defense.md" ]; then echo "PASS: dry-run copies nothing"; PASS=$((PASS+1)); else echo "FAIL: dry-run copied"; FAIL=$((FAIL+1)); fi

SYNC_SRC="$SRC" SYNC_DST="$DST" bash "$SYNC" --apply >/dev/null 2>&1
if [ -f "$DST/rules/prompt-defense.md" ] && [ -f "$DST/skills/config-audit/SKILL.md" ]; then echo "PASS: apply copies allowlist"; PASS=$((PASS+1)); else echo "FAIL: apply did not copy"; FAIL=$((FAIL+1)); fi
if grep -q PRIVATE "$DST/skills/cfo/SKILL.md"; then echo "PASS: home-only untouched"; PASS=$((PASS+1)); else echo "FAIL: home-only clobbered"; FAIL=$((FAIL+1)); fi
if [ "$(cat "$DST/settings.json")" = '{}' ]; then echo "PASS: settings.json preserved"; PASS=$((PASS+1)); else echo "FAIL: settings.json modified"; FAIL=$((FAIL+1)); fi

echo "==== Results: $PASS passed, $FAIL failed ===="
[ "$FAIL" -eq 0 ]
