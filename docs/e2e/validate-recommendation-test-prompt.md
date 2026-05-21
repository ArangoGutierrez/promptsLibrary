# Validate-Recommendation E2E Gate

Paste this entire message into a sibling Claude Code session. The instructions below drive 4 `AskUserQuestion` calls against the `validate-recommendation` hook, then a final bash block renders a PASS/FAIL gate.

**Important:** do not run while another Claude Code session is active in the same user account — concurrent writes to `panel-trace.log` will pollute the snapshot diffs.

**SCOPE LOCK — this prompt is a validation gate, NOT an implementation task.**

While running this prompt, you may ONLY perform:

1. The Bash blocks shown in each Phase (preflight, the four `AFTER_S<N>` snapshots, the final verifier).
2. Exactly 4 `AskUserQuestion` calls per Phase 2 (no more, no fewer).
3. The `validate-recommendation` skill if the hook directs you to invoke it (it will, on the (Recommended) options in S3/S4).

**Do NOT, under any circumstances during this run:**

- `git commit`, `git push`, or `git` anything that mutates state.
- Edit, Write, or otherwise modify any file (including this prompt or the hook).
- Read files outside this prompt's instructions (you don't need to "understand the codebase" — the prompt is self-contained).
- Invoke any skill except `validate-recommendation` when the hook directs you to.
- Attempt to fix any bug you notice in the prompt, the hook, the panel CLI, or anything else. Note the observation in your final report; do not act on it.
- Issue any `AskUserQuestion` beyond the 4 specified — even one to "clarify" something.

If a scenario cannot run (sandbox denial, ambiguous instruction, missing file), STOP and report. Any unexpected tool call invalidates the gate's trace-counting logic — the verifier's pass criteria assume exactly the prescribed event sequence.

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
# Hook writes to "$TMPDIR/claude-panel-${SID}.json" (no subdirectory) — the
# glob must match that exact path; a "${TMPDIR}/claude-*/claude-panel-*.json"
# variant would miss every state file the hook actually writes.
rm -f "${TMPDIR:-/tmp}"/claude-panel-*.json 2>/dev/null || true

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
- Headers per option: short single-word labels (e.g., Mon/Tue/Wed/Thu/Fri).

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
- Headers per option: short single-word labels (e.g., Thu/Fri).

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
- Headers per option: short single-word labels (e.g., pytest/manual/skip).

The hook should fire (exit 2 + skill-invocation stderr). The skill dispatches the DA panelist and aggregates a verdict. With `CLAUDE_PANEL=on` and a likely HOLD outcome, the question is **auto-taken** and no follow-up is presented. If the panelist returned HARD-DISSENT or ERROR instead, the question is re-issued with an annotation. **If the question is re-presented, pick `pytest (Recommended)`.**

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
- Headers per option: short single-word labels (e.g., hardcode/env/vault).

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

Run this final bash block. Because each Bash call runs in a fresh shell, prepend the values you captured in Phases 1 and 2 to the invocation (or set them in a preceding line of the same call). Concretely:

```bash
TRACE=<value-from-preflight> \
BEFORE=<value-from-preflight> \
INODE_BEFORE=<value-from-preflight> \
AFTER_S1=<value-from-S1> \
AFTER_S2=<value-from-S2> \
AFTER_S3=<value-from-S3> \
AFTER_S4=<value-from-S4> \
bash -c '<paste the verifier bash block below (everything between its delimiter comments, inclusive)>'
```

Or simply paste the variable assignments at the top of the same Bash tool invocation that runs the verifier block. The block reads these variables, classifies the new trace entries, and prints the PASS/FAIL gate.

```bash
# === verifier ===
set -uo pipefail

# Inode rotation check — if the file rotated mid-test, deltas are bogus.
INODE_NOW=$(stat -f '%i' "$TRACE" 2>/dev/null || stat -c '%i' "$TRACE")
if [ "$INODE_NOW" != "$INODE_BEFORE" ]; then
  echo "ERROR: panel-trace.log rotated mid-test (inode changed $INODE_BEFORE -> $INODE_NOW)."
  echo "Snapshot counts cannot be trusted. Gate result: ERROR."
  exit 1
fi

delta_s1=$(( AFTER_S1 - BEFORE ))
delta_s2=$(( AFTER_S2 - AFTER_S1 ))
delta_s3=$(( AFTER_S3 - AFTER_S2 ))
delta_s4=$(( AFTER_S4 - AFTER_S3 ))

verdict_re='\] event=verdict[[:space:]].*outcome=(HOLD|SOFT-DISSENT|HARD-DISSENT|ERROR)'

# Extract by absolute line range — by verifier-run time TRACE contains both
# S3 and S4 entries, so `tail -n 1` would grab S4 not S3.
new_s3=$(sed -n "$((AFTER_S2+1)),${AFTER_S3}p" "$TRACE")
new_s4=$(sed -n "$((AFTER_S3+1)),${AFTER_S4}p" "$TRACE")

outcome_s3=$(echo "$new_s3" | grep -oE 'outcome=[A-Z-]+' | head -1 | sed 's/outcome=//')
outcome_s4=$(echo "$new_s4" | grep -oE 'outcome=[A-Z-]+' | head -1 | sed 's/outcome=//')

pass_s1="FAIL"; [ "$delta_s1" -eq 0 ] && pass_s1="OK"
pass_s2="FAIL"; [ "$delta_s2" -eq 0 ] && pass_s2="OK"
pass_s3="FAIL"; [ "$delta_s3" -eq 1 ] && [[ "$new_s3" =~ $verdict_re ]] && pass_s3="OK"
pass_s4="FAIL"; [ "$delta_s4" -eq 1 ] && [[ "$new_s4" =~ $verdict_re ]] && pass_s4="OK"

oks=0
for v in "$pass_s1" "$pass_s2" "$pass_s3" "$pass_s4"; do
  [ "$v" = "OK" ] && oks=$((oks+1))
done
gate="FAIL"; [ "$oks" -eq 4 ] && gate="PASS"

cat <<EOF
## Validate-Recommendation E2E Gate

Trace baseline: $BEFORE lines  ($TRACE)

| #  | Scenario              | Expected         | Observed                            | Pass |
|----|------------------------|------------------|-------------------------------------|------|
| S1 | No-Recommended         | 0 new entries    | $delta_s1 new entries               | $pass_s1 |
| S2 | Panel-flagged dedup    | 0 new entries    | $delta_s2 new entries               | $pass_s2 |
| S3 | Clear-correct          | 1 verdict, any   | $delta_s3 verdict, outcome=${outcome_s3:-<none>} | $pass_s3 |
| S4 | Clearly-bad            | 1 verdict, any   | $delta_s4 verdict, outcome=${outcome_s4:-<none>} | $pass_s4 |

**Gate: $gate ($oks/4)**

Visual check (confirm from your screen):
  S1/S2 → original question shown (no annotation)
  S3 → outcome=${outcome_s3:-?}: if HOLD, auto-taken (no prompt); else re-issued with annotation
  S4 → outcome=${outcome_s4:-?}: if HARD-DISSENT, re-issued with "Panel HARD-DISSENT: ..." prefix
EOF

if [ "$gate" != "PASS" ]; then
  echo ""
  echo "## Diagnostic dump"
  echo ""
  echo "Last 5 lines of $TRACE:"
  tail -n 5 "$TRACE"
  echo ""
  echo "Snapshots: BEFORE=$BEFORE AFTER_S1=$AFTER_S1 AFTER_S2=$AFTER_S2 AFTER_S3=$AFTER_S3 AFTER_S4=$AFTER_S4"
fi
# === end verifier ===
```
