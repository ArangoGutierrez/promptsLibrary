# Validate-Recommendation E2E Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a single self-contained Markdown test prompt that, when pasted into a sibling Claude Code session, drives four `AskUserQuestion` scenarios against the wired `validate-recommendation` hook and renders a PASS/FAIL gate in the chat.

**Architecture:** One deliverable file at `.worktrees/recommendation-validator/docs/e2e/validate-recommendation-test-prompt.md` containing: a pre-flight bash block (env + hygiene), four scenario instruction blocks (markdown text directing Claude what `AskUserQuestion` to issue and when to capture a `wc -l` snapshot), and a final verifier bash block (diffs snapshots, classifies new trace entries, prints PASS/FAIL table). Each bash block is unit-tested in-place by piping synthetic input before commit. No external test harness — sanity is validated by inline `diff` against expected output.

**Tech Stack:** bash 3.2+, `jq`, `sed`, `awk`, `wc`, `stat`, `tail`. Markdown for the deliverable. Git for commits (DCO `-s` + GPG `-S`, enforced by `sign-commits.sh`). Reference spec: `docs/superpowers/specs/2026-05-21-validate-recommendation-e2e-test-design.md` @ commit `3c01a5a`.

**Reference spec sections** (the plan implements §6–§10 of the spec):
- §6 Test Scenarios → Tasks 3
- §7 Verification Logic → Task 4
- §8 Output Format → Task 4
- §9 Pre-Flight → Task 2
- §10 Error Handling → Task 4

---

## File Structure

| Path | Purpose |
|---|---|
| `docs/e2e/validate-recommendation-test-prompt.md` (new) | The deliverable prompt the user pastes into a sibling Claude Code session. Contains 1 pre-flight block + 4 scenario markdown blocks + 1 verifier block. |
| `docs/e2e/.fixtures/` (new, temporary) | Synthetic trace files used to unit-test the bash blocks during implementation. **Removed before final commit** — not part of the deliverable. |

All work happens on the `feat/recommendation-validator` branch in the worktree at `.worktrees/recommendation-validator/`. No changes to `~/.claude/`, no changes to the hook script, no changes to the panel CLI.

---

### Task 1: Set up file skeleton

**Files:**
- Create: `docs/e2e/validate-recommendation-test-prompt.md`

- [ ] **Step 1: Create directory and empty skeleton**

```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/recommendation-validator
cd "$WT"
mkdir -p docs/e2e
```

Write the skeleton via the Write tool to `docs/e2e/validate-recommendation-test-prompt.md`:

```markdown
# Validate-Recommendation E2E Gate

Paste this entire message into a sibling Claude Code session. The instructions below drive 4 `AskUserQuestion` calls against the `validate-recommendation` hook, then a final bash block renders a PASS/FAIL gate.

**Important:** do not run while another Claude Code session is active in the same user account — concurrent writes to `panel-trace.log` will pollute the snapshot diffs.

---

## Phase 1 — Pre-flight

<!-- PREFLIGHT_BLOCK -->

---

## Phase 2 — Scenarios

<!-- S1_BLOCK -->

<!-- S2_BLOCK -->

<!-- S3_BLOCK -->

<!-- S4_BLOCK -->

---

## Phase 3 — Verifier

<!-- VERIFIER_BLOCK -->
```

The `<!-- *_BLOCK -->` markers are placeholders filled in by later tasks. Keep them — they're used by Task 5's lint step.

- [ ] **Step 2: Verify the skeleton renders the expected structure**

```bash
grep -c "<!-- .*_BLOCK -->" docs/e2e/validate-recommendation-test-prompt.md
```

Expected output: `6`

- [ ] **Step 3: Commit**

```bash
git add docs/e2e/validate-recommendation-test-prompt.md
git -c commit.gpgsign=true commit -s -S -m "chore(e2e): add validate-recommendation test prompt skeleton

Sets up the file structure for the E2E test prompt described in
docs/superpowers/specs/2026-05-21-validate-recommendation-e2e-test-design.md.
Bash blocks land in subsequent commits."
```

---

### Task 2: Pre-flight bash block (TDD)

**Files:**
- Modify: `docs/e2e/validate-recommendation-test-prompt.md` — replace `<!-- PREFLIGHT_BLOCK -->` with actual block
- Create (temporary): `docs/e2e/.fixtures/preflight-test.sh` — removed in Task 5

- [ ] **Step 1: Write the failing test**

Create `docs/e2e/.fixtures/preflight-test.sh`:

```bash
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
  CLAUDE_PANEL_TRACE_LOG="$TRACE" \
  CLAUDE_PANEL=unset_at_start \
  PANEL_DA_API_KEY="" \
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x docs/e2e/.fixtures/preflight-test.sh
docs/e2e/.fixtures/preflight-test.sh
```

Expected: `FAIL: preflight block empty` (exit 1) — because the prompt has the `<!-- PREFLIGHT_BLOCK -->` placeholder, not the actual delimited bash.

- [ ] **Step 3: Write the pre-flight block**

Replace `<!-- PREFLIGHT_BLOCK -->` in `docs/e2e/validate-recommendation-test-prompt.md` with this Markdown (note the delimiter comments inside the bash block — they're used by the test extractor):

````markdown
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
````

- [ ] **Step 4: Run test to verify it passes**

```bash
docs/e2e/.fixtures/preflight-test.sh
```

Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add docs/e2e/validate-recommendation-test-prompt.md docs/e2e/.fixtures/preflight-test.sh
git -c commit.gpgsign=true commit -s -S -m "feat(e2e): add pre-flight bash block + unit test

Exports CLAUDE_PANEL=on explicitly, warns on missing API key, creates
trace log if absent, cleans stale state files from prior crashes, and
captures the trace baseline and file inode.

The companion test in .fixtures/ extracts the block via delimiter
comments and validates each behavior with a temp TRACE log. The
.fixtures/ directory is removed in the final lint commit."
```

---

### Task 3: Scenario instruction blocks

**Files:**
- Modify: `docs/e2e/validate-recommendation-test-prompt.md` — replace `<!-- S1_BLOCK -->` … `<!-- S4_BLOCK -->`

This task has no bash logic to TDD — only Markdown text instructing the assistant what `AskUserQuestion` to issue, and what `wc -l` snapshot to capture after each. Verification is via `grep` for required tokens.

- [ ] **Step 1: Replace `<!-- S1_BLOCK -->` with the S1 instruction**

````markdown
### Scenario 1 — No-Recommended passthrough

Call `AskUserQuestion` with exactly:
- **Question:** "Which day of the week is today?"
- **Options:** `Monday` / `Tuesday` / `Wednesday` / `Thursday` / `Friday` (NO `(Recommended)` tag anywhere)
- multiSelect: false
- Headers per option: short single-word labels.

After the user answers, capture the snapshot:

```bash
AFTER_S1=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S1=$AFTER_S1"
```

Expected trace delta: 0 (hook should exit 0, no panel-trace entry).
````

- [ ] **Step 2: Replace `<!-- S2_BLOCK -->` with the S2 instruction**

````markdown
### Scenario 2 — Already-Panel-flagged dedup

Call `AskUserQuestion` with exactly:
- **Question:** "Which day of the week is today?" (intentionally the same question as S1)
- **Options:** `Thursday (Recommended; Panel-flagged)` / `Friday`
- multiSelect: false

After the user answers, capture the snapshot:

```bash
AFTER_S2=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S2=$AFTER_S2"
```

Expected trace delta: 0 (hook detects the `Panel-flagged` marker, treats as already-validated, exits 0).
````

- [ ] **Step 3: Replace `<!-- S3_BLOCK -->` with the S3 instruction**

````markdown
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

```bash
AFTER_S3=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S3=$AFTER_S3"
```

Expected trace delta: exactly 1 new `event=verdict` line.
````

- [ ] **Step 4: Replace `<!-- S4_BLOCK -->` with the S4 instruction**

````markdown
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

```bash
AFTER_S4=$(wc -l < "$TRACE" | tr -d ' ')
echo "AFTER_S4=$AFTER_S4"
```

Expected trace delta: exactly 1 new `event=verdict` line.
````

- [ ] **Step 5: Verify all four scenarios present**

```bash
grep -cE "^### Scenario [1-4]" docs/e2e/validate-recommendation-test-prompt.md
```

Expected output: `4`

```bash
grep -cE "AFTER_S[1-4]=" docs/e2e/validate-recommendation-test-prompt.md
```

Expected output: `8` (one assignment + one echo per scenario × 4 scenarios)

- [ ] **Step 6: Commit**

```bash
git add docs/e2e/validate-recommendation-test-prompt.md
git -c commit.gpgsign=true commit -s -S -m "feat(e2e): add S1-S4 scenario instructions

S1: no-Recommended passthrough → expect delta=0.
S2: already (Recommended; Panel-flagged) dedup → expect delta=0.
S3: clear-correct (pytest in CI) → expect delta=1 with verdict
    (likely HOLD; tolerant of HARD-DISSENT/ERROR per design).
S4: clearly-bad (hardcoded API key) → expect delta=1 with verdict
    (likely HARD-DISSENT; same tolerance).

Each scenario block ends with a wc -l capture into AFTER_S<N> that the
verifier in Phase 3 uses to compute per-scenario deltas."
```

---

### Task 4: Verifier bash block (TDD)

**Files:**
- Modify: `docs/e2e/validate-recommendation-test-prompt.md` — replace `<!-- VERIFIER_BLOCK -->`
- Create (temporary): `docs/e2e/.fixtures/verifier-test.sh`

- [ ] **Step 1: Write the failing test**

Create `docs/e2e/.fixtures/verifier-test.sh`:

```bash
#!/bin/bash
# Verifies the verifier block: synthesizes 5 snapshot values + a tiny trace
# file, extracts the verifier bash block via delimiter comments, runs it,
# and inspects the rendered output for the expected PASS table.
set -euo pipefail

PROMPT="$(dirname "$0")/../validate-recommendation-test-prompt.md"
TMPDIR_TEST="$(mktemp -d)"
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x docs/e2e/.fixtures/verifier-test.sh
docs/e2e/.fixtures/verifier-test.sh
```

Expected: `FAIL: verifier block empty` (exit 1).

- [ ] **Step 3: Write the verifier block**

Replace `<!-- VERIFIER_BLOCK -->` in `docs/e2e/validate-recommendation-test-prompt.md` with:

````markdown
Run this final bash block. It reads `BEFORE`, `INODE_BEFORE`, `TRACE`, and the four `AFTER_S*` snapshots from your environment, classifies the new trace entries, and prints the PASS/FAIL gate.

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

verdict_re='event=verdict.*outcome=(HOLD|SOFT-DISSENT|HARD-DISSENT|ERROR)'

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
````

- [ ] **Step 4: Run test to verify pass-case**

```bash
docs/e2e/.fixtures/verifier-test.sh
```

Expected: `PASS (pass-case)`

- [ ] **Step 5: Add a fail-case test**

Append to `docs/e2e/.fixtures/verifier-test.sh` (BEFORE the final `echo "PASS (pass-case)"` line, replace it with):

```bash
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
```

- [ ] **Step 6: Run both cases**

```bash
docs/e2e/.fixtures/verifier-test.sh
```

Expected: two lines — `PASS (pass-case)` then `PASS (fail-case)`.

- [ ] **Step 7: Commit**

```bash
git add docs/e2e/validate-recommendation-test-prompt.md docs/e2e/.fixtures/verifier-test.sh
git -c commit.gpgsign=true commit -s -S -m "feat(e2e): add verifier bash block + pass+fail unit tests

Diffs the BEFORE / AFTER_S1..S4 snapshots captured by the scenario
blocks, extracts S3/S4's new trace entries by absolute line range
(sed -n start,end p), and renders a Markdown PASS/FAIL gate with a
per-scenario row plus an outcome column for S3/S4.

Inode-rotation guard: if panel-trace.log rotates mid-test the deltas
are nonsense, so we abort with gate=ERROR rather than reporting
misleading numbers.

Companion tests cover the all-pass case and a fail-case where S3 has
delta=2 (two trace entries instead of one) — proving the verifier
flags the failing row, downgrades the gate, and dumps the diagnostic
section."
```

---

### Task 5: Final lint + cleanup commit

**Files:**
- Modify (delete content): `docs/e2e/.fixtures/` — removed entirely
- Modify: `docs/e2e/validate-recommendation-test-prompt.md` — no content changes; lint-only pass

- [ ] **Step 1: Lint — placeholder scan**

```bash
grep -nE "TBD|TODO|XXX|FIXME|<!-- .*_BLOCK -->" docs/e2e/validate-recommendation-test-prompt.md
```

Expected output: empty (exit 1 from grep). If any line prints, fix it before continuing.

- [ ] **Step 2: Lint — structural sanity**

```bash
echo "=== Section count ==="
grep -cE "^## Phase [1-3]" docs/e2e/validate-recommendation-test-prompt.md  # expect: 3
grep -cE "^### Scenario [1-4]" docs/e2e/validate-recommendation-test-prompt.md  # expect: 4

echo "=== Bash delimiter count ==="
grep -cE "^# === (preflight|verifier) ===" docs/e2e/validate-recommendation-test-prompt.md  # expect: 2 (preflight + verifier opening)
grep -cE "^# === end (preflight|verifier) ===" docs/e2e/validate-recommendation-test-prompt.md  # expect: 2

echo "=== Snapshot variable references ==="
grep -cE "AFTER_S[1-4]=" docs/e2e/validate-recommendation-test-prompt.md  # expect: 8 (assign + echo per scenario)
```

If any count is off, fix the relevant block before continuing.

- [ ] **Step 3: Remove the .fixtures directory**

The test scripts have served their purpose. Delete them so the deliverable directory contains only the prompt file.

```bash
rm -rf docs/e2e/.fixtures
ls docs/e2e/
# Expected: just validate-recommendation-test-prompt.md
```

- [ ] **Step 4: Final commit**

```bash
git add -A docs/e2e
git -c commit.gpgsign=true commit -s -S -m "chore(e2e): remove test scaffolding, finalize deliverable

The .fixtures/ unit tests proved the pre-flight and verifier bash
blocks work correctly with synthetic snapshots. They're not needed for
the deliverable prompt — drop them so docs/e2e/ contains only the
single file the user pastes into the sibling Claude Code session."
```

- [ ] **Step 5: Verify final state**

```bash
git log --oneline -6
ls docs/e2e/
wc -l docs/e2e/validate-recommendation-test-prompt.md
```

Expected git log (most recent first):
1. `chore(e2e): remove test scaffolding, finalize deliverable`
2. `feat(e2e): add verifier bash block + pass+fail unit tests`
3. `feat(e2e): add S1-S4 scenario instructions`
4. `feat(e2e): add pre-flight bash block + unit test`
5. `chore(e2e): add validate-recommendation test prompt skeleton`
6. `docs(panel): fix S3 trace-extract bug in E2E spec`

`ls docs/e2e/` should show exactly one file. The prompt should be ~150–200 lines.

---

## Out-of-Plan Steps (after merge)

Once this plan is complete, the artifact lives at `docs/e2e/validate-recommendation-test-prompt.md` on the `feat/recommendation-validator` branch. **Running the actual E2E gate is not part of this plan** — it requires a sibling Claude Code session and a human pasting the prompt. After the gate passes, the user is unblocked on:

1. Running the gate in another session and observing the PASS table.
2. Rotating `$PANEL_DA_API_KEY` (the original handoff goal).
3. Merging `feat/recommendation-validator` to mainline once the gate has passed at least once in real conditions.

---

## Self-Review

**Spec coverage:**
- §6 Test Scenarios → Task 3 ✓
- §7 Verification Logic → Task 4 ✓
- §8 Output Format → Task 4 (verifier block) ✓
- §9 Pre-Flight → Task 2 ✓
- §10 Error Handling → Task 4 (inode rotation guard, diagnostic dump on fail) ✓
- §11 Acceptance Criteria → Task 4 verifier renders gate from these criteria ✓
- §12 Out of Scope → respected (no SOFT-DISSENT scenario, no advise-mode test, no ERROR forcing) ✓

**Placeholder scan:** no TBD/TODO/FIXME in any task step; every code block contains complete code.

**Type consistency:** variable names match across blocks (`BEFORE`, `INODE_BEFORE`, `TRACE`, `AFTER_S1..S4`); delimiter comments (`# === preflight ===` / `# === verifier ===`) match between the blocks and their extractor tests.
