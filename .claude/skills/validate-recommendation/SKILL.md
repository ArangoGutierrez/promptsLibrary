---
name: validate-recommendation
description: Validate (Recommended) options in AskUserQuestion via two parallel panelists — devil's advocate (external chat-completion API) + principal-engineer (Claude subagent). Triggered by the validate-recommendation hook; do not invoke manually.
---

# Validate Recommendation

You were invoked because the `validate-recommendation` hook fired on an
`AskUserQuestion` call that contained a `(Recommended)` option marker.
Your job: dispatch a two-panelist review, aggregate verdicts, and act on
the directive.

## Inputs

The hook wrote tool input to a session state file. Read it via the
`Read` tool:

```
STATE_FILE="${TMPDIR:-/tmp}/claude-panel-${CLAUDE_SESSION_ID:-unknown}.json"
```

If the file is missing, emit the user-visible message
"Panel state file missing; asking the original question." and fall
back to issuing the original `AskUserQuestion` unmodified. Stop here.

State file keys you'll use:

- `tool_input.questions` — array of question objects (1-4 items per the
  AskUserQuestion schema)
- `recommended_label` — first label containing `(Recommended)` (loop-
  guard excluded). For multi-question payloads this is the FIRST
  recommendation found; you'll need to re-extract per question.
- `timeout_seconds` — per-panelist budget (default 90)

## Personas

The persona prompts live in `personas.md` next to this skill. Read that
file once before constructing panelist prompts. It contains:

- **Devil's Advocate (DA)** — system prompt (with one-shot example)
  embedded by `dispatch-da.sh`. You construct only the user prompt.
- **Principal Engineer (PE)** — full prompt passed verbatim to the
  Agent tool.

## Per-question dispatch

For EACH question in `tool_input.questions` that has an option labeled
with `(Recommended)` AND NOT `Panel-flagged`:

### 1. Build the user prompt body

Construct from state file data:

```
Question: <question text>
Options (verbatim labels and descriptions):
  <option 1 label> — <option 1 description>
  <option 2 label> — <option 2 description>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <see "Reasoning extraction" below>
```

### 2. Reasoning extraction

The "stated reasoning" passed to panelists comes from:

1. The recommended option's `description` field (primary source). This
   is where the "why this option is recommended" story lives.
2. The question's lead text, if it contains rationale phrases.

If neither is informative, pass `(no reasoning supplied)`. Panelists
are told this is acceptable input. NEVER attempt to read or fabricate
hidden chain-of-thought.

### 3. Construct DA prompt file

Combine the DA system prompt (from `personas.md`) + the one-shot
example + the user prompt body. Write the entire prompt to a temp file
via the `Write` tool:

```
DA_PROMPT_FILE="${TMPDIR:-/tmp}/panel-da-prompt-${CLAUDE_SESSION_ID}-q<N>.txt"
```

(Where `<N>` is the question index, 0-based.)

### 4. Construct PE prompt

The PE prompt is the persona's "PE prompt" section verbatim, with the
templated user prompt body substituted at the bottom. This is a STRING
you pass to the Agent tool — no file needed.

### 5. Dispatch BOTH panelists in parallel

In a SINGLE message, call two tools:

- **`Bash`** tool:
  ```
  .claude/skills/validate-recommendation/dispatch-da.sh \
      --prompt-file "$DA_PROMPT_FILE" \
      --output "${TMPDIR:-/tmp}/panel-da-verdict-${CLAUDE_SESSION_ID}-q<N>.txt"
  ```
  Note: `dispatch-da.sh` reads `$PANEL_DA_API_KEY`,
  `$CLAUDE_PANEL_DA_ENDPOINT`, and `$CLAUDE_PANEL_DA_MODEL` from the
  inherited environment. Do not pass them on the command line; do not
  echo the key anywhere.

- **`Agent`** tool:
  - `subagent_type`: `principal-engineer`
  - `description`: short, e.g., "Panel PE review"
  - `prompt`: the full PE prompt string

The two tools execute concurrently because they're in one message.

### 6. Save PE response to a verdict file

When the `Agent` tool returns, its output is a string (possibly with
prose framing). Write the ENTIRE response to:

```
PE_VERDICT_FILE="${TMPDIR:-/tmp}/panel-pe-verdict-${CLAUDE_SESSION_ID}-q<N>.txt"
```

`aggregate.sh` uses `grep -m1 "^VERDICT: "` to find the verdict line,
so surrounding prose is ignored. If the Agent omitted the strict
format entirely (no `VERDICT:` line), aggregate.sh will emit ERROR —
that's the desired behavior.

### 7. Run aggregate.sh

Via the `Bash` tool:

```
.claude/skills/validate-recommendation/aggregate.sh \
    --da "$DA_VERDICT_FILE" \
    --pe "$PE_VERDICT_FILE" \
    --recommended-label "<recommended_label from state for THIS question>"
```

Capture stdout — that's the directive.

## Acting on verdicts

After running `aggregate.sh` for each question, you have a directive
per question. Apply per-question logic.

### `PANEL_VERDICT: HOLD`

Behavior depends on `${CLAUDE_PANEL:-on}`:

**Default (`on`)** — auto-take mode:

The recommendation stands. Take the recommended option without asking
the user. Print a brief one-paragraph message so the user can interrupt
if surprised:

> Panel validated `<recommended_label>` for "<question excerpt>".
> DA: <abbreviated rationale from aggregate stdout>
> PE: <abbreviated rationale from aggregate stdout>
> Proceeding.

Then continue the work as if the user had picked the recommended
option. The `AskUserQuestion` for this question is NEVER issued.

**`advise`** — advisory mode (preserves user agency):

Do NOT auto-take. Re-issue `AskUserQuestion` for this question with
the panel's affirmative annotation appended. Augmented payload:

- **Question text**: original question + two newlines +
  `**Panel validated:** DA: <rationale>. PE: <rationale>.` The phrasing
  is positive (validated, not flagged) so
  the user knows the panel agreed; they still pick the answer.
- **Options**: identical to original, EXCEPT the recommended option's
  label has `(Recommended)` replaced with `(Recommended;
  Panel-flagged)`. Same loop-safety mechanism as DISSENT — the hook's
  re-entry guard handles the second call.

Use this when `CLAUDE_PANEL=advise` is set. The user explicitly opted
into seeing every recommendation question, panel commentary included.

### `PANEL_VERDICT: DISSENT`

Re-issue `AskUserQuestion` for this question only. The augmented
payload:

- **Question text**: original question + two newlines + the panel
  summary line from `aggregate.sh` stdout (starts with
  `**Panel review:**`).
- **Options**: identical to original, EXCEPT the recommended option's
  label has `(Recommended)` replaced with
  `(Recommended; Panel-flagged)`. The hook detects this marker and
  skips the panel on the re-ask, so you won't infinite-loop.

If the original `AskUserQuestion` call had multiple questions, only
the DISSENTed questions get augmented and re-asked; HOLD questions
are auto-resolved without re-asking; ERROR questions are re-asked
unchanged (see below).

### `PANEL_VERDICT: ERROR`

Something went wrong (DA backend down, malformed PE response,
missing files, aggregator parse error). For this question, re-issue
the original `AskUserQuestion` unmodified — same options, same
`(Recommended)` marker — BUT swap the marker to `(Recommended;
Panel-flagged)` so the hook doesn't fire panel again and create an
infinite loop. The user sees the question, no dissent appended,
panel rationale silently dropped.

Print a brief explanation to the user:

> Panel evaluation failed for "<question excerpt>" (see hook trace
> for detail). Asking the question directly.

## Cleanup

After processing ALL questions (HOLD + DISSENT + ERROR paths
included), delete the temp files:

```
rm -f "$STATE_FILE" \
      "${TMPDIR:-/tmp}/panel-da-prompt-${CLAUDE_SESSION_ID}-q"*.txt \
      "${TMPDIR:-/tmp}/panel-da-verdict-${CLAUDE_SESSION_ID}-q"*.txt \
      "${TMPDIR:-/tmp}/panel-pe-verdict-${CLAUDE_SESSION_ID}-q"*.txt
```

If you crash before cleanup, stale files are harmless (different
session = different `CLAUDE_SESSION_ID` = different file paths).

## Failure modes you must handle gracefully

| What goes wrong | Behavior |
|---|---|
| State file missing | Print "Panel state file missing; asking the original question." Fall back to original `AskUserQuestion`. |
| `personas.md` unreadable | Same fallback. Print "Panel personas unavailable; asking directly." |
| `dispatch-da.sh` exits non-zero (only happens if --prompt-file or --output missing) | Treat as ERROR for that question. |
| DA verdict file is missing after Bash call | Treat as ERROR for that question. |
| PE Agent times out or returns garbled output | aggregate.sh will emit ERROR; follow ERROR branch. |
| aggregate.sh missing | Print "Panel infrastructure unavailable; asking directly." Fall back. |
| `$PANEL_DA_API_KEY` / `$CLAUDE_PANEL_DA_ENDPOINT` / `$CLAUDE_PANEL_DA_MODEL` unset | dispatch-da.sh writes an ERROR verdict; aggregate emits ERROR; follow ERROR branch. The user-facing message ends up the same. |

The whole panel is best-effort. The user-visible question ALWAYS
survives.

### Loop safety on fallback

When you fall back to re-issuing the original `AskUserQuestion` (state
file missing, personas unreadable, aggregate.sh missing, etc.), the
original payload still has the `(Recommended)` marker — meaning the
hook will fire AGAIN when you re-issue. To prevent an infinite loop
of failed-panel → re-issue → failed-panel, the hook has a re-entry
guard: if a state file for the current session already exists when the
hook runs, the hook removes it and approves (exit 0) without
dispatching the skill again.

This means your fallback re-issue is mechanically safe — even if you
forget to swap the marker to `(Recommended; Panel-flagged)`, the
second call gets through. As a courtesy to future readers, you may
still swap the marker in your fallback re-issue (it's a no-op for
loop safety but documents intent). The hook test `test8` verifies the
re-entry guard.

## Multi-question parallelism (optional optimization)

If the `AskUserQuestion` call had multiple questions each with a
`(Recommended)` marker, you MAY dispatch panel calls for ALL
questions in parallel (one Bash call per question DA + one Agent
call per question PE, all in one message). Aggregate.sh runs per
question after both panelists return.

For v1, sequential per-question dispatch is fine. Optimize only if
multi-question recommendations are common (they aren't in practice).

## What you must NOT do

- Do NOT echo `$PANEL_DA_API_KEY` in any user-facing text or
  trace output.
- Do NOT write the API key to any file.
- Do NOT fall back to `reasoning_content` (or any other field) if the
  DA response's `content` is null — `dispatch-da.sh` is responsible
  for that decision and intentionally emits ERROR in that case.
- Do NOT modify the AskUserQuestion call beyond augmenting question
  text (for DISSENT) or swapping the marker (for ERROR).
- Do NOT re-invoke the panel skill after taking a recommendation
  (HOLD path). The work continues as if the user picked.
- Do NOT introduce a third panelist or override the persona prompts.
  If you think the personas need tuning, propose a separate change
  via brainstorm — don't improvise in the moment.
