# Recommendation Validator — Design

**Date:** 2026-05-10
**Status:** Approved (sections 1–6, brainstorm transcript)
**Owner:** eduardoa@nvidia.com

## Problem

When the assistant calls `AskUserQuestion` with one option marked `(Recommended)`,
the user has to read the full question and decide whether to accept the
recommendation. For questions where the recommendation is sound, this is a
papercut — but the cost compounds across a session. For questions where the
recommendation is wrong, the user has to catch it manually.

Goal: when the assistant is confident, validate the recommendation with a small
adversarial panel; if the panel agrees, take the recommendation without asking
the user. If the panel dissents, surface the dissent in the question so the
user has more context.

## Architecture

A `PreToolUse` hook on `AskUserQuestion` watches for the `(Recommended)`
marker. When triggered, it writes the tool input to a session-scoped state
file and returns a `block` decision instructing the assistant to invoke a
`validate-recommendation` skill. The skill reads the state file, dispatches
two panelists in parallel via the `Agent` tool — devil's advocate (DA) as a
`general-purpose` subagent with an adversarial charter, and Principal
Engineer (PE) as the existing `principal-engineer` subagent — waits for both,
parses verdicts, and emits a directive for the assistant to act on.

Behavior on verdicts:
- **Both HOLD** → assistant auto-proceeds with the recommended option,
  printing a one-line panel summary so the user can interrupt if surprised.
- **Any OVERTURN** → assistant re-issues `AskUserQuestion` with the original
  options but with a one-paragraph dissent summary appended to the question
  text. The recommendation marker is swapped from `(Recommended)` to
  `(Recommended; Panel-flagged)` so the hook does not fire again (loop guard).
- **ERROR** (timeout, malformed verdict, parse failure) → assistant asks the
  original question unmodified.

Bypass: `CLAUDE_PANEL=off` env var skips the hook entirely.

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

**State file** (`${TMPDIR}/claude-panel-${session_id}.json`):
```json
{
  "session_id": "...",
  "tool_input": { "...": "verbatim copy" },
  "recommended_label": "Option A (Recommended)",
  "timeout_seconds": 90,
  "created_at": "2026-05-10T..."
}
```
When `tool_input.questions` has multiple entries, each question with a
`(Recommended)` option contributes one entry to a `questions[]` array in the
state file. Verdicts are computed per question; the augmented payload
preserves question order.

**Per-panelist Agent prompt** (constructed by skill):
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

**Reasoning extraction**: the skill extracts the "why this is recommended"
narrative from the option's `description` field (which is where the
recommendation rationale typically lives) and the question's lead text. No
attempt to read hidden chain-of-thought; "(no reasoning supplied)" is
acceptable input.

**Aggregation rules** (`aggregate.sh`):
- Both `VERDICT: HOLD` → `PANEL_VERDICT: HOLD`
- Any `VERDICT: OVERTURN` → `PANEL_VERDICT: DISSENT` + augmented question JSON
  (original text + appended `**Panel review:** <DA rationale> / <PE rationale>`,
  marker swapped to `Panel-flagged`)
- Either verdict file unparsable / empty → `PANEL_VERDICT: ERROR`
- Both panelists OVERTURN with different alternatives → DISSENT, both
  alternatives included in the summary

## Components

| Path | Purpose | Approx LOC |
|------|---------|------------|
| `.claude/hooks/validate-recommendation.sh` | PreToolUse hook: detects marker, writes state, blocks with skill directive | 50 |
| `.claude/hooks/validate-recommendation_test.sh` | Hook test suite (7 cases) | 80 |
| `.claude/skills/validate-recommendation/SKILL.md` | Orchestration: read state, dispatch panelists, call aggregate, emit directive | 150 |
| `.claude/skills/validate-recommendation/personas.md` | Two persona prompts (DA + PE charter) | 80 |
| `.claude/skills/validate-recommendation/aggregate.sh` | Verdict parsing + augmented question construction | 100 |
| `.claude/skills/validate-recommendation/aggregate_test.sh` | Aggregator unit tests | 60 |
| `.claude/skills/validate-recommendation/fixtures/*.json` | Test fixtures (5 verdict scenarios) | n/a |
| `.claude/skills/validate-recommendation/README.md` | Install notes + E2E smoke test procedure | 50 |
| `.claude/settings.json` | Add PreToolUse hook entry for AskUserQuestion | +5 |
| `.claude/CLAUDE.md` | Add "Recommendation panel" section | +10 |

## Personas

**Devil's Advocate** (general-purpose subagent):
> You are a devil's advocate reviewing a recommendation made by another
> assistant. Your job is to find the strongest reason this recommendation is
> wrong. Consider: hidden assumptions, edge cases the recommendation breaks
> on, alternatives that better match the user's stated goal, second-order
> effects. If after honest scrutiny you cannot find a meaningful counter,
> say so explicitly — `VERDICT: HOLD` with rationale "no stronger counter
> found, options examined: ...". Do not manufacture criticism.

**Principal Engineer** (`principal-engineer` subagent):
> You are reviewing a recommendation against the engineering principles in
> ~/.claude/CLAUDE.md and ~/.claude/rules/. Evaluate against:
> - Atomicity (one concern per change)
> - YAGNI (no unnecessary abstractions)
> - Security > Correctness > Performance > Style
> - TDD (testable, verifiable)
> - Where relevant: K8s conventions, Go conventions, container conventions,
>   git workflow.
> If the recommendation aligns with these principles, `VERDICT: HOLD`. If it
> violates one, `VERDICT: OVERTURN` and name the principle and a specific
> alternative option that aligns better.

Both panelists receive the question text, all options with descriptions, the
recommended label, and the extracted reasoning. Both must produce the strict
output format.

## Error handling

| # | Failure mode | Behavior |
|---|--------------|----------|
| 1 | Subagent timeout (>90s) | Treat as ERROR for that vote → overall ERROR → fall through to original question |
| 2 | Subagent returns malformed verdict | Same as timeout |
| 3 | State file missing when skill runs | Skill exits with one-line error; assistant falls back to original question |
| 4 | `CLAUDE_PANEL=off` | Hook approves immediately; no state file, no skill |
| 5 | Loop guard (Panel-flagged marker) | Hook approves immediately; question reaches user |
| 6 | Multi-question `AskUserQuestion` | Per-question panel; questions without recommendations skip panel |
| 7 | `jq` missing or hook script error | Hook fails open (status 0, approve); error logged to stderr |

Stale state files: path includes `$CLAUDE_SESSION_ID`, so cross-session
collisions are impossible. Tools are sequential within a session, so
intra-session collision is not possible either.

Reasoning extraction returns empty: skill includes "(no reasoning supplied)";
panelists evaluate options on their merits.

Auto-take residual risk (panel HOLD but recommendation is wrong): mitigated
by always printing abbreviated panel rationales on auto-take —
*"Panel validated A. DA: <one-line rationale>. PE: <one-line rationale>.
Proceeding."* — so the user can interrupt.

## Configuration

Environment variables (all read at hook execution; none must be permanently
exported):
- `CLAUDE_PANEL` — `on` (default) or `off`
- `CLAUDE_PANEL_TIMEOUT` — seconds per panelist, default 90
- `CLAUDE_PANEL_DEBUG` — if set, hook writes trace to `~/.claude/debug/panel-trace.log`

Settings file change (`.claude/settings.json`): one entry appended to
`hooks.PreToolUse` with matcher `AskUserQuestion`. If a PreToolUse matcher
for `AskUserQuestion` already exists, append to its `hooks` list.

Documentation update (`.claude/CLAUDE.md`): one new section, ~10 lines,
explaining what the panel does, the bypass env var, and the dissent flow.

## Testing

**Hook unit tests** (`validate-recommendation_test.sh`, follows existing
`_test.sh` pattern in the repo):
- `test_marker_present_blocks` — input with `(Recommended)` → decision=block
- `test_marker_absent_approves` — input without marker → decision=approve
- `test_loop_guard_approves` — input with `Panel-flagged` → approve
- `test_env_off_approves` — `CLAUDE_PANEL=off` → approve regardless
- `test_malformed_json_approves` — bad JSON → approve + stderr (fail-open)
- `test_state_file_written_on_block` — state file exists, has expected keys
- `test_no_state_file_on_approve` — no leftover state file

**Aggregator unit tests** (`aggregate_test.sh`):
- `both_hold.fixture` → `PANEL_VERDICT: HOLD`
- `da_overturn.fixture` → DISSENT, alternative=DA's pick
- `pe_overturn.fixture` → DISSENT, alternative=PE's pick
- `both_overturn_diff.fixture` → DISSENT, both alternatives in summary
- `malformed_da.fixture` → ERROR

Each fixture is a verdict file pair (DA verdict + PE verdict) plus the
expected aggregator output.

**E2E smoke test** (manual, documented in skill README):
1. Confirm `CLAUDE_PANEL` is unset (default = on)
2. Open a fresh Claude Code session
3. Ask the assistant for a recommendation that triggers `AskUserQuestion`
4. Verify the panel runs (hook block + skill dispatch) before the question
   surfaces (or doesn't surface, if HOLD)
5. Inspect `~/.claude/debug/` for hook stderr — should be empty on success
6. Repeat with `CLAUDE_PANEL=off` — verify panel does NOT fire

**Not unit-tested**: persona prompt quality (validated by reading panel
outputs over first ~10 real uses, iterated in `personas.md`); assistant
fidelity to skill instructions (a model+prompt question, not a contract).

## Out of scope (v1)

- Persona prompts in external YAML config (overkill until iteration demands)
- Tracking panel verdict statistics or rates over time
- Configurable third panelist for tie-breaking
- Caching panel verdicts for identical questions across sessions
- Triggering panel on plain-text recommendations (only `AskUserQuestion`)
- Running panel on ExitPlanMode or other tools that contain options
