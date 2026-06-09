# Completion Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A deterministic Stop hook that blocks ending a turn while unverified source edits exist, and re-prompts the agent to verify.

**Architecture:** A single bash hook (`completion-gate.sh`) parses the Stop-hook transcript (nested JSONL) with `jq`, computes the set of source files edited with no passing build/test/lint afterward (cross-turn), and — if non-empty — emits `{"decision":"block","reason":…}` on stdout to block the stop and re-prompt. Fail-open, content-hash debounced, kill-switchable.

**Tech Stack:** bash, `jq`, `shasum`, `git`. Test harness: plain-bash `*_test.sh` (repo convention). Verified against CC 2.1.169 transcript schema and an empirical Stop-hook probe.

**Execution method: solo** (one hook script + one test + one surgical settings edit; design fully settled in spec v2).

---

## File Structure

**Authoring vs. deployment (RESOLVED today):** `.claude/hooks/` is git-tracked in the repo (31 files) and is the **source of truth**; `~/.claude/hooks/` is the **deployed/active copy** that the runtime executes — and it currently *drifts* from the repo (the live `done-hook.sh` is older than the repo's). No sync script exists; deployment is a manual `cp`. Therefore:

- **Create** `<worktree>/.claude/hooks/completion-gate.sh` — the Stop hook (tracked source). Code in the Reference section.
- **Create** `<worktree>/.claude/hooks/completion-gate_test.sh` — behavioral tests.
- **Create** `<worktree>/.claude/hooks/fixtures/completion-gate/real-slice.jsonl` — captured real transcript slice.
- **Modify** `<worktree>/.claude/settings.json` — remove **only** the `"type":"prompt"` LLM-judge element from `Stop`; de-dupe the command block; add the `completion-gate.sh` command to `Stop`.
- **Deploy** (only for the live smoke test, Task 8): `cp <worktree>/.claude/hooks/completion-gate.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/completion-gate.sh`, and mirror the `Stop` wiring into `~/.claude/settings.json`.

> **Path convention for this plan:** author everything under `<worktree>/.claude/hooks/`. The test's `$HOOK` resolves to that worktree copy (so unit tests need **no** deploy). Where task steps write `~/.claude/hooks/completion-gate.sh`, read it as "the worktree source, deployed to the live path only for the Task 8 smoke test." `git add -A` in the worktree captures the hook, test, fixture, and settings edit for the PR.
> Worktree: you are on branch `feat/completion-gate` (not `agents-workbench`), so `enforce-worktree.sh` permits these `.claude/` writes.

---

## Reference: the complete hook (built incrementally below)

`~/.claude/hooks/completion-gate.sh`:

```bash
#!/usr/bin/env bash
# completion-gate.sh — Stop hook. Block ending a turn while unverified source edits exist.
# Mechanism: print {"decision":"block","reason":...} on stdout, exit 0 (probe-verified, CC 2.1.169).
# Fail-open: any internal error -> exit 0.
set -o pipefail

# 0. Kill-switch
[ "${COMPLETION_GATE:-on}" = "off" ] && exit 0

# 1. Read Stop-hook stdin
INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

LOGDIR="$HOME/.claude/audit"; mkdir -p "$LOGDIR" 2>/dev/null
LOG="$LOGDIR/completion-gate-$(date -u +%Y-%m-%d).log"
LEDGER="$LOGDIR/completion-gate-ledger-${SESSION}.txt"

# 2. Config (tunable)
SRC='\.(go|py|ts|tsx|js|jsx|rs|c|h|cc|cpp|java|rb|sh|bash)$'
DENY='(\.md$|\.txt$|LICENSE|\.gitignore$|\.lock$)'
VERIFY='(go (test|build|vet)( |$)|golangci-lint|make (test|build|lint|check|ci)( |$)|_test\.sh( |$)|(^| )bats( |$)|shellcheck|pytest|python[0-9.]* -m pytest|npm (test|run build|run lint)|cargo (test|build|clippy))'

# 3. Compute unverified source set (nested-schema walk; is_error absent => success)
UNV=$(jq -rs --arg src "$SRC" --arg deny "$DENY" --arg verify "$VERIFY" '
  (reduce .[] as $m ({};
     if $m.type=="user" then
       reduce (($m.message.content // []) | if type=="array" then .[] else empty end
               | select(type=="object" and .type=="tool_result")) as $r
         (.; .[$r.tool_use_id] = ($r.is_error // false))
     else . end)) as $res
  | [ .[] | select(.type=="assistant")
      | (.message.content // []) | if type=="array" then .[] else empty end
      | select(type=="object" and .type=="tool_use") ] as $tus
  | reduce $tus[] as $t ({};
      if ($t.name=="Write" or $t.name=="Edit" or $t.name=="MultiEdit")
         and (($t.input.file_path // "") | test($src))
         and ((($t.input.file_path // "") | test($deny)) | not)
      then . + {($t.input.file_path): true}
      elif ($t.name=="Bash") and (($t.input.command // "") | test($verify))
           and ($res | has($t.id)) and (($res[$t.id]) != true)
      then {}
      else . end)
  | keys[]
' "$TRANSCRIPT" 2>/dev/null)

# 4. Drop paths that no longer exist or are git-clean vs HEAD (revert/delete); keep untracked-new
FINAL=()
while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ ! -e "$p" ] && continue                      # deleted
  d=$(dirname "$p")
  if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$d" ls-files --error-unmatch "$p" >/dev/null 2>&1; then
      git -C "$d" diff --quiet HEAD -- "$p" 2>/dev/null && continue   # tracked & clean -> reverted
    fi
  fi
  FINAL+=("$p")
done <<< "$UNV"
[ "${#FINAL[@]}" -eq 0 ] && exit 0

# 5. Waiver: last assistant text starts a line with VERIFY-WAIVED:
LASTTXT=$(jq -rs 'map(select(.type=="assistant")) | (last // {}) | (.message.content // [])
                  | if type=="array" then map(select(.type=="text").text) | join("\n") else "" end' \
          "$TRANSCRIPT" 2>/dev/null)
if printf '%s\n' "$LASTTXT" | grep -qE '^[[:space:]]*VERIFY-WAIVED:'; then
  printf '{"ts":"%s","session":"%s","decision":"waiver"}\n' "$(date -u +%FT%TZ)" "$SESSION" >> "$LOG" 2>/dev/null
  exit 0
fi

# 6. Content-hash debounce (NOT mtime; auto-format perturbs mtime)
STATE=$( { for p in "${FINAL[@]}"; do printf '%s:' "$p"; shasum "$p" 2>/dev/null | cut -d' ' -f1; done; } | sort | shasum | cut -c1-16)
if [ -f "$LEDGER" ] && grep -qx "$STATE" "$LEDGER" 2>/dev/null; then
  printf '{"ts":"%s","session":"%s","decision":"override","state":"%s"}\n' "$(date -u +%FT%TZ)" "$SESSION" "$STATE" >> "$LOG" 2>/dev/null
  exit 0
fi
echo "$STATE" >> "$LEDGER" 2>/dev/null

# 7. Block: legitimate engineering reprompt (NOT injection-shaped)
files=$(printf '%s, ' "${FINAL[@]}"); files=${files%, }
reason="Completion gate: ${#FINAL[@]} source file(s) changed this session with no passing build/test/lint afterward: ${files}. Run the appropriate verification (e.g. go test ./... or the relevant linter) and include its output before ending the turn. If verification is genuinely impossible here, end your final message with a line:  VERIFY-WAIVED: <reason>"
printf '{"ts":"%s","session":"%s","decision":"block","n":%d,"state":"%s"}\n' "$(date -u +%FT%TZ)" "$SESSION" "${#FINAL[@]}" "$STATE" >> "$LOG" 2>/dev/null
jq -nc --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
```

---

## Reference: the test harness header (used by every task)

Top of `~/.claude/hooks/completion-gate_test.sh`:

```bash
#!/usr/bin/env bash
# completion-gate_test.sh — behavioral tests. Each builds a transcript fixture, pipes the
# hook its Stop stdin, asserts on stdout JSON (decision:block) — NOT exit code.
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/completion-gate.sh"
PASS=0; FAIL=0
pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# run_gate <transcript-file> -> prints hook stdout; sets RC
run_gate(){ printf '{"transcript_path":"%s","session_id":"s-%s","stop_hook_active":false}' "$1" "$RANDOM" | bash "$HOOK"; RC=$?; }
assert_block(){    echo "$1" | grep -q '"decision":"block"' && pass || fail "$2 (expected block)"; }
assert_no_block(){ echo "$1" | grep -q '"decision":"block"' && fail "$2 (expected NO block)" || pass; }

# Fixture builders (exact verified schema)
A_edit(){  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Edit","input":{"file_path":"%s"}}]}}\n' "$1" "$2"; }
A_bash(){  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" "$2"; }
A_text(){  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$1"; }
U_ok(){    printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s"}]}}\n' "$1"; }            # is_error ABSENT (success)
U_okf(){   printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":false}]}}\n' "$1"; }
U_err(){   printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":true}]}}\n' "$1"; }
```

Footer (runs last):

```bash
echo "== completion-gate: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
```

---

## Task 1: Core block / no-block + the `is_error`-absent regression

**Files:** Create `~/.claude/hooks/completion-gate.sh`, `~/.claude/hooks/completion-gate_test.sh`.

- [ ] **Step 1: Write failing tests** (append to test file after the header)

```bash
echo "test: edit with no verify -> block"
f="$WORK/t1.jsonl"; : >"$f"; src="$WORK/foo.go"; echo 'package x' >"$src"
A_edit id1 "$src" >>"$f"
out=$(run_gate "$f"); assert_block "$out" "edit-no-verify"

echo "test: edit then passing verify (is_error ABSENT) -> no block  [D1 regression]"
f="$WORK/t2.jsonl"; : >"$f"
A_edit id1 "$src" >>"$f"; A_bash id2 "go test ./..." >>"$f"; U_ok id2 >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "verify-absent-is_error"

echo "test: edit then passing verify (is_error:false) -> no block"
f="$WORK/t2b.jsonl"; : >"$f"
A_edit id1 "$src" >>"$f"; A_bash id2 "go test ./..." >>"$f"; U_okf id2 >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "verify-false-is_error"

echo "test: pure conversation, no edits -> no block"
f="$WORK/t4.jsonl"; : >"$f"; A_text "just talking" >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "no-edits"
```

- [ ] **Step 2: Run, expect failure**

Run: `bash ~/.claude/hooks/completion-gate_test.sh`
Expected: FAIL (hook does not exist yet / not executable).

- [ ] **Step 3: Implement the hook** — write the full `completion-gate.sh` from the Reference section above; `chmod +x ~/.claude/hooks/completion-gate.sh`.

- [ ] **Step 4: Run, expect pass**

Run: `bash ~/.claude/hooks/completion-gate_test.sh`
Expected: `4 passed, 0 failed`. (If the `is_error`-absent test fails, the predicate is wrong — it must be `!= true`, not `== false`.)

- [ ] **Step 5: Commit**

```bash
git -C <repo>/.worktrees/completion-gate add -A 2>/dev/null
git -C <repo>/.worktrees/completion-gate commit -s -S -m "feat(completion-gate): core edit-triggered block with is_error!=true verify-clear" --allow-empty
# (hook lives in ~/.claude; commit records the plan/fixtures tracked in-repo. Hook files are tracked separately if ~/.claude is a repo; otherwise note in PR.)
```

## Task 2: Failing verify still blocks; cross-turn

- [ ] **Step 1: Write failing tests**

```bash
echo "test: edit then FAILING verify -> block"
f="$WORK/t6.jsonl"; : >"$f"
A_edit id1 "$src" >>"$f"; A_bash id2 "go test ./..." >>"$f"; U_err id2 >>"$f"
out=$(run_gate "$f"); assert_block "$out" "failing-verify-blocks"

echo "test: edit on early turn, final turn pure text, no verify -> block (cross-turn)"
f="$WORK/t3.jsonl"; : >"$f"
A_edit id1 "$src" >>"$f"; A_text "all done" >>"$f"
out=$(run_gate "$f"); assert_block "$out" "cross-turn"
```

- [ ] **Step 2: Run** — Expected: PASS (already handled by `($res[$t.id]) != true` and cross-turn set retention). Run: `bash ~/.claude/hooks/completion-gate_test.sh`.
- [ ] **Step 3: Commit** — `git ... commit -s -S -m "test(completion-gate): failing-verify + cross-turn cases"`.

## Task 3: Deny-list + waiver

- [ ] **Step 1: Write failing tests**

```bash
echo "test: edit README.md only -> no block (deny-list)"
f="$WORK/t5.jsonl"; : >"$f"; doc="$WORK/README.md"; echo x >"$doc"
A_edit id1 "$doc" >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "deny-md"

echo "test: edit + VERIFY-WAIVED in last message -> no block"
f="$WORK/t7.jsonl"; : >"$f"
A_edit id1 "$src" >>"$f"; A_text "VERIFY-WAIVED: no toolchain here" >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "waiver"
```

- [ ] **Step 2: Run** — Expected: PASS (deny regex + waiver grep already in hook). Fix hook if not.
- [ ] **Step 3: Commit** — `... -m "test(completion-gate): deny-list + VERIFY-WAIVED escape"`.

## Task 4: Content-hash debounce, delete, revert, untracked

**These need real files + a temp git repo.**

- [ ] **Step 1: Write failing tests**

```bash
echo "test: debounce — identical content state blocked once, allowed on re-stop"
G=$(mktemp -d); git -C "$G" init -q; git -C "$G" config user.email t@t; git -C "$G" config user.name t
echo 'package x' >"$G/a.go"; git -C "$G" add a.go; git -C "$G" commit -qm base
echo 'package x // edited' >"$G/a.go"
f="$WORK/t8.jsonl"; : >"$f"; A_edit id1 "$G/a.go" >>"$f"
out1=$(run_gate "$f"); assert_block "$out1" "debounce-first"
out2=$(run_gate "$f"); assert_no_block "$out2" "debounce-second"   # same content state

echo "test: edit then revert (clean vs HEAD) -> no block"
git -C "$G" checkout -- a.go      # revert to HEAD
f="$WORK/t9.jsonl"; : >"$f"; A_edit id9 "$G/a.go" >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "reverted-clean"

echo "test: edit then delete file -> no block, no crash"
f="$WORK/t10.jsonl"; : >"$f"; A_edit idA "$G/gone.go" >>"$f"
out=$(run_gate "$f"); assert_no_block "$out" "deleted-path"

echo "test: untracked NEW source file, no verify -> block (kept)"
echo 'package n' >"$G/new.go"   # untracked
f="$WORK/t11.jsonl"; : >"$f"; A_edit idN "$G/new.go" >>"$f"
out=$(run_gate "$f"); assert_block "$out" "untracked-new-kept"
```

- [ ] **Step 2: Run** — Expected: PASS. If `debounce-second` blocks, the ledger keys on the wrong thing; if `reverted-clean` blocks, the `ls-files`/`diff --quiet` logic is wrong; if `untracked-new-kept` does NOT block, the untracked branch is wrong.
- [ ] **Step 3: Commit** — `... -m "test(completion-gate): content-debounce, revert, delete, untracked"`.

## Task 5: Kill-switch + fail-open

- [ ] **Step 1: Write failing tests**

```bash
echo "test: COMPLETION_GATE=off -> no block"
f="$WORK/t12.jsonl"; : >"$f"; A_edit id1 "$src" >>"$f"
out=$(printf '{"transcript_path":"%s","session_id":"s","stop_hook_active":false}' "$f" | COMPLETION_GATE=off bash "$HOOK")
assert_no_block "$out" "kill-switch"

echo "test: garbage transcript_path -> no block (fail-open)"
out=$(printf '{"transcript_path":"/nope/nope.jsonl","session_id":"s","stop_hook_active":false}' | bash "$HOOK")
assert_no_block "$out" "fail-open-missing"

echo "test: malformed stdin -> no block (fail-open)"
out=$(printf 'not json' | bash "$HOOK"); assert_no_block "$out" "fail-open-badstdin"
```

- [ ] **Step 2: Run** — Expected: PASS. Run: `bash ~/.claude/hooks/completion-gate_test.sh`.
- [ ] **Step 3: Commit** — `... -m "test(completion-gate): kill-switch + fail-open"`.

## Task 6: Real-transcript fixture (schema regression)

- [ ] **Step 1: Capture a real slice** (a session with an Edit and a passing Bash whose result omits `is_error`)

```bash
mkdir -p ~/.claude/hooks/fixtures/completion-gate
REAL=$(ls -t ~/.claude/projects/*/*.jsonl | head -1)
# Take assistant tool_use + user tool_result lines only; sanitize text blocks out.
jq -c 'select(.type=="assistant" or .type=="user")
       | if .type=="assistant" then {type, message:{content:[(.message.content//[])[]|select(.type=="tool_use")|{type,id,name,input:{file_path:(.input.file_path//null),command:(.input.command//null)}}]}}
         else {type, message:{content:[(.message.content//[])[]?|select(type=="object" and .type=="tool_result")|{type,tool_use_id,is_error:(.is_error//null)}]}} end' \
  "$REAL" | grep -vE '"content":\[\]' | head -60 > ~/.claude/hooks/fixtures/completion-gate/real-slice.jsonl
echo "fixture lines: $(wc -l < ~/.claude/hooks/fixtures/completion-gate/real-slice.jsonl)"
# Confirm it contains an is_error-absent result:
grep -c '"is_error":null' ~/.claude/hooks/fixtures/completion-gate/real-slice.jsonl
```

- [ ] **Step 2: Write the test**

```bash
echo "test: real captured transcript slice parses without error"
fx="$HOME/.claude/hooks/fixtures/completion-gate/real-slice.jsonl"
out=$(run_gate "$fx"); test $? -le 1 && pass || fail "real-slice parse crashed"
```

(Note: the sanitized fixture stores `is_error:null`; the hook's `.is_error // false` treats null as success — matching real ABSENT semantics. Verify the slice has at least one such row in Step 1.)

- [ ] **Step 3: Run** — Expected: PASS, no jq crash. Run: `bash ~/.claude/hooks/completion-gate_test.sh`.
- [ ] **Step 4: Commit** — `... -m "test(completion-gate): real-transcript schema fixture"`.

## Task 7: Mutation check (prove the tests bite)

- [ ] **Step 1:** Temporarily change the block emission line `jq -nc --arg r "$reason" '{decision:"block", reason:$r}'` to `true` (no output).
- [ ] **Step 2:** Run `bash ~/.claude/hooks/completion-gate_test.sh`. Expected: tests `edit-no-verify`, `failing-verify-blocks`, `cross-turn`, `untracked-new-kept`, `debounce-first` FAIL. If any still pass, that test is theater — fix it.
- [ ] **Step 3:** Revert the mutation; confirm all pass again. Commit nothing (verification only).

## Task 8: Wire into settings; remove the LLM-judge

- [ ] **Step 1:** Add to `~/.claude/settings.json` `Stop` array a new element: `{"type":"command","command":"$HOME/.claude/hooks/completion-gate.sh"}` (use the absolute path). Keep `context-watch.sh`/`done-hook.sh`.

- [ ] **Step 2:** In `<repo>/.claude/settings.json`, delete **only** the `Stop` block whose hook has `"type":"prompt"` (the LLM-judge). Leave the command block. Validate JSON:

Run: `python3 -c "import json;json.load(open('.claude/settings.json'));print('OK')"`
Expected: `OK`

- [ ] **Step 3: Live smoke test** (the real caller path) — in a scratch dir, edit a `.go` file via a headless agent and confirm the gate blocks; then run a test and confirm it stops. (Mirror the probe rig in `/tmp/claude-stop-probe`.) Document the observed block in the PR.

- [ ] **Step 4: Commit** — `... -m "feat(completion-gate): wire Stop hook; remove LLM-judge prompt hook"`.

---

## Self-Review (run before handoff)

1. **Spec coverage:** §6 algorithm (Task 1–2), §7 flow (Task 1,3,4), §8 reason wording (hook), §9 config (hook), §10 debounce+log (Task 4), §11 fail-open (Task 5), §12 tests incl. real fixture (Task 6) + mutation (Task 7), §4 wiring/removal (Task 8). YAML §9 OPEN question is intentionally deferred — note in PR.
2. **Placeholder scan:** none — every step has runnable code/commands.
3. **Consistency:** predicate `!= true` everywhere; mechanism `{"decision":"block"}` everywhere; `COMPLETION_GATE` default `on`.

## Open item to confirm with the user
- **§9 YAML/manifests** still excluded by default. Ship v1 excluded; revisit with `kubeconform`/`yamllint` if desired.
- **Deploy:** RESOLVED — `.claude/hooks/` is tracked in-repo (source of truth, 31 files); `~/.claude/hooks/` is a deployed copy that currently drifts. Author in the worktree; `cp` to `~/.claude/hooks/` only for the live smoke test. No sync script exists (deployment is manual). If the user later adds a deploy target, use it instead of `cp`.
