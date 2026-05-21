# Validate-Recommendation E2E Gate

Paste this entire message into a sibling Claude Code session. The instructions below drive 4 `AskUserQuestion` calls against the `validate-recommendation` hook, then a final bash block renders a PASS/FAIL gate.

**Important:** do not run while another Claude Code session is active in the same user account — concurrent writes to `panel-trace.log` will pollute the snapshot diffs.

---

## Phase 1 — Pre-flight

Run this bash block first. It exports `CLAUDE_PANEL=on`, verifies prerequisites, cleans stale state, and captures the trace-log baseline.

```bash
# === preflight ===
set -uo pipefail

export CLAUDE_PANEL=on
echo "CLAUDE_PANEL=on"

if [ -z "${PANEL_DA_API_KEY:-}${NVIDIA_API_KEY:-}" ]; then
  echo "WARNING: no API key set in PANEL_DA_API_KEY or NVIDIA_API_KEY."
  echo "         S3/S4 will produce ERROR verdicts. Hook wiring is still validated."
fi

TRACE="${CLAUDE_PANEL_TRACE_LOG:-$HOME/.claude/debug/panel-trace.log}"
if [ ! -w "$TRACE" ]; then
  mkdir -p "$(dirname "$TRACE")"
  touch "$TRACE"
fi

# Clean any stale state files from prior crashes.
rm -f "${TMPDIR:-/tmp}"/claude-*/claude-panel-*.json 2>/dev/null || true

BEFORE=$(wc -l < "$TRACE" | tr -d ' ')
INODE_BEFORE=$(stat -f '%i' "$TRACE" 2>/dev/null || stat -c '%i' "$TRACE")

echo "BEFORE=$BEFORE"
echo "INODE_BEFORE=$INODE_BEFORE"
echo "TRACE=$TRACE"
# === end preflight ===
```

After running, you should see four lines: `CLAUDE_PANEL=on`, an optional warning, `BEFORE=<N>`, and `INODE_BEFORE=<digits>`. Remember `BEFORE`, `INODE_BEFORE`, and `TRACE` — Phase 3 uses them.

---

## Phase 2 — Scenarios

<!-- S1_BLOCK -->

<!-- S2_BLOCK -->

<!-- S3_BLOCK -->

<!-- S4_BLOCK -->

---

## Phase 3 — Verifier

<!-- VERIFIER_BLOCK -->
