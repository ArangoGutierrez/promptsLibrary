#!/bin/bash
# Verifies the verifier block: synthesizes 5 snapshot values + a tiny trace
# file, extracts the verifier bash block via delimiter comments, runs it,
# and inspects the rendered output for the expected PASS table.
set -euo pipefail

PROMPT="$(dirname "$0")/../validate-recommendation-test-prompt.md"
TMPDIR_TEST="$(mktemp -d "$TMPDIR/verifier-test-XXXXXX")"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Synthesize a trace file with 12 baseline lines + 2 verdict entries (S3, S4).
TRACE="$TMPDIR_TEST/panel-trace.log"
for i in $(seq 1 12); do echo "[2026-05-20T00:00:00Z] event=trigger session=warmup-$i"; done > "$TRACE"
echo "[2026-05-21T08:00:00Z] event=verdict session=s3 outcome=HOLD detail=\"da-nemotron=HOLD\"" >> "$TRACE"
echo "[2026-05-21T08:00:01Z] event=verdict session=s4 outcome=HARD-DISSENT detail=\"da-nemotron=OVERTURN\"" >> "$TRACE"

# Extract the verifier block.
awk '/^# === verifier ===$/,/^# === end verifier ===$/' "$PROMPT" \
  | sed '1d;$d' > "$TMPDIR_TEST/verifier.sh"
[ -s "$TMPDIR_TEST/verifier.sh" ] || { echo "FAIL: verifier block empty"; exit 1; }

# Inject snapshots into the env, then run.
INODE_NOW=$(stat -f '%i' "$TRACE" 2>/dev/null || stat -c '%i' "$TRACE")
OUT=$(
  TRACE="$TRACE" \
  BEFORE=12 \
  AFTER_S1=12 \
  AFTER_S2=12 \
  AFTER_S3=13 \
  AFTER_S4=14 \
  INODE_BEFORE="$INODE_NOW" \
  bash "$TMPDIR_TEST/verifier.sh"
)

# Assertions: every scenario row should be PASS, gate PASS 4/4.
echo "$OUT" | grep -qE "S1.*0.*OK"            || { echo "FAIL: S1 row missing or wrong"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -qE "S2.*0.*OK"            || { echo "FAIL: S2 row missing or wrong"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -qE "S3.*HOLD.*OK"         || { echo "FAIL: S3 row missing or wrong"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -qE "S4.*HARD-DISSENT.*OK" || { echo "FAIL: S4 row missing or wrong"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -qE "Gate: PASS \(4/4\)"   || { echo "FAIL: gate line missing or wrong"; echo "$OUT"; exit 1; }

echo "PASS (pass-case)"

# --- Fail-case: S3 delta=2 (two verdict entries) should render FAIL row + gate FAIL ---
OUT_FAIL=$(
  TRACE="$TRACE" \
  BEFORE=12 \
  AFTER_S1=12 \
  AFTER_S2=12 \
  AFTER_S3=14 \
  AFTER_S4=14 \
  INODE_BEFORE="$INODE_NOW" \
  bash "$TMPDIR_TEST/verifier.sh"
)

echo "$OUT_FAIL" | grep -qE "S3.*2 verdict.*FAIL"      || { echo "FAIL (fail-case): S3 row should be FAIL with delta=2"; echo "$OUT_FAIL"; exit 1; }
echo "$OUT_FAIL" | grep -qE "Gate: FAIL \([0-3]/4\)"   || { echo "FAIL (fail-case): gate should be FAIL"; echo "$OUT_FAIL"; exit 1; }
echo "$OUT_FAIL" | grep -q "Diagnostic dump"           || { echo "FAIL (fail-case): missing diagnostic dump"; echo "$OUT_FAIL"; exit 1; }

echo "PASS (fail-case)"
