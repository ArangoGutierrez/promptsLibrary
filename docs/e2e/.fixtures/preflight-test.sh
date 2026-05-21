#!/bin/bash
# Verifies the pre-flight block sets CLAUDE_PANEL, captures inode, captures baseline,
# and cleans stale state files. Extracts the block from the prompt via comment
# delimiters (# === preflight === ... # === end preflight ===), runs in a temp
# subshell, and asserts environment + outputs.
set -euo pipefail

PROMPT="$(dirname "$0")/../validate-recommendation-test-prompt.md"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Plant a stale state file that pre-flight should clean up.
mkdir -p "$TMPDIR_TEST/claude-501"
echo '{"stale":true}' > "$TMPDIR_TEST/claude-501/claude-panel-stale.json"

# Extract the bash block between the delimiter comments.
awk '/^# === preflight ===$/,/^# === end preflight ===$/' "$PROMPT" \
  | sed '1d;$d' > "$TMPDIR_TEST/preflight.sh"
[ -s "$TMPDIR_TEST/preflight.sh" ] || { echo "FAIL: preflight block empty"; exit 1; }

# Override TMPDIR/HOME so the script's side effects land in our temp dir, and
# point CLAUDE_PANEL_TRACE_LOG at a non-existent file to verify creation.
TRACE="$TMPDIR_TEST/panel-trace.log"
OUTPUT=$(
  TMPDIR="$TMPDIR_TEST" \
  HOME="$TMPDIR_TEST" \
  CLAUDE_PANEL_TRACE_LOG="$TRACE" \
  CLAUDE_PANEL=off \
  PANEL_DA_API_KEY="" \
  NVIDIA_API_KEY="" \
  bash "$TMPDIR_TEST/preflight.sh"
)

# Assertions.
echo "$OUTPUT" | grep -q "CLAUDE_PANEL=on" || { echo "FAIL: did not export CLAUDE_PANEL=on"; exit 1; }
echo "$OUTPUT" | grep -q "WARNING: no API key" || { echo "FAIL: missing API-key warning"; exit 1; }
[ -f "$TRACE" ] || { echo "FAIL: trace log not created"; exit 1; }
[ ! -f "$TMPDIR_TEST/claude-501/claude-panel-stale.json" ] || { echo "FAIL: stale state file not removed"; exit 1; }
echo "$OUTPUT" | grep -qE "BEFORE=[0-9]+" || { echo "FAIL: baseline not captured"; exit 1; }
echo "$OUTPUT" | grep -qE "INODE_BEFORE=[0-9]+" || { echo "FAIL: inode not captured"; exit 1; }

echo "PASS"
