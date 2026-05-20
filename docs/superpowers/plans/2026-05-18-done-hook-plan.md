# Done-Hook + Session-Goal Protocol — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the done-hook + session-goal protocol per `docs/superpowers/specs/2026-05-18-done-hook-design.md` — two hooks (`session-goal-init.sh`, `done-hook.sh`), two skills (`/goal`, `/done`), JSONL outcomes log, and NAT-backed evidence evaluator.

**Architecture:** Bash hooks for the hot path (`<100ms` Stop budget); pure-bash `/goal` skill for goal capture; Python 3.12 + `nvidia-nat` for `/done` skill (mirrors the validate-recommendation v3 `panel/dispatch.py` pattern: `_invoke_nat` mockable seam + ERROR-fallback). Goal file is per-session append-only Markdown; outcomes log is daily JSONL.

**Tech Stack:**
- Bash 5 + `jq` 1.7+ for hooks (already required by `context-watch.sh`)
- Python 3.12 (`/opt/homebrew/bin/python3.12`) + `nvidia-nat[langchain]>=1.6,<2.0` for `/done` evaluator
- `shellcheck` and `markdownlint-cli2` for static checks (already used in repo)
- pytest via `~/.local/pipx/venvs/pytest/bin/pytest` (matches the recommendation-panel v3 setup)
- Worktree: `.worktrees/done-hook/` on branch `feat/done-hook` (already created off `origin/main`)

**Execution method:** subagent-driven-development (per brief). Each task is self-contained — a fresh subagent should be able to execute it without needing prior turns' context. Per CLAUDE.md the bigger framing fits the "team-execute" criteria (≥2 source files + design decisions), but the brief explicitly chose subagent-driven; the principal-engineer + QA gates apply at PR review time instead of via the team-execute orchestration skill.

**Spec:** `docs/superpowers/specs/2026-05-18-done-hook-design.md` (commit `676ce89`).

**Pre-flight context for every task:**
- Worktree root: `/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/done-hook/`
- All hook/skill source lives at `.claude/...` paths in the repo (canonical). The user's live `~/.claude/` is synced via `scripts/deploy.sh`. **Do not edit `~/.claude/` directly during development** — edit in the worktree and let deploy.sh handle the sync.
- Tests execute against the worktree's `.claude/...` paths via the test harness's own internal path resolution. No deploy needed until Task 22.
- `~/.claude/` writes (when needed for integration testing) require `dangerouslyDisableSandbox: true` per global CLAUDE.md.
- Commits must be DCO sign-off (`-s`) + SSH-signed (existing `commit.gpgsign=true` config handles signing automatically).
- TDD is enforced by `~/.claude/hooks/tdd-guard.sh`. Tests must be written BEFORE implementation; both must commit separately.

---

## File Structure

All paths relative to worktree root (`.worktrees/done-hook/`).

### New files

| File | Responsibility |
|---|---|
| `.claude/hooks/session-goal-init.sh` | SessionStart hook. Nudge user if no goal file for this session. ≤30 LOC. |
| `.claude/hooks/session-goal-init_test.sh` | Integration harness for session-goal-init.sh. ≥3 scenarios. |
| `.claude/hooks/done-hook.sh` | Stop hook. Read goal file, scan recent activity, compute heuristic, debounce, write JSONL entry + stderr evidence block. ≤200 LOC. |
| `.claude/hooks/done-hook_test.sh` | Integration harness for done-hook.sh. ≥6 scenarios. |
| `.claude/skills/goal/SKILL.md` | `/goal` skill definition (frontmatter + flow). |
| `.claude/skills/goal/tests/test_goal_skill.sh` | Integration harness for /goal. ≥4 scenarios. |
| `.claude/skills/done/SKILL.md` | `/done` skill definition. |
| `.claude/skills/done/eval.py` | Python module: `_invoke_nat` seam + `evaluate()` + ERROR-fallback wrapping. |
| `.claude/skills/done/personas/goal-evaluator.md` | NAT panelist system prompt. |
| `.claude/skills/done/tests/test_eval.py` | pytest suite. Mocks `_invoke_nat`. ≥5 cases. |
| `.claude/skills/done/tests/test_skill_integration.sh` | End-to-end: fake session + hook + /done. |
| `docs/superpowers/plans/2026-05-18-done-hook-plan.md` | This plan (already being written). |

### Modified files

| File | Change |
|---|---|
| `.claude/settings.json` | Register `session-goal-init.sh` as a SessionStart hook and `done-hook.sh` as a Stop hook (peer to `context-watch.sh`). |
| `.gitignore` | Add `.claude/audit/session-goals/` and `.claude/audit/session-outcomes-*.log` to ignore generated runtime data. |

### Untouched (deliberately)

- `.claude/hooks/context-watch.sh` — peer Stop hook; coordinates but is not modified.
- `.claude/skills/reflection/` — consumes the new log via existing jq/grep patterns; no changes needed for v1.
- `.claude/skills/validate-recommendation/panel/` — `/done` deliberately duplicates the dispatch pattern rather than coupling; refactor to shared lib is v2.

---

## Task 0: Pre-flight verification

**Goal:** Confirm prerequisites before any code changes.

**Files:** none modified. Diagnostic only.

- [ ] **Step 1: Verify worktree state**

```bash
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/done-hook \
    status --short
```

Expected: clean working tree, branch `feat/done-hook`, no untracked files except possibly `.worktrees/`.

- [ ] **Step 2: Verify required tools**

```bash
which jq && jq --version
which shellcheck && shellcheck --version | head -1
which markdownlint-cli2 && markdownlint-cli2 --version
which /opt/homebrew/bin/python3.12 && /opt/homebrew/bin/python3.12 --version
ls -la ~/.local/pipx/venvs/pytest/bin/pytest 2>&1 || echo "pytest venv missing"
```

Expected: all present. If `pytest` venv missing, install per recommendation-panel v3 conventions (`pipx install pytest`).

- [ ] **Step 3: Verify NAT importability for `/done`**

```bash
/opt/homebrew/bin/python3.12 -c "import nat; print('nat:', getattr(nat, '__version__', '(no version attr)'))" 2>&1
```

Expected one of:
- `nat: 1.6.x` — proceed normally.
- `ModuleNotFoundError: No module named 'nat'` — install:

```bash
/opt/homebrew/bin/python3.12 -m pip install --user --break-system-packages 'nvidia-nat[langchain]>=1.6,<2.0'
/opt/homebrew/bin/python3.12 -c "import nat; print(nat.__version__)"
```

- [ ] **Step 4: Confirm existing `context-watch.sh` is healthy (peer hook)**

```bash
shellcheck .worktrees/done-hook/.claude/hooks/context-watch.sh
echo '{"transcript_path":"/tmp/nonexistent.jsonl"}' | bash .worktrees/done-hook/.claude/hooks/context-watch.sh
echo "exit=$?"
```

Expected: shellcheck clean, exit 0 silently. Confirms the peer hook works as documented (we'll fire alongside it).

- [ ] **Step 5: Verify audit directory layout**

```bash
ls -la ~/.claude/audit/ | head -8
mkdir -p ~/.claude/audit/session-goals/
ls ~/.claude/audit/session-goals/
```

Expected: `session-goals/` directory exists (empty is fine).

**Commit:** none for Task 0 — diagnostic only.

---

## Task 1: SessionStart hook — RED scenarios

**Goal:** Write the failing integration tests for `session-goal-init.sh` (scenarios 1-3 from the spec §Testing).

**Files:** Create `.claude/hooks/session-goal-init_test.sh`.

- [ ] **Step 1: Write the failing test harness**

Create `.worktrees/done-hook/.claude/hooks/session-goal-init_test.sh`:

```bash
#!/bin/bash
# session-goal-init_test.sh — integration harness for session-goal-init.sh
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/session-goal-init.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

run_case() {
  local name="$1" input="$2" expected_exit="$3" expected_stderr_pattern="$4"
  shift 4
  local got_stderr
  got_stderr=$(echo "$input" | env "$@" bash "$HOOK" 2>&1 >/dev/null)
  local got_exit=$?
  if [ "$got_exit" -ne "$expected_exit" ]; then
    echo "FAIL: $name — expected exit $expected_exit, got $got_exit"
    FAIL=$((FAIL + 1)); return
  fi
  if [ -n "$expected_stderr_pattern" ] && ! echo "$got_stderr" | grep -q "$expected_stderr_pattern"; then
    echo "FAIL: $name — stderr did not match /$expected_stderr_pattern/"
    echo "  got: $got_stderr"
    FAIL=$((FAIL + 1)); return
  fi
  if [ -z "$expected_stderr_pattern" ] && [ -n "$got_stderr" ]; then
    echo "FAIL: $name — expected silent stderr, got: $got_stderr"
    FAIL=$((FAIL + 1)); return
  fi
  echo "PASS: $name"
  PASS=$((PASS + 1))
}

# Scenario 1: no goal file → prints nudge to stderr
FAKE_TRANSCRIPT="$TMP/abc12345-deadbeef.jsonl"
touch "$FAKE_TRANSCRIPT"
run_case "no goal file -> nudge" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "No session goal set" \
  HOME="$TMP"

# Scenario 2: goal file present → silent
mkdir -p "$TMP/.claude/audit/session-goals"
echo "## Initial 2026-05-18T00:00:00Z" > "$TMP/.claude/audit/session-goals/abc12345-deadbeef.md"
run_case "goal file present -> silent" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "" \
  HOME="$TMP"

# Scenario 3: session-goals/ dir missing → graceful (still exit 0, prints nudge since no file)
rm -rf "$TMP/.claude/audit/session-goals"
run_case "session-goals dir missing -> graceful nudge" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "No session goal set" \
  HOME="$TMP"

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Make the test harness executable**

```bash
chmod +x .worktrees/done-hook/.claude/hooks/session-goal-init_test.sh
```

- [ ] **Step 3: Run to verify it fails (RED)**

```bash
bash .worktrees/done-hook/.claude/hooks/session-goal-init_test.sh
echo "exit=$?"
```

Expected: all 3 cases FAIL with messages like "FAIL: no goal file -> nudge — expected exit 0, got 127" (script doesn't exist yet) or similar. Test harness exits non-zero.

- [ ] **Step 4: Commit the failing test**

```bash
git -C .worktrees/done-hook add .claude/hooks/session-goal-init_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add session-goal-init_test.sh harness (RED)

Three scenarios covering goal-absent nudge, goal-present silence, and
session-goals dir absent graceful path. Implementation in next commit."
```

---

## Task 2: SessionStart hook — GREEN implementation

**Goal:** Implement `session-goal-init.sh` so the tests pass.

**Files:** Create `.claude/hooks/session-goal-init.sh`.

- [ ] **Step 1: Write the hook**

Create `.worktrees/done-hook/.claude/hooks/session-goal-init.sh`:

```bash
#!/bin/bash
# session-goal-init.sh — Nudge user to capture a session goal when none exists.
# Hook: SessionStart
# Exit 0 always — never blocks.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 2
set -o pipefail

INPUT=$(cat)

# Extract transcript_path from hook input
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0

UUID=$(basename "$TRANSCRIPT" .jsonl)
GOAL_FILE="${HOME}/.claude/audit/session-goals/${UUID}.md"

if [ ! -f "$GOAL_FILE" ]; then
  echo "" >&2
  echo "[session-goal] No session goal set for ${UUID:0:8}." >&2
  echo "[session-goal] Run /goal to capture one (optional in v1)." >&2
fi

exit 0
```

- [ ] **Step 2: Make executable + shellcheck**

```bash
chmod +x .worktrees/done-hook/.claude/hooks/session-goal-init.sh
shellcheck .worktrees/done-hook/.claude/hooks/session-goal-init.sh
echo "shellcheck exit=$?"
```

Expected: shellcheck exits 0 with no warnings.

- [ ] **Step 3: Run the test harness to verify GREEN**

```bash
bash .worktrees/done-hook/.claude/hooks/session-goal-init_test.sh
echo "harness exit=$?"
```

Expected: `==== Results: 3 passed, 0 failed ====`, harness exits 0.

- [ ] **Step 4: Performance check (<50ms)**

```bash
echo '{"transcript_path":"/tmp/perf-test.jsonl"}' > /tmp/sg-input.json
time bash .worktrees/done-hook/.claude/hooks/session-goal-init.sh < /tmp/sg-input.json 2>/dev/null
```

Expected: `real` time <50ms (typically 5-15ms).

- [ ] **Step 5: Commit**

```bash
git -C .worktrees/done-hook add .claude/hooks/session-goal-init.sh
git -C .worktrees/done-hook commit -s -m "feat(hooks): add SessionStart nudge for missing goal file

Prints a two-line stderr nudge when no session-goal file exists for the
current session UUID. Silent when present. Always exits 0; never blocks.

Tests: 3/3 PASS via session-goal-init_test.sh.
shellcheck: clean.
Perf: <50ms typical.

Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 2"
```

---

## Task 3: Stop hook — RED for NO_GOAL path + scaffold

**Goal:** Establish `done-hook.sh` skeleton + test harness with the goal-absent case driving the first RED.

**Files:** Create `.claude/hooks/done-hook_test.sh`.

- [ ] **Step 1: Write the failing test harness with scenario 1 (NO_GOAL)**

Create `.worktrees/done-hook/.claude/hooks/done-hook_test.sh`:

```bash
#!/bin/bash
# done-hook_test.sh — integration harness for done-hook.sh
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/done-hook.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

setup_fake_home() {
  local home="$1" uuid="$2"
  mkdir -p "$home/.claude/audit/session-goals"
}

fake_transcript_path() {
  local home="$1" uuid="$2"
  echo "$home/projects/fake/$uuid.jsonl"
}

assert_outcomes_entry() {
  local home="$1" uuid="$2" want_field="$3" want_value="$4"
  local log
  log=$(ls "$home/.claude/audit/session-outcomes-"*.log 2>/dev/null | tail -1)
  if [ -z "$log" ]; then
    echo "    (no outcomes log written)"
    return 1
  fi
  grep "\"session\":\"$uuid\"" "$log" | tail -1 | \
    grep -qE "\"$want_field\":\"?$want_value\"?" || {
      echo "    (expected $want_field=$want_value in last entry; got:)"
      grep "\"session\":\"$uuid\"" "$log" | tail -1
      return 1
    }
}

# Scenario 1: no goal file → single NO_GOAL outcomes entry, silent stderr
UUID1="11111111-aaaa-bbbb-cccc-000000000001"
HOME1="$TMP/home1"
setup_fake_home "$HOME1" "$UUID1"
TRANSCRIPT1=$(fake_transcript_path "$HOME1" "$UUID1")
mkdir -p "$(dirname "$TRANSCRIPT1")"; touch "$TRANSCRIPT1"

# First fire: writes NO_GOAL
STDERR=$(echo "{\"transcript_path\":\"$TRANSCRIPT1\"}" | HOME="$HOME1" bash "$HOOK" 2>&1 >/dev/null)
if [ -n "$STDERR" ]; then
  echo "FAIL: scenario 1 first fire — expected silent stderr, got: $STDERR"; FAIL=$((FAIL+1))
elif ! assert_outcomes_entry "$HOME1" "$UUID1" "verdict" "NO_GOAL"; then
  echo "FAIL: scenario 1 first fire — outcomes entry missing NO_GOAL"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 1a — NO_GOAL entry written on first fire"; PASS=$((PASS+1))
fi

# Second fire: NO new entry (debounce on existing NO_GOAL)
ENTRIES_BEFORE=$(grep -c "\"session\":\"$UUID1\"" "$HOME1/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)
echo "{\"transcript_path\":\"$TRANSCRIPT1\"}" | HOME="$HOME1" bash "$HOOK" 2>/dev/null
ENTRIES_AFTER=$(grep -c "\"session\":\"$UUID1\"" "$HOME1/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)
if [ "$ENTRIES_BEFORE" -ne "$ENTRIES_AFTER" ]; then
  echo "FAIL: scenario 1b — debounce broken; got $ENTRIES_AFTER entries (expected $ENTRIES_BEFORE)"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 1b — debounce keeps NO_GOAL to one entry"; PASS=$((PASS+1))
fi

# More scenarios added in later tasks (2 - 6)

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Make harness executable + run to RED**

```bash
chmod +x .worktrees/done-hook/.claude/hooks/done-hook_test.sh
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "exit=$?"
```

Expected: harness FAILS because `done-hook.sh` does not exist (or both scenarios fail).

- [ ] **Step 3: Commit the failing test**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add done-hook_test.sh harness with NO_GOAL scenario (RED)

Scaffolds the integration harness; scenario 1 (NO_GOAL path) drives the
first RED. Additional scenarios appended task-by-task in later commits."
```

---

## Task 4: Stop hook — GREEN for NO_GOAL path

**Goal:** Implement `done-hook.sh` skeleton + NO_GOAL handling so scenario 1 passes.

**Files:** Create `.claude/hooks/done-hook.sh`.

- [ ] **Step 1: Write the minimal hook (NO_GOAL only)**

Create `.worktrees/done-hook/.claude/hooks/done-hook.sh`:

```bash
#!/bin/bash
# done-hook.sh — Surface evidence against the captured session goal.
# Hook: Stop  (peer with context-watch.sh)
# Exit 0 always — coordinates with context-watch.sh, never blocks.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 3
set -o pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0

UUID=$(basename "$TRANSCRIPT" .jsonl)
GOAL_FILE="${HOME}/.claude/audit/session-goals/${UUID}.md"
OUTCOMES_LOG="${HOME}/.claude/audit/session-outcomes-$(date -u +%Y-%m-%d).log"
mkdir -p "$(dirname "$OUTCOMES_LOG")"

# NO_GOAL path: emit ONCE per session, then silent.
if [ ! -f "$GOAL_FILE" ]; then
  if [ -f "$OUTCOMES_LOG" ] && grep -q "\"session\":\"${UUID}\".*\"verdict\":\"NO_GOAL\"" "$OUTCOMES_LOG"; then
    exit 0  # already emitted; debounce
  fi
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"schema":1,"session":"%s","seq":1,"ts":"%s","goal_file":null,"heuristic":{"verdict":"NO_GOAL","matched":0,"total":0},"evidence":[],"state_hash":"","user":null}\n' \
    "$UUID" "$TS" >> "$OUTCOMES_LOG"
  exit 0
fi

# GOAL_PRESENT path: implemented in Task 5+ — for now, exit 0.
exit 0
```

- [ ] **Step 2: Make executable + shellcheck**

```bash
chmod +x .worktrees/done-hook/.claude/hooks/done-hook.sh
shellcheck .worktrees/done-hook/.claude/hooks/done-hook.sh
echo "shellcheck exit=$?"
```

Expected: shellcheck clean.

- [ ] **Step 3: Run the harness to verify scenarios 1a + 1b PASS**

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "harness exit=$?"
```

Expected: `2 passed, 0 failed`, exit 0.

- [ ] **Step 4: Commit**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook.sh
git -C .worktrees/done-hook commit -s -m "feat(hooks): add done-hook.sh skeleton with NO_GOAL path

First implementation iteration. Reads transcript_path, derives session
UUID, writes a single NO_GOAL outcomes entry per session (debounced via
grep on the existing log). GOAL_PRESENT path stubbed for next tasks.

Tests: 2/2 PASS (scenarios 1a + 1b).
shellcheck: clean."
```

---

## Task 5: Stop hook — goal-file parsing (RED)

**Goal:** Add scenario 2 to the harness — goal file present with 3 bullets, all matched → `LIKELY_MET`. Drives implementation of goal-file parsing.

**Files:** Modify `.claude/hooks/done-hook_test.sh`.

- [ ] **Step 1: Append scenario 2 to the harness**

Edit `.worktrees/done-hook/.claude/hooks/done-hook_test.sh`. Find the line `# More scenarios added in later tasks (2 - 6)` and replace it with:

```bash
# Scenario 2: goal file present, 3/3 acceptance bullets match recent bash log → LIKELY_MET
UUID2="22222222-aaaa-bbbb-cccc-000000000002"
HOME2="$TMP/home2"
setup_fake_home "$HOME2" "$UUID2"
TRANSCRIPT2=$(fake_transcript_path "$HOME2" "$UUID2")
mkdir -p "$(dirname "$TRANSCRIPT2")"; touch "$TRANSCRIPT2"

# Synthesize a goal file with 3 bullets
cat > "$HOME2/.claude/audit/session-goals/$UUID2.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
GOAL

# Synthesize a bash audit log with 3 matching commands
BASH_LOG="$HOME2/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
mkdir -p "$(dirname "$BASH_LOG")"
cat > "$BASH_LOG" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
2026-05-18T14:31:00Z	shellcheck ~/.claude/hooks/done-hook.sh	exit=0
2026-05-18T14:32:00Z	git commit -s -m "docs(specs): add design"	exit=0
LOG

# Fire the hook
echo "{\"transcript_path\":\"$TRANSCRIPT2\"}" | HOME="$HOME2" bash "$HOOK" 2>/dev/null

# Assert outcomes entry has LIKELY_MET + matched=3 + total=3
if ! assert_outcomes_entry "$HOME2" "$UUID2" "verdict" "LIKELY_MET"; then
  echo "FAIL: scenario 2 — heuristic.verdict != LIKELY_MET"; FAIL=$((FAIL+1))
elif ! grep -q "\"matched\":3" "$HOME2/.claude/audit/session-outcomes-"*.log; then
  echo "FAIL: scenario 2 — matched != 3"; FAIL=$((FAIL+1))
elif ! grep -q "\"total\":3" "$HOME2/.claude/audit/session-outcomes-"*.log; then
  echo "FAIL: scenario 2 — total != 3"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 2 — 3/3 matched -> LIKELY_MET"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run to verify RED**

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "exit=$?"
```

Expected: scenario 2 FAILS (goal-present path is currently a stub).

- [ ] **Step 3: Commit the new RED**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add done-hook scenario 2 (LIKELY_MET, RED)

Goal file with 3 acceptance bullets + bash log with 3 matching commands
should yield heuristic.verdict=LIKELY_MET, matched=3, total=3."
```

---

## Task 6: Stop hook — implement goal-file parsing + heuristic (GREEN)

**Goal:** Implement last-stanza extraction, bullet enumeration, anchor matching, heuristic computation, JSONL writing for the goal-present path.

**Files:** Modify `.claude/hooks/done-hook.sh`.

- [ ] **Step 1: Add helper functions and goal-present logic**

Replace the `# GOAL_PRESENT path: implemented in Task 5+ — for now, exit 0.` block in `.worktrees/done-hook/.claude/hooks/done-hook.sh` with the following. Place helper functions ABOVE the main logic (after `set -o pipefail` line; keep all NO_GOAL logic intact):

```bash
# --- Helpers ---

# Extract the LAST stanza (## ...) body from the goal file.
extract_last_stanza() {
  local file="$1"
  awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$file"
}

# Extract the Goal: line (one-line summary).
extract_goal_name() {
  local stanza="$1"
  local raw
  raw=$(echo "$stanza" | grep -m1 '^Goal: ' | sed 's/^Goal: //; s/[[:space:]]*$//')
  [ -z "$raw" ] && raw="<unnamed>"
  if [ "${#raw}" -gt 60 ]; then
    raw="${raw:0:60}…"
  fi
  echo "$raw"
}

# Extract acceptance bullets (lines starting with "- " under "Acceptance:").
extract_bullets() {
  local stanza="$1"
  echo "$stanza" | awk '
    /^Acceptance:/ { in_acc=1; next }
    /^## / { in_acc=0 }
    in_acc && /^- / { sub(/^- /, ""); print }
  '
}

# Given a bullet, return matched evidence records (or empty).
# Looks for any token in the bullet that appears in the recent bash audit log.
match_bullet_evidence() {
  local bullet="$1" bash_log="$2"
  [ ! -f "$bash_log" ] && return 1
  # Anchors: paths, test-script names, command-like tokens.
  local anchors
  anchors=$(echo "$bullet" | grep -oE '(\.?\.?/[a-zA-Z0-9_/.-]+|[a-z][a-z0-9_-]{2,}_test\.sh|[a-z][a-z0-9_-]{2,}\.sh|docs/[a-zA-Z0-9_/.-]+|[a-z][a-z0-9_-]{2,})' | sort -u)
  local last_chunk
  last_chunk=$(tail -c 200000 "$bash_log" 2>/dev/null)
  while read -r anchor; do
    [ -z "$anchor" ] && continue
    # Skip noise words shorter than 3 chars (already filtered by regex but defensive)
    [ "${#anchor}" -lt 3 ] && continue
    if echo "$last_chunk" | grep -qF "$anchor"; then
      # Capture the matching line for evidence
      local line
      line=$(echo "$last_chunk" | grep -F "$anchor" | tail -1)
      printf '%s' "$line"
      return 0
    fi
  done <<< "$anchors"
  return 1
}

# JSON-escape a string (minimal: backslash, quote, control chars).
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"))[1:-1])' <<< "$1"
}

# --- Main GOAL_PRESENT path ---
# (replaces the previous `exit 0` stub)

STANZA=$(extract_last_stanza "$GOAL_FILE")
GOAL_NAME=$(extract_goal_name "$STANZA")
BULLETS=$(extract_bullets "$STANZA")
TOTAL=$(echo "$BULLETS" | sed '/^$/d' | wc -l | tr -d ' ')

BASH_LOG="${HOME}/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
MATCHED=0
EVIDENCE_RECORDS="["
FIRST_REC=1

while IFS= read -r bullet; do
  [ -z "$bullet" ] && continue
  evidence=$(match_bullet_evidence "$bullet" "$BASH_LOG")
  if [ -n "$evidence" ]; then
    MATCHED=$((MATCHED + 1))
    bullet_esc=$(json_escape "$bullet")
    evidence_esc=$(json_escape "$evidence")
    if [ "$FIRST_REC" -eq 1 ]; then
      FIRST_REC=0
    else
      EVIDENCE_RECORDS+=","
    fi
    EVIDENCE_RECORDS+="{\"bullet\":\"${bullet_esc}\",\"raw\":\"${evidence_esc}\"}"
  fi
done <<< "$BULLETS"
EVIDENCE_RECORDS+="]"

if [ "$TOTAL" -gt 0 ] && [ "$MATCHED" -ge "$((TOTAL - 1))" ]; then
  HEURISTIC="LIKELY_MET"
elif [ "$MATCHED" -gt 0 ]; then
  HEURISTIC="PARTIAL"
else
  HEURISTIC="NO_EVIDENCE"
fi

# Compute next seq for this session
SEQ=1
if [ -f "$OUTCOMES_LOG" ]; then
  PREV_SEQ=$(grep "\"session\":\"$UUID\"" "$OUTCOMES_LOG" 2>/dev/null | \
             grep -oE '"seq":[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
  [ -n "$PREV_SEQ" ] && SEQ=$((PREV_SEQ + 1))
fi

# State-change-hash debounce (Task 7 will refine this; v1 = always emit)
STATE_HASH="$(date -u +%s%N | shasum | cut -c1-12)"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GOAL_REL_PATH="session-goals/${UUID}.md"
printf '{"schema":1,"session":"%s","seq":%d,"ts":"%s","goal_file":"%s","heuristic":{"verdict":"%s","matched":%d,"total":%d},"evidence":%s,"state_hash":"%s","user":null}\n' \
  "$UUID" "$SEQ" "$TS" "$GOAL_REL_PATH" "$HEURISTIC" "$MATCHED" "$TOTAL" "$EVIDENCE_RECORDS" "$STATE_HASH" \
  >> "$OUTCOMES_LOG"

exit 0
```

- [ ] **Step 2: Shellcheck**

```bash
shellcheck .worktrees/done-hook/.claude/hooks/done-hook.sh
echo "shellcheck exit=$?"
```

Expected: clean. If it warns about the embedded `python3` for json_escape, that's acceptable (Python is available; bash's printf isn't safe for arbitrary strings).

- [ ] **Step 3: Run harness — scenarios 1+2 should PASS**

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "exit=$?"
```

Expected: `3 passed, 0 failed` (scenarios 1a, 1b, 2 all green).

- [ ] **Step 4: Commit**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook.sh
git -C .worktrees/done-hook commit -s -m "feat(hooks): parse goal stanza + compute heuristic verdict

Implements last-stanza extraction, acceptance-bullet enumeration, anchor
extraction (paths/commands/test-script names), bash audit log matching,
and heuristic verdict computation (LIKELY_MET / PARTIAL / NO_EVIDENCE).
Writes a JSONL outcomes entry per fire (debounce deferred to Task 7).

Tests: 3/3 PASS (scenarios 1a + 1b + 2).
shellcheck: clean."
```

---

## Task 7: Stop hook — PARTIAL + NO_EVIDENCE scenarios (RED+GREEN)

**Goal:** Add scenarios 3 (1/3 matched = PARTIAL) and 4 (0/3 matched = NO_EVIDENCE) to the harness.

**Files:** Modify `.claude/hooks/done-hook_test.sh`.

- [ ] **Step 1: Append scenarios 3+4 to the harness**

Append these two scenarios to `.worktrees/done-hook/.claude/hooks/done-hook_test.sh`, after scenario 2's PASS line, before the final `echo "==== Results: ..."` block:

```bash
# Scenario 3: 1/3 bullets match → PARTIAL
UUID3="33333333-aaaa-bbbb-cccc-000000000003"
HOME3="$TMP/home3"
setup_fake_home "$HOME3" "$UUID3"
TRANSCRIPT3=$(fake_transcript_path "$HOME3" "$UUID3")
mkdir -p "$(dirname "$TRANSCRIPT3")"; touch "$TRANSCRIPT3"
cat > "$HOME3/.claude/audit/session-goals/$UUID3.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
GOAL
mkdir -p "$HOME3/.claude/audit"
cat > "$HOME3/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
LOG
echo "{\"transcript_path\":\"$TRANSCRIPT3\"}" | HOME="$HOME3" bash "$HOOK" 2>/dev/null
if ! assert_outcomes_entry "$HOME3" "$UUID3" "verdict" "PARTIAL"; then
  echo "FAIL: scenario 3 — verdict != PARTIAL"; FAIL=$((FAIL+1))
elif ! grep -q "\"matched\":1" "$HOME3/.claude/audit/session-outcomes-"*.log; then
  echo "FAIL: scenario 3 — matched != 1"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 3 — 1/3 matched -> PARTIAL"; PASS=$((PASS+1))
fi

# Scenario 4: 0/3 bullets match → NO_EVIDENCE
UUID4="44444444-aaaa-bbbb-cccc-000000000004"
HOME4="$TMP/home4"
setup_fake_home "$HOME4" "$UUID4"
TRANSCRIPT4=$(fake_transcript_path "$HOME4" "$UUID4")
mkdir -p "$(dirname "$TRANSCRIPT4")"; touch "$TRANSCRIPT4"
cat > "$HOME4/.claude/audit/session-goals/$UUID4.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
GOAL
mkdir -p "$HOME4/.claude/audit"
# Empty bash log
: > "$HOME4/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
echo "{\"transcript_path\":\"$TRANSCRIPT4\"}" | HOME="$HOME4" bash "$HOOK" 2>/dev/null
if ! assert_outcomes_entry "$HOME4" "$UUID4" "verdict" "NO_EVIDENCE"; then
  echo "FAIL: scenario 4 — verdict != NO_EVIDENCE"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 4 — 0/3 matched -> NO_EVIDENCE"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run harness — expect both new scenarios to PASS immediately** (Task 6 already implemented the heuristic logic)

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "exit=$?"
```

Expected: `5 passed, 0 failed`. If scenario 3 fails because PARTIAL threshold is off, fix the inequality in `done-hook.sh` and re-run (the spec says "matched ≥ total-1 → LIKELY_MET; matched ≥ 1 → PARTIAL"; with matched=1, total=3, total-1=2; 1 ≥ 2 is false; matched ≥ 1 is true → PARTIAL ✓).

- [ ] **Step 3: Commit (test + any fix together since they're inseparable)**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add PARTIAL + NO_EVIDENCE scenarios

Scenarios 3 and 4 exercise the heuristic threshold boundaries:
- 1/3 matched → PARTIAL
- 0/3 matched → NO_EVIDENCE

Both PASS immediately on existing Task 6 implementation; no hook
changes required (validates the threshold logic)."
```

---

## Task 8: Stop hook — state-change debounce (RED+GREEN)

**Goal:** Add scenario 5 (debounce on unchanged state); refine `STATE_HASH` to be deterministic.

**Files:** Modify `done-hook_test.sh` (add scenario 5) and `done-hook.sh` (replace timestamp-based hash with content-based hash).

- [ ] **Step 1: Append scenario 5 to the harness**

```bash
# Scenario 5: state-change debounce
# Fire twice with same goal + same bash log → only one new entry (besides any NO_GOAL/etc)
UUID5="55555555-aaaa-bbbb-cccc-000000000005"
HOME5="$TMP/home5"
setup_fake_home "$HOME5" "$UUID5"
TRANSCRIPT5=$(fake_transcript_path "$HOME5" "$UUID5")
mkdir -p "$(dirname "$TRANSCRIPT5")"; touch "$TRANSCRIPT5"
cat > "$HOME5/.claude/audit/session-goals/$UUID5.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
GOAL
mkdir -p "$HOME5/.claude/audit"
cat > "$HOME5/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
LOG

# First fire
echo "{\"transcript_path\":\"$TRANSCRIPT5\"}" | HOME="$HOME5" bash "$HOOK" 2>/dev/null
COUNT1=$(grep -c "\"session\":\"$UUID5\"" "$HOME5/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)

# Second fire with identical state
echo "{\"transcript_path\":\"$TRANSCRIPT5\"}" | HOME="$HOME5" bash "$HOOK" 2>/dev/null
COUNT2=$(grep -c "\"session\":\"$UUID5\"" "$HOME5/.claude/audit/session-outcomes-"*.log 2>/dev/null || echo 0)

if [ "$COUNT1" -ne "$COUNT2" ]; then
  echo "FAIL: scenario 5 — debounce broken; entries grew $COUNT1 -> $COUNT2"; FAIL=$((FAIL+1))
elif [ "$COUNT1" -eq 0 ]; then
  echo "FAIL: scenario 5 — no entries written at all"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 5 — debounce holds entries at $COUNT1"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run to confirm RED on scenario 5**

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
```

Expected: scenarios 1-4 PASS, scenario 5 FAILS (current `STATE_HASH` uses timestamp → always different).

- [ ] **Step 3: Commit the RED**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add state-change debounce scenario (RED)

Scenario 5 fires the hook twice with identical state; only one outcomes
entry should result. Currently FAILS because STATE_HASH is timestamp-
based; Task 8b switches to content hash."
```

- [ ] **Step 4: Replace `STATE_HASH` computation in done-hook.sh**

In `.worktrees/done-hook/.claude/hooks/done-hook.sh`, find:

```bash
# State-change-hash debounce (Task 7 will refine this; v1 = always emit)
STATE_HASH="$(date -u +%s%N | shasum | cut -c1-12)"
```

Replace with:

```bash
# State-change-hash debounce: hash of (goal-mtime, sorted evidence raws).
GOAL_MTIME=$(stat -f %m "$GOAL_FILE" 2>/dev/null || stat -c %Y "$GOAL_FILE" 2>/dev/null || echo 0)
STATE_HASH=$(printf '%s|%s' "$GOAL_MTIME" "$EVIDENCE_RECORDS" | shasum | cut -c1-12)

# Compare to last entry's state_hash for this session
LAST_HASH=""
if [ -f "$OUTCOMES_LOG" ]; then
  LAST_HASH=$(grep "\"session\":\"$UUID\"" "$OUTCOMES_LOG" | tail -1 | \
              grep -oE '"state_hash":"[^"]*"' | sed 's/"state_hash":"\(.*\)"/\1/')
fi
if [ -n "$LAST_HASH" ] && [ "$STATE_HASH" = "$LAST_HASH" ]; then
  exit 0  # no state change since last entry
fi
```

- [ ] **Step 5: Run harness — all 5 scenarios PASS**

```bash
shellcheck .worktrees/done-hook/.claude/hooks/done-hook.sh
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "exit=$?"
```

Expected: shellcheck clean, `5 passed, 0 failed`.

- [ ] **Step 6: Commit the GREEN**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook.sh
git -C .worktrees/done-hook commit -s -m "feat(hooks): content-based state-change debounce

STATE_HASH is now sha1(goal_mtime + evidence_records) instead of a fresh
per-fire timestamp hash. Hook compares to the last entry's state_hash
for the same session; identical hash = no new entry. Eliminates Stop-
event spam in the outcomes log on quiet turns.

Tests: 5/5 PASS.
shellcheck: clean."
```

---

## Task 9: Stop hook — stderr evidence-block formatting (RED+GREEN)

**Goal:** Add stderr output per spec §Component 3 (Stderr output shape). Verify it surfaces evidence but never claims "accomplished."

**Files:** Modify `done-hook_test.sh` (add scenario 6) and `done-hook.sh` (emit stderr block when state changed).

- [ ] **Step 1: Append scenario 6**

```bash
# Scenario 6: stderr evidence block on a state change
UUID6="66666666-aaaa-bbbb-cccc-000000000006"
HOME6="$TMP/home6"
setup_fake_home "$HOME6" "$UUID6"
TRANSCRIPT6=$(fake_transcript_path "$HOME6" "$UUID6")
mkdir -p "$(dirname "$TRANSCRIPT6")"; touch "$TRANSCRIPT6"
cat > "$HOME6/.claude/audit/session-goals/$UUID6.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
GOAL
mkdir -p "$HOME6/.claude/audit"
cat > "$HOME6/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
LOG
STDERR6=$(echo "{\"transcript_path\":\"$TRANSCRIPT6\"}" | HOME="$HOME6" bash "$HOOK" 2>&1 >/dev/null)

# Must surface evidence; must NOT claim "accomplished"
if ! echo "$STDERR6" | grep -q "Heuristic: LIKELY_MET"; then
  echo "FAIL: scenario 6 — missing 'Heuristic: LIKELY_MET' in stderr"; FAIL=$((FAIL+1))
elif echo "$STDERR6" | grep -qi "session goal accomplished"; then
  echo "FAIL: scenario 6 — hook claimed 'Session goal accomplished' (theater)"; FAIL=$((FAIL+1))
elif ! echo "$STDERR6" | grep -q "${UUID6:0:8}"; then
  echo "FAIL: scenario 6 — UUID prefix missing from header"; FAIL=$((FAIL+1))
elif ! echo "$STDERR6" | grep -q "ship done-hook v1"; then
  echo "FAIL: scenario 6 — goal name missing from header"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 6 — evidence block surfaced; no completion claim"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run to confirm RED on scenario 6**

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
```

Expected: scenarios 1-5 PASS, scenario 6 FAIL (no stderr emitted yet).

- [ ] **Step 3: Commit the RED**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add stderr evidence-block scenario (RED)

Scenario 6 verifies the hook surfaces a 'Heuristic:' line + matched
counts + UUID prefix + goal name, and NEVER emits 'Session goal
accomplished' (the theater string belongs to /done only)."
```

- [ ] **Step 4: Add stderr block in done-hook.sh**

In `.worktrees/done-hook/.claude/hooks/done-hook.sh`, after the JSONL printf that appends to `$OUTCOMES_LOG`, before `exit 0`, add:

```bash
# Stderr evidence block (informational; never claims completion).
echo "" >&2
echo "[done-hook] Session ${UUID:0:8} vs goal '${GOAL_NAME}':" >&2
echo "  Acceptance bullets: ${MATCHED}/${TOTAL} matched" >&2
while IFS= read -r bullet; do
  [ -z "$bullet" ] && continue
  ev=$(match_bullet_evidence "$bullet" "$BASH_LOG")
  if [ -n "$ev" ]; then
    short_ev=$(echo "$ev" | head -c 80)
    echo "    [✓] ${bullet:0:50}: ${short_ev}" >&2
  else
    echo "    [ ] ${bullet:0:50}: no matching evidence" >&2
  fi
done <<< "$BULLETS"
echo "  Heuristic: ${HEURISTIC} (${MATCHED}/${TOTAL}). Run /done to confirm or amend." >&2
```

- [ ] **Step 5: Verify**

```bash
shellcheck .worktrees/done-hook/.claude/hooks/done-hook.sh
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
echo "exit=$?"
```

Expected: shellcheck clean, 6/6 PASS.

- [ ] **Step 6: Commit**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook.sh
git -C .worktrees/done-hook commit -s -m "feat(hooks): add stderr evidence block

Surfaces per-bullet evidence and heuristic verdict on state change.
Never claims 'Session goal accomplished' (that string is reserved for
/done after user.verdict=MET).

Tests: 6/6 PASS."
```

---

## Task 10: Stop hook — performance gate (RED+GREEN)

**Goal:** Assert <300ms on a 1.5 MB synthetic bash log. Currently uncertain whether the bash loop scales; this task verifies it.

**Files:** Append scenario 7 to `done-hook_test.sh`.

- [ ] **Step 1: Append scenario 7**

```bash
# Scenario 7: performance gate — <300ms on a 1.5 MB synthetic bash log
UUID7="77777777-aaaa-bbbb-cccc-000000000007"
HOME7="$TMP/home7"
setup_fake_home "$HOME7" "$UUID7"
TRANSCRIPT7=$(fake_transcript_path "$HOME7" "$UUID7")
mkdir -p "$(dirname "$TRANSCRIPT7")"; touch "$TRANSCRIPT7"
cat > "$HOME7/.claude/audit/session-goals/$UUID7.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
- plan committed to docs/superpowers/plans/
GOAL
mkdir -p "$HOME7/.claude/audit"

# Generate 1.5 MB of synthetic bash log entries
{
  for i in $(seq 1 30000); do
    printf '2026-05-18T14:30:%02d.%03dZ\tsome_command_%d arg1 arg2\texit=0\n' $((i % 60)) $((i % 1000)) "$i"
  done
} > "$HOME7/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
LOG_SIZE=$(wc -c < "$HOME7/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log")
echo "  (perf scenario: log size = $LOG_SIZE bytes)"

START=$(date +%s%N)
echo "{\"transcript_path\":\"$TRANSCRIPT7\"}" | HOME="$HOME7" bash "$HOOK" 2>/dev/null
END=$(date +%s%N)
ELAPSED_MS=$(( (END - START) / 1000000 ))
echo "  (perf scenario: elapsed = ${ELAPSED_MS} ms)"

if [ "$ELAPSED_MS" -ge 300 ]; then
  echo "FAIL: scenario 7 — perf budget exceeded: ${ELAPSED_MS}ms (limit 300ms)"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 7 — perf ${ELAPSED_MS}ms < 300ms"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run**

```bash
bash .worktrees/done-hook/.claude/hooks/done-hook_test.sh
```

Two possible outcomes:
- **PASSES on first try** — proceed to commit (7/7 PASS).
- **FAILS perf budget** — hook needs optimization. Likely candidates:
  - `tail -c 200000` already caps input; verify it's being used (it is).
  - Replace inner `grep -F "$anchor"` with `grep -F -f anchors-file last-chunk` to avoid per-anchor process spawn.
  - Cache `last_chunk` once outside the bullet loop instead of recomputing.
  Apply the smallest optimization that brings perf under budget. Commit the fix separately (`perf(hooks): cache tail output across bullets`).

- [ ] **Step 3: Commit the perf gate**

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook_test.sh
git -C .worktrees/done-hook commit -s -m "test(hooks): add <300ms perf gate on 1.5MB synthetic log

Scenario 7 generates 30,000 fake bash log lines (~1.5MB) and times the
hook end-to-end. Asserts elapsed < 300ms per spec §15."
```

If a perf fix was needed, also commit:

```bash
git -C .worktrees/done-hook add .claude/hooks/done-hook.sh
git -C .worktrees/done-hook commit -s -m "perf(hooks): cache tail output to clear perf budget

Cache the 'tail -c 200000' result once outside the bullet loop instead
of re-reading for each anchor. Drops typical perf from ~Xms to <100ms
on the 1.5MB scenario."
```

---

## Task 11: `/goal` skill — scaffold + Initial stanza (RED+GREEN)

**Goal:** Create the skill directory, SKILL.md, and the test harness with scenario 1 (Initial stanza on empty file).

**Files:**
- Create `.claude/skills/goal/SKILL.md`
- Create `.claude/skills/goal/tests/test_goal_skill.sh`

- [ ] **Step 1: Write the failing test harness**

Create `.worktrees/done-hook/.claude/skills/goal/tests/test_goal_skill.sh`:

```bash
#!/bin/bash
# test_goal_skill.sh — integration harness for the /goal skill
# Skill implementations vary; this harness exercises the skill's behavior
# via a thin shell wrapper at .claude/skills/goal/goal.sh (created in Task 12).
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOAL_BIN="$(cd "$SCRIPT_DIR/.." && pwd)/goal.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# Helper: run the goal binary with a fake HOME and a session-id file.
run_goal() {
  local home="$1"; shift
  local uuid="$1"; shift
  mkdir -p "$home/.claude/sessions"
  echo "{\"sessionId\":\"$uuid\"}" > "$home/.claude/sessions/$$.json"
  HOME="$home" CLAUDE_SESSION_ID="$uuid" bash "$GOAL_BIN" "$@"
}

UUID1="goalt001-aaaa-bbbb-cccc-000000000001"
HOME1="$TMP/h1"

# Scenario 1: empty session → /goal creates Initial stanza
INPUT1=$'Goal: ship X\nAcceptance:\n- one\n- two'
run_goal "$HOME1" "$UUID1" "$INPUT1" >/dev/null 2>&1
FILE1="$HOME1/.claude/audit/session-goals/$UUID1.md"
if [ ! -f "$FILE1" ]; then
  echo "FAIL: scenario 1 — goal file not created"; FAIL=$((FAIL+1))
elif ! grep -q "^## Initial " "$FILE1"; then
  echo "FAIL: scenario 1 — Initial stanza header missing"; FAIL=$((FAIL+1))
elif ! grep -q "Goal: ship X" "$FILE1"; then
  echo "FAIL: scenario 1 — Goal line missing"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 1 — Initial stanza written"; PASS=$((PASS+1))
fi

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run to confirm RED**

```bash
chmod +x .worktrees/done-hook/.claude/skills/goal/tests/test_goal_skill.sh
bash .worktrees/done-hook/.claude/skills/goal/tests/test_goal_skill.sh
```

Expected: FAIL (goal.sh doesn't exist).

- [ ] **Step 3: Commit RED**

```bash
git -C .worktrees/done-hook add .claude/skills/goal/tests/test_goal_skill.sh
git -C .worktrees/done-hook commit -s -m "test(skills/goal): add test harness with Initial-stanza scenario (RED)"
```

---

## Task 12: `/goal` skill — implement Initial stanza (GREEN)

**Goal:** Create `goal.sh` (the skill's runtime) and `SKILL.md` (the trigger metadata).

**Files:**
- Create `.claude/skills/goal/SKILL.md`
- Create `.claude/skills/goal/goal.sh`

- [ ] **Step 1: Write SKILL.md**

Create `.worktrees/done-hook/.claude/skills/goal/SKILL.md`:

```markdown
---
name: goal
description: Capture or amend the session goal. Per the done-hook protocol, the goal file at ~/.claude/audit/session-goals/<uuid>.md anchors the Stop-hook evidence collection. Triggered by /goal, or by user phrases like "set session goal", "amend goal".
user-invocable: true
tools:
  - Read
  - Write
  - Bash
---

# /goal

Records the current session goal as a stanza in `~/.claude/audit/session-goals/<session-uuid>.md`.

## When to use

- Beginning of a session — capture the goal and 1-N acceptance bullets.
- Mid-session — amend the goal if scope has refined (brainstorm → plan → impl evolution).

## Invocation

```
/goal Goal: <one-line goal>
Acceptance:
- <bullet 1>
- <bullet 2>
- <bullet N>
```

The skill runs `~/.claude/skills/goal/goal.sh` with the provided text. Behavior:

1. Resolves the session UUID via `~/.claude/sessions/$$.json`.
2. If the goal file does not exist, writes a `## Initial <ts>` stanza.
3. If it exists, appends a `## Amendment <ts>` stanza.
4. Warns to stderr if the input lacks a `Goal:` line or an `Acceptance:` section (writes anyway — soft rollout).

## Format

See spec `docs/superpowers/specs/2026-05-18-done-hook-design.md` §Component 1 for the stanza format.
```

- [ ] **Step 2: Write goal.sh**

Create `.worktrees/done-hook/.claude/skills/goal/goal.sh`:

```bash
#!/bin/bash
# goal.sh — write or amend the session-goal file.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 4
set -o pipefail

INPUT="${1:-}"

# Resolve session UUID — prefer $CLAUDE_SESSION_ID, fall back to ~/.claude/sessions/$$.json
UUID="${CLAUDE_SESSION_ID:-}"
if [ -z "$UUID" ] || [ "$UUID" = "unknown" ]; then
  if [ -f "$HOME/.claude/sessions/$$.json" ]; then
    UUID=$(jq -r '.sessionId // empty' "$HOME/.claude/sessions/$$.json" 2>/dev/null)
  fi
fi
if [ -z "$UUID" ]; then
  # last-resort: newest session file
  SESS_FILE=$(ls -t "$HOME/.claude/sessions/"*.json 2>/dev/null | head -1)
  [ -n "$SESS_FILE" ] && UUID=$(jq -r '.sessionId // empty' "$SESS_FILE" 2>/dev/null)
fi
if [ -z "$UUID" ]; then
  echo "[goal] ERROR: could not resolve session UUID" >&2
  exit 1
fi

GOAL_DIR="$HOME/.claude/audit/session-goals"
mkdir -p "$GOAL_DIR"
GOAL_FILE="$GOAL_DIR/$UUID.md"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Determine stanza type by file presence (NOT by 'amend' keyword)
if [ -f "$GOAL_FILE" ]; then
  HEADER="## Amendment $TS"
else
  HEADER="## Initial $TS"
fi

# Strip leading "amend " keyword if present (user signal, not behavior change)
INPUT=$(echo "$INPUT" | sed 's/^amend //')

# Format check — warn but write
if ! echo "$INPUT" | grep -q '^Goal: '; then
  echo "[goal] WARNING: input missing 'Goal: ' line" >&2
fi
if ! echo "$INPUT" | grep -q '^Acceptance:'; then
  echo "[goal] WARNING: input missing 'Acceptance:' section" >&2
fi

{
  [ -f "$GOAL_FILE" ] && echo ""
  echo "$HEADER"
  echo "$INPUT"
} >> "$GOAL_FILE"

echo "[goal] wrote $HEADER to $GOAL_FILE" >&2
```

- [ ] **Step 3: Make executable + shellcheck**

```bash
chmod +x .worktrees/done-hook/.claude/skills/goal/goal.sh
shellcheck .worktrees/done-hook/.claude/skills/goal/goal.sh
```

Expected: clean.

- [ ] **Step 4: Run harness — scenario 1 PASS**

```bash
bash .worktrees/done-hook/.claude/skills/goal/tests/test_goal_skill.sh
```

Expected: `1 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git -C .worktrees/done-hook add .claude/skills/goal/SKILL.md .claude/skills/goal/goal.sh
git -C .worktrees/done-hook commit -s -m "feat(skills/goal): add /goal skill with Initial stanza handling

Resolves session UUID via CLAUDE_SESSION_ID or ~/.claude/sessions/\$\$.json,
writes ## Initial stanza when goal file absent. Warns on missing Goal:/
Acceptance: lines but writes anyway (soft rollout per spec decision #14).

Tests: 1/1 PASS.
shellcheck: clean."
```

---

## Task 13: `/goal` skill — Amendment + format-check scenarios (RED+GREEN)

**Goal:** Add scenarios 2-4 (Amendment append, format warning, idempotent).

**Files:** Modify `.claude/skills/goal/tests/test_goal_skill.sh`. No goal.sh changes expected (already implemented in Task 12).

- [ ] **Step 1: Append scenarios 2-4**

After scenario 1's PASS line, before `echo` final results, append:

```bash
# Scenario 2: existing file → /goal appends Amendment stanza
INPUT2=$'Goal: ship Y\nAcceptance:\n- three'
run_goal "$HOME1" "$UUID1" "$INPUT2" >/dev/null 2>&1
if ! grep -q "^## Amendment " "$FILE1"; then
  echo "FAIL: scenario 2 — Amendment header missing"; FAIL=$((FAIL+1))
elif [ "$(grep -c '^## ' "$FILE1")" -ne 2 ]; then
  echo "FAIL: scenario 2 — expected exactly 2 stanzas, got $(grep -c '^## ' "$FILE1")"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 2 — Amendment stanza appended"; PASS=$((PASS+1))
fi

# Scenario 3: malformed input (no Goal: line) → warning but written
UUID3="goalt003-aaaa-bbbb-cccc-000000000003"
HOME3="$TMP/h3"
INPUT3="not-a-goal-format"
STDERR3=$(run_goal "$HOME3" "$UUID3" "$INPUT3" 2>&1 >/dev/null)
FILE3="$HOME3/.claude/audit/session-goals/$UUID3.md"
if ! echo "$STDERR3" | grep -q "missing 'Goal: '"; then
  echo "FAIL: scenario 3 — no warning emitted"; FAIL=$((FAIL+1))
elif [ ! -f "$FILE3" ]; then
  echo "FAIL: scenario 3 — file not written despite warning"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 3 — malformed input warns but writes"; PASS=$((PASS+1))
fi

# Scenario 4: 'amend' keyword stripped, behavior unchanged
UUID4="goalt004-aaaa-bbbb-cccc-000000000004"
HOME4="$TMP/h4"
INPUT4=$'amend Goal: stripped X\nAcceptance:\n- one'
run_goal "$HOME4" "$UUID4" "$INPUT4" >/dev/null 2>&1
FILE4="$HOME4/.claude/audit/session-goals/$UUID4.md"
if grep -q "^amend Goal:" "$FILE4"; then
  echo "FAIL: scenario 4 — 'amend' keyword leaked into stanza"; FAIL=$((FAIL+1))
elif ! grep -q "Goal: stripped X" "$FILE4"; then
  echo "FAIL: scenario 4 — Goal line missing after strip"; FAIL=$((FAIL+1))
else
  echo "PASS: scenario 4 — 'amend' keyword stripped"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run — all 4 PASS**

```bash
bash .worktrees/done-hook/.claude/skills/goal/tests/test_goal_skill.sh
echo "exit=$?"
```

Expected: `4 passed, 0 failed`.

- [ ] **Step 3: Commit**

```bash
git -C .worktrees/done-hook add .claude/skills/goal/tests/test_goal_skill.sh
git -C .worktrees/done-hook commit -s -m "test(skills/goal): add Amendment + format-warning + amend-keyword scenarios

Three additional scenarios all PASS on Task 12 implementation:
- existing file -> Amendment stanza
- malformed input -> stderr warning + still writes
- 'amend' prefix is stripped before write

4/4 PASS."
```

---

## Task 14: `/done` skill — scaffold (no logic yet)

**Goal:** Create the skill directory layout, SKILL.md, persona file, and an empty Python module stub. Establishes import surface.

**Files:**
- Create `.claude/skills/done/SKILL.md`
- Create `.claude/skills/done/personas/goal-evaluator.md`
- Create `.claude/skills/done/eval.py` (skeleton only)
- Create `.claude/skills/done/tests/__init__.py` (empty)
- Create `.claude/skills/done/tests/test_eval.py` (stub failing test)

- [ ] **Step 1: Write SKILL.md**

Create `.worktrees/done-hook/.claude/skills/done/SKILL.md`:

```markdown
---
name: done
description: Confirm or abandon the session goal with NAT-backed evidence evaluation. Triggered by /done, /done confirm, /done abandon <reason>, /done amend <text>.
user-invocable: true
tools:
  - Bash
  - Read
---

# /done

Surfaces a candidate verdict against the captured session goal using a NAT-backed goal-evaluator panelist, and writes the authoritative `user.verdict` into the daily outcomes log.

## When to use

- End of a session, when the user believes the goal has been met (or not).
- When the user wants to record `ABANDONED <reason>` or amend the goal.

## Subcommands

| Subcommand | Behavior |
|---|---|
| `/done` or `/done confirm` | Read latest outcomes evidence + last goal stanza. Invoke NAT goal-evaluator. AGREE → write `user.verdict=MET`. DISAGREE → surface NAT rationale; ask user to amend or override. INSUFFICIENT → ask user for explicit verdict using NAT's `GAPS`. NAT ERROR → fall through to `user_only`. |
| `/done abandon <reason>` | Skip NAT call. Write `user.verdict=ABANDONED` with `reason=<reason>`. |
| `/done amend <text>` | Forward to `/goal amend <text>`; no outcomes entry written. |

## Implementation

The skill runs `~/.claude/skills/done/eval.py` via Python 3.12. The Python module mirrors the validate-recommendation v3 `panel/dispatch.py` pattern: a single mockable `_invoke_nat` seam and ERROR-fallback wrapping so all NAT/HTTP/parse failures degrade gracefully to `user_only`.

## NAT model

Default model is configurable; v1 uses `nvidia/nemotron-3-super-v3` (matches the panel default). Override via `DONE_NAT_MODEL` env var.

## Spec

`docs/superpowers/specs/2026-05-18-done-hook-design.md` §Component 5.
```

- [ ] **Step 2: Write persona**

Create `.worktrees/done-hook/.claude/skills/done/personas/goal-evaluator.md`:

```markdown
You are a strict goal-evaluation panelist. You are given:

1. A session goal stanza (Goal: line + Acceptance: bullets).
2. A list of evidence records collected from the session's bash audit log.
3. The user's claimed verdict (MET / PARTIAL / PIVOTED / ABANDONED).

Your job: judge whether the evidence demonstrates that the acceptance
criteria were satisfied. You are an INDEPENDENT second opinion, not a
rubber stamp. If the evidence is weak or missing for any acceptance
bullet, say so.

Three possible verdicts:

- AGREE — every acceptance bullet has at least one piece of evidence
  that reasonably supports it.
- DISAGREE — at least one acceptance bullet has NO supporting evidence,
  OR the evidence contradicts the bullet (e.g., test exit != 0).
- INSUFFICIENT_EVIDENCE — the bullets are too vague to evaluate, OR
  the evidence is insufficient to judge in either direction.

Output ONLY this strict format. No preamble. No markdown fencing.

VERDICT: AGREE | DISAGREE | INSUFFICIENT_EVIDENCE
RATIONALE: <one paragraph, 3-5 sentences citing specific bullets and evidence>
GAPS: <comma-separated list of acceptance bullets with weak/missing evidence; "n/a" if none>
```

- [ ] **Step 3: Write eval.py skeleton**

Create `.worktrees/done-hook/.claude/skills/done/eval.py`:

```python
"""done/eval.py — NAT-backed goal evidence evaluator.

Mirrors the validate-recommendation v3 panel/dispatch.py pattern:
one mockable _invoke_nat seam + ERROR-fallback wrapping.
"""
from __future__ import annotations

import json
import pathlib
import sys
from typing import Any, Literal

Verdict = Literal["AGREE", "DISAGREE", "INSUFFICIENT_EVIDENCE", "ERROR"]

PERSONA_PATH = pathlib.Path(__file__).parent / "personas" / "goal-evaluator.md"


def _invoke_nat(prompt: str, model: str, max_tokens: int = 32768) -> str:
    """Single mockable seam. Raises on any failure — caller wraps in ERROR-fallback.

    Real implementation imports nvidia-nat lazily so tests that mock this
    function never trigger the NAT cold-start cost.
    """
    from nat.builder import build_llm  # type: ignore[import-not-found]
    llm = build_llm(model=model)
    response = llm.invoke(prompt, max_tokens=max_tokens)
    if isinstance(response, dict):
        return response.get("content", "") or ""
    return str(response)


def _parse_verdict(raw: str) -> dict[str, Any]:
    """Parse the strict 'VERDICT: ... / RATIONALE: ... / GAPS: ...' format."""
    lines = raw.strip().splitlines()
    out: dict[str, Any] = {"verdict": "ERROR", "rationale": "", "gaps": []}
    for line in lines:
        if line.startswith("VERDICT:"):
            v = line.split(":", 1)[1].strip()
            if v in ("AGREE", "DISAGREE", "INSUFFICIENT_EVIDENCE"):
                out["verdict"] = v
        elif line.startswith("RATIONALE:"):
            out["rationale"] = line.split(":", 1)[1].strip()
        elif line.startswith("GAPS:"):
            g = line.split(":", 1)[1].strip()
            out["gaps"] = [] if g == "n/a" else [x.strip() for x in g.split(",")]
    return out


def evaluate(
    goal_stanza: str,
    evidence: list[dict[str, Any]],
    user_claim: str,
    model: str = "nvidia/nemotron-3-super-v3",
) -> dict[str, Any]:
    """Evaluate evidence against goal; return {verdict, rationale, gaps}.

    On any internal failure (NAT unavailable, parse error, model error),
    returns {verdict: "ERROR", rationale: "<reason>", gaps: []}. The caller
    falls through to user_only.
    """
    try:
        persona = PERSONA_PATH.read_text()
    except OSError as exc:
        return {"verdict": "ERROR", "rationale": f"persona load failed: {exc}", "gaps": []}

    prompt = (
        f"{persona}\n\n"
        f"## Goal stanza\n{goal_stanza}\n\n"
        f"## Evidence collected\n{json.dumps(evidence, indent=2)}\n\n"
        f"## User claims\n{user_claim}\n"
    )
    try:
        raw = _invoke_nat(prompt, model=model)
        result = _parse_verdict(raw)
        if result["verdict"] == "ERROR":
            result["rationale"] = "parse failed: no VERDICT line"
        return result
    except Exception as exc:  # noqa: BLE001 — ERROR fallback per spec
        return {"verdict": "ERROR", "rationale": f"NAT dispatch failed: {exc}", "gaps": []}


def main(argv: list[str]) -> int:
    """CLI entry. Reads JSON from stdin, prints JSON to stdout."""
    payload = json.load(sys.stdin)
    result = evaluate(
        goal_stanza=payload["goal_stanza"],
        evidence=payload["evidence"],
        user_claim=payload.get("user_claim", "MET"),
        model=payload.get("model", "nvidia/nemotron-3-super-v3"),
    )
    json.dump(result, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Write failing pytest stub**

Create `.worktrees/done-hook/.claude/skills/done/tests/__init__.py` (empty file).

Create `.worktrees/done-hook/.claude/skills/done/tests/test_eval.py`:

```python
"""Tests for done/eval.py — mocks _invoke_nat only."""
from __future__ import annotations

import json
from unittest.mock import patch

import pytest

# Add the parent dir to sys.path so `import eval` works.
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
import eval as done_eval  # noqa: E402


def _make_goal() -> str:
    return (
        "## Initial 2026-05-18T10:00:00Z\n"
        "Goal: ship done-hook v1\n"
        "Acceptance:\n"
        "- ./done-hook_test.sh passes\n"
        "- shellcheck clean\n"
        "- spec committed\n"
    )


def _make_evidence(complete: bool) -> list[dict]:
    base = [
        {"cmd": "./done-hook_test.sh", "exit": 0, "ts": "2026-05-18T14:32Z"},
        {"cmd": "shellcheck ~/.claude/hooks/done-hook.sh", "exit": 0, "ts": "2026-05-18T14:33Z"},
    ]
    if complete:
        base.append({"cmd": "git commit", "subject": "docs(specs): add design", "sha": "f3a4b5c", "ts": "2026-05-18T14:15Z"})
    return base


def test_agree_path_returns_met():
    """When NAT returns AGREE, evaluate() yields verdict=AGREE + non-empty rationale."""
    fake_response = (
        "VERDICT: AGREE\n"
        "RATIONALE: All three bullets have supporting evidence.\n"
        "GAPS: n/a"
    )
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
    assert result["verdict"] == "AGREE"
    assert "All three bullets" in result["rationale"]
    assert result["gaps"] == []
```

- [ ] **Step 5: Run the test — expect IMPORT error or PASS**

```bash
~/.local/pipx/venvs/pytest/bin/pytest \
    .worktrees/done-hook/.claude/skills/done/tests/test_eval.py -v
echo "exit=$?"
```

Expected: PASS (eval.py is fully implemented; this just exercises the AGREE path with a mocked NAT).

If the test fails because `_invoke_nat` is being called instead of mocked, verify `patch.object(done_eval, "_invoke_nat", ...)` is correct (path-targeted patching).

- [ ] **Step 6: Commit**

```bash
git -C .worktrees/done-hook add .claude/skills/done/
git -C .worktrees/done-hook commit -s -m "feat(skills/done): scaffold /done skill with eval.py + persona + tests

Initial NAT-backed goal-evaluator. Mirrors validate-recommendation v3
panel/dispatch.py: _invoke_nat mockable seam, ERROR-fallback wrapping.
Persona at personas/goal-evaluator.md returns strict
VERDICT/RATIONALE/GAPS format.

Tests: 1/1 PASS (AGREE path).
NAT cold-start avoided in tests via lazy import in _invoke_nat."
```

---

## Task 15: `/done` skill — DISAGREE + INSUFFICIENT + ERROR paths

**Goal:** Add scenarios 2-4 to `test_eval.py`.

**Files:** Modify `.claude/skills/done/tests/test_eval.py`.

- [ ] **Step 1: Append three more tests**

After `test_agree_path_returns_met`, append:

```python
def test_disagree_path_returns_disagree_with_gaps():
    """When NAT returns DISAGREE, evaluate() yields verdict=DISAGREE + GAPS list."""
    fake_response = (
        "VERDICT: DISAGREE\n"
        "RATIONALE: Spec committed but no evidence for shellcheck run.\n"
        "GAPS: shellcheck clean"
    )
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=False), "MET")
    assert result["verdict"] == "DISAGREE"
    assert "shellcheck clean" in result["gaps"]


def test_insufficient_path_returns_insufficient():
    """When NAT returns INSUFFICIENT_EVIDENCE, evaluate() preserves that label."""
    fake_response = (
        "VERDICT: INSUFFICIENT_EVIDENCE\n"
        "RATIONALE: Bullets are vague; cannot judge.\n"
        "GAPS: n/a"
    )
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), [], "MET")
    assert result["verdict"] == "INSUFFICIENT_EVIDENCE"


def test_error_fallback_when_nat_raises():
    """When _invoke_nat raises any exception, evaluate() returns verdict=ERROR."""
    def boom(*args, **kwargs):
        raise RuntimeError("NIM endpoint unreachable")
    with patch.object(done_eval, "_invoke_nat", side_effect=boom):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
    assert result["verdict"] == "ERROR"
    assert "NIM endpoint unreachable" in result["rationale"]


def test_error_fallback_when_response_lacks_verdict_line():
    """Malformed NAT response (no VERDICT line) → verdict=ERROR with parse-failed reason."""
    fake_response = "I think the goal might be met but I'm not sure."  # no strict format
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
    assert result["verdict"] == "ERROR"
    assert "parse failed" in result["rationale"]
```

- [ ] **Step 2: Run**

```bash
~/.local/pipx/venvs/pytest/bin/pytest \
    .worktrees/done-hook/.claude/skills/done/tests/test_eval.py -v
```

Expected: 5/5 PASS.

- [ ] **Step 3: Commit**

```bash
git -C .worktrees/done-hook add .claude/skills/done/tests/test_eval.py
git -C .worktrees/done-hook commit -s -m "test(skills/done): cover DISAGREE / INSUFFICIENT / ERROR paths

Four additional tests for eval.evaluate():
- DISAGREE -> verdict + populated GAPS list
- INSUFFICIENT_EVIDENCE -> preserved label
- NAT raises -> ERROR + reason includes exception
- malformed response -> ERROR + 'parse failed' reason

5/5 PASS. All exercises mock _invoke_nat; no real NAT calls."
```

---

## Task 16: `/done` skill — orchestrator shell wrapper

**Goal:** Add `done.sh` that orchestrates the full `/done` flow: read goal + outcomes → call eval.py → write user verdict entry. Plus the `abandon` subcommand.

**Files:**
- Create `.claude/skills/done/done.sh`
- Create `.claude/skills/done/tests/test_skill_integration.sh`

- [ ] **Step 1: Write integration harness with two failing scenarios**

Create `.worktrees/done-hook/.claude/skills/done/tests/test_skill_integration.sh`:

```bash
#!/bin/bash
# test_skill_integration.sh — end-to-end harness for the /done skill
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DONE_BIN="$(cd "$SCRIPT_DIR/.." && pwd)/done.sh"
HOOK="$(cd "$SCRIPT_DIR/../../../hooks" && pwd)/done-hook.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

# Common setup
UUID="donesk01-aaaa-bbbb-cccc-000000000001"
HOME_DIR="$TMP/h1"
mkdir -p "$HOME_DIR/.claude/audit/session-goals" "$HOME_DIR/.claude/audit"
TRANSCRIPT="$HOME_DIR/projects/fake/$UUID.jsonl"
mkdir -p "$(dirname "$TRANSCRIPT")"; touch "$TRANSCRIPT"

cat > "$HOME_DIR/.claude/audit/session-goals/$UUID.md" <<'GOAL'
## Initial 2026-05-18T10:00:00Z
Goal: ship done-hook v1
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed
GOAL

cat > "$HOME_DIR/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log" <<'LOG'
2026-05-18T14:30:00Z	./done-hook_test.sh	exit=0
2026-05-18T14:31:00Z	shellcheck ~/.claude/hooks/done-hook.sh	exit=0
2026-05-18T14:32:00Z	git commit -s -m "docs(specs): add design"	exit=0
LOG

# Run the Stop hook first to seed the outcomes log
echo "{\"transcript_path\":\"$TRANSCRIPT\"}" | HOME="$HOME_DIR" bash "$HOOK" >/dev/null 2>&1

# Scenario 1: /done confirm with mocked NAT returning AGREE → user.verdict=MET written
DONE_FAKE_NAT_RESPONSE=$'VERDICT: AGREE\nRATIONALE: all three bullets supported.\nGAPS: n/a' \
  HOME="$HOME_DIR" CLAUDE_SESSION_ID="$UUID" \
  bash "$DONE_BIN" confirm >/dev/null 2>&1

LATEST=$(grep "\"session\":\"$UUID\"" "$HOME_DIR/.claude/audit/session-outcomes-"*.log | tail -1)
if echo "$LATEST" | grep -q '"verdict":"MET"' && \
   echo "$LATEST" | grep -q '"nat_verdict":"AGREE"' && \
   echo "$LATEST" | grep -q '"evaluator":"nat-goal-evaluator"'; then
  echo "PASS: /done confirm AGREE -> MET + nat-goal-evaluator"; PASS=$((PASS+1))
else
  echo "FAIL: /done confirm AGREE — latest entry missing expected fields"
  echo "  got: $LATEST"; FAIL=$((FAIL+1))
fi

# Scenario 2: /done abandon "blocked by Y" → user.verdict=ABANDONED, evaluator=user_only, no NAT
UUID2="donesk02-aaaa-bbbb-cccc-000000000002"
HOME_DIR2="$TMP/h2"
mkdir -p "$HOME_DIR2/.claude/audit/session-goals" "$HOME_DIR2/.claude/audit"
cp "$HOME_DIR/.claude/audit/session-goals/$UUID.md" "$HOME_DIR2/.claude/audit/session-goals/$UUID2.md"
TRANSCRIPT2="$HOME_DIR2/projects/fake/$UUID2.jsonl"
mkdir -p "$(dirname "$TRANSCRIPT2")"; touch "$TRANSCRIPT2"
echo "{\"transcript_path\":\"$TRANSCRIPT2\"}" | HOME="$HOME_DIR2" bash "$HOOK" >/dev/null 2>&1

# DONE_FAKE_NAT_RESPONSE unset — if NAT is accidentally called, it errors
HOME="$HOME_DIR2" CLAUDE_SESSION_ID="$UUID2" \
  bash "$DONE_BIN" abandon "blocked by Y" >/dev/null 2>&1

LATEST2=$(grep "\"session\":\"$UUID2\"" "$HOME_DIR2/.claude/audit/session-outcomes-"*.log | tail -1)
if echo "$LATEST2" | grep -q '"verdict":"ABANDONED"' && \
   echo "$LATEST2" | grep -q '"reason":"blocked by Y"' && \
   echo "$LATEST2" | grep -q '"evaluator":"user_only"'; then
  echo "PASS: /done abandon — ABANDONED + user_only + reason"; PASS=$((PASS+1))
else
  echo "FAIL: /done abandon — latest entry missing expected fields"
  echo "  got: $LATEST2"; FAIL=$((FAIL+1))
fi

echo
echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Make executable + confirm RED**

```bash
chmod +x .worktrees/done-hook/.claude/skills/done/tests/test_skill_integration.sh
bash .worktrees/done-hook/.claude/skills/done/tests/test_skill_integration.sh
```

Expected: both scenarios FAIL (no `done.sh` yet).

- [ ] **Step 3: Commit the RED**

```bash
git -C .worktrees/done-hook add .claude/skills/done/tests/test_skill_integration.sh
git -C .worktrees/done-hook commit -s -m "test(skills/done): add integration harness (RED)

Two scenarios:
- /done confirm with mocked NAT AGREE -> user.verdict=MET + nat-goal-evaluator
- /done abandon -> user.verdict=ABANDONED + user_only (no NAT call)

NAT is mocked via DONE_FAKE_NAT_RESPONSE env var (done.sh handles this
seam — see Task 16b)."
```

- [ ] **Step 4: Write done.sh**

Create `.worktrees/done-hook/.claude/skills/done/done.sh`:

```bash
#!/bin/bash
# done.sh — /done skill orchestrator.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 5
set -o pipefail

SUBCOMMAND="${1:-confirm}"
shift || true
REASON="${*:-}"

# Resolve session UUID (same algorithm as goal.sh)
UUID="${CLAUDE_SESSION_ID:-}"
if [ -z "$UUID" ] || [ "$UUID" = "unknown" ]; then
  if [ -f "$HOME/.claude/sessions/$$.json" ]; then
    UUID=$(jq -r '.sessionId // empty' "$HOME/.claude/sessions/$$.json" 2>/dev/null)
  fi
fi
if [ -z "$UUID" ]; then
  SESS_FILE=$(ls -t "$HOME/.claude/sessions/"*.json 2>/dev/null | head -1)
  [ -n "$SESS_FILE" ] && UUID=$(jq -r '.sessionId // empty' "$SESS_FILE" 2>/dev/null)
fi
if [ -z "$UUID" ]; then
  echo "[done] ERROR: could not resolve session UUID" >&2
  exit 1
fi

GOAL_FILE="$HOME/.claude/audit/session-goals/$UUID.md"
OUTCOMES_LOG="$HOME/.claude/audit/session-outcomes-$(date -u +%Y-%m-%d).log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Compute next seq
SEQ=1
if [ -f "$OUTCOMES_LOG" ]; then
  PREV_SEQ=$(grep "\"session\":\"$UUID\"" "$OUTCOMES_LOG" 2>/dev/null | \
             grep -oE '"seq":[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
  [ -n "$PREV_SEQ" ] && SEQ=$((PREV_SEQ + 1))
fi

GOAL_REL_PATH="session-goals/${UUID}.md"

append_user_entry() {
  local verdict="$1" reason="$2" evaluator="$3" nat_verdict="$4" rationale="$5"
  # Escape strings via python (matches done-hook.sh)
  reason=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"))[1:-1])' <<< "$reason")
  rationale=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"))[1:-1])' <<< "$rationale")
  printf '{"schema":1,"session":"%s","seq":%d,"ts":"%s","goal_file":"%s","heuristic":null,"evidence":[],"state_hash":"","user":{"verdict":"%s","reason":"%s","evaluator":"%s","nat_verdict":"%s","evaluator_rationale":"%s","ts":"%s"}}\n' \
    "$UUID" "$SEQ" "$TS" "$GOAL_REL_PATH" "$verdict" "$reason" "$evaluator" "$nat_verdict" "$rationale" "$TS" \
    >> "$OUTCOMES_LOG"
}

case "$SUBCOMMAND" in
  abandon)
    [ -z "$REASON" ] && { echo "[done] ERROR: /done abandon requires <reason>" >&2; exit 1; }
    append_user_entry "ABANDONED" "$REASON" "user_only" "n/a" ""
    echo "[done] session $UUID logged as ABANDONED: $REASON" >&2
    ;;
  amend)
    [ -z "$REASON" ] && { echo "[done] ERROR: /done amend requires <text>" >&2; exit 1; }
    exec bash "$HOME/.claude/skills/goal/goal.sh" "amend $REASON"
    ;;
  confirm|"")
    [ ! -f "$GOAL_FILE" ] && { echo "[done] ERROR: no goal file for $UUID; run /goal first" >&2; exit 1; }
    # Read last stanza
    STANZA=$(awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$GOAL_FILE")
    # Read latest outcomes entry's evidence (for the eval payload)
    EVIDENCE_JSON='[]'
    if [ -f "$OUTCOMES_LOG" ]; then
      EVIDENCE_JSON=$(grep "\"session\":\"$UUID\"" "$OUTCOMES_LOG" | tail -1 | \
                      python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(json.dumps(d.get("evidence",[])))' 2>/dev/null || echo '[]')
    fi

    # Build the eval payload
    PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"goal_stanza": sys.argv[1], "evidence": json.loads(sys.argv[2]), "user_claim": "MET"}))' \
              "$STANZA" "$EVIDENCE_JSON")

    # Test seam: if DONE_FAKE_NAT_RESPONSE is set, skip the Python call and inject the response directly
    if [ -n "${DONE_FAKE_NAT_RESPONSE:-}" ]; then
      RESULT=$(python3 -c '
import json, os, sys
sys.path.insert(0, os.path.expandvars("$HOME/.claude/skills/done"))
import eval as e
def fake(*a, **k): return os.environ["DONE_FAKE_NAT_RESPONSE"]
e._invoke_nat = fake
payload = json.loads(sys.stdin.read())
print(json.dumps(e.evaluate(payload["goal_stanza"], payload["evidence"], payload["user_claim"])))
' <<< "$PAYLOAD")
    else
      RESULT=$(echo "$PAYLOAD" | /opt/homebrew/bin/python3.12 "$HOME/.claude/skills/done/eval.py")
    fi

    NAT_VERDICT=$(echo "$RESULT" | jq -r '.verdict')
    NAT_RATIONALE=$(echo "$RESULT" | jq -r '.rationale')

    case "$NAT_VERDICT" in
      AGREE)
        append_user_entry "MET" "NAT agree on $TOTAL/$TOTAL" "nat-goal-evaluator" "AGREE" "$NAT_RATIONALE"
        echo "[done] ✅ Session goal accomplished. NAT: $NAT_RATIONALE" >&2
        ;;
      DISAGREE)
        echo "[done] ⚠ NAT disagreed: $NAT_RATIONALE" >&2
        echo "[done] No verdict written. Run /done confirm to override, or /done amend / abandon." >&2
        ;;
      INSUFFICIENT_EVIDENCE)
        echo "[done] ⚠ NAT: insufficient evidence: $NAT_RATIONALE" >&2
        echo "[done] No verdict written. Provide explicit verdict via /done abandon <reason> or refine the goal." >&2
        ;;
      ERROR|*)
        append_user_entry "MET" "user claim; NAT unavailable" "user_only" "ERROR" "$NAT_RATIONALE"
        echo "[done] ⚠ NAT unavailable ($NAT_RATIONALE); logged user claim as MET." >&2
        ;;
    esac
    ;;
  *)
    echo "[done] ERROR: unknown subcommand '$SUBCOMMAND'" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 5: Make executable + shellcheck**

```bash
chmod +x .worktrees/done-hook/.claude/skills/done/done.sh
shellcheck .worktrees/done-hook/.claude/skills/done/done.sh
```

Expected: shellcheck clean. If it warns about `python3 -c` heredoc-style usage, those are acceptable (Python is required regardless).

- [ ] **Step 6: Run integration harness — 2/2 PASS**

```bash
bash .worktrees/done-hook/.claude/skills/done/tests/test_skill_integration.sh
echo "exit=$?"
```

Expected: `2 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git -C .worktrees/done-hook add .claude/skills/done/done.sh
git -C .worktrees/done-hook commit -s -m "feat(skills/done): orchestrator done.sh with confirm + abandon + amend

confirm: read last goal stanza + latest outcomes evidence, dispatch to
eval.py (NAT-backed). AGREE -> user.verdict=MET + nat-goal-evaluator.
DISAGREE / INSUFFICIENT -> surface to user, no verdict written.
ERROR -> fall through to user_only with NAT error rationale.

abandon: skip NAT, log ABANDONED + reason + user_only.

amend: forward to /goal amend.

Test seam: DONE_FAKE_NAT_RESPONSE env var injects a fake verdict string
into _invoke_nat (used by test_skill_integration.sh).

Tests: 2/2 PASS (integration), 5/5 PASS (eval pytest)."
```

---

## Task 17: Register hooks in settings.json

**Goal:** Wire `session-goal-init.sh` and `done-hook.sh` into the hook registry.

**Files:** Modify `.claude/settings.json`.

- [ ] **Step 1: Read current settings.json**

```bash
cat .worktrees/done-hook/.claude/settings.json | jq '.hooks // {}'
```

Note the existing structure — Claude Code uses an event-keyed array format. Find `SessionStart` and `Stop` keys.

- [ ] **Step 2: Add the new hooks**

Append entries to the relevant arrays. The exact JSON shape depends on existing settings — match what `context-watch.sh` uses for `Stop`. Example shape (verify against actual file):

```json
"SessionStart": [
  {
    "command": "${HOME}/.claude/hooks/session-goal-init.sh"
  }
],
"Stop": [
  {
    "command": "${HOME}/.claude/hooks/context-watch.sh"
  },
  {
    "command": "${HOME}/.claude/hooks/done-hook.sh"
  }
]
```

Use the Edit tool to add the new entries; do NOT remove existing hooks.

- [ ] **Step 3: Validate JSON**

```bash
jq empty .worktrees/done-hook/.claude/settings.json && echo "JSON valid"
```

Expected: "JSON valid".

- [ ] **Step 4: Commit**

```bash
git -C .worktrees/done-hook add .claude/settings.json
git -C .worktrees/done-hook commit -s -m "chore(settings): register done-hook.sh + session-goal-init.sh

done-hook.sh added as peer Stop hook alongside context-watch.sh;
session-goal-init.sh added as SessionStart hook. Both exit 0 always,
never block."
```

---

## Task 18: Update .gitignore for runtime data

**Goal:** Prevent generated outcomes log + session-goal files from being committed.

**Files:** Modify `.gitignore`.

- [ ] **Step 1: Add entries**

Append to `.worktrees/done-hook/.gitignore` (after the existing exclude block):

```
# Done-hook runtime data (per-session goal files + daily outcomes log)
.claude/audit/session-goals/
.claude/audit/session-outcomes-*.log
.claude/audit/otel-spans-*.jsonl
```

- [ ] **Step 2: Verify**

```bash
git -C .worktrees/done-hook check-ignore -v .claude/audit/session-goals/xyz.md
git -C .worktrees/done-hook check-ignore -v .claude/audit/session-outcomes-2026-05-18.log
```

Expected: both paths reported as ignored.

- [ ] **Step 3: Commit**

```bash
git -C .worktrees/done-hook add .gitignore
git -C .worktrees/done-hook commit -s -m "chore(gitignore): exclude done-hook runtime data

Session-goal files and the daily outcomes log are runtime data, not
checked-in config. OTel spans (v2 emission, off by default) also
ignored proactively."
```

---

## Task 19: Markdown lint pass on spec + plan

**Goal:** Ensure the design + plan docs pass `markdownlint-cli2`.

**Files:** Self-correct any lint violations in `docs/superpowers/specs/2026-05-18-done-hook-design.md` and `docs/superpowers/plans/2026-05-18-done-hook-plan.md`.

- [ ] **Step 1: Run linter**

```bash
markdownlint-cli2 \
  .worktrees/done-hook/docs/superpowers/specs/2026-05-18-done-hook-design.md \
  .worktrees/done-hook/docs/superpowers/plans/2026-05-18-done-hook-plan.md
echo "exit=$?"
```

Expected: 0 violations OR a small number of fixable ones (line length, trailing whitespace).

- [ ] **Step 2: Fix violations**

For each reported violation, edit the file inline. Common fixes:
- MD013 (line length): split long lines.
- MD024 (duplicate headers): rename or merge.
- MD031 (blanks around fences): add blank lines around ```code``` blocks.

If many MD013 violations exist, accept that some are unavoidable (URLs, code) and configure a small exception in `.markdownlint.json` if needed — but prefer fixing the markdown.

- [ ] **Step 3: Re-run + verify clean**

```bash
markdownlint-cli2 \
  .worktrees/done-hook/docs/superpowers/specs/2026-05-18-done-hook-design.md \
  .worktrees/done-hook/docs/superpowers/plans/2026-05-18-done-hook-plan.md
```

Expected: 0 violations.

- [ ] **Step 4: Commit (if changes made)**

```bash
git -C .worktrees/done-hook add docs/superpowers/specs/2026-05-18-done-hook-design.md docs/superpowers/plans/2026-05-18-done-hook-plan.md
git -C .worktrees/done-hook commit -s -m "docs: fix markdownlint violations in design + plan"
```

If no changes were needed, skip this step.

---

## Task 20: Deploy + live smoke test

**Goal:** Sync the new hooks/skills into `~/.claude/` and verify they fire correctly in a real Claude Code context.

**Files:** none. Operational only.

- [ ] **Step 1: Dry-run the deploy script to see what would change**

```bash
scripts/deploy.sh --dry-run 2>&1 | head -50
```

(If `--dry-run` flag doesn't exist, read `scripts/deploy.sh` to understand what it does before running.)

- [ ] **Step 2: Run the deploy**

```bash
bash scripts/deploy.sh
```

- [ ] **Step 3: Verify the new files are live**

```bash
ls -la ~/.claude/hooks/done-hook.sh ~/.claude/hooks/session-goal-init.sh \
       ~/.claude/skills/goal/SKILL.md ~/.claude/skills/done/SKILL.md \
       ~/.claude/skills/done/eval.py 2>&1
```

Expected: all files present with executable bits where needed.

- [ ] **Step 4: Run all tests against the live paths (sanity)**

```bash
bash ~/.claude/hooks/session-goal-init_test.sh && \
bash ~/.claude/hooks/done-hook_test.sh && \
bash ~/.claude/skills/goal/tests/test_goal_skill.sh && \
bash ~/.claude/skills/done/tests/test_skill_integration.sh && \
~/.local/pipx/venvs/pytest/bin/pytest ~/.claude/skills/done/tests/test_eval.py -v
```

Expected: all suites PASS.

- [ ] **Step 5: Live smoke — open a fresh Claude Code session (manual)**

The user opens a new Claude session in a new terminal. The SessionStart hook should fire and emit the nudge in the session header (visible in the conversation as a system-reminder block).

- [ ] **Step 6: Run `/goal` in that session (manual)**

User types `/goal` with a simple goal block. Verify `~/.claude/audit/session-goals/<new-uuid>.md` is created.

- [ ] **Step 7: Run a couple of commands, then `/done confirm` (manual)**

User runs the verification commands listed in §Verification of the brief (e.g., `bash ~/.claude/hooks/done-hook_test.sh`). Then `/done confirm`. NAT should fire (3-5s); the daily outcomes log should gain a user entry with `verdict=MET`.

- [ ] **Step 8: No commit for Task 20**

This task is operational. No file changes. Document the smoke test results in the PR description.

---

## Task 21: Open draft PR

**Goal:** Push the branch and open a draft PR with full context for review.

**Files:** PR body only.

- [ ] **Step 1: Push the branch**

```bash
git -C .worktrees/done-hook push -u origin feat/done-hook
```

- [ ] **Step 2: Open draft PR**

```bash
gh pr create --draft \
  --base main \
  --head feat/done-hook \
  --title "feat(hooks+skills): done-hook + session-goal protocol" \
  --body "$(cat <<'EOF'
## Summary

Implements the done-hook + session-goal protocol per `docs/superpowers/specs/2026-05-18-done-hook-design.md`.

Two-part protocol for end-of-session goal-met verification:

1. **`/goal` skill** captures a per-session goal file at `~/.claude/audit/session-goals/<uuid>.md` (append-only stanzas).
2. **SessionStart hook** nudges when goal absent; **Stop hook** (`done-hook.sh`) collects evidence and writes a JSONL outcomes log entry (debounced via state hash). Hook never claims completion — surfaces matched acceptance bullets and a heuristic verdict (max `LIKELY_MET`).
3. **`/done` skill** invokes a NAT-backed goal-evaluator (mirrors the validate-recommendation v3 dispatch pattern) and writes the authoritative `user.verdict`. Falls through to `user_only` when NAT is unavailable.
4. **Outcomes log** at `~/.claude/audit/session-outcomes-YYYY-MM-DD.log` feeds reflection skill for calibration analysis.

## Why

The existing Stop hook gates negative claims ("you didn't verify") but never emits a positive signal. This adds the positive signal *without* committing the theater pattern the constitution warns against — the cheap heuristic (bash pattern-match) is informational; the authoritative claim routes through an LLM judge with explicit user accountability.

## Testing done

- `done-hook_test.sh` — 7/7 scenarios PASS (NO_GOAL, LIKELY_MET, PARTIAL, NO_EVIDENCE, debounce, stderr block, <300ms perf).
- `session-goal-init_test.sh` — 3/3 PASS.
- `goal/tests/test_goal_skill.sh` — 4/4 PASS.
- `done/tests/test_eval.py` — 5/5 PASS (pytest, mocks `_invoke_nat`).
- `done/tests/test_skill_integration.sh` — 2/2 PASS.
- `shellcheck` — clean on all `.sh` files.
- `markdownlint-cli2` — clean on spec + plan.
- Live smoke — verified hook fires in a real Claude session and `/done` writes correct outcomes entry.

## Breaking changes

None. New hooks are peers (Stop) or supplementary (SessionStart) — they never block existing flow. `context-watch.sh` is untouched.

## Follow-ups (not in this PR)

- OTel uploader (v2)
- Refactor `panel/dispatch.py` + `done/eval.py` into shared `~/.claude/lib/` (v2)
- Mandatory goal-setting (v2, after data-driven adoption review)
- Extend `reflection/scripts/analyze-sessions.sh` with named modes for the new jq queries

## Spec + plan

- Spec: `docs/superpowers/specs/2026-05-18-done-hook-design.md`
- Plan: `docs/superpowers/plans/2026-05-18-done-hook-plan.md`

## Closes / Refs

References handoff `~/.claude/audit/handoffs/2026-05-15-2000-handoff.md`.
EOF
)"
```

- [ ] **Step 3: Note PR number**

Capture the PR number reported by `gh pr create` — it's needed for Task 22's three-panel review.

---

## Task 22: Three-panel PR review (PA + QA + DA)

**Goal:** Trigger the three-panel review pattern documented in CLAUDE.md / the recommendation-panel v3 spec.

**Files:** Comments on the PR; no source changes unless reviewers flag issues.

- [ ] **Step 1: Dispatch principal-engineer subagent for architecture review**

Use the Agent tool with `subagent_type: principal-engineer`:

> Review PR #<N> on feat/done-hook (done-hook + session-goal protocol). Check architecture against ~/.claude/CLAUDE.md + ~/.claude/rules/. Focus areas:
> 1. Atomicity — does done-hook.sh bundle concerns?
> 2. YAGNI — any speculative abstractions?
> 3. Security — `~/.claude/` write safety; transcript_path parsing.
> 4. TDD adherence — did tests precede impl per commit log?
> 5. Coordination with context-watch.sh — does it stomp on stderr / output?
> Output: VERDICT (APPROVE / CHANGES_REQUESTED / BLOCK) + bulleted findings. Post the review via `gh pr review <N> --body "$(...)"`.

- [ ] **Step 2: Dispatch qa-engineer subagent for test quality**

Use the Agent tool with `subagent_type: qa-engineer`:

> Review PR #<N> test quality. Apply the theater-test rule (constitution.md): does every test fail when its subject is broken? For each test:
> 1. Is the assertion meaningful (not `expect(true)` etc.)?
> 2. If you deleted the implementation, would the test detect the breakage?
> 3. Are edge cases / error paths covered, not just happy paths?
> 4. Does the perf scenario (#7 in done-hook_test.sh) accurately reflect the budget?
> 5. Mock discipline — does test_eval.py only mock _invoke_nat (one layer)?
> Output: VERDICT + finding list. Post via `gh pr review <N>`.

- [ ] **Step 3: Dispatch devil's-advocate (if NAT panel is wired up)**

If the user's recommendation-panel v3 is live, the panel can be invoked separately. Otherwise: use the Agent tool with a `principal-engineer` subagent and a DA prompt:

> Devil's advocate review of PR #<N>. Find the strongest reason this design is wrong. Consider: hidden assumptions, edge cases, alternative approaches better-fit to the brief. Specifically scrutinize:
> 1. The bash pattern-match approach in done-hook.sh — when does it falsely match? When does it falsely miss?
> 2. The NAT-backed /done — what if NAT is consistently wrong? What's the user's recourse?
> 3. The deliberate code duplication between panel/dispatch.py and done/eval.py — is the YAGNI cost worth the maintenance overhead?
> 4. Soft rollout — without mandatory goal-setting, will most sessions just produce NO_GOAL entries?
> Output: counter-arguments, then VERDICT (HOLD / OVERTURN). Post via `gh pr review <N>`.

- [ ] **Step 4: Address findings**

If any panelist blocks or requests changes:
- Address inline in a new commit.
- Re-run all tests + linters to verify.
- Push the fix; re-request review (mark relevant comment as resolved).
- Re-dispatch the specific panelist that raised the issue, NOT all three (per the panel re-entry guard pattern).

- [ ] **Step 5: When all three approve, mark PR ready**

```bash
gh pr ready <N>
```

- [ ] **Step 6: Wait for CI green**

```bash
gh pr checks <N> --watch
```

Expected: all checks PASS.

- [ ] **Step 7: Admin-merge to main**

```bash
gh pr merge <N> --squash --delete-branch --admin
```

Squash commit message should match the conventional commit format (`feat(hooks+skills): done-hook + session-goal protocol`).

- [ ] **Step 8: Update memory**

After merge, optionally save a `claude-tooling/decisions` MemPalace drawer noting:
- The deliberate panel-flag override on Q4 (Stop hook auto-detect — accepted with evidence-only stderr framing).
- The NAT-backed `/done` integration as the precedent for future hook+skill pairs (hook = bash, reasoning = NAT-Python).

---

## Self-review

After writing this plan, the following checks were applied (per writing-plans skill):

**1. Spec coverage:**

| Spec section | Task(s) covering it |
|---|---|
| §1 Goal file format | Task 12 (initial write), Task 13 (append) |
| §2 SessionStart nudge hook | Task 1 + Task 2 |
| §3 Stop verdict hook | Tasks 3 - 10 (one task per scenario or feature) |
| §4 /goal skill | Tasks 11 - 13 |
| §5 /done skill | Tasks 14 - 16 |
| §6 Outcomes log JSONL schema | Tasks 4, 6, 8, 16 (writes from both hook and skill) |
| §7 Reflection integration | Out of scope for v1 PR (Task 22 follow-up); no code change needed |
| §8 OTel opt-in | Out of scope for v1; flagged as follow-up in PR body |
| §Performance & concurrency | Task 10 (perf gate), spec covers concurrency design |
| §Testing | Embedded in every implementation task |
| §Failure modes | Implementation tests cover the key modes; rest are documented |
| §Sandbox rules | Task 20 (deploy) requires `dangerouslyDisableSandbox` per CLAUDE.md |
| §Out of scope | Documented in PR body |
| §Acceptance criteria | Tasks 20 + 22 verify each |

No spec section uncovered.

**2. Placeholder scan:** No `TBD` / `TODO` / `implement later` markers. All code blocks contain complete content. Test assertions are concrete.

**3. Type / name consistency:**
- `EVIDENCE_RECORDS` consistent across Tasks 6, 7, 8 in done-hook.sh.
- `evaluate(goal_stanza, evidence, user_claim, model)` consistent in Tasks 14, 15, 16.
- `_invoke_nat(prompt, model, max_tokens)` signature stable across Tasks 14, 15.
- `nat_verdict` enum values `AGREE / DISAGREE / INSUFFICIENT_EVIDENCE / ERROR / n/a` consistent.
- `user.evaluator` enum `nat-goal-evaluator / user_only / none` consistent.

No mismatches found.

**4. Task granularity check:** All steps are 2-5 minutes of work. Each TDD cycle is split: failing test commit, then implementation commit. Commits are signed (`-s`) — SSH signature is auto-applied by existing `commit.gpgsign=true` config.

If gaps surface during execution, the executing-plans skill allows mid-execution amendments via `git commit -s` on this plan file before continuing.
