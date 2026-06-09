# Reconcile repo `.claude/` mirror with live `~/.claude/`

**Date:** 2026-06-09
**Branch:** `chore/reconcile-claude-config` (off `origin/main` = `6b5ffa9`, PR #34 merged)
**Execution method:** solo
**Concern:** make `scripts/deploy.sh` non-destructive by capturing genuine live→repo
drift, reconciling diverged files by judgment, without reverting main-ahead content
or leaking private skills.

## Problem

The repo ships a `.claude/` mirror of the user's live `~/.claude/`, kept in sync by
three scripts: `deploy.sh` (repo→live rsync), `capture.sh` (live→repo rsync,
additive, sanitized), `diff.sh` (read-only comparison). The mirror has drifted from
live. A naive `deploy.sh` (repo→live) would overwrite live-only improvements with
stale repo content; the goal is to capture the live state so a future `deploy.sh`
is a no-op for already-reconciled files.

### Baseline correction

The task was scoped against the **stale local `main`** (`5522307`, checked out in
`.worktrees/recommendation-validator`), which inflated apparent drift. Diffing against
the **real `origin/main`** (`6b5ffa9`, post-PR #34) shows PR #34 already captured every
item the task flagged as "live-only a blind deploy would revert":

- `panel/work` sandbox `allowWrite` — already in main `settings.json`
- `effortLevel: "xhigh"` — already in main
- `skipWorkflowUsageWarning: true` — already in main
- `validate-recommendation` on `AskUserQuestion` — already in main
- `config-audit-staleness.sh` hook (and its source) — already in main, in sync

These need **no action**. The genuine remaining drift is small.

## Approach (decided)

**Surgical per-file reconciliation**, not a blanket `capture.sh` run.

Rationale: `capture.sh` is additive (no `--delete`), but a blanket run would
(a) **revert ~170 lines of main-ahead test content** — `done-hook_test.sh` (−53),
`test_goal_skill.sh` (−87), `test_skill_integration.sh` (−37) — because live is
*behind* main on those, and (b) **leak private/internal skills** into the public
repo, since `capture.sh`'s `NVIDIA_CLAUDE_EXCLUDES` does not yet cover every
private skill (it currently lists only a subset).
Both hazards would require the same manual `git checkout`/`rm` after a capture, so a
surgical approach reaches the identical end-state with a smaller, auditable diff.

(Devil's-Advocate panel preferred "capture then revert" for fidelity to the literal
instruction and an executable record of the method; the user chose surgical. This
spec serves as the auditable record the DA wanted.)

## Per-file disposition

Drift enumerated by `scripts/diff.sh --claude-only` run from the off-main worktree
(repo-main ↔ live). Noise (`__pycache__`, `.pytest_cache`, `*.bak*`, `.last-*`,
`mcp-needs-auth-cache.json`, `hooks/bin/`, `hooks/src/*/coverage.out`, runtime state)
is correctly excluded by `capture.sh` and is out of scope.

| File | Drift | Direction | Action |
|---|---|---|---|
| `settings.json` | live +3 | live ahead | **Add** `sandbox.filesystem.allowRead: ["**/site-packages/**"]`. Verify valid JSON; preserve all flagged keys. |
| `hooks/enforce-worktree.sh` | live +13 | live ahead | Replace repo copy with live. |
| `hooks/enforce-worktree_test.sh` | live-only | new, real test | Import from live. |
| `rules/learned-anti-patterns.md` | live +6 / repo +3 | diverged | **Union**, dedup by pattern text, project (repo) wins on conflicts, keep ≤50 lines. |
| `hooks/done-hook.sh` | live +1 / repo +5 | diverged | Per-line diff; take live delta only if not a PR-#34/main-ahead change. |
| `plugins/installed_plugins.json` | live +18 / repo +7 | diverged | Reconcile public (non-`local`-scope) plugin set; apply `capture.sh` sanitizer semantics by hand. |
| `policy-limits.json` | live +5 / repo +7 | diverged | Per-line diff; take live delta. |
| `skills/done/done.sh` | live +1 / repo +1 | diverged | Per-line diff. |
| `skills/tdd-protocol/SKILL.md` | live +3 / repo +3 | diverged; **PR #34 touched** | Inspect: if repo side is the #34 change, keep repo (live behind). |
| `skills/team-execute/SKILL.md` | live +2 / repo +1 | diverged; **PR #34 touched** | Same as above. |
| `skills/goal/goal.sh` | live +1 / repo +41 | mostly repo ahead | Keep repo; evaluate the 1 live line. |
| `statusline.sh` | live +5 / repo +33 | mostly repo ahead | Keep repo; evaluate the 5 live lines. |
| `hooks/done-hook_test.sh` | repo +53 | **main ahead** | **No action** (capture would revert). |
| `skills/done/tests/test_skill_integration.sh` | repo +37 | **main ahead** | **No action.** |
| `skills/goal/tests/test_goal_skill.sh` | repo +87 | **main ahead** | **No action.** |
| `remote-settings.json` | live +112 / repo +27 | NVIDIA-excluded | **No action** (private; `capture.sh` excludes it). |

"Diverged" resolution rule: for each, diff repo-main vs live line-by-line. A repo-side
line that originates from a recent main commit (`git log -S`) means **main is ahead** →
keep repo. A repo-side line absent from main history with a newer live counterpart means
**live is ahead** → take live. When genuinely both-changed, take the union if additive,
else prefer the semantically-newer (live) version and note it in the PR.

## Live-only hooks (audit-flagged)

- `hooks/probe-approve.sh` → **delete from live** (panel-validated HOLD). Temporary
  auto-approve-every-`PreToolUse` probe; header says "remove after probe complete"; not
  referenced in any settings (inert); security liability. Not in repo → no repo change.
  Confirm at the `rm`. Live mutation only.
- `hooks/mempalace-wake.sh` → **leave live-only.** NVIDIA-internal; `capture.sh` already
  excludes it and strips its `settings.json` hook entries. No action.
- `hooks/enforce-worktree_test.sh` → **keep / import** (see table).

## Out of scope (this PR)

- **`capture.sh` exclude hardening** (add the remaining private/internal skills
  and `panel/` to private excludes) → **follow-up task chip**
  (user chose one-concern-per-PR). The surgical approach does not touch these files,
  so the leak risk is not realized by this PR; the chip closes it for future captures.
- `.worktrees/completion-gate` — unrelated; leave untouched.
- `.cursor/` mirror — not part of this task (`--claude-only`).

## Verification

1. `scripts/deploy.sh --claude-only --dry-run` from the worktree shows **only intended
   diffs**: repo→live updates for main-ahead files and repo-only files, and **zero**
   cases where repo would overwrite a preserved live improvement (`settings.json`
   `allowRead`/`allowWrite`/`effortLevel`/`skipWorkflowUsageWarning`/
   `validate-recommendation`/`config-audit-staleness`, `enforce-worktree.sh`).
2. `python3 -c 'import json;json.load(open(...))'` on `settings.json` → valid JSON,
   still contains all six preserved keys.
3. `bash hooks/enforce-worktree_test.sh` and `rules/learned-anti-patterns.md` ≤ 50 lines.
4. PR opened as **draft** off `main`; CI green; promote to ready after gates pass.
