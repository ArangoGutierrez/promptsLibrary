# Goal-Origin Anchor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bind each `/goal` stanza to the git `remote.origin.url` at write time; statusline warns on cwd-vs-goal-file project mismatch.

**Architecture:** Add an `Origin: <url>` line below `Goal:` in each stanza when cwd has a git origin (omit entirely otherwise). At render, statusline parses the last stanza's `Origin:`, compares to current cwd's `git config --get remote.origin.url`, appends ` ⚠ wrong-repo` to the goal segment when both sides are non-empty and differ. Observe-only; no downstream behavior changes.

**Tech Stack:** Bash, awk, `git config`, `shellcheck`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-26-goal-origin-anchor-design.md` (commit `a8d28ec`).

**Execution method:** solo (single-file changes per task, no design judgment).

**Working tree:** `/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/` on branch `feat/goal-origin-anchor`.

**Sandbox / signing rules carried forward:**

- `.claude/` writes are sandbox-blocked: set `dangerouslyDisableSandbox: true` on Bash calls that read or write under `.claude/`, including `shellcheck`, harness runs (`bash <test>.sh`), and `git add`/`commit`.
- `mktemp` in `$TMPDIR` is also sandbox-blocked: any harness invocation that internally calls `mktemp -d` needs the flag.
- All commits signed via `git commit -s` only. Never pass `-S`, `--no-gpg-sign`, or `--no-verify`.
- No `gh`, no `git push`, no Slack/email — local commits only. PR-open is the user's explicit action, not part of this plan.

---

## File structure

Three files touched:

| File | Responsibility |
|---|---|
| `.claude/skills/goal/goal.sh` | Writes the `Origin:` line into each stanza when cwd has a git origin. |
| `.claude/skills/goal/tests/test_goal_skill.sh` | Two new scenarios assert the write behavior (origin-present and origin-absent). |
| `.claude/statusline.sh` | Reads `Origin:` from the last stanza, compares to current cwd's `git config`, appends mismatch tag when both sides non-empty and differ. |

No new files. No new dependencies. No changes to `done-hook.sh`, `done.sh`, or `eval.py`.

---

## Task 1: Add scenario A (Origin written when cwd has remote) — RED

**Files:** Modify `.claude/skills/goal/tests/test_goal_skill.sh`.

**Insertion point:** After scenario 4's closing `fi`, before the final `echo "==== Results: ..."` block.

- [ ] **Step 1: Inspect baseline**

```bash
shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh
echo "shellcheck exit=$?"
bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh 2>&1 | tail -8
```

Expected: shellcheck exit 0; harness reports `4 passed, 0 failed`.

- [ ] **Step 2: Append scenario A to the test harness**

Find the final block of the test file (after the four existing scenario `if/elif/else/fi` blocks, before the final `echo` / `==== Results:`). Append the following block before the final echo:

```bash
# Scenario A: cwd has a git origin → stanza records 'Origin: <url>'
UUID_A="goalt00a-aaaa-bbbb-cccc-00000000000a"
HOME_A="$TMP/hA"
INPUT_A=$'Goal: scenario A\nAcceptance:\n- one'
WORK_A="$TMP/repoA"
mkdir -p "$WORK_A"
( cd "$WORK_A" && git init -q && git remote add origin git@example.com:foo/bar.git )
( cd "$WORK_A" && run_goal "$HOME_A" "$UUID_A" "$INPUT_A" >/dev/null 2>&1 )
FILE_A="$HOME_A/.claude/audit/session-goals/$UUID_A.md"
if [ ! -f "$FILE_A" ]; then
  echo "FAIL: scenario A — goal file not created"; FAIL=$((FAIL+1))
elif ! grep -q "^Origin: git@example.com:foo/bar.git$" "$FILE_A"; then
  echo "FAIL: scenario A — Origin line missing or wrong"
  echo "  got: $(grep -E '^(Goal|Origin):' "$FILE_A" | head -4)"
  FAIL=$((FAIL+1))
else
  echo "PASS: scenario A — Origin recorded from cwd's git remote"; PASS=$((PASS+1))
fi
```

Use the Edit tool with a sufficiently unique anchor. The unique anchor inside the existing test file is the final results-echo block (`echo "==== Results: ${PASS} passed, ${FAIL} failed ===="` preceded by a blank line and `echo`). Insert the new block immediately above that echo, separated by a blank line.

- [ ] **Step 3: Run harness — confirm RED**

```bash
bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh 2>&1 | tail -10
```

Expected: 4 existing scenarios PASS; scenario A FAILS with `Origin line missing or wrong`. Total: `4 passed, 1 failed`. Exit code 1.

- [ ] **Step 4: shellcheck must remain clean**

```bash
shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh
echo "shellcheck exit=$?"
```

Expected: exit 0.

- [ ] **Step 5: Commit RED**

```bash
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor add .claude/skills/goal/tests/test_goal_skill.sh
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor commit -s -m "test(skills/goal): assert Origin recorded from cwd's git remote (RED)

Scenario A: when /goal runs in a cwd that is a git repo with an
'origin' remote, the written stanza must contain an
'Origin: <url>' line below the 'Goal:' line.

Test currently FAILS — goal.sh does not yet write the Origin line.
Fix lands in the next commit."
```

---

## Task 2: Implement Origin-write in `goal.sh` — GREEN

**Files:** Modify `.claude/skills/goal/goal.sh`.

- [ ] **Step 1: Read current goal.sh**

```bash
cat /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/goal.sh
```

Expected: the existing skill from PR #19 (UUID resolution + stanza-write block ending with the heredoc-style `{ ... } >> "$GOAL_FILE"` group).

- [ ] **Step 2: Resolve `ORIGIN` before the append block**

Use the Edit tool. Find the existing block:

```bash
# Strip leading "amend " keyword if present (user signal, not behavior change)
INPUT="${INPUT#amend }"
```

Replace with:

```bash
# Strip leading "amend " keyword if present (user signal, not behavior change)
INPUT="${INPUT#amend }"

# Project anchor: git remote.origin.url of the cwd at write time.
# Empty when cwd is not a git repo OR the repo has no 'origin' remote.
# Recorded in the stanza so the statusline can warn on cwd-vs-goal mismatch.
ORIGIN=$(git config --get remote.origin.url 2>/dev/null || true)
```

- [ ] **Step 3: Add `Origin:` to the stanza when non-empty**

Find the current stanza-write block:

```bash
{
  [ "$PREPEND_NL" -eq 1 ] && echo ""
  echo "$HEADER"
  echo "$INPUT"
} >> "$GOAL_FILE"
```

Replace with:

```bash
{
  [ "$PREPEND_NL" -eq 1 ] && echo ""
  echo "$HEADER"
  # Inject 'Origin: <url>' immediately after the 'Goal:' line if origin known.
  # $INPUT format is: "Goal: ...\nAcceptance:\n- ..."  →  split at first newline.
  if [ -n "$ORIGIN" ]; then
    GOAL_LINE="${INPUT%%$'\n'*}"
    REST="${INPUT#*$'\n'}"
    if [ "$GOAL_LINE" = "$INPUT" ]; then
      # No newline in $INPUT — single-line goal body.
      echo "$INPUT"
      echo "Origin: $ORIGIN"
    else
      echo "$GOAL_LINE"
      echo "Origin: $ORIGIN"
      echo "$REST"
    fi
  else
    echo "$INPUT"
  fi
} >> "$GOAL_FILE"
```

This preserves the existing single-block append semantic. When `ORIGIN` is empty, output is byte-identical to today. When non-empty, the `Origin:` line is injected between the `Goal:` line and the `Acceptance:` block.

- [ ] **Step 4: Run shellcheck on the updated file**

```bash
shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/goal.sh
echo "shellcheck exit=$?"
```

Expected: exit 0. If shellcheck warns about unused vars from the split (e.g., SC2034), add `# shellcheck disable=` only for legitimate warnings; do not blanket-suppress.

- [ ] **Step 5: Run harness — confirm GREEN**

```bash
bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh 2>&1 | tail -8
```

Expected: 5 passed, 0 failed. Scenario A now PASSES.

- [ ] **Step 6: Commit GREEN**

```bash
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor add .claude/skills/goal/goal.sh
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor commit -s -m "feat(skills/goal): record git origin in each stanza

Resolves 'git config --get remote.origin.url' from the cwd at
write time. When non-empty, the stanza now contains an
'Origin: <url>' line immediately below 'Goal:'. When empty (no
.git, or repo with no origin remote), the line is omitted —
preserves backward compat with pre-spec goal files.

Spec: docs/superpowers/specs/2026-05-26-goal-origin-anchor-design.md
Tests: 5/5 PASS.
shellcheck: clean."
```

---

## Task 3: Add scenario B (Origin omitted when cwd has no remote)

**Files:** Modify `.claude/skills/goal/tests/test_goal_skill.sh`.

This scenario passes immediately on the Task 2 implementation. Single commit (test + verify, no impl change).

- [ ] **Step 1: Append scenario B to the test harness**

Use the Edit tool. Find scenario A's closing `fi` (from Task 1). Append the following block immediately after it, before the final results echo:

```bash
# Scenario B: cwd has no git remote → stanza has no 'Origin:' line
UUID_B="goalt00b-aaaa-bbbb-cccc-00000000000b"
HOME_B="$TMP/hB"
INPUT_B=$'Goal: scenario B\nAcceptance:\n- one'
WORK_B="$TMP/repoB"
mkdir -p "$WORK_B"  # plain dir, no git init
( cd "$WORK_B" && run_goal "$HOME_B" "$UUID_B" "$INPUT_B" >/dev/null 2>&1 )
FILE_B="$HOME_B/.claude/audit/session-goals/$UUID_B.md"
if [ ! -f "$FILE_B" ]; then
  echo "FAIL: scenario B — goal file not created"; FAIL=$((FAIL+1))
elif grep -q "^Origin: " "$FILE_B"; then
  echo "FAIL: scenario B — Origin line should be absent"
  echo "  got: $(grep '^Origin:' "$FILE_B")"
  FAIL=$((FAIL+1))
else
  echo "PASS: scenario B — Origin omitted when cwd has no git remote"; PASS=$((PASS+1))
fi
```

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh
echo "shellcheck exit=$?"
```

Expected: exit 0.

- [ ] **Step 3: Run harness — scenario B passes immediately**

```bash
bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh 2>&1 | tail -10
```

Expected: 6 passed, 0 failed.

- [ ] **Step 4: Commit**

```bash
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor add .claude/skills/goal/tests/test_goal_skill.sh
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor commit -s -m "test(skills/goal): assert Origin omitted when cwd has no git remote

Scenario B: when /goal runs in a plain (non-git) directory, the
written stanza must NOT contain an 'Origin:' line. Documents the
intentional backward-compat behavior (pre-spec goal files and
non-git cwds both produce stanzas without the anchor).

Passes immediately on the Task 2 implementation; no code change."
```

---

## Task 4: Statusline reads `Origin:` + warns on mismatch

**Files:** Modify `.claude/statusline.sh`.

This task changes statusline rendering. There is no automated test harness for statusline; verification is via running the script directly with synthesized JSON in 4 controlled scenarios. Single commit (impl + manual verify).

- [ ] **Step 1: Inspect baseline statusline.sh**

```bash
shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh
echo "shellcheck exit=$?"
wc -l /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh
```

Expected: shellcheck exit 0; ~68 lines (the version from PR #19).

- [ ] **Step 2: Extract goal origin AND current cwd origin in the goal-segment block**

Use the Edit tool. Find the current goal-extraction block in `.claude/statusline.sh`:

```bash
# Session goal (from done-hook protocol — ~/.claude/audit/session-goals/<id>.md)
GOAL="(no goal)"
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$SESSION_ID" ]; then
    GOAL_FILE="${HOME}/.claude/audit/session-goals/${SESSION_ID}.md"
    if [ -f "$GOAL_FILE" ]; then
        # Extract last stanza's "Goal: " line via awk + grep + sed
        RAW=$(awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$GOAL_FILE" \
              | grep -m1 '^Goal: ' | sed 's/^Goal: //; s/[[:space:]]*$//')
        if [ -n "$RAW" ]; then
            if [ "${#RAW}" -gt 40 ]; then RAW="${RAW:0:38}…"; fi
            GOAL="$RAW"
        fi
    fi
fi
```

Replace with:

```bash
# Session goal (from done-hook protocol — ~/.claude/audit/session-goals/<id>.md)
GOAL="(no goal)"
GOAL_ORIGIN=""
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$SESSION_ID" ]; then
    GOAL_FILE="${HOME}/.claude/audit/session-goals/${SESSION_ID}.md"
    if [ -f "$GOAL_FILE" ]; then
        # Extract last stanza body once, then pull Goal: and Origin: from it.
        STANZA=$(awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$GOAL_FILE")
        RAW=$(echo "$STANZA" | grep -m1 '^Goal: ' | sed 's/^Goal: //; s/[[:space:]]*$//')
        GOAL_ORIGIN=$(echo "$STANZA" | grep -m1 '^Origin: ' | sed 's/^Origin: //; s/[[:space:]]*$//')
        if [ -n "$RAW" ]; then
            if [ "${#RAW}" -gt 40 ]; then RAW="${RAW:0:38}…"; fi
            GOAL="$RAW"
        fi
    fi
fi

# Project-anchor mismatch detection. Append " ⚠ wrong-repo" when both the
# goal-file Origin and the current cwd's git remote are known AND differ.
# Empty on either side → no check, no warning (preserves backward compat
# with pre-spec goal files and non-git cwds).
CUR_ORIGIN=$(git config --get remote.origin.url 2>/dev/null || true)
GOAL_WARN=""
if [ -n "$GOAL_ORIGIN" ] && [ -n "$CUR_ORIGIN" ] && [ "$GOAL_ORIGIN" != "$CUR_ORIGIN" ]; then
    GOAL_WARN=" ⚠ wrong-repo"
fi
```

- [ ] **Step 3: Append the mismatch tag to the goal segment output**

Find the current output-assembly line:

```bash
PARTS="$PARTS | 🎯 $GOAL"
```

Replace with:

```bash
PARTS="$PARTS | 🎯 ${GOAL}${GOAL_WARN}"
```

- [ ] **Step 4: shellcheck**

```bash
shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh
echo "shellcheck exit=$?"
```

Expected: exit 0, no warnings.

- [ ] **Step 5: Manual verify — matching origin (no warning)**

```bash
TMP=$(mktemp -d)
UUID="match01-aaaa-bbbb-cccc-000000000001"
mkdir -p "$TMP/.claude/audit/session-goals"
ORIGIN_URL="git@example.com:foo/bar.git"
cat > "$TMP/.claude/audit/session-goals/$UUID.md" <<GOAL
## Initial 2026-05-26T10:00:00Z
Goal: matching test
Origin: $ORIGIN_URL
Acceptance:
- one
GOAL
WORK="$TMP/work"
mkdir -p "$WORK"
( cd "$WORK" && git init -q && git remote add origin "$ORIGIN_URL" )

JSON='{"model":{"display_name":"Opus"},"session_id":"'"$UUID"'","worktree":{"branch":"feat/x"},"workspace":{"git_worktree":"x","current_dir":"'"$WORK"'"},"context_window":{"total_input_tokens":1000,"total_output_tokens":0,"used_percentage":0}}'
( cd "$WORK" && echo "$JSON" | HOME="$TMP" bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh )
rm -rf "$TMP"
```

Expected output ends with `| 🎯 matching test | 1.0k tok (0%)` — no warning suffix.

- [ ] **Step 6: Manual verify — mismatching origin (warning appended)**

```bash
TMP=$(mktemp -d)
UUID="mismatch-aaaa-bbbb-cccc-000000000001"
mkdir -p "$TMP/.claude/audit/session-goals"
cat > "$TMP/.claude/audit/session-goals/$UUID.md" <<'GOAL'
## Initial 2026-05-26T10:00:00Z
Goal: mismatching test
Origin: git@example.com:projectA/repoA.git
Acceptance:
- one
GOAL
WORK="$TMP/work"
mkdir -p "$WORK"
( cd "$WORK" && git init -q && git remote add origin git@example.com:projectB/repoB.git )

JSON='{"model":{"display_name":"Opus"},"session_id":"'"$UUID"'","worktree":{"branch":"feat/x"},"workspace":{"git_worktree":"x","current_dir":"'"$WORK"'"},"context_window":{"total_input_tokens":1000,"total_output_tokens":0,"used_percentage":0}}'
( cd "$WORK" && echo "$JSON" | HOME="$TMP" bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh )
rm -rf "$TMP"
```

Expected output contains `🎯 mismatching test ⚠ wrong-repo` — warning is appended after the goal text.

- [ ] **Step 7: Manual verify — goal file without `Origin:` (backward compat, no warning)**

```bash
TMP=$(mktemp -d)
UUID="legacy01-aaaa-bbbb-cccc-000000000001"
mkdir -p "$TMP/.claude/audit/session-goals"
cat > "$TMP/.claude/audit/session-goals/$UUID.md" <<'GOAL'
## Initial 2026-05-26T10:00:00Z
Goal: legacy goal file
Acceptance:
- one
GOAL
WORK="$TMP/work"
mkdir -p "$WORK"
( cd "$WORK" && git init -q && git remote add origin git@example.com:foo/bar.git )

JSON='{"model":{"display_name":"Opus"},"session_id":"'"$UUID"'","worktree":{"branch":"feat/x"},"workspace":{"git_worktree":"x","current_dir":"'"$WORK"'"},"context_window":{"total_input_tokens":1000,"total_output_tokens":0,"used_percentage":0}}'
( cd "$WORK" && echo "$JSON" | HOME="$TMP" bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh )
rm -rf "$TMP"
```

Expected output ends with `| 🎯 legacy goal file | 1.0k tok (0%)` — no warning, because goal file has no Origin.

- [ ] **Step 8: Manual verify — session cwd is not a git repo (no warning)**

```bash
TMP=$(mktemp -d)
UUID="nogit001-aaaa-bbbb-cccc-000000000001"
mkdir -p "$TMP/.claude/audit/session-goals"
cat > "$TMP/.claude/audit/session-goals/$UUID.md" <<'GOAL'
## Initial 2026-05-26T10:00:00Z
Goal: session in plain dir
Origin: git@example.com:foo/bar.git
Acceptance:
- one
GOAL
WORK="$TMP/work"
mkdir -p "$WORK"  # plain dir, no git init

JSON='{"model":{"display_name":"Opus"},"session_id":"'"$UUID"'","worktree":{"branch":"feat/x"},"workspace":{"git_worktree":"x","current_dir":"'"$WORK"'"},"context_window":{"total_input_tokens":1000,"total_output_tokens":0,"used_percentage":0}}'
( cd "$WORK" && echo "$JSON" | HOME="$TMP" bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh )
rm -rf "$TMP"
```

Expected output ends with `| 🎯 session in plain dir | 1.0k tok (0%)` — no warning, because current cwd has no git origin.

- [ ] **Step 9: Perf sanity — 10 runs of the matching scenario, target <50ms aspirational / 300ms ceiling**

```bash
TMP=$(mktemp -d)
UUID="perf001-aaaa-bbbb-cccc-000000000001"
mkdir -p "$TMP/.claude/audit/session-goals"
ORIGIN_URL="git@example.com:perf/repo.git"
cat > "$TMP/.claude/audit/session-goals/$UUID.md" <<GOAL
## Initial 2026-05-26T10:00:00Z
Goal: perf test
Origin: $ORIGIN_URL
Acceptance:
- one
GOAL
WORK="$TMP/work"
mkdir -p "$WORK"
( cd "$WORK" && git init -q && git remote add origin "$ORIGIN_URL" )
JSON='{"model":{"display_name":"Opus"},"session_id":"'"$UUID"'","worktree":{"branch":"feat/x"},"workspace":{"git_worktree":"x","current_dir":"'"$WORK"'"},"context_window":{"total_input_tokens":45000,"total_output_tokens":2300,"used_percentage":23}}'

for i in 1 2 3 4 5 6 7 8 9 10; do
    START=$(date +%s%N)
    ( cd "$WORK" && echo "$JSON" | HOME="$TMP" bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh >/dev/null )
    END=$(date +%s%N)
    echo "run $i: $(( (END - START) / 1000000 ))ms"
done
rm -rf "$TMP"
```

Expected: all 10 runs under 300ms; typical median 100-130ms (adds one `git config` subprocess to the existing ~99ms baseline).

- [ ] **Step 10: Commit**

```bash
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor add .claude/statusline.sh
git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor commit -s -m "feat(statusline): warn on goal-vs-cwd project mismatch

Reads 'Origin: <url>' from the goal file's last stanza (added by the
/goal write path in this PR). Resolves 'git config --get remote.origin.url'
from the current cwd. When both sides are non-empty and differ,
appends ' ⚠ wrong-repo' to the goal segment.

When either side is empty (pre-spec goal files without Origin, or
session cwd outside a git repo / with no origin remote), no comparison
is performed and no warning is rendered — preserves backward compat.

Spec: docs/superpowers/specs/2026-05-26-goal-origin-anchor-design.md
shellcheck: clean.
Manual verify: 4 scenarios (matching, mismatching, legacy goal, non-git cwd).
Perf: 10 runs all <300ms ceiling (adds ~5-10ms to baseline)."
```

---

## Final verification

After Task 4 commits, run the full sweep once more to confirm no regressions:

```bash
echo "=== goal skill (6) ===" && bash /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh 2>&1 | tail -10
echo "=== shellcheck (all changed) ===" && shellcheck /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/goal.sh \
  /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/skills/goal/tests/test_goal_skill.sh \
  /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/.claude/statusline.sh \
  && echo "all clean"
echo "=== commits on feat/goal-origin-anchor ===" && git -C /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor log --oneline origin/main..HEAD
```

Expected: goal harness 6/6 PASS, shellcheck clean on all three files, four commits on the branch (Task 1 RED, Task 2 GREEN, Task 3, Task 4).

---

## Self-review

**1. Spec coverage**

| Spec section | Task(s) covering it |
|---|---|
| §Schema change (`Origin:` line below `Goal:`) | Tasks 2 (write), 4 (read) |
| §`/goal` write path | Task 2 |
| §Statusline read path | Task 4 |
| §Failure mode: no Origin in file | Task 3 (Scenario B) + Task 4 Step 7 |
| §Failure mode: cwd not a git repo | Task 4 Step 8 |
| §Backward compatibility | Task 3 (Scenario B) + Task 4 Step 7 |
| §Test scenario A (Origin written) | Tasks 1+2 |
| §Test scenario B (Origin omitted) | Task 3 |
| §Statusline manual: matching | Task 4 Step 5 |
| §Statusline manual: mismatching | Task 4 Step 6 |
| §Statusline manual: file without Origin | Task 4 Step 7 |
| §Statusline manual: non-git cwd | Task 4 Step 8 |
| §Performance budget | Task 4 Step 9 |
| §Out of scope items | Not implemented; documented in spec |

No spec section uncovered.

**2. Placeholder scan**

No `TBD` / `TODO` / `implement later` / "Add appropriate error handling" / "Similar to Task N" markers. All code blocks contain complete content. Test assertions are concrete (exact grep patterns).

**3. Type / name consistency**

- `ORIGIN`, `GOAL_ORIGIN`, `CUR_ORIGIN`, `GOAL_WARN` — variable names consistent across Task 2 (write side) and Task 4 (read side).
- File paths `.claude/skills/goal/goal.sh`, `.claude/skills/goal/tests/test_goal_skill.sh`, `.claude/statusline.sh` — consistent in every task.
- Worktree path `/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/goal-origin-anchor/` — consistent throughout.
- Scenario naming: `Scenario A` (origin written), `Scenario B` (origin omitted) — consistent.
- Test fixture URLs (`git@example.com:foo/bar.git`, `git@example.com:projectA/repoA.git`, etc.) — distinct per scenario; no collisions.

**4. Task granularity check**

Each step is one action (2-5 minutes of work). Test commit (Task 1) precedes implementation commit (Task 2) per TDD discipline. Task 3 is a single commit because the scenario passes immediately on Task 2's implementation (documented honestly in the commit message). Task 4 is a single commit because there is no automated test harness for statusline; manual verification is captured in the commit message body.

All commits signed (`-s`); SSH signature applied automatically via `commit.gpgsign=true`.

If gaps surface during execution, the executing-plans skill allows mid-execution amendments via `git commit -s` on this plan file before continuing.
