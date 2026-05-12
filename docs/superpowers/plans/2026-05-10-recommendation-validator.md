# Recommendation Validator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a hook + skill that validates `(Recommended)` answers in `AskUserQuestion` calls via two parallel panelists. Auto-take when both hold; re-ask with dissent summary when either overturns.

**Architecture (revised — see addendum below):** A `PreToolUse` hook on `AskUserQuestion` detects the marker, writes tool input to a session-scoped state file, and blocks with stderr feedback instructing the assistant to invoke a `/validate-recommendation` skill. The skill orchestrates two parallel calls — DA via `dispatch-da.sh` (POSTs to a user-configured OpenAI-compatible chat completions endpoint), PE via `Agent` with `principal-engineer` subagent — parses verdicts via a `aggregate.sh` helper, and emits a directive (HOLD / DISSENT / ERROR) for the assistant to act on.

**Tech Stack:** bash 4+, jq, curl, Claude Code hook+skill model. External chat-completion API for DA backend (configured via `$PANEL_DA_API_KEY`, `$CLAUDE_PANEL_DA_ENDPOINT`, `$CLAUDE_PANEL_DA_MODEL` env vars; never embedded in repo). Repo: ArangoGutierrez/promptsLibrary (dotfiles-as-mirror pattern, `deploy.sh` syncs `.claude/` to `~/.claude/`).

**Spec:** `docs/superpowers/specs/2026-05-10-recommendation-validator-design.md`

---

## Revision addendum (2026-05-10)

After T1–T4 were committed, the design shifted to a hybrid backend: DA goes through an external OpenAI-compatible chat completions endpoint rather than a Claude `general-purpose` subagent; PE remains a Claude `principal-engineer` subagent. Rationale: independent reasoning from a different model family for the adversarial check, while keeping tool access for the principle-evaluation check.

**Net effect on the plan:**

- **T1–T6 (fixtures, aggregator, hook): UNCHANGED.** The aggregator is backend-agnostic; the hook never knew about backends. Already committed work stands.
- **NEW T6.5 — DA dispatch test (Red).** A bash test for `dispatch-da.sh` using a mock HTTP server (or fixture-based response).
- **NEW T6.6 — DA dispatch impl (Green).** The HTTP wrapper that POSTs to the configured DA endpoint and writes a verdict file.
- **T7 (Personas): MODIFIED.** DA persona becomes external-backend-tuned (one-shot example of strict format included to maximize compliance across model families).
- **T8 (SKILL.md): MODIFIED.** Skill orchestration now dispatches DA via `Bash(./dispatch-da.sh ...)` instead of `Agent(general-purpose, ...)`. PE dispatch unchanged. Aggregation step unchanged.
- **T9 (README): MODIFIED.** Documents `$PANEL_DA_API_KEY`, `$CLAUDE_PANEL_DA_ENDPOINT`, `$CLAUDE_PANEL_DA_MODEL`, fallback behavior when API unreachable.
- **T11 (CLAUDE.md): MODIFIED.** Mentions the new env var and the ERROR-fallback path.
- **T10, T12, T13: UNCHANGED** (settings registration, verification, PR).

**Secrets handling:**

`$PANEL_DA_API_KEY` is read by `dispatch-da.sh` at runtime. NEVER persisted to any file in the repo, never logged in trace output, never echoed in error messages (use a redacted form like `<key set: ${PANEL_DA_API_KEY:0:6}...>` if debugging). Tests use a synthetic key set via `PANEL_DA_API_KEY=test-key ./dispatch-da_test.sh`. The key is passed to curl via `-H @<file>` so it does not appear in process argv. Real-API smoke tests are documented in the README; no automated CI runs them.

**For implementer subagents:** receive task instructions directly from the controller, not from this plan file. The original T7–T13 sections below are left intact for reference; the controller will hand subagents the revised task text inline.

---

## Pre-flight

This plan assumes implementation happens in an isolated worktree per `agents-workbench` workflow.

### Task 0: Create implementation worktree

**Files:** none (workspace setup)

- [ ] **Step 1: Create worktree from origin/main**

```bash
cd /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary
git fetch origin
BASE="origin/$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
git worktree add .worktrees/recommendation-validator -b feat/recommendation-validator "$BASE"
cd .worktrees/recommendation-validator
```

- [ ] **Step 2: Verify worktree is on the new branch**

```bash
git branch --show-current
```

Expected output: `feat/recommendation-validator`

---

## Task 1: Skill directory scaffolding

**Files:**
- Create: `.claude/skills/validate-recommendation/`
- Create: `.claude/skills/validate-recommendation/fixtures/`

- [ ] **Step 1: Create directories**

```bash
mkdir -p .claude/skills/validate-recommendation/fixtures
```

- [ ] **Step 2: Verify structure**

```bash
ls -la .claude/skills/validate-recommendation/
```

Expected: `fixtures/` subdir exists, no other files yet.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/validate-recommendation/
git commit -s -S -m "chore(skills): scaffold validate-recommendation skill dir"
```

Note: `.gitkeep` not used; the next tasks add real files. If commit fails because the dir is empty, defer this commit until after Task 2.

---

## Task 2: Aggregator test fixtures

**Files:**
- Create: `.claude/skills/validate-recommendation/fixtures/da_hold.txt`
- Create: `.claude/skills/validate-recommendation/fixtures/pe_hold.txt`
- Create: `.claude/skills/validate-recommendation/fixtures/da_overturn_b.txt`
- Create: `.claude/skills/validate-recommendation/fixtures/pe_overturn_c.txt`
- Create: `.claude/skills/validate-recommendation/fixtures/malformed.txt`

These are the verdict files panelists produce (per spec data flow). They feed `aggregate.sh` tests.

- [ ] **Step 1: Create `da_hold.txt`**

```
VERDICT: HOLD
RATIONALE: After examining options A, B, and C, no stronger counter found. Option A's reasoning around atomicity holds; B introduces unnecessary indirection and C couples concerns.
ALTERNATIVE: n/a
```

Save to `.claude/skills/validate-recommendation/fixtures/da_hold.txt`.

- [ ] **Step 2: Create `pe_hold.txt`**

```
VERDICT: HOLD
RATIONALE: Option A aligns with YAGNI and atomicity per ~/.claude/CLAUDE.md. No principle violation. Security and correctness implications are equivalent across options; A wins on simplicity.
ALTERNATIVE: n/a
```

Save to `.claude/skills/validate-recommendation/fixtures/pe_hold.txt`.

- [ ] **Step 3: Create `da_overturn_b.txt`**

```
VERDICT: OVERTURN
RATIONALE: Option A assumes the caller controls retry semantics, but the existing client wrapper already retries. Choosing A double-retries on transient failures. Option B sidesteps this entirely.
ALTERNATIVE: Option B
```

Save to `.claude/skills/validate-recommendation/fixtures/da_overturn_b.txt`.

- [ ] **Step 4: Create `pe_overturn_c.txt`**

```
VERDICT: OVERTURN
RATIONALE: Option A violates atomicity by bundling logging changes with the core fix. Per ~/.claude/CLAUDE.md, ">1 concern → break down first." Option C isolates the fix and defers logging.
ALTERNATIVE: Option C
```

Save to `.claude/skills/validate-recommendation/fixtures/pe_overturn_c.txt`.

- [ ] **Step 5: Create `malformed.txt`**

```
This is not a valid verdict. There's no VERDICT line.
Just some prose that doesn't match the format.
```

Save to `.claude/skills/validate-recommendation/fixtures/malformed.txt`.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/validate-recommendation/fixtures/
git commit -s -S -m "test(panel): add verdict fixtures for aggregator tests"
```

---

## Task 3: Aggregator unit test (Red)

**Files:**
- Create: `.claude/skills/validate-recommendation/aggregate_test.sh`

This is TDD Red: test must fail because `aggregate.sh` doesn't exist yet.

- [ ] **Step 1: Write the failing test script**

```bash
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
```

Save to `.claude/skills/validate-recommendation/aggregate_test.sh`, then `chmod +x`.

- [ ] **Step 2: Run the test to confirm it fails (Red)**

```bash
chmod +x .claude/skills/validate-recommendation/aggregate_test.sh
.claude/skills/validate-recommendation/aggregate_test.sh
```

Expected: `FAIL: aggregate.sh missing or not executable` and exit 1.

- [ ] **Step 3: Commit Red**

```bash
git add .claude/skills/validate-recommendation/aggregate_test.sh
git commit -s -S -m "test(panel): aggregate_test.sh covering hold/dissent/error rules

[RED]"
```

---

## Task 4: Aggregator implementation (Green)

**Files:**
- Create: `.claude/skills/validate-recommendation/aggregate.sh`

- [ ] **Step 1: Write the aggregator**

```bash
#!/bin/bash
# aggregate.sh - parse panelist verdicts and emit final directive.
# Inputs: --da <verdict-file> --pe <verdict-file> --recommended-label <label>
# Output (stdout, one of):
#   PANEL_VERDICT: HOLD   (followed by one-line rationale summary)
#   PANEL_VERDICT: DISSENT (followed by augmented question JSON on next lines)
#   PANEL_VERDICT: ERROR  (followed by reason)
set -o pipefail

DA_FILE=""
PE_FILE=""
REC_LABEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --da) DA_FILE="$2"; shift 2 ;;
        --pe) PE_FILE="$2"; shift 2 ;;
        --recommended-label) REC_LABEL="$2"; shift 2 ;;
        *) echo "PANEL_VERDICT: ERROR"; echo "unknown arg: $1"; exit 0 ;;
    esac
done

if [ -z "$DA_FILE" ] || [ -z "$PE_FILE" ] || [ -z "$REC_LABEL" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "missing required args"
    exit 0
fi

if [ ! -r "$DA_FILE" ] || [ ! -r "$PE_FILE" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "verdict file unreadable"
    exit 0
fi

parse_field() {
    local file="$1"; local field="$2"
    grep -m1 "^${field}: " "$file" 2>/dev/null | sed "s/^${field}: //"
}

DA_VERDICT=$(parse_field "$DA_FILE" "VERDICT")
DA_RATIONALE=$(parse_field "$DA_FILE" "RATIONALE")
DA_ALT=$(parse_field "$DA_FILE" "ALTERNATIVE")
PE_VERDICT=$(parse_field "$PE_FILE" "VERDICT")
PE_RATIONALE=$(parse_field "$PE_FILE" "RATIONALE")
PE_ALT=$(parse_field "$PE_FILE" "ALTERNATIVE")

# Validate verdicts parsed
case "$DA_VERDICT" in HOLD|OVERTURN) ;; *)
    echo "PANEL_VERDICT: ERROR"
    echo "DA verdict unparseable"
    exit 0
    ;;
esac
case "$PE_VERDICT" in HOLD|OVERTURN) ;; *)
    echo "PANEL_VERDICT: ERROR"
    echo "PE verdict unparseable"
    exit 0
    ;;
esac

# Validate rationale present
if [ -z "$DA_RATIONALE" ] || [ -z "$PE_RATIONALE" ]; then
    echo "PANEL_VERDICT: ERROR"
    echo "rationale missing"
    exit 0
fi

# Both HOLD → HOLD
if [ "$DA_VERDICT" = "HOLD" ] && [ "$PE_VERDICT" = "HOLD" ]; then
    echo "PANEL_VERDICT: HOLD"
    # Abbreviate rationales to first sentence for the user-facing summary
    DA_SHORT=$(echo "$DA_RATIONALE" | sed 's/\([.!?]\).*/\1/')
    PE_SHORT=$(echo "$PE_RATIONALE" | sed 's/\([.!?]\).*/\1/')
    echo "DA: $DA_SHORT"
    echo "PE: $PE_SHORT"
    exit 0
fi

# Otherwise DISSENT
echo "PANEL_VERDICT: DISSENT"
SUMMARY="**Panel review:** "
if [ "$DA_VERDICT" = "OVERTURN" ]; then
    SUMMARY+="DA flagged ${REC_LABEL} → suggests ${DA_ALT}: ${DA_RATIONALE} "
else
    SUMMARY+="DA held ${REC_LABEL}: ${DA_RATIONALE} "
fi
if [ "$PE_VERDICT" = "OVERTURN" ]; then
    SUMMARY+="PE flagged ${REC_LABEL} → suggests ${PE_ALT}: ${PE_RATIONALE}"
else
    SUMMARY+="PE held ${REC_LABEL}: ${PE_RATIONALE}"
fi
echo "$SUMMARY"
exit 0
```

Save to `.claude/skills/validate-recommendation/aggregate.sh`, then `chmod +x`.

- [ ] **Step 2: Run the test to verify it passes (Green)**

```bash
chmod +x .claude/skills/validate-recommendation/aggregate.sh
.claude/skills/validate-recommendation/aggregate_test.sh
```

Expected: `PASS` and exit 0.

- [ ] **Step 3: Commit Green**

```bash
git add .claude/skills/validate-recommendation/aggregate.sh
git commit -s -S -m "feat(panel): aggregate.sh emits HOLD/DISSENT/ERROR per verdicts

Aggregation rules per spec:
- both HOLD → HOLD with abbreviated rationales
- any OVERTURN → DISSENT with augmented summary
- malformed/missing → ERROR (caller falls back to original question)

[GREEN]"
```

---

## Task 5: Hook unit test (Red)

**Files:**
- Create: `.claude/hooks/validate-recommendation_test.sh`

- [ ] **Step 1: Write the failing hook test**

```bash
#!/bin/bash
# Test validate-recommendation.sh hook behavior.
set -o pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-recommendation.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

if [ ! -x "$HOOK" ]; then
    echo "FAIL: hook missing or not executable: $HOOK"
    exit 1
fi

run_hook() {
    # $1: stdin JSON, $2: env vars (space-separated key=val), $3: optional session id
    local input="$1"; local envs="$2"; local sid="${3:-test-session}"
    env $envs TMPDIR="$TMP" CLAUDE_SESSION_ID="$sid" bash -c "echo '$input' | '$HOOK'" 2>&1
    return $?
}

# Test 1: marker present → exit 2 (block) + stderr mentions skill
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"the recommended choice"},{"label":"Option B","description":"alt"}]}]},"session_id":"t1"}'
OUT=$(run_hook "$INPUT" "" "t1") && RC=0 || RC=$?
if [ "$RC" != "2" ]; then
    echo "FAIL test1: expected exit 2 (block), got $RC"
    echo "OUT: $OUT"
    exit 1
fi
if ! echo "$OUT" | grep -qi 'validate-recommendation'; then
    echo "FAIL test1: stderr should mention skill name"
    echo "OUT: $OUT"
    exit 1
fi
if [ ! -f "$TMP/claude-panel-t1.json" ]; then
    echo "FAIL test1: state file not written"
    exit 1
fi

# Test 2: no marker → exit 0 (approve), no state file
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t2"}'
run_hook "$INPUT" "" "t2" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test2: expected exit 0, got $RC"
    exit 1
fi
if [ -f "$TMP/claude-panel-t2.json" ]; then
    echo "FAIL test2: state file should NOT exist"
    exit 1
fi

# Test 3: loop guard (Panel-flagged) → exit 0
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended; Panel-flagged)","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t3"}'
run_hook "$INPUT" "" "t3" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test3 loop guard: expected exit 0, got $RC"
    exit 1
fi
if [ -f "$TMP/claude-panel-t3.json" ]; then
    echo "FAIL test3: state file should NOT exist on loop guard"
    exit 1
fi

# Test 4: CLAUDE_PANEL=off bypasses panel even with marker
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"a"}]}]},"session_id":"t4"}'
run_hook "$INPUT" "CLAUDE_PANEL=off" "t4" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test4 CLAUDE_PANEL=off: expected exit 0, got $RC"
    exit 1
fi
if [ -f "$TMP/claude-panel-t4.json" ]; then
    echo "FAIL test4: state file should NOT exist when panel off"
    exit 1
fi

# Test 5: malformed JSON → exit 0 (fail-open) + stderr log
INPUT='not valid json'
OUT=$(run_hook "$INPUT" "" "t5") && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test5 malformed: expected exit 0 (fail-open), got $RC"
    exit 1
fi

# Test 6: state file has expected keys
INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Pick one","options":[{"label":"Option A (Recommended)","description":"a"},{"label":"Option B","description":"b"}]}]},"session_id":"t6"}'
run_hook "$INPUT" "" "t6" >/dev/null 2>&1 || true
STATE="$TMP/claude-panel-t6.json"
if [ ! -f "$STATE" ]; then
    echo "FAIL test6: state file missing"
    exit 1
fi
for key in session_id tool_input recommended_label timeout_seconds created_at; do
    if ! jq -e --arg k "$key" 'has($k)' "$STATE" >/dev/null 2>&1; then
        echo "FAIL test6: state file missing key: $key"
        cat "$STATE"
        exit 1
    fi
done

# Test 7: non-AskUserQuestion tool → exit 0 (no-op)
INPUT='{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"t7"}'
run_hook "$INPUT" "" "t7" >/dev/null && RC=0 || RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test7 wrong tool: expected exit 0, got $RC"
    exit 1
fi

echo "PASS"
```

Save to `.claude/hooks/validate-recommendation_test.sh`, then `chmod +x`.

- [ ] **Step 2: Run test to confirm it fails (Red)**

```bash
chmod +x .claude/hooks/validate-recommendation_test.sh
.claude/hooks/validate-recommendation_test.sh
```

Expected: `FAIL: hook missing or not executable: ...`

- [ ] **Step 3: Commit Red**

```bash
git add .claude/hooks/validate-recommendation_test.sh
git commit -s -S -m "test(hooks): validate-recommendation_test.sh covering marker/bypass/state

[RED]"
```

---

## Task 6: Hook implementation (Green)

**Files:**
- Create: `.claude/hooks/validate-recommendation.sh`

- [ ] **Step 1: Write the hook**

```bash
#!/bin/bash
# validate-recommendation.sh - PreToolUse hook for AskUserQuestion.
# Detects "(Recommended)" marker in option labels; if present and not already
# panel-flagged, writes tool_input to a session state file and blocks with
# stderr feedback instructing Claude to invoke the validate-recommendation skill.
#
# Exit 0 = approve (let tool proceed). Exit 2 = block (stderr is feedback).
# Fails open: any error in this script results in exit 0 + stderr log.

set -o pipefail

INPUT=$(cat)

# Bypass switch
if [ "${CLAUDE_PANEL:-on}" = "off" ]; then
    exit 0
fi

# Parse tool name; bail unless AskUserQuestion
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL" != "AskUserQuestion" ]; then
    exit 0
fi

# Find first option label containing "(Recommended)"; loop guard if Panel-flagged
RECOMMENDED_LABEL=$(echo "$INPUT" \
    | jq -r '.tool_input.questions[]?.options[]?.label
             | select(contains("(Recommended)"))' 2>/dev/null \
    | grep -v 'Panel-flagged' \
    | head -n 1)

if [ -z "$RECOMMENDED_LABEL" ]; then
    exit 0
fi

# Write state file
SID="${CLAUDE_SESSION_ID:-unknown}"
TMP="${TMPDIR:-/tmp}"
STATE_FILE="$TMP/claude-panel-${SID}.json"
TIMEOUT="${CLAUDE_PANEL_TIMEOUT:-90}"
CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$INPUT" | jq \
    --arg sid "$SID" \
    --arg label "$RECOMMENDED_LABEL" \
    --arg timeout "$TIMEOUT" \
    --arg created "$CREATED" \
    '{
        session_id: $sid,
        tool_input: .tool_input,
        recommended_label: $label,
        timeout_seconds: ($timeout | tonumber),
        created_at: $created
    }' > "$STATE_FILE" 2>/dev/null || {
        echo "panel: failed to write state file at $STATE_FILE" >&2
        exit 0  # fail-open
    }

# Optional debug trace
if [ -n "${CLAUDE_PANEL_DEBUG:-}" ]; then
    DEBUG_DIR="$HOME/.claude/debug"
    mkdir -p "$DEBUG_DIR" 2>/dev/null
    echo "[$CREATED] panel triggered: session=$SID label='$RECOMMENDED_LABEL' state=$STATE_FILE" \
        >> "$DEBUG_DIR/panel-trace.log"
fi

# Block with feedback
cat >&2 <<EOF
Recommendation panel required: this AskUserQuestion has a (Recommended) option.
Invoke the validate-recommendation skill before asking the user. State file:
  $STATE_FILE

The skill will:
  1. Dispatch devil's advocate (general-purpose) and PE (principal-engineer) panelists in parallel
  2. Aggregate verdicts via aggregate.sh
  3. Emit PANEL_VERDICT: HOLD (auto-proceed) or DISSENT (re-ask augmented) or ERROR (re-ask original)

Skill location: .claude/skills/validate-recommendation/SKILL.md
EOF
exit 2
```

Save to `.claude/hooks/validate-recommendation.sh`, then `chmod +x`.

- [ ] **Step 2: Run hook test to verify it passes (Green)**

```bash
chmod +x .claude/hooks/validate-recommendation.sh
.claude/hooks/validate-recommendation_test.sh
```

Expected: `PASS` and exit 0.

- [ ] **Step 3: Commit Green**

```bash
git add .claude/hooks/validate-recommendation.sh
git commit -s -S -m "feat(hooks): validate-recommendation.sh PreToolUse hook for AskUserQuestion

Detects (Recommended) marker; writes session state, blocks with skill directive.
Honors CLAUDE_PANEL=off bypass and Panel-flagged loop guard. Fails open on
errors so AskUserQuestion is never blocked by hook bugs.

[GREEN]"
```

---

## Task 7: Personas

**Files:**
- Create: `.claude/skills/validate-recommendation/personas.md`

- [ ] **Step 1: Write personas.md**

```markdown
# Panel Personas

These persona prompts are loaded by SKILL.md and embedded in each Agent call.

## Devil's Advocate (DA)

> You are a devil's advocate reviewing a recommendation made by another
> assistant. Your job is to find the strongest reason this recommendation is
> wrong. Consider:
>
> - Hidden assumptions in the recommendation that may not hold
> - Edge cases the recommendation breaks on
> - Alternatives that better match the user's stated goal
> - Second-order effects (maintenance burden, debugging cost, lock-in)
>
> If after honest scrutiny you cannot find a meaningful counter, say so
> explicitly: VERDICT: HOLD with rationale "no stronger counter found,
> options examined: ...". Do NOT manufacture criticism — manufactured
> dissent wastes the user's attention.
>
> Output strictly:
> ```
> VERDICT: <HOLD|OVERTURN>
> RATIONALE: <one paragraph, 3-5 sentences>
> ALTERNATIVE: <option label, only if OVERTURN; otherwise "n/a">
> ```

## Principal Engineer (PE)

> You are reviewing a recommendation against the engineering principles in
> ~/.claude/CLAUDE.md and ~/.claude/rules/. Evaluate against:
>
> - Atomicity: does this bundle multiple concerns?
> - YAGNI: any unnecessary abstractions or speculative generality?
> - Priority order: Security > Correctness > Performance > Style — does the
>   recommendation respect this order?
> - TDD: is the recommended option testable and verifiable?
> - Where relevant: K8s conventions, Go conventions, container conventions,
>   git workflow (one concern per PR, signed commits, no merge commits).
>
> If the recommendation aligns with these principles, VERDICT: HOLD. If it
> violates one, VERDICT: OVERTURN — name the principle and a specific
> alternative option that aligns better.
>
> Output strictly:
> ```
> VERDICT: <HOLD|OVERTURN>
> RATIONALE: <one paragraph, 3-5 sentences, naming the principle if OVERTURN>
> ALTERNATIVE: <option label, only if OVERTURN; otherwise "n/a">
> ```
```

Save to `.claude/skills/validate-recommendation/personas.md`.

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/validate-recommendation/personas.md
git commit -s -S -m "feat(panel): persona prompts for DA and PE panelists"
```

---

## Task 8: Skill markdown (orchestration)

**Files:**
- Create: `.claude/skills/validate-recommendation/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

```markdown
---
name: validate-recommendation
description: Validate (Recommended) options in AskUserQuestion via two parallel panelists. Triggered by the validate-recommendation hook; do not invoke manually.
---

# Validate Recommendation

You were invoked because the validate-recommendation hook fired on an
`AskUserQuestion` call that contained a `(Recommended)` option marker. Your
job: dispatch a two-panelist review, aggregate verdicts, and emit a directive
for yourself to act on.

## Inputs

The hook wrote tool input to a session state file:

```bash
STATE_FILE="${TMPDIR:-/tmp}/claude-panel-${CLAUDE_SESSION_ID:-unknown}.json"
```

Read it. If the file is missing, emit `PANEL_VERDICT: ERROR (state file
missing)`, ask the original question unmodified, and stop.

The state file shape (keys you'll use):
- `tool_input.questions` — array of question objects (1-4 items)
- `recommended_label` — first label containing `(Recommended)` (loop-guard
  excluded)
- `timeout_seconds` — per-panelist budget

## Personas

Load `personas.md` from this skill directory. Two sections: `## Devil's
Advocate (DA)` and `## Principal Engineer (PE)`. Use those persona blocks
verbatim in the panelist prompts below.

## Per-question dispatch

For EACH question in `tool_input.questions` that has an option labeled with
`(Recommended)` (and NOT `Panel-flagged`):

1. Construct the panelist prompt using this template:

   ```
   Question: <question text>
   Options (verbatim):
     A. <label> — <description>
     B. <label> — <description>
     ...
   Assistant's recommended option: <recommended label>
   Assistant's stated reasoning: <see "Reasoning extraction" below>

   Your role: <DA or PE persona prompt verbatim from personas.md>

   Required output (strict, parsed by aggregate.sh):
   VERDICT: <HOLD|OVERTURN>
   RATIONALE: <one paragraph, 3-5 sentences>
   ALTERNATIVE: <option label, only if OVERTURN; otherwise "n/a">
   ```

2. Dispatch both panelists in PARALLEL via two `Agent` tool calls in a single
   message (per the parallelism guidance in your tool docs):
   - DA: `subagent_type: "general-purpose"`, prompt = template + DA persona
   - PE: `subagent_type: "principal-engineer"`, prompt = template + PE persona
   - Set a description like "Panel review (DA)" / "Panel review (PE)"

3. When both return, write each verdict to a temp file:

   ```bash
   echo "<DA agent output>" > "${TMPDIR:-/tmp}/panel-da-${CLAUDE_SESSION_ID}-q<N>.txt"
   echo "<PE agent output>" > "${TMPDIR:-/tmp}/panel-pe-${CLAUDE_SESSION_ID}-q<N>.txt"
   ```

4. Run aggregate.sh:

   ```bash
   .claude/skills/validate-recommendation/aggregate.sh \
     --da "<da-file>" \
     --pe "<pe-file>" \
     --recommended-label "<recommended_label from state>"
   ```

   Capture stdout — that's the verdict directive.

## Reasoning extraction

The "stated reasoning" passed to panelists comes from:

1. The recommended option's `description` field (primary source).
2. The question's lead text, if it contains rationale phrases.

If neither is informative, pass `(no reasoning supplied)` and let panelists
evaluate on the options themselves.

NEVER attempt to read or fabricate hidden chain-of-thought.

## Acting on verdicts

After running aggregate.sh for each question, you have a directive per
question. Apply per-question logic:

### `PANEL_VERDICT: HOLD`

The recommendation stands. For this question, take the recommended option
without asking the user. Print to the user (terse, one paragraph max):

> Panel validated <recommended_label> for "<question excerpt>".
> DA: <one-line rationale from aggregate output>
> PE: <one-line rationale from aggregate output>
> Proceeding.

Then continue the work as if the user picked the recommended option.

### `PANEL_VERDICT: DISSENT`

Re-issue `AskUserQuestion` for this question only. The augmented payload:

- Question text: original question + two newlines + the panel summary line
  from aggregate.sh stdout (starts with `**Panel review:**`)
- Options: identical to original, EXCEPT the recommended option's label has
  `(Recommended)` replaced with `(Recommended; Panel-flagged)`. The hook
  detects this marker and skips the panel on the re-ask.

If the original `AskUserQuestion` call had multiple questions, only the
dissented questions get augmented; HOLD questions are auto-resolved without
re-asking.

### `PANEL_VERDICT: ERROR`

Something went wrong (timeout, malformed verdict, missing files). For this
question, fall back to asking the original `AskUserQuestion` payload
unmodified — same options, same `(Recommended)` marker. Do NOT swap the
marker (we want to preserve user-visible recommendation), but the loop guard
in the hook would still fire panel again. Compromise: DO swap the marker to
`(Recommended; Panel-flagged)` to prevent infinite loops. The user sees the
question, no dissent appended.

## Cleanup

After processing all questions:

```bash
rm -f "$STATE_FILE" "${TMPDIR:-/tmp}/panel-da-${CLAUDE_SESSION_ID}-q"*.txt \
       "${TMPDIR:-/tmp}/panel-pe-${CLAUDE_SESSION_ID}-q"*.txt
```

If you crash before cleanup, the next session has a different
`CLAUDE_SESSION_ID`, so stale files are harmless (they get overwritten or
ignored).

## Failure modes (you, the skill)

- State file missing: emit `PANEL_VERDICT: ERROR`, fall back to original
  question, do NOT crash the session.
- One Agent call returns malformed output: aggregate.sh handles this and
  emits ERROR; you fall back per the ERROR branch above.
- Both Agents time out: same — ERROR → fall back.
- aggregate.sh missing or not executable: emit `PANEL_VERDICT: ERROR`,
  user-visible message: "Panel infrastructure unavailable; asking question
  directly."

The whole panel is best-effort. The user-visible question always survives.
```

Save to `.claude/skills/validate-recommendation/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/validate-recommendation/SKILL.md
git commit -s -S -m "feat(panel): SKILL.md orchestrates DA + PE panelists per question"
```

---

## Task 9: Skill README

**Files:**
- Create: `.claude/skills/validate-recommendation/README.md`

- [ ] **Step 1: Write README**

```markdown
# validate-recommendation

A Claude Code skill that validates `(Recommended)` options in
`AskUserQuestion` calls by dispatching two parallel panelists (devil's
advocate and principal-engineer). Auto-takes the recommendation when both
panelists agree; surfaces dissent in the question text otherwise.

## How it works

1. The `validate-recommendation.sh` `PreToolUse` hook watches every
   `AskUserQuestion` call.
2. If any option label contains `(Recommended)` (and not `Panel-flagged`),
   the hook writes the tool input to a session state file and exits 2 (block)
   with a stderr message instructing Claude to invoke this skill.
3. The skill dispatches two `Agent` calls in parallel (DA + PE), each with
   the question, options, recommendation, and persona charter.
4. `aggregate.sh` parses the two verdict files and emits one of:
   - `PANEL_VERDICT: HOLD` — Claude auto-proceeds with the recommendation
   - `PANEL_VERDICT: DISSENT` — Claude re-asks with dissent summary
   - `PANEL_VERDICT: ERROR` — Claude asks original question unmodified

## Configuration

| Variable | Default | Effect |
|----------|---------|--------|
| `CLAUDE_PANEL` | `on` | Set to `off` to bypass the panel entirely. |
| `CLAUDE_PANEL_TIMEOUT` | `90` | Per-panelist timeout (seconds). |
| `CLAUDE_PANEL_DEBUG` | unset | If set, hook writes trace to `~/.claude/debug/panel-trace.log`. |

## Files

- `SKILL.md` — orchestration instructions Claude follows when invoked.
- `personas.md` — DA and PE persona prompts (verbatim in panelist input).
- `aggregate.sh` — verdict parser; emits final directive.
- `aggregate_test.sh` — unit tests for aggregator.
- `fixtures/*.txt` — verdict file fixtures used by aggregator tests.
- (sibling) `../../hooks/validate-recommendation.sh` — the hook.
- (sibling) `../../hooks/validate-recommendation_test.sh` — hook tests.

## E2E smoke test (post-install)

After running `./scripts/deploy.sh` to sync this to `~/.claude/`:

1. Confirm `CLAUDE_PANEL` is unset (default = on):
   ```bash
   echo "${CLAUDE_PANEL:-on}"  # should print "on"
   ```
2. Open a fresh Claude Code session.
3. Prompt the assistant for a recommendation that triggers `AskUserQuestion`
   (e.g., "Recommend an HTTP client for a Go service. Show 3 options.").
4. Verify in the assistant's stream that:
   - The hook fires (you'll see a brief panel-running message).
   - On HOLD: the assistant prints the panel rationales and proceeds without
     asking. The `AskUserQuestion` UI never surfaces.
   - On DISSENT: the question shows up with a `**Panel review:**` line
     attached.
5. Inspect for errors:
   ```bash
   ls -lt ~/.claude/debug/panel-trace.log 2>/dev/null
   ls -lt ~/.claude/debug/*.log 2>/dev/null
   ```
6. Repeat with `CLAUDE_PANEL=off claude` and verify the panel does NOT fire
   (the question should appear immediately, original options).

## Uninstall

1. Remove the matcher block from `.claude/settings.json` under
   `hooks.PreToolUse` (the entry pointing at
   `validate-recommendation.sh`).
2. Delete the skill and hook files:
   ```bash
   rm -rf .claude/skills/validate-recommendation/
   rm -f .claude/hooks/validate-recommendation.sh \
         .claude/hooks/validate-recommendation_test.sh
   ```
3. Re-run `./scripts/deploy.sh` (or hand-delete from `~/.claude/`).
```

Save to `.claude/skills/validate-recommendation/README.md`.

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/validate-recommendation/README.md
git commit -s -S -m "docs(panel): README with config, smoke test, uninstall"
```

---

## Task 10: Register hook in settings.json

**Files:**
- Modify: `.claude/settings.json`

The current `.claude/settings.json` has `hooks.PreToolUse` matchers for
`Bash`, `Write`, and `Edit`. We add a new matcher for `AskUserQuestion`.

- [ ] **Step 1: Read current PreToolUse block**

```bash
jq '.hooks.PreToolUse' .claude/settings.json
```

Note the structure — array of `{matcher, hooks}` objects.

- [ ] **Step 2: Add the AskUserQuestion matcher**

Use jq to insert (avoids hand-editing JSON):

```bash
jq '.hooks.PreToolUse += [{
    "matcher": "AskUserQuestion",
    "hooks": [{
        "type": "command",
        "command": "/Users/eduardoa/.claude/hooks/validate-recommendation.sh"
    }]
}]' .claude/settings.json > .claude/settings.json.tmp \
&& mv .claude/settings.json.tmp .claude/settings.json
```

- [ ] **Step 3: Verify the JSON is valid and the matcher is present**

```bash
jq '.hooks.PreToolUse | map(.matcher)' .claude/settings.json
```

Expected output includes `"AskUserQuestion"`.

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -s -S -m "chore(settings): register validate-recommendation PreToolUse hook"
```

---

## Task 11: Document in CLAUDE.md

**Files:**
- Modify: `.claude/CLAUDE.md`

- [ ] **Step 1: Read the current CLAUDE.md to find an insertion point**

```bash
grep -n '^## ' .claude/CLAUDE.md
```

Pick a location near other behavior-shaping sections (e.g., after `## TDD
Protocol` or `## Subagent Discipline`).

- [ ] **Step 2: Add the section**

Insert this section using `Edit` (one operation, exact string match):

```markdown
## Recommendation Panel

`AskUserQuestion` calls with a `(Recommended)` option are intercepted by
the `validate-recommendation` hook. Two panelists run in parallel:
- **Devil's advocate** (general-purpose subagent) — finds the strongest
  reason the recommendation is wrong; explicit "no stronger counter" if
  none.
- **Principal Engineer** (`principal-engineer` subagent) — checks the
  recommendation against `~/.claude/CLAUDE.md` and `~/.claude/rules/`.

If both **HOLD** → recommendation taken automatically with abbreviated
rationales printed.
If either **OVERTURN** → question is re-asked with `**Panel review:**`
summary appended; user picks.

Bypass: `CLAUDE_PANEL=off claude`.
Skill: `.claude/skills/validate-recommendation/`.
```

- [ ] **Step 3: Verify the edit is in place**

```bash
grep -A 3 "Recommendation Panel" .claude/CLAUDE.md
```

- [ ] **Step 4: Commit**

```bash
git add .claude/CLAUDE.md
git commit -s -S -m "docs(claude): document validate-recommendation panel"
```

---

## Task 12: Re-run all tests + integration check

**Files:** none (verification)

- [ ] **Step 1: Run aggregator tests**

```bash
.claude/skills/validate-recommendation/aggregate_test.sh
```

Expected: `PASS`.

- [ ] **Step 2: Run hook tests**

```bash
.claude/hooks/validate-recommendation_test.sh
```

Expected: `PASS`.

- [ ] **Step 3: Lint markdown (if markdownlint configured)**

```bash
if command -v markdownlint >/dev/null 2>&1; then
    markdownlint .claude/skills/validate-recommendation/*.md docs/superpowers/specs/2026-05-10-*.md docs/superpowers/plans/2026-05-10-*.md
fi
```

Expected: no output (clean) or specific issues to fix.

- [ ] **Step 4: jq lint settings.json**

```bash
jq empty .claude/settings.json && echo "settings.json: valid"
```

Expected: `settings.json: valid`.

- [ ] **Step 5: Verify hook is registered**

```bash
jq -e '.hooks.PreToolUse[] | select(.matcher == "AskUserQuestion")' .claude/settings.json
```

Expected: prints the matcher block.

---

## Task 13: Push branch and open draft PR

**Files:** none (publish)

- [ ] **Step 1: Push the feature branch**

```bash
git push -u origin feat/recommendation-validator
```

- [ ] **Step 2: Open draft PR**

```bash
gh pr create --draft \
    --title "feat: recommendation validator panel (hook + skill)" \
    --body "$(cat <<'EOF'
## Problem

`AskUserQuestion` calls with `(Recommended)` options ask the user to
validate by hand even when the recommendation is sound. For unsound
recommendations there's no second pair of eyes.

## Approach

Add a `PreToolUse` hook + `validate-recommendation` skill. The hook
detects the marker and blocks; the skill runs two parallel panelists
(devil's advocate via `general-purpose` agent, PE via
`principal-engineer` agent) and either:
- auto-takes the recommendation if both panelists hold, OR
- re-asks the question with a dissent summary if either overturns.

## Spec / Plan

- Spec: `docs/superpowers/specs/2026-05-10-recommendation-validator-design.md`
- Plan: `docs/superpowers/plans/2026-05-10-recommendation-validator.md`

## Testing

- Hook unit tests: 7 cases covering marker, loop-guard, env-bypass,
  malformed JSON (fail-open), state-file shape, non-AskUserQuestion noop
- Aggregator unit tests: 6 cases covering hold, dissent, malformed
- Manual E2E smoke test procedure in skill README

All tests pass via:
```
.claude/hooks/validate-recommendation_test.sh
.claude/skills/validate-recommendation/aggregate_test.sh
```

## Breaking changes

None. New hook is opt-out via `CLAUDE_PANEL=off`. Settings.json adds one
matcher block; existing hooks untouched.
EOF
)"
```

- [ ] **Step 3: Capture PR URL for handoff**

```bash
gh pr view --json url --jq '.url'
```

- [ ] **Step 4: E2E smoke test (manual, post-deploy)**

After PR merge and `./scripts/deploy.sh`:
1. Open a fresh Claude Code session.
2. Prompt: "Recommend a Go HTTP client for a service that needs retries.
   Show 3 options."
3. Verify panel runs before any user-facing question. Expect HOLD or
   DISSENT, not ERROR.
4. Run with `CLAUDE_PANEL=off claude` and verify the panel does NOT fire.
5. Set `CLAUDE_PANEL_DEBUG=1 claude` once and inspect
   `~/.claude/debug/panel-trace.log`.

If E2E fails: do NOT promote PR to ready-for-review. File a follow-up
issue with the trace log.

---

## Acceptance criteria

- [ ] Hook test (`validate-recommendation_test.sh`) passes all 7 cases.
- [ ] Aggregator test (`aggregate_test.sh`) passes all 6 cases.
- [ ] `jq empty .claude/settings.json` succeeds.
- [ ] `.claude/CLAUDE.md` contains the "Recommendation Panel" section.
- [ ] PR is open as draft, links spec and plan.
- [ ] E2E smoke test (manual) confirms panel fires on `(Recommended)` and
      does not fire on `(Recommended; Panel-flagged)` or with
      `CLAUDE_PANEL=off`.

## Out of scope (do not add to this PR)

- Persona prompts in external YAML
- Panel verdict statistics
- Tie-breaker third panelist
- Verdict caching across sessions
- Plain-text recommendation panel (non-AskUserQuestion path)
