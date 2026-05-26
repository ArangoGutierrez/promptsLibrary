# Goal-Origin Anchor — Design

**Date:** 2026-05-26
**Author:** Carlos Eduardo Arango Gutierrez
**Status:** Approved (brainstorm 2026-05-26)
**Scope:** Bind each `/goal` stanza to the git origin URL of the cwd at write time; statusline warns when the current session's cwd resolves to a different origin.

## Why

The done-hook protocol keys session-goal files off Claude Code's session UUID. The statusline (`statusline.sh`) reads the goal text via the session UUID with no anchor to the project the goal was set for. This led to an observed real-world miscue: a session opened with cwd in project A had `/goal` invoked with goal text describing project B; statusline correctly displayed B's text in A's session, leaving the user confused. The session UUID is the right identity for *this conversation*, but a session's goal is conceptually about *a project* — there is no link.

This spec adds a project-identity anchor (the git `remote.origin.url`) to each stanza at write time, and a non-blocking visual warning in the statusline when the anchor disagrees with the current session's cwd.

## Schema change

Goal-file stanzas gain an `Origin:` line immediately below `Goal:`. Existing fields are unchanged.

Example stanza after this change:

```text
## Initial 2026-05-26T13:30:00Z
Goal: ship done-hook v1
Origin: git@github.com:NVIDIA/holodeck.git
Acceptance:
- ./done-hook_test.sh passes
- shellcheck clean
- spec committed to docs/superpowers/specs/
```

The `Origin:` value is the literal output of `git config --get remote.origin.url` from the cwd at stanza-write time. If `git config` returns nothing (cwd is not in a git repo, or the repo has no `origin` remote), the `Origin:` line is omitted from the stanza entirely (rather than written as `Origin:` with empty value — this avoids ambiguous parsing downstream).

## `/goal` write path (`goal.sh`)

At each stanza write (Initial or Amendment), `goal.sh`:

1. Computes `ORIGIN=$(git config --get remote.origin.url 2>/dev/null || true)`. Empty if cwd is not a git repo or the repo has no origin.
2. Emits the existing `Goal:` line.
3. If `ORIGIN` is non-empty, emits `Origin: $ORIGIN` immediately below the `Goal:` line. Otherwise omits the line.
4. Continues emitting `Acceptance:` block as today.

The git resolution uses the actual cwd of the `goal.sh` process. This matches what the user perceives as "where I am" at the moment they ran `/goal`. The skill is invoked from the user's session cwd, so this should align with `.workspace.current_dir` in normal use.

Amendment behavior: `/goal amend` writes a new stanza with `Origin:` derived from the *current* cwd at amend time. If the user amends from a different repo, the new Origin will reflect that. The statusline (which reads the *last* stanza) will then warn in any other session that had been operating against the previous Origin — that is the intended early-warning behavior.

## Statusline read path (`statusline.sh`)

At each render, after extracting the last stanza's `Goal:` text via the existing awk pipeline, the statusline additionally:

1. Parses `Origin: <url>` from the same last stanza into `GOAL_ORIGIN`. Same awk-style: scan the last `## ...` stanza for a line matching `^Origin: `. Empty if absent.
2. Computes `CUR_ORIGIN=$(git config --get remote.origin.url 2>/dev/null || true)` from the current cwd. Empty if the session cwd is not in a git repo or has no origin remote. The cwd to use is the one Claude Code already passes via `.workspace.current_dir` — but `git config` runs in `statusline.sh`'s own cwd (which is the project dir when launched by Claude Code). Either is fine; we just use the current process's cwd via plain `git config`.
3. If `GOAL_ORIGIN` and `CUR_ORIGIN` are both non-empty AND not equal, the goal segment becomes `🎯 <goal-text> ⚠ wrong-repo` (truncation of `<goal-text>` is unchanged; the warning is appended after the truncated text).
4. In all other cases (either side empty, or both equal), the segment renders as today: `🎯 <goal-text>`.

The mismatch tag is plain text (`⚠ wrong-repo`), no ANSI color, no emoji-replace. Compact, doesn't depend on terminal-color support.

## Failure modes

| Failure | Behavior |
|---|---|
| Goal file has no `Origin:` line (old files or non-git write-time cwd) | No comparison performed; no warning. |
| Goal file has malformed `Origin:` (whitespace-only or absent value) | Treated as empty; no warning. |
| Current cwd has no `.git` directory | `git config` returns empty; no comparison; no warning. |
| Current cwd is a git repo with no `origin` remote | `git config` returns empty; no comparison; no warning. |
| `git config --get` errors out | `2>/dev/null` suppresses; treated as empty; no warning. Fail-open. |
| Both sides equal | No warning (correct match). |
| Both sides differ on URL normalization (e.g., `https://github.com/foo/bar.git` vs `git@github.com:foo/bar.git`) | Treated as mismatch; user sees warning. This is acceptable: a session that intentionally uses both URLs is uncommon, and the warning is non-blocking. If observed in practice as a noisy false-positive, a follow-up normalizes the URL (strip `.git` suffix, normalize host) before comparison. |

## Performance

The existing statusline runs ~5 jq calls plus an optional `git branch --show-current`. Measured median ~99ms on this machine. Adding `git config --get remote.origin.url` is one additional `git` subprocess; expected delta ~5-10ms. Total stays well below the 300ms render-debounce ceiling.

The `goal.sh` script runs only on explicit `/goal` invocation (not on every prompt), so the added `git config` call is irrelevant to perf.

## Backward compatibility

The existing three goal files (`~/.claude/audit/session-goals/*.md` at the time of this spec) have no `Origin:` line. They will continue to render without warning per the "no comparison performed" rule. No migration script is provided — old files lose the anchor benefit silently and are not retroactively flagged.

The `done-hook.sh` Stop hook and the `done.sh` orchestrator do NOT read `Origin:` and do NOT need changes. They continue to operate on the session UUID alone. The mismatch check is observe-only in the statusline; no downstream behavior changes.

## Tests

### `goal.sh` unit tests (new, in `test_goal_skill.sh`)

- **Scenario A — origin written when cwd has remote.** Setup: temp dir initialized as a git repo with a fake `origin` remote pointing at `git@example.com:foo/bar.git`. Invoke `goal.sh` with a goal body. Assert the resulting stanza in `~/.claude/audit/session-goals/<uuid>.md` contains exactly one line matching `^Origin: git@example.com:foo/bar\.git$`, and it appears between the `Goal:` line and the `Acceptance:` line.
- **Scenario B — origin omitted when cwd has no remote.** Setup: temp dir, no `.git` directory. Invoke `goal.sh`. Assert the stanza contains no `Origin:` line.

Existing `test_goal_skill.sh` scenarios (4) continue to pass without modification — they don't currently check for absent `Origin:` lines, and adding optional `Origin:` lines does not affect their existing assertions on `Goal:` / `Acceptance:` lines or stanza counts.

### `statusline.sh` manual verification (new, run inline in the Task plan)

- **Matching origin** — goal file written with `Origin: <url>`, session cwd is a git repo with the same `origin`. Expected: goal segment renders without warning.
- **Mismatching origin** — goal file written with `Origin: <url-A>`, session cwd is a different repo with `Origin: <url-B>`. Expected: goal segment ends with ` ⚠ wrong-repo`.
- **Goal file without Origin** — represents the existing 3 pre-spec files. Expected: no warning (no comparison performed).
- **Session cwd not in a git repo** — goal file has `Origin:`, but session cwd is a plain dir. Expected: no warning.

The existing statusline scenarios (goal-set, no-goal, pre-API, long-goal-truncation) continue to pass.

## Scope discipline

In scope:
- `.claude/skills/goal/goal.sh` — write the `Origin:` line.
- `.claude/skills/goal/tests/test_goal_skill.sh` — two new scenarios (A + B above).
- `.claude/statusline.sh` — read `Origin:`, compare, append warning on mismatch.

Out of scope:
- `done-hook.sh`, `done.sh`, `eval.py` — no changes. The mismatch check is observe-only; downstream behavior unchanged.
- Migration of existing goal files — left as-is.
- URL normalization (https vs ssh, trailing `.git`) — accept naive string equality in v1; revisit if false-positives become a real problem.
- Auto-correction or user prompts on mismatch — observe-only, no nudges.
- Multi-cwd sessions via `/add-dir` — statusline only sees one cwd at a time; the comparison reflects whichever cwd `git config` resolves in. Acceptable for v1.
- Project name in the statusline — could be a separate follow-up. The goal of this spec is mismatch detection, not project labeling.

## Open follow-ups (deferred)

- URL normalization if false-positive rate is non-trivial.
- Project-name segment in statusline as an explicit `[<project>]` tag.
- Auto-deduce goal from first prompt (separate brainstormed feature; tracked from the merged PR).
