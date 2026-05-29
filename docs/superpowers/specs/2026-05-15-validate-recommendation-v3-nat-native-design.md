# validate-recommendation v3 — NAT-native canonical design

**Date:** 2026-05-15
**Status:** Approved
**Supersedes:**
- `2026-05-14-validate-recommendation-redesign-design.md` (v2.0 + v2.1 amendment)
- `2026-05-10-recommendation-validator-design.md` (v1)

v3 is a fresh canonical design, not an amendment. It consolidates the v2.0 spec, the v2.1 NAT amendment, and Phase 1+2 implementation experience into one document. Reading the older specs is not required to build v3 — every locked decision and every behavioral contract is restated here.

## Why a v3 redesign

The v1 panel shipped two-backend (1 DA + 1 PE) with a binary HOLD/DISSENT contract. End-to-end verification on 2026-05-14 surfaced three blocking bugs and a structural limit:

1. `dispatch-da.sh` did not embed the DA system prompt — payload contained only a `role: "user"` message, so Nemotron returned prose without the strict format and the aggregator emitted ERROR.
2. `max_tokens: 1024` truncated reasoning-model output mid-RATIONALE.
3. The aggregator accepted `OVERTURN + ALTERNATIVE: n/a` as a valid dissent (contradicts the personas spec).
4. Single-DA composition meant single-model blind-spot risk; binary contract meant every dissent surfaced at the same urgency regardless of how strong the rationale was.

v2.0 and v2.1 specified a fix path in patchwork form (one spec, one amendment, six phase plans, plus a NAT integration plan). v3 is the consolidated successor: a single document a future-Claude can read cold and understand the system without reconstructing context from v2.0 + v2.1 + seven plans.

The panel is intended as a moat — the thing that makes recommending Claude faster and better than recommending Claude alone, by catching bad recommendations before the user has to.

## Locked design decisions

These were settled across v2.0, v2.1, and Phase 1+2 implementation. They are constraints on v3, not open questions.

| # | Decision | Choice |
|---|---|---|
| 1 | Panel-to-user contract | `HOLD` / `SOFT-DISSENT` / `HARD-DISSENT` / `ERROR` (severity-tiered friction) |
| 2 | Severity source | Vote count + rationale-strength gate. HARD requires majority OVERTURN AND ≥1 panelist names a principle or concrete alternative |
| 3 | Panel composition | Configurable N panelists with heterogeneous roles (`DA` / `PE` / `QA` / extensible), each backed by NAT-* or `claude-subagent` |
| 4 | Panel size invariant | Count of *enabled* panelists must be odd |
| 5 | Default panel size | N=1 (DA only); PE/QA opt-in via `enabled: true` in config |
| 6 | HARD-DISSENT UX | Bounded auto re-brainstorm (max 2 cycles, visible note, escalate to user on cap) |
| 7 | Telemetry | Always-on JSONL at `~/.claude/panel/decisions.jsonl` + batch labeling CLI. Optional NAT OTel emit when configured |
| 8 | Implementation language | Python 3.12 (`/opt/homebrew/bin/python3.12`) for all panel logic |
| 9 | NAT substrate | `nvidia-nat>=1.6,<2.0` (public PyPI, import name `nat`) as LLM provider abstraction for HTTP-backed panelists; imported as library, in-process. No NAT Workflow/Function/Agent primitives |
| 10 | Config format | YAML at `~/.claude/panel/config.yml` |
| 11 | `max_tokens` default | 32768 (Nemotron-typical max). Overridable per panelist |
| 12 | Orchestration model | Thin Python (per-panelist dispatch + final aggregate) + fat SKILL.md (parallel fan-out across NAT and subagent backends in one Claude turn) |
| 13 | State location | `~/.claude/panel/` (not `$TMPDIR`) — survives sandbox restrictions, persists across hook re-entries |
| 14 | Phase 1+2 reuse | Keep `verdict.py`, `sanitize.py`, `trace.py`, `cli.py`; rewrite `aggregate.py` for N panelists + severity tiers |

NAT does **not** provide voting/consensus, re-brainstorm cycle accounting, Claude Code hook integration, or severity logic. All four stay custom Python.

## System overview

```
┌──────────────────┐
│ AskUserQuestion  │  Claude emits with a (Recommended) option
└─────────┬────────┘
          ▼
┌──────────────────────────────────────────────┐
│ Hook: validate-recommendation.sh             │
│   PreToolUse, qhash-keyed state, exit 2      │
└─────────┬────────────────────────────────────┘
          ▼
┌──────────────────────────────────────────────┐
│ SKILL.md orchestrator (Claude)               │
│ 1. Read state + config.yml                   │
│ 2. Build per-panelist prompts                │
│ 3. Parallel fan-out in ONE message:          │
│      Bash panel dispatch (per nat-* panelist)│
│      Agent call          (per claude-subagent)│
│ 4. Collect verdict files                     │
│ 5. Bash panel aggregate                      │
│ 6. Act on directive (HOLD/SOFT/HARD/ERROR)   │
└─────────┬────────────────────────────────────┘
          ▼   (parallel, all in one Claude turn)
┌─────────┴───────────────┐
▼                         ▼
┌──────────────┐  ┌──────────────────┐
│ Bash         │  │ Agent (Claude)   │
│ panel dispatch│ │ subagent_type:   │
│   → Python    │ │   principal-eng. │
│   → NAT-NIM   │ │   → response text│
│ → verdict file│ │ → verdict file   │
└──────┬───────┘  └─────────┬────────┘
       │                    │
       └────────┬───────────┘
                ▼
┌──────────────────────────────────────────────┐
│ Bash panel aggregate                         │
│   Python: severity decision tree             │
│         + JSONL append (decisions.jsonl)     │
│         + directive JSON on stdout           │
└─────────┬────────────────────────────────────┘
          ▼
┌──────────────────────────────────────────────┐
│ Directive JSON → SKILL.md acts               │
│   HOLD     → auto-take (mode=on) / advise    │
│   SOFT     → re-ask with summary             │
│   HARD     → re-brainstorm directive OR      │
│              escalate to user on cycle cap   │
│   ERROR    → re-ask original unmodified      │
└──────────────────────────────────────────────┘
```

Two orchestration tiers, no overlap. SKILL.md handles parallelism and `claude-subagent` calls. Python handles NAT dispatch, severity decisions, and telemetry. Neither layer knows the other's internals.

### Component responsibilities

| Component | Role |
|---|---|
| Hook `~/.claude/hooks/validate-recommendation.sh` | Detect `(Recommended)` marker, compute qhash, write state file, exit 2 to invoke skill. Cycle-aware re-entry logic. |
| Hook `~/.claude/hooks/panel-record-userpick.sh` | PostToolUse on `AskUserQuestion`. Compute qhash from the answered question. Call `panel record-userpick` if a matching decision row exists in JSONL. |
| `SKILL.md` | Claude-driven orchestrator. Reads config, builds per-panelist prompts, dispatches N panelists in parallel (Bash + Agent calls in one message), runs aggregator, acts on directive. Only Claude-aware logic lives here. |
| `panel/dispatch.py` | NAT integration. Called per panelist via `python -m panel dispatch --panelist <id>`. `_invoke_nat(panelist, system, user)` is the seam tests mock. |
| `Agent` tool | Used directly by skill for `claude-subagent`-backed panelists. Not wrapped — shell can't invoke Claude tools. |
| `panel/aggregate.py` | N-panelist aggregation. Reads verdict files, calls severity tree, emits directive JSON on stdout, appends `decision` event to JSONL. |
| `panel/severity.py` | Pure decision tree. Inputs: parsed panelist verdicts + config + cycle. Output: directive dict. No I/O. |
| `panel/config.py` | YAML loader. Dataclass-based. Enforces odd-N invariant on enabled count, backend whitelist, threshold/failure-mode/max-cycles validation. |
| `panel/personas.py` | Per-role persona file loader. Splits front-matter + `# System prompt` / `# One-shot example` / `# User prompt template` sections. |
| `panel/state.py` | State file lifecycle: read/write/cleanup `~/.claude/panel/state-<qhash>.json`. qhash computation (canonical, identical across hook + skill + aggregator + post-hook). |
| `panel/decisions.py` | JSONL append-only: `decision`, `user_pick`, `label` events. Optional NAT OTel emit when `telemetry.otel_endpoint` is set. |
| `panel/cli.py` | argparse multi-subcommand dispatch. |
| `panel/verdict.py` | Parse `VERDICT/RATIONALE/ALTERNATIVE` from one verdict file. (Carried from Phase 1+2.) |
| `panel/sanitize.py` | Strip markdown injection vectors from rationales before embedding in user-visible summaries. (Carried from Phase 1+2.) |
| `panel/trace.py` | Append-only one-line trace events to `~/.claude/debug/panel-trace.log`. (Carried from Phase 1+2.) |
| `personas/<role>.md` | One Markdown file per role. New roles ship by dropping a new file — no code change. |
| `~/.claude/panel/config.yml` | User-owned panel composition, severity thresholds, failure mode, telemetry settings. |
| `~/.claude/panel/state-<qhash>.json` | Per-question cycle tracking. Survives hook re-entries. Cleaned by `panel gc`. |
| `~/.claude/panel/decisions.jsonl` | Append-only event log: `decision` / `user_pick` / `label` events. |
| `~/.claude/panel/work/<qhash>-<id>.verdict` | Transient per-panelist verdict files. Cleaned by skill after dispatch. |

## Directory layout

```
~/.claude/skills/validate-recommendation/
  SKILL.md                           # orchestrator (rewritten for N panelists)
  personas/
    da.md                            # Devil's Advocate persona
    pe.md                            # Principal Engineer persona
    qa.md                            # QA Engineer persona
  panel/
    __init__.py
    __main__.py                      # python -m panel ...
    cli.py                           # subcommand dispatch
    config.py                        # YAML loader + validation
    personas.py                      # per-role persona loader
    dispatch.py                      # NAT integration
    aggregate.py                     # N-panelist aggregation (rewritten)
    severity.py                      # pure decision tree
    state.py                         # state file + qhash
    decisions.py                     # JSONL telemetry
    verdict.py                       # verdict parser (carried)
    sanitize.py                      # markdown stripper (carried)
    trace.py                         # trace log (carried)
    tests/
      conftest.py                    # fixtures, mocked _invoke_nat
      test_*.py                      # one file per module
  README.md                          # user-facing docs

~/.claude/panel/                     # user state directory (mode 0700)
  config.yml                         # user-owned config (mode 0600)
  state-<qhash>.json                 # in-flight question state (mode 0600)
  decisions.jsonl                    # always-on telemetry (mode 0600)
  work/                              # transient per-panelist verdict files (mode 0700)

~/.claude/debug/panel-trace.log      # ops telemetry (carried, mode 0600)
~/.claude/hooks/
  validate-recommendation.sh         # PreToolUse hook (modified for cycle continuation)
  panel-record-userpick.sh           # PostToolUse hook (new)

Deleted in v3:
  dispatch-da.sh                     # superseded by panel/dispatch.py
  dispatch-da_test.sh                # superseded by tests/test_dispatch.py
  aggregate.sh                       # SKILL.md calls Python directly
  personas.md                        # split into per-role files
```

## Configuration

`~/.claude/panel/config.yml`:

```yaml
version: 1

panelists:
  - id: da-nemotron
    role: DA
    enabled: true                       # default ON
    backend: nat-nim
    model: nvidia/nemotron-3-super-v3
    max_tokens: 32768
    temperature: 0.3
    timeout_seconds: 60

  - id: pe
    role: PE
    enabled: false                      # opt-in: set true and PE joins the panel
    backend: claude-subagent
    subagent_type: principal-engineer

  - id: qa
    role: QA
    enabled: false                      # opt-in
    backend: claude-subagent
    subagent_type: qa-engineer

severity:
  hard_threshold: majority              # or supermajority (2/3 of N)
  rationale_gate:
    requires_principle_or_alternative: true
    principle_patterns:
      - '\b(YAGNI|atomicity|TDD|priority order|conventions?)\b'
      - '\bviolates? (the )?(principle|convention|rule)\b'
      - '\bbreaks?\b.*\b(rule|convention|invariant)\b'

failure_mode:
  on_panelist_error: auto               # strict | graceful | auto
                                        # auto: strict at N=3, graceful at N≥5

re_brainstorm:
  enabled: true
  max_cycles: 2

telemetry:
  jsonl: ~/.claude/panel/decisions.jsonl
  otel_endpoint: null                   # optional Phoenix/LangSmith endpoint
```

### Validation rules (`panel lint-config`)

- `panelists` length ≥ 1.
- Count of panelists with `enabled: true` must be odd. (Even N produces tie-prone votes; the odd-N invariant is required.)
- Each panelist `role` must have a corresponding `personas/<role>.md` file (case-insensitive match: role `DA` → `personas/da.md`).
- `backend` ∈ `{nat-nim, nat-anthropic, nat-openai, claude-subagent}`.
- For `nat-*` backends: `model` is required. Required env vars (warn if unset at lint time, error if unset at dispatch time): `nat-nim` → `$NVIDIA_API_KEY` or `$PANEL_DA_API_KEY`; `nat-anthropic` → `$ANTHROPIC_API_KEY`; `nat-openai` → `$OPENAI_API_KEY`.
- For `claude-subagent`: `subagent_type` is required and must match an available Claude Code subagent.
- `severity.hard_threshold` ∈ `{majority, supermajority}`.
- `failure_mode.on_panelist_error` ∈ `{strict, graceful, auto}`.
- `re_brainstorm.max_cycles` ∈ `[0, 5]`.

### Role catalog (v1 ships three)

Each role is one persona file under `personas/<role>.md`. New roles ship by dropping a new file.

| Role | Stance | Default backend |
|---|---|---|
| `DA` | Adversarial — finds the strongest counter-argument; cross-context bias resistance | `nat-nim` (Nemotron) |
| `PE` | Principles-grounded — reads `~/.claude/CLAUDE.md` and `~/.claude/rules/`; checks atomicity/YAGNI/priority order | `claude-subagent` (`principal-engineer`) |
| `QA` | Test quality and verifiability — is the recommendation testable, do failure modes surface | `claude-subagent` (`qa-engineer`) |

Future roles (extensible, no code change): `SEC` (security implications), `OPS` (oncall/runbook implications), `PERF` (performance implications), or any user-defined role.

### Persona file format

```markdown
---
role: DA
description: Adversarial reviewer — finds strongest counter-argument
intended_backends: [nat-nim, nat-openai]
---

# System prompt

You are a devil's-advocate reviewer. …

# One-shot example

Example input:
…

Example output:
VERDICT: HOLD
RATIONALE: …
ALTERNATIVE: n/a

# User prompt template

Question: <question text>
Options (verbatim labels and descriptions):
  <label 1> — <description 1>
  …
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <extracted reasoning or "(no reasoning supplied)">
```

The persona loader (`panel/personas.py`) slices on the three known `# Heading` lines and exposes them as a dataclass with `system_prompt`, `one_shot_example`, `user_prompt_template` fields.

## Dispatchers

### `panel/dispatch.py` (NAT integration)

Called by SKILL.md per `nat-*` panelist:

```bash
python3.12 -m panel dispatch \
    --panelist <id> \
    --config ~/.claude/panel/config.yml \
    --persona personas/<role>.md \
    --prompt-file <body> \
    --output ~/.claude/panel/work/<qhash>-<id>.verdict
```

**Contract:**

- Exit 0 on any path that wrote the verdict file (success or ERROR). Non-zero only on missing CLI args.
- Output file format: `VERDICT/RATIONALE/ALTERNATIVE` triplet (see Personas).
- Failures (network error, unparsable model output, NAT exception, OVERTURN+missing-alternative) become `VERDICT: ERROR` verdict files — never crash.
- File written with `umask 077`.

**Key implementation seam:**

```python
def _invoke_nat(panelist: Panelist, system: str, user: str) -> object:
    backend = panelist.backend
    if backend == "nat-nim":
        from nat.llm.nim_llm import NIMLLM   # actual import path verified during impl
        llm = NIMLLM(model=panelist.model, max_tokens=panelist.max_tokens,
                     temperature=panelist.temperature)
    elif backend == "nat-anthropic":
        from nat.llm.anthropic_llm import AnthropicLLM
        llm = AnthropicLLM(model=panelist.model, max_tokens=panelist.max_tokens,
                           temperature=panelist.temperature)
    elif backend == "nat-openai":
        from nat.llm.openai_llm import OpenAILLM
        llm = OpenAILLM(model=panelist.model, max_tokens=panelist.max_tokens,
                        temperature=panelist.temperature)
    else:
        raise ValueError(f"unsupported NAT backend: {backend}")
    return llm.invoke(messages=[
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ])
```

Tests mock at this single function. Real NAT module paths are verified at implementation time via `pkgutil.walk_packages` discovery — if NAT's layout differs, only this function's imports change. Tests do NOT mock `requests`/`httpx`/`nat.llm.*` directly — that couples too tightly to NAT's internals.

### `Agent` tool (claude-subagent dispatch)

No shell wrapper. SKILL.md, after parsing config, separates panelists by backend. For each `backend: claude-subagent` entry, the skill emits an `Agent` tool call inline with the Bash `panel dispatch` calls — all in one message for true parallelism.

The skill constructs the Agent prompt by concatenating the persona file's system prompt + one-shot example + the templated user prompt body. After the Agent call returns, the skill writes the response string verbatim to the verdict file path. (Subagent dispatch is "manifest, not call" — the skill knows what to invoke; the shell can't.)

### Parallel dispatch in one skill message

For a config with 1 DA via NAT-NIM and 2 subagents (PE + QA) enabled:

```
Message from SKILL.md contains 3 tool calls:
  Bash  python3.12 -m panel dispatch --panelist da-nemotron --output ~/.claude/panel/work/<qhash>-da-nemotron.verdict
  Agent subagent_type=principal-engineer prompt=<pe prompt>
  Agent subagent_type=qa-engineer prompt=<qa prompt>
```

All three execute concurrently. Skill waits for the message to return, writes the two Agent responses to verdict files, then calls `panel aggregate`.

## Aggregator and severity

### `panel aggregate` interface

```bash
python3.12 -m panel aggregate \
    --config ~/.claude/panel/config.yml \
    --verdicts ~/.claude/panel/work/<qhash>-*.verdict \
    --recommended-label "<verbatim label>" \
    --question-id <qhash> \
    --cycle 0
```

**Output:** JSON directive on stdout + one `decision` event appended to `decisions.jsonl`.

### Directive JSON shape

```json
{
  "verdict": "HARD-DISSENT",
  "summary": "Panel rejected retryablehttp. DA flagged limited retry-condition customization; QA flagged poor middleware-hook testability.",
  "rationale_gate_passed": true,
  "panelists": [
    {"id": "da-nemotron", "role": "DA", "verdict": "OVERTURN", "rationale": "...", "alternative": "go-resty/resty"},
    {"id": "pe",          "role": "PE", "verdict": "HOLD",     "rationale": "..."},
    {"id": "qa",          "role": "QA", "verdict": "OVERTURN", "rationale": "...", "alternative": "go-resty/resty"}
  ],
  "re_brainstorm": {
    "cycle": 0,
    "max_cycles": 2,
    "suggested_alternatives": ["go-resty/resty"],
    "feedback_for_claude": "DA: ... QA: ... Panel suggests go-resty/resty."
  },
  "escalate_to_user": false
}
```

- `re_brainstorm` is present only on HARD-DISSENT with `cycle < max_cycles`.
- `escalate_to_user` is present only on HARD-DISSENT (`true` at cycle cap, `false` otherwise).
- On SOFT-DISSENT, HOLD, and ERROR, neither `re_brainstorm` nor `escalate_to_user` is present.
- On ERROR, `panelists` records what was parsed; `summary` describes the failure.

### Severity decision tree (in `panel/severity.py`)

```python
def decide(config: Config, panelists: list[ParsedVerdict], cycle: int) -> Directive:
    panelists = [validate(p) for p in panelists]   # malformed → ERROR-status
    n_error = sum(1 for p in panelists if p.verdict == "ERROR")
    if n_error > 0:
        mode = resolve_failure_mode(config, len(panelists))   # auto: strict@N=3, graceful@N≥5
        if mode == "strict" or (len(panelists) - 2 * n_error) < 1:
            return error_directive("panelist errors exceed failure-mode tolerance")
        panelists = degrade_keeping_odd(panelists, n_error)

    overturn = [p for p in panelists if p.verdict == "OVERTURN"]
    N = len(panelists)
    threshold = ceil(N / 2) if config.severity.hard_threshold == "majority" else ceil(2 * N / 3)

    if len(overturn) == 0:
        return hold_directive(panelists)
    if len(overturn) < threshold:
        return soft_dissent_directive(overturn)

    gate_passed = any(
        names_principle(p.rationale, config.severity.rationale_gate.principle_patterns)
        or (p.alternative and p.alternative != "n/a")
        for p in overturn
    )
    if not gate_passed:
        return soft_dissent_directive(overturn, rationale_gate_passed=False)

    if cycle >= config.re_brainstorm.max_cycles:
        return hard_dissent_directive(overturn, escalate_to_user=True)
    return hard_dissent_directive(overturn, re_brainstorm_payload=build_payload(overturn))
```

`names_principle()` is a regex match against the configurable `principle_patterns` list. Test coverage required: matches `YAGNI`, `atomicity`, `TDD`, `priority order`, `violates the principle`; does NOT match `principle component`, `convention center` (false-positive guards).

**Edge case at N=1 (default config):** `threshold = ceil(1/2) = 1`. A single OVERTURN crosses majority. The rationale gate still applies — without a named principle or concrete alternative, it degrades to SOFT-DISSENT. This matches the v1 contract semantics.

### SKILL.md acting on the directive

| Directive verdict | Behavior under `CLAUDE_PANEL=on` (default) | Behavior under `CLAUDE_PANEL=advise` |
|---|---|---|
| `HOLD` | Auto-take recommended option. Print a one-paragraph note with abbreviated rationales. The original `AskUserQuestion` is never issued. | Re-ask augmented with positive `**Panel validated:**` note. Marker → `(Recommended; Panel-flagged)` for loop safety. |
| `SOFT-DISSENT` | Re-ask augmented with the panel summary. Marker → `(Recommended; Panel-flagged)`. | Same as `on`. |
| `HARD-DISSENT` (`re_brainstorm` present) | Update `state-<qhash>.json` (cycle += 1, append to `cycle_history`). Emit a markdown directive in skill's final output telling future-Claude to re-think with the panel's suggested alternatives. Do not call `AskUserQuestion`. | Same as `on`. |
| `HARD-DISSENT` (`escalate_to_user: true`) | Re-ask with marker `(Recommended; Panel-flagged-after-2-cycles)` and full cycle history appended to question text. User decides. | Same as `on`. |
| `ERROR` | Re-ask original unmodified. Marker swapped to `(Recommended; Panel-flagged)` for loop safety. Brief explanation to user. | Same as `on`. |
| Any verdict, `CLAUDE_PANEL=off` | Panel bypassed entirely. Original `AskUserQuestion` re-asked unmodified. (Hook itself is no-op when `CLAUDE_PANEL=off`.) | — |

## HARD-DISSENT re-brainstorm flow

The novel mechanic. Walked through cycle-by-cycle.

### Cycle 0 — first try

1. Claude emits `AskUserQuestion` (recommends option A).
2. Hook fires. Computes `qhash`. No state file exists. Writes `state-<qhash>.json` with `cycle: 0`. Exits 2.
3. SKILL.md reads state, dispatches panel in parallel, calls `panel aggregate --cycle 0`.
4. Aggregator returns HARD-DISSENT with `re_brainstorm` payload.
5. SKILL.md updates `state-<qhash>.json` (`cycle: 1`, appends cycle-0 result to `cycle_history`).
6. SKILL.md emits a markdown directive as its final output:

```markdown
## Panel HARD-DISSENT — cycle 1 of 2

**Rejected recommendation:** `retryablehttp (Recommended)`

**Panel feedback to incorporate:**
- DA-nemotron: retryablehttp's retry conditions aren't customizable per status code or header
- QA: resty's middleware hooks make retry behavior easier to assert in tests

**Panel suggests:** `go-resty/resty`

**Next step:** re-think the design with this feedback as new constraints. Re-emit `AskUserQuestion` with your reconsidered recommendation. The hook will re-evaluate.

If after re-thinking you still believe `retryablehttp` is correct, emit it again — but include in the question description an explicit response to the panel's concern (e.g., "we accept the customization limit because X"). The panel will weight that.

**This is cycle 1 of 2.** If panel HARD-DISSENTs again at cycle 2, the question will be surfaced to the user with full cycle history.
```

7. SKILL.md does NOT call `AskUserQuestion`. Claude reads the directive on its next turn and decides what to do.

### Cycle 1 — Claude re-emits with reconsidered recommendation

1. Claude re-thinks. Emits `AskUserQuestion` (recommends option B, or a re-framed question).
2. Hook computes `qhash`. State file exists with `cycle: 1`. Continuation — exit 2.
3. SKILL.md dispatches; `panel aggregate --cycle 1`.

Branching on cycle-1 result:

- **HARD again** → update state to `cycle: 2`, append cycle-1 to history, emit cycle-2 directive (`cycle 2 of 2 — last chance`).
- **HOLD** → act normally per `CLAUDE_PANEL` mode. State marked resolved; cleaned up.
- **SOFT** → re-ask with panel note. State resolved.
- **ERROR** → re-ask original unmodified. State resolved.

### Cycle 2 — final, escalates if still HARD

1. Claude re-emits again. Hook finds state at `cycle: 2`. Exit 2.
2. Aggregator at `cycle >= max_cycles`: if result is HARD-DISSENT, sets `escalate_to_user: true`.
3. SKILL.md acts:
   - **HARD with `escalate_to_user: true`** → re-ask with marker `(Recommended; Panel-flagged-after-2-cycles)` and full cycle history appended. User decides.
   - **HOLD / SOFT / ERROR** → standard handling. State resolved.
4. JSONL captures the eventual `user_pick` regardless of branch.

### qhash algorithm (canonical)

The hash is computed identically by the PreToolUse hook, the PostToolUse hook, the skill, and the aggregator. Spec contract:

```python
def question_hash(question_text: str, options: list[Option]) -> str:
    normalized = "\n".join(sorted(
        strip_recommended_marker(opt.label).strip()
        for opt in options
    ))
    payload = f"{question_text.strip()}\n---\n{normalized}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]

def strip_recommended_marker(label: str) -> str:
    return re.sub(r"\s*\(Recommended[^)]*\)\s*$", "", label)
```

**Consequences:**
- Same question_text + same options + Claude swapping which option is `(Recommended)` ⇒ same hash. Treated as a continuation.
- Different question_text OR different option set ⇒ different hash. Fresh decision, fresh cycle counter.

### Hook re-entry decision

```
on AskUserQuestion PreToolUse:
    qhash = question_hash(question_text, options)
    state_file = ~/.claude/panel/state-<qhash>.json
    if not exists(state_file):
        write fresh state (cycle=0); exit 2
    state = read(state_file)
    if state.cycle == 0:                  # stale from a crashed skill run
        remove(state_file); exit 0        # bypass (current v1 re-entry guard)
    elif state.cycle <= state.max_cycles:
        exit 2                            # → skill runs cycle `state.cycle`
    else:                                 # orphan: cycle exceeded but state not cleaned
        remove(state_file); exit 0
```

The cycle counter is incremented by the **skill** after a HARD-DISSENT dispatch (not by the hook), so `state.cycle` always names the cycle *about to run*.

### State file schema

`~/.claude/panel/state-<qhash>.json`:

```json
{
  "qhash": "7e4a3f1b2c5d6e8f",
  "session_id": "abc123",
  "question_text": "Which HTTP client...",
  "normalized_options": ["go-resty/resty", "net/http + custom loop", "retryablehttp"],
  "created_at": "2026-05-15T08:30:00Z",
  "updated_at": "2026-05-15T08:31:22Z",
  "cycle": 1,
  "max_cycles": 2,
  "cycle_history": [
    {
      "cycle": 0,
      "recommended_label": "retryablehttp",
      "verdict": "HARD-DISSENT",
      "panelist_summary": ["da-nemotron:OVERTURN(go-resty/resty)", "pe:HOLD", "qa:OVERTURN(go-resty/resty)"],
      "feedback": "..."
    }
  ]
}
```

Mode `0600`. Cleaned by `panel gc` (default: state files older than 1h get removed; resolved state files removed immediately on the resolving turn).

## Telemetry

Append-only event log at `~/.claude/panel/decisions.jsonl`. Three event types, joined on `question_id`:

```jsonl
{"event":"decision","v":1,"ts":"2026-05-15T08:30:00Z","question_id":"7e4a3f1b2c5d6e8f","cycle":0,"session_id":"abc123","question_text":"…","options":[…],"recommended_label":"retryablehttp (Recommended)","panelists":[{"id":"da-nemotron","role":"DA","backend":"nat-nim","model":"nvidia/nemotron-3-super-v3","verdict":"OVERTURN","rationale":"…","alternative":"go-resty/resty","latency_ms":4123,"tokens_in":184,"tokens_out":287}],"aggregate":{"verdict":"HARD-DISSENT","rationale_gate_passed":true,"summary":"…"}}
{"event":"user_pick","v":1,"ts":"2026-05-15T08:35:00Z","question_id":"7e4a3f1b2c5d6e8f","pick":"go-resty/resty"}
{"event":"label","v":1,"ts":"2026-05-15T09:00:00Z","question_id":"7e4a3f1b2c5d6e8f","label":"right","note":"resty's retry-condition flexibility paid off"}
```

### Event-shape rationale

- Append-only is safe under concurrent panel runs from multiple sessions.
- `user_pick` and `label` arrive at different times than `decision` — separate events avoid mutating existing rows.
- Join on `question_id` to reconstruct a question's full timeline. In-memory dict for ~10k entries is trivial (years of usage at ~50 decisions/day).

### `user_pick` capture

PostToolUse hook `~/.claude/hooks/panel-record-userpick.sh`:

1. Reads `tool_result` from stdin (Claude Code's PostToolUse hook spec).
2. For each (question, answer) pair, computes `question_id` via the canonical `question_hash`.
3. Calls `python -m panel record-userpick --question-id <qid> --pick <answer>`.
4. `panel record-userpick` appends a `user_pick` event row if `question_id` matches an existing `decision` row (cheap skip otherwise — most `AskUserQuestion` calls aren't panel-evaluated).

**Dependency note:** harness support for PostToolUse on `AskUserQuestion` is unverified. Fallback: SKILL.md observes the answer in the next turn it sees and calls `panel record-userpick` itself. Validate hook support during Phase 6.

### Optional NAT OTel emit

When `telemetry.otel_endpoint` is set in config, `panel/decisions.py` emits the `decision` event to that endpoint (Phoenix, LangSmith, or any OTel-compatible collector) in addition to JSONL. JSONL is canonical; OTel is a convenience for users who want hosted dashboards. Never replaces JSONL.

## `panel` CLI

| Subcommand | Purpose |
|---|---|
| `panel aggregate …` | Internal — called by SKILL.md per dispatch |
| `panel dispatch --panelist <id> --persona <file> --prompt-file <file> --output <file>` | Internal — called by SKILL.md per `nat-*` panelist |
| `panel record-userpick --question-id <qid> --pick <label>` | Internal — called by PostToolUse hook |
| `panel ls [--status unlabeled\|labeled] [--label …] [--since <date>] [--cycle <n>]` | List decisions matching filters |
| `panel show <question_id>` | Show full event timeline for one question |
| `panel label [--since <date>] [--status unlabeled]` | Interactive batch labeling |
| `panel stats [--since <date>]` | Bucket counts, false-positive rate, per-panelist OVERTURN rate, latency p50/p95 |
| `panel replay <question_id> [--with-personas-dir <path>]` | Re-dispatch same prompts; diff verdicts |
| `panel lint-config [--config <path>]` | Validate config (odd-enabled-N, personas exist, backend whitelist, env vars) |
| `panel gc [--older-than 1h]` | Clean up stale `state-<qhash>.json` files |
| `panel tune --candidate-personas-dir <path>` | (deferred to v1.x) Score candidates against labeled corpus |

### `panel label` interactive UX

Single-question-per-screen, single-keystroke labels:

```
[12/47 unlabeled]  question: "Which HTTP client should I use for a Go service that needs retries?"
   Panel: HARD-DISSENT (escalated after 2 cycles)
   Recommended (final): retryablehttp  →  User picked: go-resty/resty
   Panelists (cycle 0): DA=OVERTURN(go-resty/resty), PE=HOLD, QA=OVERTURN(go-resty/resty)
   Panelists (cycle 1): DA=HOLD, PE=HOLD, QA=OVERTURN(go-resty/resty)
   Panelists (cycle 2): DA=OVERTURN(net/http+custom), PE=HOLD, QA=OVERTURN(go-resty/resty)

Panel call: [r]ight  [w]rong  [m]ixed  [u]nsure  [s]kip  [q]uit  >
```

## Testing strategy

| Layer | Tool | Coverage |
|---|---|---|
| Unit | pytest | One test file per module. NAT mocked at `_invoke_nat` seam. Property tests (hypothesis) on vote-tallying and qhash determinism. |
| Hook | bash + fixtures | Stale state (`cycle=0`) → bypass. `cycle=1` state → exit 2. Cycle cap exceeded → bypass. New qhash → fresh run. Even-enabled-N config → rejected at `panel lint-config`. PostToolUse on `AskUserQuestion` calls `record-userpick` with the right qhash. |
| Integration | pytest | End-to-end via fixture-mocked panelists: HOLD / SOFT / HARD / ERROR / cycle cap escalation. Verifies directive JSON shape and JSONL records. |
| Mutation | `mutmut` | `severity.py` and `aggregate.py` must fail when thresholds, vote counts, gate booleans, cycle-cap comparisons mutated. Catches theater tests (per constitution: "every test must fail when implementation is deleted"). |
| Live | Manual runbook | `panel/testing/e2e.md` checklist. Real Nemotron, default config, opt-in config. |

**Mock discipline.** Per `rules/learned-anti-patterns.md`: mock at most one layer deep. NAT's response object is mocked via `_invoke_nat`; everything below (real NAT, real HTTP, real models) is integration territory. We do NOT mock `requests`/`httpx`/`nat.llm.*` in unit tests — those mocks couple too tightly to NAT's implementation and break on every NAT version bump.

## Error handling matrix

| Failure | Behavior |
|---|---|
| Panelist HTTP timeout / non-2xx / malformed | `panel dispatch` writes ERROR verdict. `failure_mode` applied at aggregate: `strict` at N=3 → directive ERROR; `graceful` at N≥5 → drop one more to stay odd. |
| Panelist returns `OVERTURN` + `ALTERNATIVE: n/a` | Aggregator rejects as ERROR (Phase 1 bug #3 fix preserved). |
| Subagent `Agent` call errors / returns non-format prose | SKILL.md writes Agent response to verdict file regardless; aggregator sees no `VERDICT:` line → ERROR for that panelist. |
| `panel aggregate` crashes (non-zero exit) | SKILL.md catches stderr, falls back to re-ask original (marker swapped to prevent loop). Hook re-entry guard ensures one bypass at most. |
| `config.yml` missing or invalid | `panel lint-config` runs at skill startup; on failure print user-visible "panel disabled: <reason>" and re-ask original. |
| Persona file missing | Same as config missing. |
| Cycle cap reached, still HARD-DISSENT | `escalate_to_user: true` in directive. SKILL.md re-asks with `(Recommended; Panel-flagged-after-2-cycles)` and full cycle history. |
| Two sessions, same qhash, concurrent panel | Second session reads existing state. Under 1h → uses existing cycle counter (shared decision is acceptable). Over 1h → `panel gc` cleans first. |
| `decisions.jsonl` append fails | Best-effort: log `panel-jsonl-write-failed` to stderr; do not block panel decision. |
| PostToolUse on `AskUserQuestion` unsupported by harness | SKILL.md captures answer in observed next turn and calls `panel record-userpick` itself. Documented in SKILL.md fallback section. |
| Claude ignores HARD-DISSENT re-brainstorm directive | State ages out after 1h via `panel gc`. No infinite memory growth. |
| qhash collision | sha256-16hex = 2^64 entropy. Practically impossible at one-user scale. Documented as not-handled. |
| `~/.claude/panel/` unwritable | Pre-flight canary write in skill startup. On failure: "panel disabled: `~/.claude/panel/` unwritable" + re-ask original. |

## Security posture

- **API keys**: env-var only (`PANEL_DA_API_KEY` / `NVIDIA_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`). Never on argv, never written to disk, never logged. NAT's SDK reads env vars natively. `panel/dispatch.py` never echoes them.
- **`~/.claude/panel/`**: directory mode `0700`. `state-<qhash>.json` and `decisions.jsonl` mode `0600`. `work/` subdirectory inherits `0700`. Contains user question text + recommendations + picks — sensitive at a personal-tooling level.
- **Persona files**: world-readable (no secrets; they are prompts).
- **Subagent calls**: same trust boundary as `Agent` tool today. Persona file content is the entire prompt — reviewed before adding new roles. No third-party persona files loaded from outside the skill repo.
- **Aggregator sanitization**: `sanitize.py` strips markdown links, images, backticks from panelist rationales before embedding in user-facing `summary`. Defense in depth — format compliance is the first guard; sanitization is the second.
- **`$TMPDIR` avoidance for persistent state**: state and telemetry live under `~/.claude/panel/`, not `$TMPDIR`. Survives sandbox restrictions.
- **NAT supply chain**: pinned `nvidia-nat>=1.6,<2.0` from public PyPI. Apache-2.0. Installed via `pipx` (isolated venv); no impact on system Python.

## Migration plan

Phase 1 and Phase 2 already shipped under v2.0; they remain valid foundations. v3 collapses v2.0 Phases 3-6 into the layout below.

| Phase | Goal | Status | Approx |
|---|---|---|---|
| 1 — Foundation bug fixes | `dispatch-da.sh` system prompt + max_tokens=32768 + OVERTURN-alt rejection | ✓ shipped (uncommitted in `~/.claude/skills/validate-recommendation/`) | done |
| 2 — Python aggregator port | `panel/{verdict,sanitize,trace,cli,aggregate}.py` + 21 tests; `aggregate.sh` is a shim | ✓ shipped (uncommitted) | done |
| 3a — Config + personas split | `panel/config.py` (YAML loader, odd-enabled-N), `panel/personas.py` (per-role files), `personas/{da,pe,qa}.md`, `panel lint-config` subcommand. `personas.md` not yet deleted. | pending | 1-2 days |
| 3b — NAT dispatch | `panel/dispatch.py`, `panel dispatch` subcommand. `nvidia-nat[langchain]` installed via pipx. NAT module-path discovery before implementation. | pending | 1-2 days |
| 3c — N-panelist aggregator + severity | `panel/aggregate.py` rewritten as `aggregate_n()`. `panel/severity.py` extracted. Directive becomes JSON. SKILL.md parses JSON. Delete `dispatch-da.sh`, `dispatch-da_test.sh`, `aggregate.sh`, `personas.md`. | pending | 2 days |
| 5 — Re-brainstorm cycles | `panel/state.py` (qhash, state file r/w, cleanup). Hook updated for cycle continuation. SKILL.md emits markdown re-brainstorm directive. Cycle cap enforced. | pending | 2 days |
| 6 — Telemetry + labeling CLI | `panel/decisions.py` (JSONL append-only). PostToolUse hook for `user_pick`. `panel ls/show/stats/label/replay/gc` subcommands. Optional NAT OTel emit. | pending | 2 days |
| 7 — `panel tune` | Score candidate personas against labeled corpus. | deferred (v1.x) | — |

Phase 4 from v2.0 (separate "severity tiers") is rolled into 3c — severity logic is inseparable from the rewritten aggregator. v2.0's Phases 5 and 6 carry forward in number for continuity.

Total remaining v1 work: ~8-10 days.

## Open questions

- **`nat-anthropic` for PE/QA quality vs `claude-subagent`**: defer until usage data. Default ships PE/QA backend as `claude-subagent` (free, principal-engineer subagent identity). User can switch via `backend: nat-anthropic` when paid uniformity is preferred.
- **NAT module paths** (e.g., `nat.llm.nim_llm.NIMLLM`): verify in Phase 3b Task 1 via `pkgutil.walk_packages` discovery. Tests mock at `_invoke_nat` so import-path correctness is verified only at live-run time.
- **NAT workflow YAML mode** (`nat run --config_file workflow.yml`): not used; we import NAT as a library in-process. Add a `panel-workflow.yml` later if the panel needs external invocation (e.g., from a non-Claude context).
- **PostToolUse on `AskUserQuestion`**: harness support unverified. Phase 6 verifies; fallback in SKILL.md captures answer from observed next turn.
- **Per-role vote weighting** (e.g., PE OVERTURN weights more on principle questions): equal weights for v1. Revisit after `panel stats` surfaces per-role false-positive rates.
- **Cross-session decision dedup**: each session re-runs the panel. A qhash-keyed cache could short-circuit. Out of scope for v1.
- **Cost budget enforcement**: no $/decision cap in v1. Future `panel stats` could surface cumulative spend; future config could enforce a daily budget.
- **Local-model DA via Ollama**: future `nat-ollama` backend if NAT supports it natively, or a custom `dispatch.py` branch otherwise.
- **Persona-tuning automation**: v1.x ships manual scoring. v2.x could auto-promote winning personas with operator approval.
- **Tool-equipped NAT panelists (v3.1 extension)**: v3 uses NAT as an LLM-only client, which leaves a capability gap — `claude-subagent` panelists (PE/QA) have Read/Grep/Bash; `nat-*` panelists (default DA) are text-only and can hallucinate alternatives that don't exist (the `rules/learned-anti-patterns.md` "verify external references" entry). NAT's `ReActAgent`/`ToolCallingAgent` primitives would let DA run a tool loop (web_search → http_head → pypi_lookup → final verdict) before issuing OVERTURN. Proposed shape when added: per-panelist `tools: [...]` field with an allowlisted set (`web_search`, `http_head`, `pypi_lookup`, `oci_manifest_check`); empty default preserves v3 behavior; non-empty switches `_invoke_nat` from `llm.invoke()` to `agent.run()`. Trade-offs: 2-5× cost/latency per panelist, weaker `panel replay` determinism (tool state changes), expanded security surface (allowlist enforced, no Bash). Defer until `panel stats` shows DA's hallucinated-alternative rate justifies the complexity; adding it later re-opens locked decision #9 ("no NAT Agent primitives") and adds a `panel/tools.py` module.

## Relation to v2.0 and v2.1

| v2.0/v2.1 piece | v3 disposition |
|---|---|
| `HOLD/SOFT-DISSENT/HARD-DISSENT/ERROR` contract | Preserved. |
| Severity decision tree (vote + rationale gate) | Preserved. Extracted from `aggregate.py` into `severity.py` for testability. |
| Configurable N panelists, odd-N invariant | Preserved. Invariant applies to *enabled* count (not total). |
| Default N=1 (DA only) | Preserved from v2.1. (v2.0 had N=3 default; v2.1 amended to opt-in.) |
| Bounded auto re-brainstorm (2 cycles) | Preserved. |
| Telemetry JSONL canonical + optional OTel | Preserved from v2.1. |
| `~/.claude/panel/config.yml` (YAML) | Preserved from v2.1. |
| Backend abstraction: `nat-nim`/`nat-anthropic`/`nat-openai`/`claude-subagent` | Preserved from v2.1. |
| `max_tokens=32768` default | Preserved from v2.1. |
| `dispatch-http.sh` (v2.0 plan) / `panel/dispatch.py` (v2.1 amendment) | v3 ships `panel/dispatch.py` (no shell dispatcher). |
| `aggregate.sh` shim (Phase 2 era) | v3 deletes the shim; SKILL.md calls `python3.12 -m panel aggregate` directly. |
| Phase 4 (separate severity-tiers phase) | Rolled into Phase 3c. |
| State files in `$TMPDIR/claude-panel-<session>.json` | Relocated to `~/.claude/panel/state-<qhash>.json` (cycle tracking + sandbox durability). |
| Phase 1+2 implementation (uncommitted in `~/.claude/`) | Verdict/sanitize/trace/cli kept; aggregate rewritten under N-panelist contract. Commit posture decided as part of Phase 3a execution. |
