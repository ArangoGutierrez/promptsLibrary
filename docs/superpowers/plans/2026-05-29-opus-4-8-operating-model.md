# Opus 4.8 Operating Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the `~/.claude` config with Opus 4.8 and make the `goal → brainstorm → plan → TDD → review → finishing` daily flow the soft-gated default, via config edits plus one new stateless `/day` driver skill.

**Architecture:** Edit the version-controlled mirror in the repo's `.claude/` (Track A), then deploy to live `~/.claude/` with `scripts/deploy.sh` (no `--delete`). The only new code is `skills/day/day.sh` (pure decision logic + thin I/O glue) with a `day_test.sh` unit test. All other changes are config/docs edits or deletions.

**Tech Stack:** Bash (hooks + driver), JSON (`settings.json`), Markdown (CLAUDE.md, skill docs), `rsync` via `deploy.sh`, `shellcheck`, `markdownlint`, `typos`.

**Execution method: solo.** Rationale: changes are sequential and low-risk (config + docs + one ~60-line shell script); there are no independent parallel subsystems to warrant the team path. TDD applies to the two shell scripts; JSON/Markdown edits are edit-then-verify (JSON validity + grep), since red-green TDD does not apply to declarative config.

**Spec:** [docs/superpowers/specs/2026-05-29-opus-4-8-operating-model-design.md](../specs/2026-05-29-opus-4-8-operating-model-design.md)

**Working directory:** `.worktrees/opus-4-8-operating-model` (branch `docs/opus-4-8-operating-model`, off current `main`). All `git`/path references below are relative to the repo root in that worktree.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `.claude/settings.json` | Harness config | Modify — remove Stop-prompt block; remove `tdd-guard.sh` from Write+Edit `PreToolUse` |
| `.claude/CLAUDE.md` | Engineering standards / workflow | Modify — Daily Flow section, Effort (4.8) section, `gh` note, de-hook TDD/Execution references |
| `.claude/hooks/session-goal-init.sh` | SessionStart goal nudge | Modify — append 1-line flow reminder inside the no-goal branch |
| `.claude/hooks/session-goal-init_test.sh` | Test for the above | Modify — add assertion for the flow-reminder line |
| `.claude/skills/day/day.sh` | Stateless stage classifier + printer | Create |
| `.claude/skills/day/day_test.sh` | Unit test for `classify_stage`/`recommend` | Create |
| `.claude/skills/day/SKILL.md` | `/day` skill entry (runs `day.sh`, presents output) | Create |
| `.claude/hooks/tdd-guard.sh` | Removed PreToolUse TDD enforcer | Delete |

**Naming contract (used across tasks):** `day.sh` exposes two pure functions — `classify_stage <has_goal> <has_spec> <has_plan> <tree_dirty> <work_committed>` (each arg `1`/`0`) echoing one of `no-goal|needs-brainstorm|needs-plan|ready-to-impl|mid-impl|needs-review`, and `recommend <stage>` echoing the one-line next action. `main` is guarded so sourcing the file does not execute it.

---

## Task 1: Remove the Stop-prompt verification hook from settings.json

Implements spec D4 / audit F-SETTINGS-01, F-HOOK-03. Opus 4.8 self-flags flaws in its own work (4× less likely to let them pass), so the per-turn LLM verification round-trip is redundant cost. The `context-watch.sh` + `done-hook.sh` Stop entry stays.

**Files:**
- Modify: `.claude/settings.json:175-196` (the `Stop` array)

- [ ] **Step 1: Remove the prompt-type Stop hook object**

Delete this object (the first element of the `Stop` array, lines 176–183) in full, including its trailing comma so the `done-hook` object becomes the sole element:

```json
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check if the assistant's last response claims work is complete, fixed, or passing. If it does, verify: did the assistant actually run a verification command (test, build, lint) and show the output BEFORE making the claim? If the claim is unverified, respond with 'STOP: You claimed completion without running verification. Run the relevant test/build command first.' Otherwise respond with 'OK'."
          }
        ]
      },
```

The resulting `Stop` array must contain exactly one object — the one whose hooks are `context-watch.sh` and `done-hook.sh`.

- [ ] **Step 2: Verify JSON validity and absence of the prompt hook**

Run:
```bash
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "JSON OK"
grep -c '"type": "prompt"' .claude/settings.json
```
Expected: `JSON OK`, and the `grep -c` prints `0`.

- [ ] **Step 3: Confirm the done-hook Stop entry survived**

Run:
```bash
grep -c 'done-hook.sh' .claude/settings.json
```
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -sS -m "chore(settings): remove Stop-prompt verification hook

Opus 4.8 self-flags flaws in its own work, making the per-turn LLM
verification round-trip redundant cost (spec D4; audit F-SETTINGS-01)."
```

---

## Task 2: Remove tdd-guard.sh from the PreToolUse matchers

Implements spec D4 context / audit F-HOOK-02. TDD moves to skill-only (`superpowers:test-driven-development` + `/tdd-protocol`), consistent with the soft-gate model.

**Files:**
- Modify: `.claude/settings.json` (Write matcher ~line 123, Edit matcher ~line 136)

- [ ] **Step 1: Remove the tdd-guard hook from the Write matcher**

In the `PreToolUse` → `"matcher": "Write"` block, delete this object (keep `enforce-worktree.sh` and `validate-year.sh`):

```json
          {
            "type": "command",
            "command": "/Users/eduardoa/.claude/hooks/tdd-guard.sh"
          }
```
Remove the comma after the `validate-year.sh` object so it becomes the last element.

- [ ] **Step 2: Remove the tdd-guard hook from the Edit matcher**

In the `PreToolUse` → `"matcher": "Edit"` block, delete the same `tdd-guard.sh` object (keep `enforce-worktree.sh`), removing the comma after `enforce-worktree.sh` so it becomes the last element.

- [ ] **Step 3: Verify**

Run:
```bash
python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "JSON OK"
grep -c 'tdd-guard.sh' .claude/settings.json
```
Expected: `JSON OK`, and `grep -c` prints `0`.

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -sS -m "chore(settings): drop tdd-guard PreToolUse hook

TDD moves to skill-only (superpowers:test-driven-development,
/tdd-protocol). Soft-gate model; audit F-HOOK-02."
```

---

## Task 3: Update CLAUDE.md — Daily Flow, Effort (4.8), gh note, de-hook TDD refs

Implements spec §4 (default flow + V-model), D2/D5 (effort + `/fast`), audit P0 #7 (`gh` note), and the consequences of Tasks 1–2 (TDD/Execution no longer hook-enforced).

**Files:**
- Modify: `.claude/CLAUDE.md:21-22` (Workflow → Daily Flow), `:30` (Execution Model tdd-guard ref), `:40` (TDD Protocol header), plus two inserts.

- [ ] **Step 1: Replace the `## Workflow` section (lines 21–22)**

Replace:
```markdown
## Workflow
brainstorm → plan (includes execution method) → execute → verify → PR → review → merge
```
with:
```markdown
## Daily Flow (the default)
`goal → brainstorm → plan → execute (TDD) → review → finish`
Run `/day` anytime to see where you are and the single next step.

| Stage | Skill | V-model |
|---|---|---|
| goal | `/goal` | — |
| brainstorm | `superpowers:brainstorming` | Requirements + Design |
| plan | `superpowers:writing-plans` (sets execution method) | Design → tasks |
| execute | `superpowers:test-driven-development` | Coding ↔ Unit |
| review | `requesting-code-review` / `receiving-code-review` | verification pair |
| finish | `superpowers:finishing-a-development-branch` | Integration/System/Acceptance → merge |

Close the day with `/reflection` or `/done`.
Verification pairs are reminders, not gates: Requirements↔Acceptance, Design↔Integration, Coding↔Unit.
```

- [ ] **Step 2: Add an `## Effort (Opus 4.8)` section immediately after `## Principles`**

Insert after the Principles list (after line 19):
```markdown
## Effort (Opus 4.8)
Default `effortLevel: "high"` — best quality/UX balance on 4.8 (≈ 4.7 default token spend, better results). Tune it actively; effort matters more on 4.8 than prior models.
- `low`/`medium`: trivial or latency-sensitive turns (risk under-thinking on complex work)
- `high`: default
- `xhigh`/`max`: deep architecture, gnarly debugging, large multi-step refactors — pair with a large max-output budget
Use `/fast` for trivial turns (cheaper throughput, same per-token price).
```

- [ ] **Step 3: De-hook the Execution Model and TDD Protocol references**

In `## Execution Model`, change the Workers bullet from:
```markdown
- Workers: implementation in isolated worktrees (TDD enforced by `tdd-guard.sh` hook on all Write/Edit, both team and solo paths)
```
to:
```markdown
- Workers: implementation in isolated worktrees (TDD via `superpowers:test-driven-development` on both team and solo paths)
```

Change the TDD Protocol header from:
```markdown
## TDD Protocol (enforced by hook)
```
to:
```markdown
## TDD Protocol (skill-driven)
```
and change `See /tdd-protocol for full details.` to `Guided by superpowers:test-driven-development and /tdd-protocol; not hook-enforced.`

- [ ] **Step 4: Add the `gh` CLI note inside `## Subagent Discipline` (or a new `## Tooling Notes`)**

Append a new `## Tooling Notes` section before `# Domain Knowledge`:
```markdown
## Tooling Notes
- `gh` CLI is pre-approved and works **unsandboxed**. If a `gh` call fails with a TLS/cert error under the sandbox, re-run it unsandboxed — do not retry sandboxed-first.
```

- [ ] **Step 5: Verify markdown lint + no stale tdd-guard hook reference**

Run:
```bash
markdownlint --config .markdownlint.json .claude/CLAUDE.md 2>&1 | head; echo "ml exit=$?"
grep -n 'tdd-guard' .claude/CLAUDE.md || echo "no tdd-guard refs"
```
Expected: no markdownlint errors; `no tdd-guard refs`.

> Note: `.claude/CLAUDE.md` may be outside the markdownlint CI glob; running it locally is still the quality gate. If markdownlint reports MD-rule errors (e.g., blanks-around-tables/lists), fix them before committing — this is the issue that failed CI on PR #22.

- [ ] **Step 6: Commit**

```bash
git add .claude/CLAUDE.md
git commit -sS -m "docs(claude-md): daily flow default, 4.8 effort guidance, gh note

Reframe workflow as goal->...->finishing with /day; add Opus 4.8 effort
section (keep high; spec D1/D2/D5); add gh-unsandboxed note (audit P0 #7);
mark TDD skill-driven now that tdd-guard is removed."
```

---

## Task 4: Add the flow reminder to session-goal-init.sh (TDD)

Implements spec §4.4. The reminder prints only in the no-goal branch (start-of-day moment), preserving the existing "silent when goal present" contract.

**Files:**
- Modify: `.claude/hooks/session-goal-init_test.sh` (add assertion)
- Modify: `.claude/hooks/session-goal-init.sh:18-22` (add echo line)

- [ ] **Step 1: Write the failing test**

In `.claude/hooks/session-goal-init_test.sh`, after Scenario 1's `run_case` (line 42), add:
```bash
# Scenario 1b: no goal file → output also includes the daily-flow reminder
run_case "no goal file -> flow reminder" \
  "{\"transcript_path\":\"$FAKE_TRANSCRIPT\"}" \
  0 "Run /day to orient" \
  HOME="$TMP"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bash .claude/hooks/session-goal-init_test.sh
```
Expected: FAIL on "no goal file -> flow reminder" — stdout did not match `/Run \/day to orient/`.

- [ ] **Step 3: Add the reminder line to the hook**

In `.claude/hooks/session-goal-init.sh`, inside the `if [ ! -f "$GOAL_FILE" ]; then` block, add a third echo after the existing two (before the closing `fi`):
```bash
  echo "[daily-flow] goal → brainstorm → plan → TDD → review → finish. Run /day to orient."
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
bash .claude/hooks/session-goal-init_test.sh
```
Expected: `==== Results: 4 passed, 0 failed ====` (Scenarios 1, 1b, 2, 3). Note Scenario 2 (goal present → silent) still passes because the new line is inside the no-goal branch.

- [ ] **Step 5: shellcheck**

Run:
```bash
shellcheck .claude/hooks/session-goal-init.sh .claude/hooks/session-goal-init_test.sh
```
Expected: no output (clean).

- [ ] **Step 6: Commit (test + impl together — single behavior addition)**

```bash
git add .claude/hooks/session-goal-init.sh .claude/hooks/session-goal-init_test.sh
git commit -sS -m "feat(hooks): daily-flow reminder in session-goal-init no-goal nudge

Prints the goal->...->finish flow and 'Run /day' only when no goal is set,
preserving the silent-when-goal-present contract (spec §4.4)."
```

---

## Task 5: Create the /day driver script (TDD)

Implements spec §4.3. Pure decision logic is unit-tested; the I/O glue (`main`) is shellcheck-clean and smoke-tested.

**Files:**
- Create: `.claude/skills/day/day_test.sh`
- Create: `.claude/skills/day/day.sh`

- [ ] **Step 1: Write the failing test**

Create `.claude/skills/day/day_test.sh`:
```bash
#!/usr/bin/env bash
# day_test.sh — unit tests for day.sh pure decision logic.
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=day.sh
source "$SCRIPT_DIR/day.sh"

PASS=0; FAIL=0
eq() { # eq <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; PASS=$((PASS+1));
  else echo "FAIL: $1 — expected '$2', got '$3'"; FAIL=$((FAIL+1)); fi
}
has() { # has <name> <needle> <haystack>
  if echo "$3" | grep -q "$2"; then echo "PASS: $1"; PASS=$((PASS+1));
  else echo "FAIL: $1 — '$3' lacks '$2'"; FAIL=$((FAIL+1)); fi
}

eq "no goal"            no-goal          "$(classify_stage 0 0 0 0 0)"
eq "goal, no spec"      needs-brainstorm "$(classify_stage 1 0 0 0 0)"
eq "spec, no plan"      needs-plan       "$(classify_stage 1 1 0 0 0)"
eq "plan, clean, fresh" ready-to-impl    "$(classify_stage 1 1 1 0 0)"
eq "dirty tree"         mid-impl         "$(classify_stage 1 1 1 1 0)"
eq "committed, clean"   needs-review     "$(classify_stage 1 1 1 0 1)"
# precedence: a dirty tree means mid-impl even if prior impl commits exist
eq "dirty beats commit" mid-impl         "$(classify_stage 1 1 1 1 1)"

has "rec no-goal"       "/goal"          "$(recommend no-goal)"
has "rec brainstorm"    "brainstorming"  "$(recommend needs-brainstorm)"
has "rec plan"          "writing-plans"  "$(recommend needs-plan)"
has "rec impl"          "test-driven"    "$(recommend ready-to-impl)"
has "rec review"        "finishing"      "$(recommend needs-review)"

echo; echo "==== Results: ${PASS} passed, ${FAIL} failed ===="
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bash .claude/skills/day/day_test.sh
```
Expected: FAIL — `source: day.sh: No such file` (the script does not exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `.claude/skills/day/day.sh`:
```bash
#!/usr/bin/env bash
# day.sh — stateless daily-flow orienter. Prints the lifecycle with the
# best-guess current stage and one recommended next action. Exit 0 always.
# Pure logic (classify_stage/recommend) is unit-tested in day_test.sh.
set -o pipefail

# classify_stage <has_goal> <has_spec> <has_plan> <tree_dirty> <work_committed>
# Each arg is "1" or "0". Echoes a stage id.
classify_stage() {
  local has_goal="$1" has_spec="$2" has_plan="$3" tree_dirty="$4" work_committed="$5"
  [ "$has_goal" != "1" ] && { echo "no-goal"; return; }
  [ "$has_spec" != "1" ] && { echo "needs-brainstorm"; return; }
  [ "$has_plan" != "1" ] && { echo "needs-plan"; return; }
  [ "$tree_dirty" = "1" ] && { echo "mid-impl"; return; }
  [ "$work_committed" = "1" ] && { echo "needs-review"; return; }
  echo "ready-to-impl"
}

# recommend <stage> — echoes the single next action.
recommend() {
  case "$1" in
    no-goal)          echo "Set today's goal:   /goal" ;;
    needs-brainstorm) echo "Explore the idea:   superpowers:brainstorming" ;;
    needs-plan)       echo "Write the plan:     superpowers:writing-plans" ;;
    ready-to-impl)    echo "Start building:     superpowers:test-driven-development" ;;
    mid-impl)         echo "Continue TDD; mind the verification pair (Coding↔Unit, Design↔Integration, Requirements↔Acceptance)" ;;
    needs-review)     echo "Review then ship:   requesting-code-review → superpowers:finishing-a-development-branch" ;;
    *)                echo "Unknown stage: $1" ;;
  esac
}

# detect_signals — best-effort, prints "has_goal has_spec has_plan tree_dirty work_committed".
# Heuristic glue, not unit-tested (covered by smoke test + shellcheck).
detect_signals() {
  local goal_dir="${HOME}/.claude/audit/session-goals" today has_goal=0 has_spec=0 has_plan=0 tree_dirty=0 work_committed=0
  if [ -n "${CLAUDE_SESSION_ID:-}" ] && [ -f "${goal_dir}/${CLAUDE_SESSION_ID}.md" ]; then
    has_goal=1
  elif [ -d "$goal_dir" ] && [ -n "$(ls -A "$goal_dir" 2>/dev/null)" ]; then
    has_goal=1
  fi
  today="$(date +%Y-%m-%d)"
  ls docs/superpowers/specs/"${today}"-* >/dev/null 2>&1 && has_spec=1
  ls docs/superpowers/plans/"${today}"-* >/dev/null 2>&1 && has_plan=1
  [ -n "$(git status --porcelain 2>/dev/null)" ] && tree_dirty=1
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    git log --oneline origin/main..HEAD -- . ':(exclude)docs/**' 2>/dev/null | grep -q . && work_committed=1
  fi
  echo "$has_goal $has_spec $has_plan $tree_dirty $work_committed"
}

main() {
  local sig stage
  # shellcheck disable=SC2046
  sig="$(detect_signals)"
  # shellcheck disable=SC2086
  stage="$(classify_stage $sig)"
  echo "Daily flow:  goal → brainstorm → plan → execute(TDD) → review → finish"
  echo "Likely here: ${stage}"
  echo "Next:        $(recommend "$stage")"
  echo "(stateless best-guess from goal file + today's spec/plan + git state)"
}

# Only run main when executed directly, not when sourced by the test.
[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
bash .claude/skills/day/day_test.sh
```
Expected: `==== Results: 12 passed, 0 failed ====`.

- [ ] **Step 5: shellcheck both files**

Run:
```bash
chmod +x .claude/skills/day/day.sh
shellcheck .claude/skills/day/day.sh .claude/skills/day/day_test.sh
```
Expected: no output (clean).

- [ ] **Step 6: Smoke-test main()**

Run (from the repo root in the worktree):
```bash
bash .claude/skills/day/day.sh
```
Expected: four lines beginning `Daily flow:`, `Likely here:`, `Next:`, `(stateless...`. The stage reflects current state (e.g. `needs-plan` or `mid-impl`).

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/day/day.sh .claude/skills/day/day_test.sh
git commit -sS -m "feat(day): stateless daily-flow driver script

classify_stage/recommend map a five-signal state tuple to one of six
lifecycle stages and a single next action; detect_signals is best-effort
glue. 12 unit tests cover the classifier (spec §4.3)."
```

---

## Task 6: Create the /day skill entry (SKILL.md)

Implements spec §4.3. The skill runs `day.sh` and presents its output.

**Files:**
- Create: `.claude/skills/day/SKILL.md`

- [ ] **Step 1: Create SKILL.md**

```markdown
---
name: day
description: Orient within the daily development flow (goal → brainstorm → plan → TDD → review → finish). Prints where you likely are and the single next step. Triggered by /day or "where am I in the flow", "what's next", "orient me".
---

# Daily Flow Driver

Run the driver and present its output to the user verbatim, then act on the recommended next step (invoke the named skill) if the user agrees.

\`\`\`bash
bash ~/.claude/skills/day/day.sh
\`\`\`

The driver is a stateless best-guess from: the session goal file, today's spec/plan files under `docs/superpowers/`, and git state. It never blocks and writes no state.

Stages and the skill each maps to:

- **no-goal** → `/goal`
- **needs-brainstorm** → `superpowers:brainstorming`
- **needs-plan** → `superpowers:writing-plans`
- **ready-to-impl** / **mid-impl** → `superpowers:test-driven-development`
- **needs-review** → `requesting-code-review` then `superpowers:finishing-a-development-branch`

If the user is not in a repo (no git, no spec/plan), just show the flow and suggest `/goal` to start.
```

- [ ] **Step 2: Verify description length and skill runs**

Run:
```bash
awk '/^description:/{sub(/^description: /,""); print length}' .claude/skills/day/SKILL.md
bash ~/.claude/skills/day/day.sh >/dev/null 2>&1 && echo "driver runs" || echo "driver path not yet deployed (expected pre-deploy)"
```
Expected: description length prints a number `< 1024` (Claude Code skill description limit; aim ≤ 300 for hygiene). The driver path under `~/.claude` resolves only after Task 8 deploy — pre-deploy, run the worktree copy instead: `bash .claude/skills/day/day.sh`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/day/SKILL.md
git commit -sS -m "feat(day): /day skill entry that runs the daily-flow driver

Maps each lifecycle stage to its skill; presents day.sh output (spec §4.3)."
```

---

## Task 7: Delete tdd-guard.sh from the repo

Implements spec §5 / audit F-HOOK-02. The settings.json references were removed in Task 2; now remove the file itself. (No `tdd-guard_test.sh` exists.)

**Files:**
- Delete: `.claude/hooks/tdd-guard.sh`

- [ ] **Step 1: Remove the file**

```bash
git rm .claude/hooks/tdd-guard.sh
```

- [ ] **Step 2: Verify no references remain anywhere in the repo**

```bash
grep -rn 'tdd-guard' .claude/ docs/ 2>/dev/null | grep -v 'docs/superpowers/\(specs\|plans\)/2026-05-29' | grep -v 'docs/audits/' || echo "no live references"
```
Expected: `no live references` (matches only in this plan/spec narrative and the historical audit are acceptable).

- [ ] **Step 3: Commit**

```bash
git commit -sS -m "chore(hooks): delete tdd-guard.sh

Unreferenced after Task 2 removed it from settings.json; TDD is skill-driven
now (audit F-HOOK-02)."
```

---

## Task 8: Deploy to live ~/.claude and remove the live tdd-guard.sh

Track A → live sync. **Never use `--delete`** — it would remove private-only skills/hooks absent from the repo (CFO suite, gh-*, nvinfo-cli, mempalace, etc.).

**Files:** none (local deploy action)

- [ ] **Step 1: Dry-run the deploy and inspect the diff**

```bash
bash scripts/deploy.sh --claude-only --dry-run
```
Expected: rsync itemized output shows updates to `settings.json`, `CLAUDE.md`, `hooks/session-goal-init.sh`, and new `skills/day/*`. It will **not** list a deletion of `hooks/tdd-guard.sh` (no `--delete`).

- [ ] **Step 2: Deploy for real (with backup)**

```bash
bash scripts/deploy.sh --claude-only
```
Expected: `>> Backing up to ...`, `>> Deploying .claude/`, then `>> Verification` ending `All checks passed.` If verification reports a non-executable hook, run `chmod +x ~/.claude/skills/day/day.sh ~/.claude/hooks/*.sh` and re-verify.

- [ ] **Step 3: Remove the now-orphaned live tdd-guard.sh (Track B)**

```bash
rm -f ~/.claude/hooks/tdd-guard.sh
ls ~/.claude/hooks/tdd-guard.sh 2>&1 || echo "removed"
```
Expected: `removed`.

- [ ] **Step 4: Confirm live settings.json is valid and de-hooked**

```bash
python3 -c "import json; json.load(open('$HOME/.claude/settings.json'))" && echo "live JSON OK"
grep -c 'tdd-guard\|"type": "prompt"' ~/.claude/settings.json
```
Expected: `live JSON OK` and `0`.

---

## Task 9: Verification gate, then open the PR

Implements spec §7.

- [ ] **Step 1: Run every affected test**

```bash
bash .claude/skills/day/day_test.sh
bash .claude/hooks/session-goal-init_test.sh
```
Expected: `12 passed, 0 failed` and `4 passed, 0 failed`.

- [ ] **Step 2: shellcheck the changed scripts**

```bash
shellcheck .claude/skills/day/day.sh .claude/skills/day/day_test.sh .claude/hooks/session-goal-init.sh .claude/hooks/session-goal-init_test.sh
```
Expected: no output.

- [ ] **Step 3: Lint the new docs (CI parity)**

```bash
typos docs/superpowers/specs/2026-05-29-opus-4-8-operating-model-design.md docs/superpowers/plans/2026-05-29-opus-4-8-operating-model.md --config .typos.toml; echo "typos exit=$?"
markdownlint --config .markdownlint.json .claude/skills/day/SKILL.md 2>&1 | head; echo "ml done"
```
Expected: `typos exit=0`; no markdownlint errors on SKILL.md.

- [ ] **Step 4: Token baseline (cross-session, manual)**

Per spec §7.1, in a **fresh** Claude Code session (so the deployed config loads), send a no-op `echo hello` turn and record the prompt-token count; compare against the pre-change baseline. Expected: the auto-loaded surface does not grow (net reduction once the Stop-prompt hook is gone). Record both numbers in the PR description. This step cannot run inside the current session.

- [ ] **Step 5: Push and open the draft PR**

```bash
git push -u origin docs/opus-4-8-operating-model
gh pr create --draft \
  --base main \
  --title "feat: Opus 4.8 operating model — 4.8 recalibration + daily-flow /day driver" \
  --body "Implements docs/superpowers/specs/2026-05-29-opus-4-8-operating-model-design.md.

Problem: config was calibrated to Opus 4.7; daily flow not wired as default.
Approach: keep effortLevel high (4.8 reverses audit F-SETTINGS-05), add 4.8 effort guidance + gh note to CLAUDE.md, remove the Stop-prompt + tdd-guard hooks, reframe workflow as goal->...->finishing, add a stateless /day driver skill.
Testing: day_test.sh (12), session-goal-init_test.sh (4), shellcheck clean, typos/markdownlint clean, token baseline recorded above.
Breaking changes: TDD is no longer hook-enforced (skill-driven). Stop-prompt verification hook removed.

Related: extends docs/audits/2026-05-25-claude-config-audit.md (#22)."
```
Expected: PR URL printed; CI (Markdown Lint, Spell Check, Check Links) goes green.

- [ ] **Step 6: Report to the user**

Summarize: files changed, test results, token delta, PR URL. Do not mark ready-for-review until the user (or QA gate) approves.

---

## Self-Review

- **Spec coverage:** D1 (Task 3 §Effort keeps high; settings already high — confirmed Task 8 §4) · D2 (Task 3 Step 2) · D3 (the §3.3 softening lives in the spec doc itself, already committed; no code task needed) · D4 (Task 1) · D5 (Task 3 Step 2 `/fast`) · §4.1 flow (Task 3 Step 1) · §4.2 V-model reminders (Task 3 Step 1) · §4.3 `/day` driver (Tasks 5–6) · §4.4 SessionStart reminder + CLAUDE.md (Tasks 4, 3) · §5 edit inventory (Tasks 1–7) · §6 dual-track/deploy (Task 8) · §7 verification (Task 9). **No gaps.**
- **Placeholder scan:** every code/step block contains literal content; no TBD/TODO/"handle errors"/"similar to". 
- **Name consistency:** `classify_stage`/`recommend` signatures and the six stage ids (`no-goal|needs-brainstorm|needs-plan|ready-to-impl|mid-impl|needs-review`) are identical across Task 5 (impl), Task 5 (test), and Task 6 (SKILL.md mapping). `detect_signals` emits exactly the five args `classify_stage` consumes.
- **Note on D3:** the tokenizer-assumption softening was authored into the spec at brainstorming time and committed with it; it requires no implementation task. Flagged here so it is not mistaken for a missing requirement.
