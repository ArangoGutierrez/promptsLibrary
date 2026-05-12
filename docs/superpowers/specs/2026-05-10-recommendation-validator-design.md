# Recommendation Validator — Design

**Date:** 2026-05-10
**Status:** Approved

## Problem

When the assistant calls `AskUserQuestion` with one option marked
`(Recommended)`, the user has to read the full question and decide
whether to accept the recommendation. For questions where the
recommendation is sound, this is a papercut — but the cost compounds
across a session. For questions where the recommendation is wrong,
the user has to catch it manually.

Goal: when the assistant is confident, validate the recommendation
with a small adversarial panel; if the panel agrees, take the
recommendation without asking the user. If the panel dissents,
surface the dissent in the question so the user has more context.

## Architecture

A `PreToolUse` hook on `AskUserQuestion` watches for the
`(Recommended)` marker. When triggered, it writes the tool input to a
session-scoped state file and returns a block decision instructing
the assistant to invoke a `validate-recommendation` skill. The skill
reads the state file and dispatches two panelists in parallel via
different backends:

- **Devil's advocate (DA)** — invoked via a helper script
  `dispatch-da.sh` that POSTs the panelist prompt to a user-configured
  OpenAI-compatible chat completions endpoint. Independent reasoner
  from a different model family than Claude; no tool access needed
  for arguing-against. Authenticates via `$PANEL_DA_API_KEY`,
  `$CLAUDE_PANEL_DA_ENDPOINT`, and `$CLAUDE_PANEL_DA_MODEL` read at
  runtime; never embedded in repo files.
- **Principal Engineer (PE)** — invoked via the existing `Agent`
  tool with `subagent_type: principal-engineer`. Retains
  Read/Grep/Bash/Glob access so it can actually read
  `~/.claude/CLAUDE.md` and `~/.claude/rules/` during evaluation
  rather than relying on inlined rules.

Both produce verdict files in the same strict format
(`VERDICT:`/`RATIONALE:`/`ALTERNATIVE:`). The skill calls
`aggregate.sh` over both files to compute the directive, which is
backend-agnostic.

Behavior on verdicts:
- **Both HOLD** → assistant auto-proceeds with the recommended option,
  printing a one-line panel summary so the user can interrupt if
  surprised. With `CLAUDE_PANEL=advise`, the question is instead
  re-issued with a `**Panel validated:**` note so the user retains
  agency.
- **Any OVERTURN** → assistant re-issues `AskUserQuestion` with the
  original options but with a one-paragraph dissent summary appended
  to the question text. The recommendation marker is swapped from
  `(Recommended)` to `(Recommended; Panel-flagged)` so the hook does
  not fire again (loop guard).
- **ERROR** (timeout, malformed verdict, missing files) → assistant
  asks the original question unmodified. The hook's re-entry guard
  ensures the second call bypasses the panel.

Bypass: `CLAUDE_PANEL=off` skips the hook entirely.

## Data flow

**Hook input** (received on stdin per Claude Code hook spec):

```json
{
  "tool_name": "AskUserQuestion",
  "tool_input": {
    "questions": [{
      "question": "...",
      "options": [
        {"label": "Option A (Recommended)", "description": "..."},
        {"label": "Option B", "description": "..."}
      ]
    }]
  },
  "session_id": "..."
}
```

**State file** (`${TMPDIR}/claude-panel-${session_id}.json`,
mode 0600):

```json
{
  "session_id": "...",
  "tool_input": { "...": "verbatim copy" },
  "recommended_label": "Option A (Recommended)",
  "timeout_seconds": 90,
  "created_at": "2026-05-10T..."
}
```

When `tool_input.questions` has multiple entries, each question with
a `(Recommended)` option contributes one entry to a `questions[]`
array in the state file. Verdicts are computed per question; the
augmented payload preserves question order.

**Per-panelist prompt** (constructed by skill):

```
Question: <question text>
Options (verbatim, with descriptions):
  A. <label> — <description>
  B. <label> — <description>
Assistant's recommended option: <recommended_label>
Assistant's stated reasoning: <extracted from option description and question text>

Your role: <DA or PE persona prompt from personas.md>

Required output (strict, parsed by aggregate.sh):
VERDICT: <HOLD|OVERTURN>
RATIONALE: <one paragraph, 3-5 sentences>
ALTERNATIVE: <option label, only if OVERTURN; otherwise "n/a">
```

**Reasoning extraction**: the skill extracts the "why this is
recommended" narrative from the option's `description` field (where
the recommendation rationale typically lives) and the question's lead
text. No attempt to read hidden chain-of-thought;
"(no reasoning supplied)" is acceptable input.

**Aggregation rules** (`aggregate.sh`):
- Both `VERDICT: HOLD` → `PANEL_VERDICT: HOLD`
- Any `VERDICT: OVERTURN` → `PANEL_VERDICT: DISSENT` + augmented
  question JSON (original text + appended `**Panel review:** <DA
  rationale> / <PE rationale>`, marker swapped to `Panel-flagged`)
- Either verdict file unparseable / empty → `PANEL_VERDICT: ERROR`
- Both panelists OVERTURN with different alternatives → DISSENT,
  both alternatives included in the summary
- Rationales are sanitized (markdown links, image syntax, backticks
  stripped) before embedding in user-visible text

## Components

| Path | Purpose |
|------|---------|
| `.claude/hooks/validate-recommendation.sh` | PreToolUse hook: detects marker, writes state, blocks with skill directive, re-entry guard |
| `.claude/hooks/validate-recommendation_test.sh` | Hook test suite (8 cases) |
| `.claude/skills/validate-recommendation/SKILL.md` | Orchestration: read state, dispatch panelists, call aggregate, emit directive |
| `.claude/skills/validate-recommendation/personas.md` | DA + PE persona prompts (the DA prompt includes a one-shot example) |
| `.claude/skills/validate-recommendation/dispatch-da.sh` | HTTP wrapper: POSTs to the configured OpenAI-compatible endpoint, parses response, writes verdict file |
| `.claude/skills/validate-recommendation/dispatch-da_test.sh` | dispatch-da test suite (14 cases including argv-leak guard) |
| `.claude/skills/validate-recommendation/aggregate.sh` | Verdict parser + augmented question construction + verdict telemetry |
| `.claude/skills/validate-recommendation/aggregate_test.sh` | Aggregator test suite (7 cases) |
| `.claude/skills/validate-recommendation/fixtures/*.json` | DA response fixtures (5 scenarios) |
| `.claude/skills/validate-recommendation/fixtures/*.txt` | Verdict fixtures (5 scenarios) |
| `.claude/skills/validate-recommendation/README.md` | Install notes + env vars + smoke tests + troubleshooting |
| `.claude/settings.json` | Add PreToolUse hook entry for AskUserQuestion |
| `.claude/CLAUDE.md` | "Recommendation Panel" section |

## Personas

**Devil's Advocate** (external chat-completion backend):

> You are a devil's advocate reviewing a recommendation made by
> another assistant. Your job is to find the strongest reason this
> recommendation is wrong. Consider: hidden assumptions, edge cases
> the recommendation breaks on, alternatives that better match the
> user's stated goal, second-order effects. If after honest scrutiny
> you cannot find a meaningful counter, say so explicitly —
> `VERDICT: HOLD` with rationale "no stronger counter found, options
> examined: ...". Do not manufacture criticism.

The DA prompt includes a one-shot example of the strict output format
to maximize format compliance. Some reasoning models emit a separate
`reasoning_content` field; `dispatch-da.sh` ignores that and
extracts only `.choices[0].message.content`.

**Principal Engineer** (`principal-engineer` subagent):

> You are reviewing a recommendation against the engineering
> principles in `~/.claude/CLAUDE.md` and `~/.claude/rules/`.
> Evaluate against: atomicity, YAGNI, security > correctness >
> performance > style, TDD, K8s/Go/container conventions where
> relevant. If the recommendation aligns, `VERDICT: HOLD`. If it
> violates a principle, `VERDICT: OVERTURN` — name the principle
> and a specific alternative option that aligns better.

Both produce the strict output format. ALTERNATIVE must be a
verbatim option label from the input (aggregator matches by string
contains; abbreviations don't match).

## Error handling

| # | Failure mode | Behavior |
|---|--------------|----------|
| 1 | Subagent / DA timeout (>90s) | Treat as ERROR for that vote → overall ERROR → fall through to original question |
| 2 | Panelist returns malformed verdict | Same as timeout |
| 3 | State file missing when skill runs | Skill exits with one-line error; assistant falls back to original question; hook re-entry guard prevents loops |
| 4 | `CLAUDE_PANEL=off` | Hook approves immediately; no state file, no skill |
| 5 | Loop guard (Panel-flagged marker) | Hook approves immediately; question reaches user |
| 6 | Re-entry: state file exists from prior failed dispatch | Hook removes stale state and approves; prevents infinite loops on skill failure |
| 7 | Multi-question `AskUserQuestion` | Per-question panel; questions without recommendations skip panel |
| 8 | `jq` missing or hook script error | Hook fails open (status 0, approve); error logged to stderr |
| 9 | `$PANEL_DA_API_KEY` / `$CLAUDE_PANEL_DA_ENDPOINT` / `$CLAUDE_PANEL_DA_MODEL` unset | `dispatch-da.sh` writes ERROR verdict; aggregator emits ERROR; user sees original question |
| 10 | DA endpoint returns non-200 / malformed body | Same ERROR fallback path |

Stale state files: path includes `$CLAUDE_SESSION_ID`, so
cross-session collisions are impossible. Re-entry within a session is
handled by the hook's re-entry guard.

Auto-take residual risk (panel HOLD but recommendation is wrong):
mitigated by always printing abbreviated panel rationales on
auto-take. `CLAUDE_PANEL=advise` removes auto-take entirely while
preserving the panel's audit value.

## Configuration

Required environment variables (DA backend):
- `PANEL_DA_API_KEY` — bearer token for the chat completions endpoint
- `CLAUDE_PANEL_DA_ENDPOINT` — full URL of an OpenAI-compatible
  `/v1/chat/completions` endpoint (`https://` only, except
  `http://localhost`)
- `CLAUDE_PANEL_DA_MODEL` — model identifier accepted by the endpoint

Optional environment variables:
- `CLAUDE_PANEL` — `on` (default) / `advise` / `off`
- `CLAUDE_PANEL_TIMEOUT` — seconds per panelist, default 90
- `CLAUDE_PANEL_DA_TIMEOUT` — DA HTTP timeout, default 60
- `CLAUDE_PANEL_TRACE_LOG` — telemetry path, default
  `~/.claude/debug/panel-trace.log`
- `CLAUDE_PANEL_DEBUG` — extra verbose trace lines

Settings file change (`.claude/settings.json`): one entry appended to
`hooks.PreToolUse` with matcher `AskUserQuestion`.

Documentation update (`.claude/CLAUDE.md`): one new section
explaining what the panel does, the three modes
(`on`/`advise`/`off`), and the bypass.

## Telemetry

Default-on append to `${CLAUDE_PANEL_TRACE_LOG}`. Lines:

- `[ISO timestamp] event=trigger session=<id> label="<recommended>"`
  — hook fired
- `[ISO timestamp] event=reentry_bypass session=<id>` — hook detected
  stale state, bypassed
- `[ISO timestamp] event=verdict session=<id> outcome=HOLD|DISSENT|ERROR detail="..."`
  — aggregator emitted directive

Operator can detect silent decay (e.g., DA backend consistently
ERRORing) by tailing the log: `grep -c outcome=ERROR
~/.claude/debug/panel-trace.log`.

## Security

- `$PANEL_DA_API_KEY` is read at runtime; never persisted in repo
  files, never logged in trace output, never echoed in errors.
- Authorization header passed to curl via `umask 077` temp file +
  `-H @<file>` syntax so the key does not appear in process argv.
- Hook + dispatch-da both set `umask 077` so state files and verdict
  files are mode 0600.
- aggregate.sh sanitizes panelist rationales (strips markdown link /
  image syntax / backticks) before embedding in user-visible text.
- Endpoint must be `https://` (or `http://localhost`); catches typos
  and accidental http://prod misconfigurations. Not an
  attacker-proof allowlist — anyone with shell-init access can
  change endpoint and validation alike.

## Testing

**Hook unit tests** (`validate-recommendation_test.sh`, 8 cases):
- marker present → exit 2 + state file written + stderr mentions skill
- no marker → exit 0, no state file
- Panel-flagged loop guard → exit 0
- `CLAUDE_PANEL=off` → exit 0 regardless
- malformed JSON → exit 0 (fail-open)
- state file has expected keys + mode 0600
- non-AskUserQuestion tool → exit 0 (no-op)
- re-entry: stale state → exit 0 + state removed; next call → block

**dispatch-da tests** (`dispatch-da_test.sh`, 14 cases including):
- API key / endpoint / model unset → ERROR verdict (one test each)
- mock HOLD/OVERTURN/malformed/null-content/api-error → expected
  verdict
- mock file unreadable → ERROR
- missing CLI args → exit non-zero
- API key NOT in verdict file content
- API key NOT in curl argv (anti-leak)
- non-https endpoint → ERROR
- http://localhost endpoint → allowed

**Aggregator tests** (`aggregate_test.sh`, 7 cases):
- both HOLD → PANEL_VERDICT: HOLD with non-empty DA/PE abbreviations
  preserving paths like `~/.claude/CLAUDE.md`
- one OVERTURN → DISSENT with alternative
- both OVERTURN with different alts → DISSENT, both listed
- malformed verdicts → ERROR
- markdown injection in rationale → sanitized

**E2E smoke test** (manual, documented in skill README):
1. Confirm required DA-backend env vars are set
2. Open a fresh Claude Code session
3. Trigger `AskUserQuestion` with `(Recommended)`
4. Verify HOLD auto-takes or DISSENT re-asks
5. `CLAUDE_PANEL=off claude` — verify panel does NOT fire

## Out of scope (v1)

- Persona prompts in external YAML config
- Tracking panel verdict statistics over time (beyond trace log)
- Configurable third panelist for tie-breaking
- Caching panel verdicts for identical questions across sessions
- Triggering panel on plain-text recommendations (only
  `AskUserQuestion`)
- Running panel on ExitPlanMode or other tools that contain options
- Retry/backoff on DA backend failures (one shot per panelist)
- Streaming responses from DA backend (single-shot completion)
- Multiple model selection per question (fixed model per session)
- Fallback DA backend (e.g., Claude subagent) when configured DA is
  down — if it consistently fails, set `CLAUDE_PANEL=off` or
  `CLAUDE_PANEL=advise`
