# Statusline Goal Integration — Design

**Date:** 2026-05-25
**Author:** Carlos Eduardo Arango Gutierrez
**Status:** Approved (brainstorm 2026-05-25)
**Scope:** Add session-goal + token-consumption display to the Claude Code statusline. Becomes Task 23 of the in-flight `feat/done-hook` plan.

## Why

The done-hook protocol captures a session goal at start (`/goal`), surfaces evidence heuristics at session end (`done-hook.sh`), and records the user-authoritative verdict (`/done`). One gap remains: between session start and end, the goal is out of sight. Claude Code's statusline is the obvious place to keep it visible alongside model, branch, worktree, and rate-limits.

## What

Modify the existing statusline at both `~/.claude/statusline.sh` (user-level) and `<project>/.claude/statusline.sh` (project mirror) to add two new segments to the single-line output: a goal segment and a context-token-consumption segment.

## Layout

Single line, segments separated by `|`:

```text
[<Model>]  <branch> (wt:<worktree>) | 🎯 <goal-text or "(no goal)"> | <N>k tok (<P>%) | 5h:<L1>% 7d:<L2>%
```

Concrete example with a goal set:

```text
[Opus]  feat/done-hook (wt:done-hook) | 🎯 ship done-hook v1 | 47.3k tok (8%) | 5h:23% 7d:41%
```

Concrete example without a goal:

```text
[Opus]  feat/done-hook (wt:done-hook) | 🎯 (no goal) | 12.1k tok (6%) | 5h:23%
```

**Risk acknowledged.** Long goal text + long branch + verbose rate-limits can overflow narrow terminals (DA-panel HARD-DISSENT during brainstorm 2026-05-25, accepted by user). Mitigated by 40-char goal truncation. If users hit wrap issues, follow-up changes the layout to two lines (goal on its own line). Tracked as a known limitation, not a blocker for v1.

## Segment specifications

### Model segment (existing, unchanged)

- Source: `.model.display_name` from the JSON payload.
- Format: `[<name>]`.
- Fallback when absent: `[?]`.

### Branch + worktree segment (existing, unchanged)

- Branch source: `.worktree.branch` (prefer, set in `--worktree` sessions) else `git branch --show-current` (live fallback).
- Worktree name source: `.workspace.git_worktree` (broader: any linked worktree, not just `--worktree` sessions).
- Format: `<branch>` then ` (wt:<name>)` if worktree name is present.

### Goal segment (new)

- Session UUID source: `.session_id` from the JSON payload.
- Goal file path: `${HOME}/.claude/audit/session-goals/${session_id}.md`.
- File absent → emit `🎯 (no goal)`.
- File present → extract the **last** `## ...` stanza's `Goal: <text>` line. If no `Goal:` line appears in the last stanza, emit `🎯 (no goal)`. If multiple `Goal:` lines exist in the last stanza, take the first.
- Truncation: if `<text>` exceeds 40 chars, take `${text:0:39}…`.
- Emoji `🎯` is literal U+1F3AF; sufficient terminal support is assumed (same assumption as the existing statusline's `📁` in the doc example).

### Token segment (new)

- Token count source: `.context_window.total_input_tokens + .context_window.total_output_tokens`. Per the Claude Code v2.1.132+ semantics, these are current-context tokens (not cumulative session totals). Both default to `0` before the first API response.
- Percent source: `.context_window.used_percentage`. May be `null` pre-first-response; treat null as `0`.
- Format:
  - count `< 1000` → bare integer (e.g., `427 tok`).
  - count `>= 1000` → one-decimal-place k-suffix (e.g., `47.3k tok`).
- Output template: `<count> tok (<P>%)`.

### Rate-limit segment (existing, unchanged)

- Source: `.rate_limits.five_hour.used_percentage`, `.rate_limits.seven_day.used_percentage`.
- Format: `5h:<P>% 7d:<P>%`. Each half independently absent on free-tier; whole segment hidden if both absent.

## Goal extraction logic (bash)

Inline in `statusline.sh`. Five-ish lines:

```bash
GOAL="(no goal)"
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$SESSION_ID" ]; then
  GOAL_FILE="${HOME}/.claude/audit/session-goals/${SESSION_ID}.md"
  if [ -f "$GOAL_FILE" ]; then
    # Extract last stanza's "Goal: " line via awk
    RAW=$(awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$GOAL_FILE" \
          | grep -m1 '^Goal: ' | sed 's/^Goal: //; s/[[:space:]]*$//')
    if [ -n "$RAW" ]; then
      if [ "${#RAW}" -gt 40 ]; then RAW="${RAW:0:39}…"; fi
      GOAL="$RAW"
    fi
  fi
fi
```

The awk pattern mirrors the one in `done-hook.sh` (`extract_last_stanza`); deliberately kept inline rather than shared via a library to preserve the statusline's single-file simplicity. If a third caller needs the same parse later, factor it into a shared helper then.

## Token formatting logic (bash)

```bash
IN=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
TOTAL=$((IN + OUT))
if [ "$TOTAL" -ge 1000 ]; then
  TOKENS=$(awk -v n="$TOTAL" 'BEGIN{ printf "%.1fk", n/1000 }')
else
  TOKENS="$TOTAL"
fi
TOK_SEG="${TOKENS} tok (${PCT}%)"
```

## Order of segments

Same order as the layout example. Goal segment is inserted **between** the branch/worktree segment and the rate-limit segment. Token segment is inserted **between** the goal segment and the rate-limit segment.

## Performance

Statusline fires on a 300ms debounce per the Claude Code spec; updates also pause while the in-flight execution is cancelled by a newer event. The existing script uses ~5 `jq` invocations and one optional `git` call. The new segments add:

- 2 new `jq` invocations (`.session_id`, then three context-window fields condensed into one or three jq calls).
- 1 file existence check + 1 file read (awk on the goal file, typically <2KB).
- 1 awk pass for formatting tokens.

Expected delta: ~5–10 ms on macOS. Total well under any perceived input lag.

## Failure modes

| Failure | Behavior |
|---|---|
| `.session_id` missing/empty | Goal segment shows `🎯 (no goal)`. No error. |
| Goal file missing | Goal segment shows `🎯 (no goal)`. No error. |
| Goal file present but malformed (no `Goal:` line in last stanza) | Goal segment shows `🎯 (no goal)`. No error. |
| `.context_window` absent/null pre-first-response | Tokens show `0 tok (0%)`. |
| `.context_window.used_percentage` null | Percent shown as `0%`. |
| `jq` missing | Existing script already breaks; out of scope. (jq is a hard prereq for the statusline.) |
| `awk` missing | macOS/Linux ship awk; treat as out of scope. |
| File read error (permissions, EIO) | `[ -f ]` guard fails → falls through to `(no goal)`. |

The statusline must NEVER produce non-zero exit; the Claude Code renderer treats stderr/exit as non-fatal but a clean output is the contract.

## Out of scope (intentional)

- Showing the heuristic verdict from the last done-hook fire (PARTIAL / LIKELY_MET / etc.). Considered during brainstorm; rejected to avoid alarming users mid-session with a heuristic label. The verdict surfaces at session end via the Stop hook's stderr block; `/done` is the authoritative claim.
- Two-line layout. Considered; rejected to preserve single-row footprint. Revisit if wrap reports come in.
- Progress-bar rendering of token usage. Considered; rejected as over-engineered for v1.
- Tests. The existing statusline has none; adding a test harness for a debounced shell renderer is more infrastructure than the change warrants. Manual verification via sample JSON inputs is sufficient.
- Refactoring `extract_last_stanza` into a shared library. YAGNI for two callers.

## Integration with done-hook plan

This design is implemented as a single new task — **Task 23** — appended to `docs/superpowers/plans/2026-05-18-done-hook-plan.md`. The plan's existing 22 tasks are untouched. Task 23 modifies only `.claude/statusline.sh` (project) and `~/.claude/statusline.sh` (user, via the deploy step from Task 20).

Plan-task summary for Task 23:

1. Edit project `.claude/statusline.sh` to add goal + token segments per this spec.
2. Manual verification with three sample JSON payloads (goal-set, no-goal, no-context-window).
3. Verify perf via `time (echo "$json" | bash statusline.sh)` (target <50ms).
4. Commit with conventional message (`feat(statusline): show session goal + context-token usage`).
5. Task 20's deploy step (`scripts/deploy.sh`) syncs the project `statusline.sh` into `~/.claude/statusline.sh`; the user-level mirror updates on deploy, not in this task.

## Open questions (none blocking)

- Whether to swap the emoji 🎯 for a less colorful glyph if terminal emoji rendering proves inconsistent. Defer to user feedback after rollout.
