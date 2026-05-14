# validate-recommendation v2 — Phase 1: Foundation bug fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the three bugs in `dispatch-da.sh` so the validate-recommendation panel works end-to-end with today's 1-DA + 1-PE composition.

**Architecture:** Surgical edits to `dispatch-da.sh` (build system message from `personas.md`, raise `max_tokens`, reject `OVERTURN + ALTERNATIVE=n/a`). Add three test fixtures and three test cases. Update `SKILL.md` to remove the contradictory bullet. No new files in production code paths; no new dependencies.

**Tech Stack:** Bash, curl, jq, sed/awk for personas.md slicing.

**Pre-flight (verify before starting):**
- `~/.claude/skills/validate-recommendation/` exists and contains `dispatch-da.sh`, `aggregate.sh`, `personas.md`, `dispatch-da_test.sh`, `aggregate_test.sh`, `fixtures/`.
- `dispatch-da_test.sh` exits 0 today (current tests pass; we're adding to them).
- `bash dispatch-da_test.sh` runs cleanly from the skill directory.

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/skills/validate-recommendation/dispatch-da.sh` | **Modify**: extract DA system prompt from `personas.md`, include it as a `role: "system"` message in the chat-completions payload, raise `max_tokens` default to 4096, reject `OVERTURN + ALTERNATIVE=n/a` as ERROR. |
| `~/.claude/skills/validate-recommendation/dispatch-da_test.sh` | **Modify**: add fixtures and three new test cases (system-message-present, max-tokens-4096, overturn-no-alternative-rejected). |
| `~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_no_alt.json` | **Create**: response with `VERDICT: OVERTURN` and `ALTERNATIVE: n/a`. Used to verify rejection. |
| `~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_missing_alt.json` | **Create**: response that has `VERDICT: OVERTURN` but no `ALTERNATIVE:` line at all. Used to verify the same rejection path. |
| `~/.claude/skills/validate-recommendation/personas.md` | **No change in Phase 1** (the file is read by `dispatch-da.sh`; the file's content stays as-is). Phase 3 splits it. |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify**: remove the bullet that says "system prompt embedded by `dispatch-da.sh`". Adjust step 3 ("Construct DA prompt file") to reflect reality: skill writes only the user body to `--prompt-file`; the dispatcher embeds the system prompt itself by reading `personas.md`. |

---

## Tasks

### Task 1: Create fixture for OVERTURN with explicit `n/a` ALTERNATIVE

**Files:**
- Create: `~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_no_alt.json`

- [ ] **Step 1: Create the fixture file**

```json
{"id":"chatcmpl-test","object":"chat.completion","model":"test-model","choices":[{"finish_reason":"stop","index":0,"message":{"role":"assistant","content":"VERDICT: OVERTURN\nRATIONALE: This recommendation has serious flaws but I cannot identify a specific concrete alternative from the options provided.\nALTERNATIVE: n/a"}}],"usage":{"completion_tokens":42,"prompt_tokens":120,"total_tokens":162}}
```

Save to `~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_no_alt.json`.

- [ ] **Step 2: Sanity-check the JSON is valid**

Run: `jq empty ~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_no_alt.json && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add fixtures/da_response_overturn_no_alt.json
git commit -s -S -m "test(panel): add fixture for OVERTURN with n/a ALTERNATIVE"
```

(If `~/.claude/` is not a git repo and you're tracking changes elsewhere, skip the commit but proceed with the rest of the plan.)

---

### Task 2: Create fixture for OVERTURN with missing ALTERNATIVE line

**Files:**
- Create: `~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_missing_alt.json`

- [ ] **Step 1: Create the fixture file**

```json
{"id":"chatcmpl-test","object":"chat.completion","model":"test-model","choices":[{"finish_reason":"length","index":0,"message":{"role":"assistant","content":"VERDICT: OVERTURN\nRATIONALE: Truncated mid-sentence because the model hit max_tokens before completing"}}],"usage":{"completion_tokens":1024,"prompt_tokens":120,"total_tokens":1144}}
```

Note: this fixture simulates the real-world Nemotron behavior observed during verification — a reasoning-model response truncated by token cap, with no `ALTERNATIVE:` line at all. `finish_reason: "length"` documents the cause.

Save to `~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_missing_alt.json`.

- [ ] **Step 2: Sanity-check the JSON is valid**

Run: `jq empty ~/.claude/skills/validate-recommendation/fixtures/da_response_overturn_missing_alt.json && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add fixtures/da_response_overturn_missing_alt.json
git commit -s -S -m "test(panel): add fixture for OVERTURN with missing ALTERNATIVE"
```

---

### Task 3: Add failing test — OVERTURN+n/a must produce ERROR

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/dispatch-da_test.sh` — append after test 13.

- [ ] **Step 1: Append the test case to `dispatch-da_test.sh`**

Append the following block immediately before the final `echo "PASS"` line:

```bash
# Test 14: OVERTURN + ALTERNATIVE=n/a must be rejected as ERROR.
# A devil's advocate that says "this is wrong but I have no alternative" is
# emitting a contradictory verdict. The dispatcher must treat this as
# malformed rather than passing it through to the aggregator.
OUT="$TMP/test14.txt"
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_overturn_no_alt.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test14: expected ERROR for OVERTURN+n/a, got '$(verdict_field "$OUT" VERDICT)'"
    cat "$OUT"
    exit 1
fi
# Rationale should mention "concrete alternative" so the failure is diagnosable.
if ! grep -qi 'alternative' "$OUT"; then
    echo "FAIL test14: ERROR rationale should mention 'alternative'"
    cat "$OUT"
    exit 1
fi

# Test 15: OVERTURN with missing ALTERNATIVE line entirely → also ERROR.
# Same root cause (truncation by token cap); same rejection.
OUT="$TMP/test15.txt"
CLAUDE_PANEL_DA_MOCK_FILE="$FIX/da_response_overturn_missing_alt.json" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"
if [ "$(verdict_field "$OUT" VERDICT)" != "ERROR" ]; then
    echo "FAIL test15: expected ERROR for OVERTURN with missing ALTERNATIVE, got '$(verdict_field "$OUT" VERDICT)'"
    cat "$OUT"
    exit 1
fi
```

- [ ] **Step 2: Run the test suite to confirm tests 14 and 15 FAIL**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh`
Expected: `FAIL test14: expected ERROR for OVERTURN+n/a, got 'OVERTURN'`

This confirms the bug exists (dispatch-da.sh currently accepts OVERTURN+n/a).

---

### Task 4: Implement bug #3 fix — reject OVERTURN with missing/n/a ALTERNATIVE

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/dispatch-da.sh:193-201` (the ALTERNATIVE default block and the verdict-write block).

- [ ] **Step 1: Replace the ALTERNATIVE default block with rejection logic**

In `dispatch-da.sh`, find this existing block (around line 192-195):

```bash
# Default ALTERNATIVE to n/a when absent (HOLD doesn't require it)
if [ -z "$ALTERNATIVE" ]; then
    ALTERNATIVE="n/a"
fi
```

Replace it with:

```bash
# HOLD doesn't require ALTERNATIVE; default missing value to "n/a".
# OVERTURN with empty or "n/a" ALTERNATIVE is malformed — the panelist
# is saying "this is wrong" without naming what to do instead. We reject
# rather than pass the contradictory verdict to the aggregator.
if [ -z "$ALTERNATIVE" ]; then
    if [ "$VERDICT" = "OVERTURN" ]; then
        write_error "OVERTURN missing concrete alternative (likely truncated by max_tokens)"
    fi
    ALTERNATIVE="n/a"
elif [ "$VERDICT" = "OVERTURN" ] && [ "$ALTERNATIVE" = "n/a" ]; then
    write_error "OVERTURN with ALTERNATIVE=n/a is a contradictory verdict"
fi
```

- [ ] **Step 2: Run dispatch-da_test.sh — tests 14 and 15 should now PASS**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh`
Expected: final line is `PASS` (all 15 tests pass).

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add dispatch-da.sh dispatch-da_test.sh
git commit -s -S -m "fix(panel): reject OVERTURN with missing/n/a ALTERNATIVE as ERROR

A devil's advocate that says \"this is wrong\" without naming an
alternative is emitting a contradictory verdict. dispatch-da.sh now
treats this as malformed and writes an ERROR verdict rather than
passing the contradiction to aggregate.sh."
```

---

### Task 5: Add failing test — `max_tokens` in payload must be 4096

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/dispatch-da_test.sh` — append after test 15.

- [ ] **Step 1: Append the test case**

Append immediately before the final `echo "PASS"`:

```bash
# Test 16: max_tokens in the chat-completions payload must be 4096.
# Reasoning models (Nemotron, o1-style) consume tokens for reasoning
# before producing the visible content. With max_tokens=1024 (the v1
# default), the visible VERDICT/RATIONALE/ALTERNATIVE block gets
# truncated. Default raised to 4096 in Phase 1.
ARGV_LOG16="$TMP/curl_argv_16.log"
CURL_MOCK16="$TMP/mock-curl-16.sh"
cat > "$CURL_MOCK16" <<'MOCK_EOF'
#!/bin/bash
# Records the curl invocation's -d (data) value to $ARGV_LOG_PATH for inspection.
prev=""
for a in "$@"; do
    if [ "$prev" = "-d" ]; then
        printf '%s' "$a" > "$ARGV_LOG_PATH"
    fi
    prev="$a"
done
# Emit a synthetic HOLD response so the dispatcher proceeds.
cat <<'BODY'
{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"VERDICT: HOLD\nRATIONALE: tokens probe response with three full sentences. Sentence two. Sentence three.\nALTERNATIVE: n/a"}}]}
BODY
MOCK_EOF
chmod +x "$CURL_MOCK16"

OUT="$TMP/test16.txt"
CURL="$CURL_MOCK16" \
    ARGV_LOG_PATH="$ARGV_LOG16" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"

if [ ! -s "$ARGV_LOG16" ]; then
    echo "FAIL test16: curl mock did not record payload"
    exit 1
fi
MAX_TOKENS=$(jq -r '.max_tokens // empty' "$ARGV_LOG16" 2>/dev/null)
if [ "$MAX_TOKENS" != "4096" ]; then
    echo "FAIL test16: expected max_tokens=4096 in payload, got '$MAX_TOKENS'"
    echo "PAYLOAD: $(cat "$ARGV_LOG16")"
    exit 1
fi
```

- [ ] **Step 2: Run the test suite to confirm test 16 FAILS**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh`
Expected: `FAIL test16: expected max_tokens=4096 in payload, got '1024'`

This confirms the bug exists.

---

### Task 6: Implement bug #2 fix — raise `max_tokens` to 4096

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/dispatch-da.sh:100-110` (the payload construction).

- [ ] **Step 1: Update the payload construction**

In `dispatch-da.sh`, find this existing block (around lines 100-110):

```bash
PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT_TEXT" \
    '{
        model: $model,
        messages: [
            {role: "user", content: $prompt}
        ],
        temperature: 0.3,
        max_tokens: 1024
    }' 2>/dev/null) || write_error "failed to build request payload"
```

Replace with:

```bash
# max_tokens raised from 1024 to 4096 in Phase 1.
# Reasoning models (Nemotron, o1-style) consume tokens for the
# reasoning_content field before producing the visible content. At 1024
# the visible VERDICT/RATIONALE/ALTERNATIVE block was getting truncated
# mid-sentence, producing malformed verdicts.
# Overridable via $CLAUDE_PANEL_DA_MAX_TOKENS for tests / experiments.
MAX_TOKENS="${CLAUDE_PANEL_DA_MAX_TOKENS:-4096}"
PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT_TEXT" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
        model: $model,
        messages: [
            {role: "user", content: $prompt}
        ],
        temperature: 0.3,
        max_tokens: $max_tokens
    }' 2>/dev/null) || write_error "failed to build request payload"
```

- [ ] **Step 2: Run the test suite — test 16 should now PASS**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh`
Expected: final line is `PASS` (all 16 tests pass).

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add dispatch-da.sh dispatch-da_test.sh
git commit -s -S -m "fix(panel): raise dispatch-da max_tokens default to 4096

Reasoning models (Nemotron, o1-style) consume tokens for an internal
reasoning_content phase before producing visible content. At
max_tokens=1024 the visible VERDICT/RATIONALE/ALTERNATIVE block was
truncated mid-RATIONALE in real Nemotron calls. Raised to 4096 with
\$CLAUDE_PANEL_DA_MAX_TOKENS env override for tests."
```

---

### Task 7: Add failing test — DA system prompt must be sent as `role: "system"` message

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/dispatch-da_test.sh` — append after test 16.

- [ ] **Step 1: Append the test case**

Append immediately before the final `echo "PASS"`:

```bash
# Test 17: dispatch-da.sh must send a role:"system" message containing
# the DA persona content. v1 sent only role:"user", causing Nemotron to
# respond with prose instead of the strict VERDICT format.
# We reuse the payload-capturing mock from test 16 with a fresh log.
ARGV_LOG17="$TMP/curl_argv_17.log"
OUT="$TMP/test17.txt"
CURL="$CURL_MOCK16" \
    ARGV_LOG_PATH="$ARGV_LOG17" \
    "$DISPATCH" --prompt-file "$PROMPT" --output "$OUT"

if [ ! -s "$ARGV_LOG17" ]; then
    echo "FAIL test17: curl mock did not record payload"
    exit 1
fi
# Payload.messages must contain at least one element with role=system.
SYSTEM_COUNT=$(jq -r '[.messages[] | select(.role == "system")] | length' "$ARGV_LOG17" 2>/dev/null)
if [ "$SYSTEM_COUNT" -lt 1 ]; then
    echo "FAIL test17: expected at least 1 message with role=system, got $SYSTEM_COUNT"
    echo "PAYLOAD: $(cat "$ARGV_LOG17")"
    exit 1
fi
# The system message content must contain the DA persona signature phrase.
# "devil's-advocate" appears in personas.md's DA system prompt.
SYSTEM_CONTENT=$(jq -r '[.messages[] | select(.role == "system")][0].content' "$ARGV_LOG17" 2>/dev/null)
if ! echo "$SYSTEM_CONTENT" | grep -qi "devil's-advocate reviewer"; then
    echo "FAIL test17: system message content does not contain DA persona signature"
    echo "SYSTEM_CONTENT: $SYSTEM_CONTENT"
    exit 1
fi
# The user message must be the prompt body unchanged.
USER_CONTENT=$(jq -r '[.messages[] | select(.role == "user")][0].content' "$ARGV_LOG17" 2>/dev/null)
EXPECTED_USER=$(cat "$PROMPT")
if [ "$USER_CONTENT" != "$EXPECTED_USER" ]; then
    echo "FAIL test17: user message content does not match prompt file"
    echo "EXPECTED: $EXPECTED_USER"
    echo "GOT: $USER_CONTENT"
    exit 1
fi
```

- [ ] **Step 2: Run the test suite to confirm test 17 FAILS**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh`
Expected: `FAIL test17: expected at least 1 message with role=system, got 0`

---

### Task 8: Implement bug #1 fix — read DA system prompt from `personas.md` and send as `role: "system"`

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/dispatch-da.sh` — add a helper function, modify the payload construction.

- [ ] **Step 1: Add a helper function to extract the DA system prompt from `personas.md`**

In `dispatch-da.sh`, immediately after the `write_error` function definition (around line 58), add:

```bash
# Extract the DA system prompt from personas.md. The persona file is the
# canonical source; the dispatcher reads it at call time rather than
# hardcoding a copy (which would drift).
#
# Slicing rule: take everything between the first occurrence of
# "### System prompt" (followed by a fenced block) and the line
# "### User prompt template". Strip the markdown fence delimiters.
# If extraction fails, fall back to a minimal embedded prompt so the
# dispatcher never crashes on a personas.md edit gone wrong.
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extract_da_system_prompt() {
    local personas="$SKILL_DIR/personas.md"
    if [ ! -r "$personas" ]; then
        printf '%s' "$DA_SYSTEM_PROMPT_FALLBACK"
        return
    fi
    # Awk extracts content between "### System prompt" and the next
    # "###" of the same depth. We keep both the system-prompt body
    # AND the one-shot example (which is the "### One-shot example"
    # section in personas.md). Both are concatenated as the system
    # message — exactly what the persona's intent has always been.
    awk '
        /^## Devil.s Advocate \(DA\)/ { in_da=1; next }
        /^## Principal Engineer \(PE\)/ { in_da=0 }
        in_da && /^### User prompt template/ { exit }
        in_da && /^### (System prompt|One-shot example)/ { capture=1; next }
        in_da && capture && /^### / { capture=0 }
        in_da && capture && /^```/ { fence = !fence; next }
        in_da && capture && fence { print }
    ' "$personas"
}

# Minimal fallback if personas.md is unreadable or malformed.
DA_SYSTEM_PROMPT_FALLBACK="You are a devil's-advocate reviewer. Output ONLY this strict format with no preamble:
VERDICT: HOLD or OVERTURN
RATIONALE: one paragraph
ALTERNATIVE: verbatim option label, or n/a if HOLD"
```

- [ ] **Step 2: Modify the payload construction to include the system message**

Replace the payload block (the one you edited in Task 6) with:

```bash
# Build the system message from personas.md. The dispatcher is the
# canonical place where the DA persona becomes a system prompt — v1
# sent only role:"user" which caused the model to answer the user's
# question directly instead of playing devil's advocate.
SYSTEM_PROMPT=$(extract_da_system_prompt)
if [ -z "$SYSTEM_PROMPT" ]; then
    SYSTEM_PROMPT="$DA_SYSTEM_PROMPT_FALLBACK"
fi

MAX_TOKENS="${CLAUDE_PANEL_DA_MAX_TOKENS:-4096}"
PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg system "$SYSTEM_PROMPT" \
    --arg prompt "$PROMPT_TEXT" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
        model: $model,
        messages: [
            {role: "system", content: $system},
            {role: "user",   content: $prompt}
        ],
        temperature: 0.3,
        max_tokens: $max_tokens
    }' 2>/dev/null) || write_error "failed to build request payload"
```

- [ ] **Step 3: Run the test suite — test 17 should now PASS**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh`
Expected: final line is `PASS` (all 17 tests pass).

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add dispatch-da.sh dispatch-da_test.sh
git commit -s -S -m "fix(panel): embed DA system prompt as role:system message

v1 dispatch-da.sh sent only a role:\"user\" message containing the
templated body. The model never received the devil's-advocate persona
or the strict VERDICT/RATIONALE/ALTERNATIVE format contract, so it
responded with prose and aggregate.sh emitted ERROR.

dispatch-da.sh now extracts the DA system prompt (and one-shot
example) from personas.md at call time and includes it as a
role:\"system\" message. Falls back to a minimal embedded prompt if
personas.md is unreadable."
```

---

### Task 9: Update `SKILL.md` to reflect the new dispatcher contract

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/SKILL.md` — fix the contradictory bullet in the Personas intro AND the step 3 instructions.

- [ ] **Step 1: Read current SKILL.md to find the contradictory section**

Run: `grep -n "embedded by" ~/.claude/skills/validate-recommendation/SKILL.md`
Expected: a line that says something like `system prompt (with one-shot example) embedded by dispatch-da.sh`.

- [ ] **Step 2: Update the Personas intro bullet**

Find this passage in `SKILL.md`:

```markdown
- **Devil's Advocate (DA)** — system prompt (with one-shot example) embedded by `dispatch-da.sh`. You construct only the user prompt.
```

Replace with:

```markdown
- **Devil's Advocate (DA)** — system prompt (with one-shot example) embedded by `dispatch-da.sh`, which reads `personas.md` at call time. You construct only the **user prompt body** (question + options + recommended label + stated reasoning) and write it to the `--prompt-file` path.
```

- [ ] **Step 3: Update step 3 of the per-question dispatch flow**

Find the `### 3. Construct DA prompt file` section. Replace its body with:

```markdown
### 3. Construct DA prompt file

Write **only the user prompt body** to a temp file via the `Write` tool:

```
DA_PROMPT_FILE="${TMPDIR:-/tmp}/panel-da-prompt-d98701f1-4cef-4160-8afe-57c2f38cb5f3-q<N>.txt"
```

(Where `<N>` is the question index, 0-based.)

The body is the templated content described in step 1 — nothing more.
The DA system prompt and one-shot example are embedded by
`dispatch-da.sh` itself; do not duplicate them in the prompt file.
```

- [ ] **Step 4: Manually verify SKILL.md by re-reading the modified sections**

Run: `grep -A 1 'Devil.s Advocate (DA)' ~/.claude/skills/validate-recommendation/SKILL.md | head -5`
Verify the bullet matches what was set in Step 2.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add SKILL.md
git commit -s -S -m "docs(panel): SKILL.md — dispatcher embeds DA system prompt from personas.md

v1 SKILL.md said the dispatcher embedded the system prompt AND step 3
said the caller should combine system+example+body into the prompt
file. The two were contradictory; the dispatcher actually did neither.
After fix(panel): embed DA system prompt as role:system message, the
dispatcher is now the canonical embedder. SKILL.md updated to match."
```

---

### Task 10: End-to-end verification with real Nemotron

**Files:** none modified. Manual verification step.

- [ ] **Step 1: Verify env vars are set**

Run:
```bash
for v in PANEL_DA_API_KEY CLAUDE_PANEL_DA_ENDPOINT CLAUDE_PANEL_DA_MODEL; do
    eval "val=\${$v:-}"; [ -n "$val" ] && echo "$v: set" || echo "$v: MISSING"
done
```
Expected: all three say `set`. If any are missing, stop and fix `~/.zshrc`.

- [ ] **Step 2: Dispatch DA against a known-substantive question (real HTTP, no mock)**

Run:
```bash
TMP=$(mktemp -d)
cat > "$TMP/prompt.txt" <<'PROMPT'
Question: Which HTTP client should I use for a Go service that needs retries?
Options (verbatim labels and descriptions):
  retryablehttp (Recommended) — hashicorp/go-retryablehttp wrapping net/http — battle-tested, sane defaults, exponential backoff with jitter built in.
  go-resty/resty — Feature-rich HTTP client with built-in retry middleware, request/response hooks, and fluent API.
  net/http + custom loop — Standard library net/http with a hand-rolled retry loop. Minimal deps, full control, more code to maintain and test.
Assistant's recommended option: retryablehttp (Recommended)
Assistant's stated reasoning: hashicorp/go-retryablehttp wrapping net/http — battle-tested, sane defaults, exponential backoff with jitter built in.
PROMPT
~/.claude/skills/validate-recommendation/dispatch-da.sh \
    --prompt-file "$TMP/prompt.txt" \
    --output "$TMP/verdict.txt"
echo "--- verdict ---"
cat "$TMP/verdict.txt"
```

Expected: the verdict file contains a parseable VERDICT/RATIONALE/ALTERNATIVE block (VERDICT either HOLD or OVERTURN; if OVERTURN, ALTERNATIVE is a verbatim option label, NOT n/a). RATIONALE is a complete paragraph (not truncated mid-word).

If the verdict is ERROR with rationale "response content missing VERDICT line": Phase 1 fix did not land — re-check Task 8.
If the verdict is OVERTURN with ALTERNATIVE=n/a: Phase 1 fix did not land for OVERTURN+n/a rejection — re-check Task 4.
If the verdict file is missing: most likely a sandbox issue — see the spec's error-handling matrix (`$TMPDIR` write blocked).

- [ ] **Step 3: Run the full v1 test pipeline end-to-end with the live panel**

Trigger a real `AskUserQuestion` with a `(Recommended)` option in a Claude Code session and confirm the hook → skill → panel → aggregate path completes successfully without manual intervention. Check `~/.claude/debug/panel-trace.log` — the new entry should be an `outcome=HOLD` or `outcome=DISSENT` (NOT `outcome=ERROR detail="DA verdict unparseable"`).

- [ ] **Step 4: Phase 1 sign-off**

When Steps 2 and 3 both produce well-formed verdicts (not ERROR), Phase 1 is done. Next phase is Phase 2: port `aggregate.sh` to Python.

---

## Self-review

**Spec coverage**: Each of the three bugs called out in the spec's "Why a redesign" section maps to a task pair (failing test + fix):

| Spec bug | Failing-test task | Fix task |
|---|---|---|
| #1 system prompt not embedded | 7 | 8 |
| #2 max_tokens too low | 5 | 6 |
| #3 OVERTURN+n/a accepted | 3 | 4 |

Plus Task 9 (SKILL.md alignment) and Task 10 (E2E verification).

**Placeholder scan**: no TBD/TODO/FIXME. All commands are exact. All commit messages are concrete. The `extract_da_system_prompt` function in Task 8 references awk patterns that depend on `personas.md` having the headings `## Devil's Advocate (DA)`, `### System prompt`, `### One-shot example`, `### User prompt template` — confirmed present in the current `personas.md`.

**Type consistency**: env var names (`CLAUDE_PANEL_DA_MAX_TOKENS`), function names (`extract_da_system_prompt`, `write_error`), fixture file names, and test numbers are consistent across all tasks.
