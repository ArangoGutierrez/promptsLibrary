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

### Scenario 1 — No-Recommended passthrough

Call `AskUserQuestion` with exactly:
- **Question:** "Which day of the week is today?"
- **Options:** `Monday` / `Tuesday` / `Wednesday` / `Thursday` / `Friday` (NO `(Recommended)` tag anywhere)
- multiSelect: false
- Headers per option: short single-word labels.

After the user answers, capture the snapshot:

````markdown
```bash
AFTER_S1=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S1=$AFTER_S1"
```
````

Expected trace delta: 0 (hook should exit 0, no panel-trace entry).

### Scenario 2 — Already-Panel-flagged dedup

Call `AskUserQuestion` with exactly:
- **Question:** "Which day of the week is today?" (intentionally the same question as S1)
- **Options:** `Thursday (Recommended; Panel-flagged)` / `Friday`
- multiSelect: false

After the user answers, capture the snapshot:

````markdown
```bash
AFTER_S2=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S2=$AFTER_S2"
```
````

Expected trace delta: 0 (hook detects the `Panel-flagged` marker, treats as already-validated, exits 0).

### Scenario 3 — Clear-correct recommendation (expect HOLD)

Call `AskUserQuestion` with exactly:
- **Question:** "How should we run the test suite in CI?"
- **Options:**
  - `pytest (Recommended)` — "Industry-standard Python test runner"
  - "Run each test manually in production" — "Execute tests by hand against the live deployment"
  - "Skip testing entirely" — "Ship without verification"
- multiSelect: false

The hook should fire (exit 2 + skill-invocation stderr). The skill dispatches the DA panelist and aggregates a verdict. With `CLAUDE_PANEL=on` and a likely HOLD outcome, the question is **auto-taken** and no follow-up is presented. If the panelist returned HARD-DISSENT or ERROR instead, the question is re-issued with an annotation.

After Claude finishes processing this scenario (auto-take or re-ask + user answers), capture:

````markdown
```bash
AFTER_S3=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S3=$AFTER_S3"
```
````

Expected trace delta: exactly 1 new `event=verdict` line.

### Scenario 4 — Clearly-bad recommendation (expect HARD-DISSENT)

Call `AskUserQuestion` with exactly:
- **Question:** "How should we handle the API key in this new service?"
- **Options:**
  - `Hardcode it in source (Recommended)` — "Commit the key directly into a .py file"
  - "Load from environment variable at startup" — "Read $API_KEY at process start"
  - "Use a secrets manager like Vault" — "Fetch from HashiCorp Vault on demand"
- multiSelect: false

The hook fires. With CLAUDE_PANEL=on and a likely HARD-DISSENT outcome, the question is re-issued with a `Panel HARD-DISSENT: …` prefix and the recommended option's label swapped to `(Recommended; Panel-flagged)`. Answer however you like.

After Claude finishes processing, capture:

````markdown
```bash
AFTER_S4=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S4=$AFTER_S4"
```
````

Expected trace delta: exactly 1 new `event=verdict` line.

---

## Phase 3 — Verifier

<!-- VERIFIER_BLOCK -->
