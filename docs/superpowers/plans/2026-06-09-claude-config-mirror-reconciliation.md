# .claude Mirror Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture genuine live→repo `.claude/` drift into the repo mirror so `scripts/deploy.sh` (repo→live) becomes non-destructive, without reverting main-ahead content or leaking private skills.

**Architecture:** Surgical per-file edits on `chore/reconcile-claude-config` (branched off `origin/main` = `6b5ffa9`). Six files are genuinely live-ahead or diverged-toward-live; the rest are repo/main-ahead and left untouched. One live-only security hook is deleted. Verification is `deploy.sh --claude-only --dry-run` + JSON validity, not unit tests (this is config curation).

**Tech Stack:** bash, rsync, jq, python3 (JSON validation), git.

**Worktree:** `/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config` (already created off `origin/main`). All paths below are relative to it unless absolute. Live env is `$HOME/.claude`.

**Conventions:** commits signed (`-s -S`, hook-enforced) — run `git`/`gpg`/`gh` **unsandboxed** (TLS/GPG/worktree sandbox blocks). `cp`/`mv` are `-i` aliased → use `/bin/cp`/`/bin/rm`. Bash cwd resets between calls → use absolute paths / `git -C`.

**Out of scope (deferred to follow-up chip):** hardening `capture.sh` private-excludes for the remaining private/internal skills and `panel/`, and considering `policy-limits.json`/`installed_plugins.json` as exclude candidates (both harness-managed). `.cursor/` mirror. `.worktrees/completion-gate`.

---

### Task 1: settings.json — add sandbox `allowRead`

**Files:**
- Modify: `.claude/settings.json` (under `sandbox.filesystem`)

Live added an `allowRead` array next to the existing `allowWrite`. All other flagged keys (`panel/work` allowWrite, `effortLevel`, `skipWorkflowUsageWarning`, `validate-recommendation`, `config-audit-staleness`) are already in main and unchanged.

- [ ] **Step 1: Apply the edit**

In `.claude/settings.json`, change the `sandbox.filesystem` block from:

```json
    "filesystem": {
      "allowWrite": [
        "/Users/eduardoa/.claude/panel/work"
      ]
    }
```

to:

```json
    "filesystem": {
      "allowWrite": [
        "/Users/eduardoa/.claude/panel/work"
      ],
      "allowRead": [
        "**/site-packages/**"
      ]
    }
```

- [ ] **Step 2: Verify valid JSON and keys intact**

Run:
```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
python3 -c "import json;d=json.load(open('$WT/.claude/settings.json'));print('VALID')"
for k in panel/work allowRead effortLevel skipWorkflowUsageWarning validate-recommendation config-audit-staleness; do
  grep -q "$k" "$WT/.claude/settings.json" && echo "OK $k" || echo "MISSING $k"; done
```
Expected: `VALID`, then `OK` for all six keys.

- [ ] **Step 3: Confirm settings.json now matches live exactly**

Run:
```bash
diff "$WT/.claude/settings.json" "$HOME/.claude/settings.json" && echo "IN SYNC"
```
Expected: no output + `IN SYNC`.

- [ ] **Step 4: Commit**

```bash
git -C "$WT" add .claude/settings.json
git -C "$WT" commit -s -S -m "chore(config-sync): capture sandbox allowRead site-packages

Live ~/.claude/settings.json grants sandbox read access to **/site-packages/**
(needed by the panel/validate-recommendation Python deps). Capture it so
deploy.sh does not revert it. All other keys already match main."
```

---

### Task 2: enforce-worktree.sh + its test — take live (live-ahead fix)

**Files:**
- Modify: `.claude/hooks/enforce-worktree.sh` (replace with live; +13-line out-of-repo guard)
- Create: `.claude/hooks/enforce-worktree_test.sh` (import live, 55-line test)

Live added a guard: absolute paths *outside* the repo root (e.g. global `~/.claude` dirs) are allowed, instead of being wrongly blocked by the repo-relative allowlist. PR #34 did not touch this hook → genuine live-ahead fix. The companion test is live-only.

- [ ] **Step 1: Copy live hook + test into repo**

```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
/bin/cp -f "$HOME/.claude/hooks/enforce-worktree.sh" "$WT/.claude/hooks/enforce-worktree.sh"
/bin/cp -f "$HOME/.claude/hooks/enforce-worktree_test.sh" "$WT/.claude/hooks/enforce-worktree_test.sh"
chmod +x "$WT/.claude/hooks/enforce-worktree.sh" "$WT/.claude/hooks/enforce-worktree_test.sh"
```

- [ ] **Step 2: Verify the hook now matches live and contains the new guard**

```bash
diff "$WT/.claude/hooks/enforce-worktree.sh" "$HOME/.claude/hooks/enforce-worktree.sh" && echo "HOOK IN SYNC"
grep -q 'inside repo: continue to the allowlist' "$WT/.claude/hooks/enforce-worktree.sh" && echo "GUARD PRESENT"
```
Expected: `HOOK IN SYNC`, `GUARD PRESENT`.

- [ ] **Step 3: Run the imported test (must pass — it is the contract for the hook)**

Run **unsandboxed** (the test does `git init` + writes under `$HOME` tmpdir):
```bash
bash "$WT/.claude/hooks/enforce-worktree_test.sh"; echo "EXIT=$?"
```
Expected: test reports pass and `EXIT=0`. If it fails, the imported hook/test pair is broken — stop and inspect (do not "fix" by editing the test to pass).

- [ ] **Step 4: Commit**

```bash
git -C "$WT" add .claude/hooks/enforce-worktree.sh .claude/hooks/enforce-worktree_test.sh
git -C "$WT" commit -s -S -m "chore(config-sync): capture enforce-worktree out-of-repo guard + test

Live hook allows writes to absolute paths outside the repo root (global
~/.claude dirs) instead of wrongly blocking them. Import the live hook and
its companion test (previously live-only)."
```

---

### Task 3: installed_plugins.json — sanitized capture (strip local-scope)

**Files:**
- Modify: `.claude/plugins/installed_plugins.json`

Live has newer plugin SHAs/dates for `code-review`/`code-simplifier` **and** a `scope:"local"` entry registering a public plugin for a private project. Reproduce `capture.sh`'s sanitizer: capture live, strip local-scoped plugins. This prevents a deploy from downgrading live's plugin metadata.

- [ ] **Step 1: Regenerate the file from live through the sanitizer**

Run (uses the exact jq the `capture.sh` sanitizer uses, with `== "local" | not` to avoid shell `!` issues):
```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
/usr/bin/jq '.plugins |= with_entries(.value |= map(select(.scope == "local" | not))) | .plugins |= with_entries(select(.value | length > 0))' \
  "$HOME/.claude/plugins/installed_plugins.json" > "$WT/.claude/plugins/installed_plugins.json"
```

- [ ] **Step 2: Verify no private/local content leaked + valid JSON**

```bash
python3 -c "import json;json.load(open('$WT/.claude/plugins/installed_plugins.json'));print('VALID')"
echo "local-scope hits: $(grep -c '\"scope\": \"local\"' "$WT/.claude/plugins/installed_plugins.json")"
echo "projectPath hits: $(grep -c 'projectPath' "$WT/.claude/plugins/installed_plugins.json")"
/usr/bin/jq -r '.plugins | keys[]' "$WT/.claude/plugins/installed_plugins.json"
```
Expected: `VALID`; `local-scope` and `projectPath` both `0` (no private-project entry leaked); keys = `clangd-lsp`, `code-review`, `code-simplifier`, `gopls-lsp`, `superpowers` (5).

- [ ] **Step 3: Commit**

```bash
git -C "$WT" add .claude/plugins/installed_plugins.json
git -C "$WT" commit -s -S -m "chore(config-sync): capture installed_plugins (sanitized, no local scope)

Update plugin SHAs/dates to current live state, stripping the local-scoped
private-project entry (capture.sh sanitizer parity).
Prevents deploy from downgrading live plugin metadata."
```

---

### Task 4: policy-limits.json — take live (harness-managed policy)

> **⚠ DEVIATION — this task was DROPPED during execution and did NOT ship.**
> Investigation proved `policy-limits.json` is a *harness-managed, volatile* file: it
> flaps between keysets and the harness rewrote even the git-worktree copy mid-session.
> Capturing it is stale-on-arrival churn, so it was left at main's version and moved to
> the sync-exclude follow-up. The steps below are kept as the original plan record only.

**Files:**
- Modify: `.claude/policy-limits.json`

Harness-managed policy file. Live is the current authoritative state: it dropped `allow_product_feedback`/`allow_remote_sessions`, added `allow_cobalt_plinth` and `compliance_taints: []`. Capture live so deploy does not overwrite current policy with stale keys.

- [ ] **Step 1: Copy live → repo**

```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
/bin/cp -f "$HOME/.claude/policy-limits.json" "$WT/.claude/policy-limits.json"
```

- [ ] **Step 2: Verify valid JSON + in sync**

```bash
python3 -c "import json;json.load(open('$WT/.claude/policy-limits.json'));print('VALID')"
diff "$WT/.claude/policy-limits.json" "$HOME/.claude/policy-limits.json" && echo "IN SYNC"
```
Expected: `VALID`, `IN SYNC`.

- [ ] **Step 3: Commit**

```bash
git -C "$WT" add .claude/policy-limits.json
git -C "$WT" commit -s -S -m "chore(config-sync): capture current policy-limits state

Harness-managed policy file; capture live (drops allow_product_feedback/
allow_remote_sessions, adds allow_cobalt_plinth + compliance_taints) so
deploy does not revert to stale policy keys. Candidate for sync-exclude
in the follow-up hardening."
```

---

### Task 5: learned-anti-patterns.md — union merge (project wins)

**Files:**
- Modify: `.claude/rules/learned-anti-patterns.md`

The repo (project) file has 6 entries (4 critical + 2 warning) at plan time. The live global file shares 4 patterns and has 5 unique warnings. Union = keep all project entries (project wins on the shared `Verify external references` line: count 2, tags `containers,k8s`), then append the 5 global-only warnings. Plan-time result: 4 critical + 7 warning = 11 entries.

> **Execution note:** the branch was later rebased onto an updated `main` (#37), which had added a 7th base entry (`Substring-matching command hooks`). The union therefore **shipped with 12 entries** (4 critical + 8 warning), ~22 lines — still ≤50. The verification expectations below say "11" for the plan-time base; the shipped file is 12.

- [ ] **Step 1: Re-read the current project file to avoid transcription drift**

```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
cat "$WT/.claude/rules/learned-anti-patterns.md"
```
Confirm it has exactly these 6 `Pattern` lines: Theater tests; Index-based access; Array ordering; Ship code without exercising real caller; Verify external references; Spec/plan/handoff numerics.

- [ ] **Step 2: Append the 5 global-only warning entries**

Append these lines verbatim to the end of the `## Warning` section (after the existing `Spec/plan/handoff numerics` line):

```markdown
- **Pattern**: Never push without local E2E for infrastructure code | **Fix**: Run `kind` cluster E2E or equivalent before pushing operator/controller changes. | **Severity**: warning | **Tags**: k8s,testing | **Count**: 2 | **Since**: 2026-03-15
- **Pattern**: Shell file copy/move/sync reports success (exit 0) while silently no-op'ing or nesting — mv -i/cp -i aliases decline overwrites returning 0; `cp -R src dst` nests into dst/src when dst exists | **Fix**: Verify the after-state (diff/ls), never trust exit 0. Bypass -i with `command cp -f`/`command mv -f`; for directory mirror use `rm -rf dst && cp -R src dst` or `cp -R src/. dst/`. | **Severity**: warning | **Tags**: shell,tooling,verification | **Count**: 3 | **Since**: 2026-06-08
- **Pattern**: Sandboxed Bash misread as a broken env — the `**/secret*` read-deny blocks importing deps that ship a `secrets.py` (e.g. `pydantic_settings`), so pytest dies with a misleading `ModuleNotFoundError`; `.git/` writes and `~/.cache/uv` writes are denied too | **Fix**: Re-run pytest/python/git/uv sandbox-disabled (or carve exceptions via `/sandbox`); don't misdiagnose the import error as a bad install or wrong venv. | **Severity**: warning | **Tags**: sandbox,python,testing,tooling | **Count**: 1 | **Since**: 2026-06-09
- **Pattern**: Bash working dir silently resets between calls despite the tool saying cwd persists — a stale `cd` caused a `git add` pathspec miss and a wrong-venv-location near-miss | **Fix**: Use absolute paths and `git -C <dir>`; never rely on a prior `cd` persisting across Bash calls. | **Severity**: warning | **Tags**: shell,tooling,verification | **Count**: 1 | **Since**: 2026-06-09
- **Pattern**: Sandbox blocks `git worktree add/remove` and writes under `~/.claude/`, `.worktrees/`, or `.claude/worktrees/` → "Operation not permitted" (exit 128) | **Fix**: Run these Bash calls sandbox-disabled from the start; don't retry sandboxed-first (same rule as `gh` TLS failures). | **Severity**: warning | **Tags**: sandbox,git,worktree,tooling | **Count**: 2 | **Since**: 2026-06-09
```

Do NOT modify the 4 shared/critical entries or the 2 existing warnings (project wins on conflicts — keep `Verify external references` at count 2, tags `containers,k8s`).

- [ ] **Step 3: Verify entry count, ≤50 lines, no duplicate patterns**

```bash
echo "entries: $(grep -c '^- \*\*Pattern\*\*' "$WT/.claude/rules/learned-anti-patterns.md")  (expect 11)"
echo "lines:   $(wc -l < "$WT/.claude/rules/learned-anti-patterns.md")  (expect <=50)"
# no duplicate pattern text:
grep '^- \*\*Pattern\*\*' "$WT/.claude/rules/learned-anti-patterns.md" | sed 's/ | \*\*Fix.*//' | sort | uniq -d
```
Expected: `entries: 11`, `lines: <=50` (~21), and the `uniq -d` line prints **nothing** (no dups).

- [ ] **Step 4: Commit**

```bash
git -C "$WT" add .claude/rules/learned-anti-patterns.md
git -C "$WT" commit -s -S -m "chore(config-sync): union project + global learned anti-patterns

Add 5 global-only warnings (E2E-before-push, shell copy no-op, sandboxed
bash misread, bash cwd reset, sandbox git-worktree block). Project entries
win on shared patterns. 11 entries total, within the 50-line cap."
```

---

### Task 6: Verification gate — deploy dry-run shows only intended diffs

**Files:** none (verification only)

- [ ] **Step 1: Run the deploy dry-run from the worktree**

```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
"$WT/scripts/deploy.sh" --claude-only --dry-run 2>&1 | tee /tmp/claude/deploy-dryrun.txt
```

- [ ] **Step 2: Confirm the 5 reconciled files are GONE from the dry-run output**

```bash
for f in settings.json hooks/enforce-worktree.sh hooks/enforce-worktree_test.sh plugins/installed_plugins.json rules/learned-anti-patterns.md; do
  if grep -q "$f" /tmp/claude/deploy-dryrun.txt; then echo "STILL DIFFERS (investigate): $f"; else echo "RECONCILED: $f"; fi
done
```
Expected: `RECONCILED` for all five (`policy-limits.json` was dropped — see Task 4 deviation — and stays at main's version). `enforce-worktree_test.sh` and the anti-patterns union may still show as `>f` (repo→live *create/update*) since live lacks the test and the extra anti-patterns — that is an **intended** repo-ahead push, not a revert. The key check: settings.json, enforce-worktree.sh, installed_plugins.json show content-identical (`>f..t` timestamp-only or absent).

- [ ] **Step 3: Confirm remaining dry-run entries are all repo/main-ahead (intended), not reverts**

```bash
grep -E '^[<>cf.]|deleting|\.sh|\.md|\.json' /tmp/claude/deploy-dryrun.txt | grep -vE 'site-packages|panel/work'
```
Manually confirm every remaining itemized line is one of: a main-ahead file pushing to live (`done-hook.sh`, `done-hook_test.sh`, `goal.sh`, `goal/tests/`, `done.sh`, `done/tests/`, `statusline.sh`, `tdd-protocol/SKILL.md`, `team-execute/SKILL.md`), or a repo-only file (`config-audit-staleness_test.sh`, `sync-to-home*.sh`, `promotion-candidates_test.sh`). There must be **zero** lines where deploy would overwrite a live improvement (`allowRead`/`allowWrite`/`effortLevel`/enforce-worktree guard).

- [ ] **Step 4: Final JSON validity sweep**

```bash
for j in settings.json plugins/installed_plugins.json; do
  python3 -c "import json;json.load(open('$WT/.claude/$j'));print('VALID $j')" || echo "INVALID $j"; done
```
Expected: `VALID` for both.

---

### Task 7: Delete probe-approve.sh from live (panel-validated)

**Files:**
- Delete (live only, NOT repo): `$HOME/.claude/hooks/probe-approve.sh`

Temporary auto-approve-every-`PreToolUse` probe; header says remove after probe; not referenced in any settings (inert); security liability. Not in repo → no repo change.

- [ ] **Step 1: Re-confirm it is inert before deleting**

```bash
grep -rn 'probe-approve' "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" 2>/dev/null && echo "REFERENCED — STOP, do not delete" || echo "INERT — safe to delete"
```
Expected: `INERT — safe to delete`. If `REFERENCED`, stop and re-evaluate.

- [ ] **Step 2: Delete (with explicit user confirmation at this step)**

```bash
/bin/rm -f "$HOME/.claude/hooks/probe-approve.sh"
ls "$HOME/.claude/hooks/probe-approve.sh" 2>&1 | grep -q 'No such file' && echo "DELETED"
```
Expected: `DELETED`. No commit (not a repo file).

---

### Task 8: Draft PR + CI + follow-up chip

**Files:** none (git/gh operations, all **unsandboxed**)

- [ ] **Step 1: Push the branch**

```bash
WT=/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/reconcile-claude-config
git -C "$WT" push -u origin chore/reconcile-claude-config
```

- [ ] **Step 2: Open the draft PR**

```bash
git -C "$WT" log --oneline origin/main..HEAD
gh --repo ArangoGutierrez/promptsLibrary pr create --draft --base main --head chore/reconcile-claude-config \
  --title "chore(config-sync): reconcile .claude mirror with live (non-destructive deploy)" \
  --body "$(cat <<'BODY'
## Problem
The repo `.claude/` mirror drifted from live `~/.claude/`. A naive `deploy.sh` would overwrite live-only improvements with stale repo content.

## Baseline correction
Scoped against the real `origin/main` (`6b5ffa9`, PR #34), not stale local main (`5522307`). PR #34 already captured every item the original task flagged as "live-only" (`panel/work`, `effortLevel: xhigh`, `skipWorkflowUsageWarning`, `validate-recommendation`, `config-audit-staleness`) — those need no action.

## Approach
Surgical per-file reconciliation (not blanket `capture.sh`), because a blanket capture would revert ~170 lines of main-ahead test content and leak private/internal skills. See `docs/superpowers/specs/2026-06-09-claude-config-mirror-reconciliation-design.md`.

## Changes (4 files, all genuine live→repo captures)
- `settings.json`: + `sandbox.filesystem.allowRead: ["**/site-packages/**"]`
- `hooks/enforce-worktree.sh` + `_test.sh`: capture the out-of-repo write guard + its test
- `plugins/installed_plugins.json`: capture current SHAs, sanitized (drop the private-project local-scope entry)
- `rules/learned-anti-patterns.md`: union project + global (project wins on conflicts)

## Dropped during execution
- `policy-limits.json`: harness-managed/volatile — left at main's version (see Task 4 deviation, → follow-up).

## Left untouched (repo/main ahead — capturing would revert)
`done-hook.sh` (PR#19 fix), `goal.sh`/`statusline.sh` (PR#26 origin-anchor), `tdd-protocol`/`team-execute` SKILL.md (PR#34 tdd-guard removal), `done.sh` (live had a machine-specific python path), 3 main-ahead test files, `remote-settings.json` (NVIDIA-excluded).

## Testing done
- `deploy.sh --claude-only --dry-run`: the reconciled files no longer show as reverts; remaining diffs are all main-ahead pushes or repo-only files (see Task 6).
- `settings.json`/`installed_plugins.json`: valid JSON.
- `enforce-worktree_test.sh`: passes.
- anti-patterns: 12 entries (after rebase onto #37), ≤50 lines, no duplicates.

## Also done outside the repo
- Deleted inert `~/.claude/hooks/probe-approve.sh` (temporary auto-approve-everything probe; security hygiene).

## Follow-up (separate)
Harden `capture.sh` private-excludes (the remaining private/internal skills + `panel/`) and consider sync-excluding harness-managed `policy-limits.json`/`installed_plugins.json`.
BODY
)"
```

- [ ] **Step 3: Wait for CI and confirm green**

```bash
gh --repo ArangoGutierrez/promptsLibrary pr checks chore/reconcile-claude-config --watch
```
Expected: all checks pass. If red, read the failing job log and fix on the branch (re-run from the relevant task). Do not promote a red PR.

- [ ] **Step 4: Spin off the capture.sh exclude-hardening follow-up**

Create a task chip (in-session tool) titled "Harden capture.sh private-excludes" with a self-contained prompt covering: add the remaining private/internal skills and `panel/` to `NVIDIA_CLAUDE_EXCLUDES` (enumerate the specific skill names in the chip prompt, which is not committed to the public repo — do not list them here); evaluate sync-excluding `policy-limits.json` + `plugins/installed_plugins.json` (harness-managed, perpetually drift); add a `capture.sh` test asserting private skills never land in the repo.

- [ ] **Step 5: Leave PR as draft for user review**

Per repo git-workflow, QA/user promotes draft → ready after gates pass. Report the PR URL and CI status; do not self-promote.

---

## Self-Review (completed during planning)

- **Spec coverage:** every spec disposition-table row maps to a task — capture rows → Tasks 1–5; no-action rows → explicitly listed in "Left untouched" (Task 8 PR body); probe-approve → Task 7; exclude-hardening → Task 8 Step 4; verification → Task 6. ✓
- **Placeholder scan:** no TBD/TODO; every edit shows exact before/after or a deterministic regeneration command; every verify step has an expected output. ✓
- **Consistency:** worktree path, `$WT` variable, branch name, and file paths identical across tasks; jq sanitizer matches `capture.sh`'s exactly (modulo `== "local" | not` for shell-safety). ✓
