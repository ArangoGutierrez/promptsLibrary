# validate-recommendation v2 — Redesign

**Date:** 2026-05-14
**Status:** Approved
**Supersedes:** `2026-05-10-recommendation-validator-design.md` (v1; landed as commit 4ad0f39)

## Why a redesign

The v1 panel shipped two-backend (1 DA + 1 PE) with a binary HOLD/DISSENT contract. End-to-end verification on 2026-05-14 surfaced three blocking bugs and a structural limit:

1. `dispatch-da.sh` does not embed the DA system prompt — payload contains only a `role: "user"` message, so Nemotron returns prose without the strict `VERDICT:` format and `aggregate.sh` emits ERROR.
2. `max_tokens: 1024` truncates reasoning-model output mid-RATIONALE.
3. The aggregator accepts `OVERTURN + ALTERNATIVE: n/a` as a valid dissent (contradicts the personas spec).
4. Single-DA composition means single-model blind-spot risk; binary contract means every dissent surfaces to the user at the same urgency level regardless of how strong the rationale is.

The v1 spec correctly identified the problem class but under-specified the dispatcher contract (the "system prompt embedded by dispatch-da.sh" bullet didn't match the script's behavior). The v2 redesign fixes the bugs and makes the panel a load-bearing system: configurable composition, severity-tiered friction, telemetry, persona tuning.

This is intended to be a moat — the thing that makes recommending Claude faster and better than recommending Claude alone, by catching bad recommendations before the user has to.

## Locked design decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Panel-to-user contract | `HOLD` / `SOFT-DISSENT` / `HARD-DISSENT` / `ERROR` (severity-tiered friction) |
| 2 | Severity source | Vote count + rationale-strength gate |
| 3 | Panel composition | Configurable N panelists with heterogeneous roles (`DA` / `PE` / `QA` / extensible), each backed by external LLM or Claude subagent |
| 4 | Panel size invariant | **N must always be odd** (default N=3; config validation rejects even N) |
| 5 | HARD-DISSENT UX | Bounded auto re-brainstorm (N=2 cycles, visible note, escalate to user on cap) |
| 6 | Telemetry | Always-on JSONL (`~/.claude/panel/decisions.jsonl`) + batch `panel-review` labeling CLI |
| 7 | Implementation language | Shell for I/O wrappers (HTTP, file emit); Python (stdlib-only for v1) for aggregator, CLI, telemetry, tuning |

## System overview

```
┌──────────────────┐
│ AskUserQuestion  │  Claude emits with a (Recommended) option
└─────────┬────────┘
          ▼
┌──────────────────────────────────────────────┐
│ Hook: validate-recommendation.sh (PreToolUse)│
│ — detects marker, writes state file, exit 2  │
└─────────┬────────────────────────────────────┘
          ▼
┌──────────────────────────────────────────────┐
│ SKILL.md orchestrator                        │
│ 1. Read state + panel-config.json            │
│ 2. Build per-panelist prompts                │
│ 3. Dispatch ALL panelists in parallel        │
│ 4. Call `panel aggregate` → directive        │
│ 5. Act on directive (HOLD/SOFT/HARD/ERROR)   │
└─────────┬────────────────────────────────────┘
          ▼     (parallel fanout, N panelists)
   ┌──────┴──────┬─────────────┬──────────────┐
   ▼             ▼             ▼              ▼
┌──────┐    ┌──────┐    ┌──────────┐    ┌──────────┐
│ DA-1 │    │ DA-2 │    │ PE       │    │ QA       │
│ ext  │    │ ext  │    │ subagent │    │ subagent │
│ HTTP │    │ HTTP │    │ Agent()  │    │ Agent()  │
└──┬───┘    └──┬───┘    └────┬─────┘    └────┬─────┘
   └───────────┴──────┬──────┴───────────────┘
                      ▼
            ┌─────────────────────────────┐
            │ panel aggregate (Python)    │
            │ - severity decision tree    │
            │ - append decisions.jsonl    │
            └──────────┬──────────────────┘
                       ▼
            ┌─────────────────────────────┐
            │ Directive JSON to SKILL.md  │
            └─────────────────────────────┘
```

### Component responsibilities

| Component | Role |
|---|---|
| Hook `~/.claude/hooks/validate-recommendation.sh` | Detect `(Recommended)` marker, write state file, block tool call, instruct skill invocation. Cycle-aware re-entry logic (new in v2). |
| Hook `~/.claude/hooks/panel-record-userpick.sh` | (New in v2.) PostToolUse on `AskUserQuestion`. Capture user's answer, append `user_pick` event to JSONL. |
| `SKILL.md` | Orchestrator. Reads config, dispatches N panelists in parallel, calls aggregator, acts on directive. Only Claude-aware logic lives here. |
| Shell dispatchers (`dispatchers/`) | One script per backend kind: `dispatch-http.sh` (chat-completion endpoint), future `dispatch-ollama.sh`. Each writes one verdict file. |
| `Agent` tool | Used directly by the skill for subagent-backed panelists (PE, QA). Not wrapped by a shell script — shell can't invoke Claude tools. |
| `panel` Python package | `aggregate`, `record-userpick`, `ls`, `show`, `label`, `stats`, `replay`, `lint-config`, `gc`, `tune` (v1.x). |
| Personas (`personas/`) | One Markdown file per role with front-matter + system prompt + one-shot example. |
| Config (`~/.claude/panel/config.json`) | Panel composition, severity thresholds, failure mode, telemetry settings. |
| State files (`~/.claude/panel/state-<qhash>.json`) | Per-question cycle tracking. Survives hook re-entries. Cleaned by `panel gc`. |
| Decisions log (`~/.claude/panel/decisions.jsonl`) | Append-only event log: `decision` / `user_pick` / `label` events. |

## Configuration

`~/.claude/panel/config.json`:

```json
{
  "version": "1",
  "panelists": [
    {
      "id": "da-nemotron",
      "role": "DA",
      "backend": "http",
      "endpoint_env": "CLAUDE_PANEL_DA_ENDPOINT",
      "api_key_env": "PANEL_DA_API_KEY",
      "model_env": "CLAUDE_PANEL_DA_MODEL",
      "max_tokens": 4096,
      "temperature": 0.3,
      "timeout_seconds": 60
    },
    { "id": "pe", "role": "PE", "backend": "subagent", "subagent_type": "principal-engineer" },
    { "id": "qa", "role": "QA", "backend": "subagent", "subagent_type": "qa-engineer" }
  ],
  "severity": {
    "hard_threshold": "majority",
    "rationale_gate": {
      "requires_principle_or_alternative": true,
      "principle_patterns": [
        "\\b(YAGNI|atomicity|TDD|priority order|conventions?)\\b",
        "\\bviolates? (the )?(principle|convention|rule)\\b",
        "\\bbreaks?\\b.*\\b(rule|convention|invariant)\\b"
      ]
    }
  },
  "failure_mode": { "on_panelist_error": "auto" },
  "re_brainstorm": { "enabled": true, "max_cycles": 2 },
  "telemetry": { "enabled": true, "decisions_jsonl": "~/.claude/panel/decisions.jsonl" }
}
```

### Validation rules (`panel lint-config`)

- `panelists` length must be odd and ≥ 1 (rejects even N — the odd-N invariant).
- Every `role` value must have a corresponding `personas/<role>.md` file.
- Every `endpoint_env` / `api_key_env` / `model_env` referenced must resolve to a non-empty value (warn if any are missing at lint time).
- Every `subagent_type` must be one of the user's available subagent types (`principal-engineer`, `qa-engineer`, …).
- `severity.hard_threshold` ∈ `{majority, supermajority}`.
- `failure_mode.on_panelist_error` ∈ `{strict, graceful, auto}` (where `auto` resolves to `strict` at N=3 and `graceful` at N≥5).
- `re_brainstorm.max_cycles` ∈ `[0, 5]`.

### Role catalog (v1)

Each role = one persona file under `~/.claude/skills/validate-recommendation/personas/<role>.md`. New roles ship by dropping a new file — no code change.

| Role | Stance | Default backend |
|---|---|---|
| `DA` | Adversarial — finds the strongest counter-argument; cross-context bias resistance | External HTTP (Nemotron) |
| `PE` | Principles-grounded — reads `~/.claude/CLAUDE.md` and `~/.claude/rules/`; checks atomicity / YAGNI / priority order | Claude subagent (`principal-engineer`) |
| `QA` | Test quality and verifiability — is the recommendation testable, would tests actually fail when broken, are failure modes observable | Claude subagent (`qa-engineer`) |

Future roles (extensible, no code change): `SEC` (security implications), `OPS` (oncall/runbook implications), `PERF` (performance implications), or any user-defined role.

### Persona file format

```markdown
---
role: DA
description: Adversarial reviewer — finds strongest counter-argument
intended_backends: [http]
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

The skill reads the file, slices on `# System prompt` / `# One-shot example` / `# User prompt template` headings, and constructs the final prompt accordingly.

## Dispatcher contracts

**Shared output contract — every dispatcher writes a verdict file:**

```
VERDICT: <HOLD|OVERTURN>
RATIONALE: <one paragraph>
ALTERNATIVE: <verbatim option label, or n/a>
```

- Exit code: 0 on any path that wrote the file (success or ERROR-verdict). Non-zero only on missing CLI args.
- Failure writes a `VERDICT: ERROR` verdict, never throws.
- File written to `${TMPDIR}/panelist-<id>-<qhash>.verdict` with `umask 077`.

### `dispatchers/dispatch-http.sh`

Replaces v1's `dispatch-da.sh`. Generalized to take a panelist config (read from a JSON file argument) rather than hardcoded env vars.

```bash
dispatch-http.sh \
    --panelist-config <path-to-single-panelist-json> \
    --persona-file <path-to-personas/<role>.md> \
    --user-prompt-file <path-to-templated-body.txt> \
    --output <verdict-file>
```

Key behaviors (v2 changes vs. v1):

1. **Builds payload with separate `system` and `user` messages.** The persona file's `# System prompt` and `# One-shot example` sections combine into the system message. The templated body becomes the user message. Fixes v1 bug #1.

2. **`max_tokens` from config**, default 4096. Fixes v1 bug #2.

3. **Rejects `OVERTURN + ALTERNATIVE empty or "n/a"`** — writes ERROR verdict file with reason `"OVERTURN missing concrete alternative"`. Fixes v1 bug #3.

4. **Authorization via temp-file `@<file>` syntax** (preserved from v1 — never embed key in argv).

5. **Endpoint must be `https://` or `http://localhost*`** (preserved from v1; catches typos).

6. **JSON validation of response.** Empty `content` with non-empty `reasoning_content` ⇒ ERROR with reason `"content empty (model hit token cap during reasoning)"`. We do *not* fall back to `reasoning_content` — the format contract is on `content`.

### `Agent` tool for subagent panelists

No shell wrapper. The skill, after parsing config, separates panelists by backend. For each `backend: "subagent"` entry, the skill emits an `Agent` tool call inline with the HTTP dispatch calls — all in one message for true parallelism.

The skill constructs the Agent prompt by concatenating the persona file's system prompt + one-shot example + templated body. After Agent returns, the skill writes the response string to the verdict file path. (Subagent-backed dispatch is "manifest, not call" — the skill knows what to call, not the shell.)

### Parallel dispatch in one skill message

For default 3-panelist config:

```
Message contains 3 tool calls:
  Bash dispatch-http.sh --panelist-config <da-nemotron.json> ...
  Agent subagent_type=principal-engineer prompt=<pe prompt>
  Agent subagent_type=qa-engineer prompt=<qa prompt>
```

All three execute concurrently. Skill waits for the message to return, writes subagent responses to verdict files, then calls `panel aggregate`.

## `panel aggregate` interface and severity logic

```
python -m panel aggregate \
    --config ~/.claude/panel/config.json \
    --verdicts ${TMPDIR}/panelist-*.verdict \
    --recommended-label "retryablehttp (Recommended)" \
    --question-id <sha256-16hex of question_text + sorted options> \
    --cycle 0
```

**Output:** JSON directive on stdout + one `event:"decision"` row appended to `decisions.jsonl`.

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
    "feedback_for_claude": "DA: retryablehttp's retry conditions aren't customizable per status code or header. QA: resty's middleware hooks make retry behavior easier to assert in tests. Panel suggests go-resty/resty."
  }
}
```

### Severity decision tree

```python
def decide(config, panelists, cycle):
    # 1. Validate. Malformed verdicts (OVERTURN with empty/n/a ALTERNATIVE,
    #    missing RATIONALE, unknown VERDICT value) become ERROR.
    panelists = [validate(p) for p in panelists]

    # 2. Failure-mode application (preserves odd N invariant).
    n_error = sum(1 for p in panelists if p.verdict == "ERROR")
    if n_error > 0:
        mode = resolve_failure_mode(config, len(panelists))  # auto → strict at N=3, graceful at N≥5
        if mode == "strict" or (len(panelists) - 2 * n_error) < 1:
            return {"verdict": "ERROR", "reason": "panelist errors exceed failure-mode tolerance"}
        panelists = degrade_keeping_odd(panelists, n_error)  # drop one more to stay odd

    # 3. Vote.
    overturn = [p for p in panelists if p.verdict == "OVERTURN"]
    N = len(panelists)
    threshold = ceil(N / 2) if config.severity.hard_threshold == "majority" else ceil(2 * N / 3)

    if len(overturn) == 0:
        return {"verdict": "HOLD", "summary": short_rationale(panelists)}
    if len(overturn) < threshold:
        return {"verdict": "SOFT-DISSENT", "summary": dissent_summary(overturn)}

    # 4. Rationale gate (only at majority OVERTURN).
    if config.severity.rationale_gate.requires_principle_or_alternative:
        gate_passed = any(
            names_principle(p.rationale, config.severity.rationale_gate.principle_patterns)
            or (p.alternative and p.alternative != "n/a")
            for p in overturn
        )
        if not gate_passed:
            return {"verdict": "SOFT-DISSENT", "rationale_gate_passed": False, "summary": "..."}

    # 5. HARD-DISSENT — emit re-brainstorm payload unless cap reached.
    if cycle >= config.re_brainstorm.max_cycles:
        return {"verdict": "HARD-DISSENT", "escalate_to_user": True, "summary": "...", "cycle_history": [...]}
    return {"verdict": "HARD-DISSENT", "re_brainstorm": build_rebrainstorm_payload(overturn), "summary": "..."}
```

`names_principle()` is a simple regex match against the configurable `principle_patterns` list. Tests must cover: matches `YAGNI`, `atomicity`, `TDD`, `priority order`, `violates the principle`, etc.; does NOT match `principle component`, `convention center` (false-positive guards).

## HARD-DISSENT re-brainstorm flow

The novel mechanic. Walked through cycle-by-cycle:

### Cycle 0 (the first try)

1. Claude emits `AskUserQuestion` (recommends option A).
2. Hook fires. Computes `qhash = sha256(question_text + sorted_option_labels)[:16]`. No state file exists for `qhash`. Hook writes `state-<qhash>.json` with `cycle: 0, cycle_history: []`. Exits 2 with skill-invoke message.
3. Skill reads state, dispatches panel in parallel, calls `panel aggregate --cycle 0`.
4. Aggregator returns HARD-DISSENT with `re_brainstorm` payload.
5. Skill **updates `state-<qhash>.json`**: `cycle: 1`, appends cycle-0 panel result to `cycle_history`.
6. Skill **emits a markdown directive as its final output** (this becomes Claude's next-turn context):

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

7. Skill does NOT call `AskUserQuestion`. Claude reads the directive and decides what to do.

### Cycle 1 (Claude re-emits with reconsidered recommendation)

1. Claude re-thinks. Emits `AskUserQuestion` (recommends option B, or a re-framed question).
2. Hook fires. Computes `qhash`. If `qhash` matches the existing state file with `state.cycle > 0`, this is a continuation — hook lets the skill run (does NOT bypass).
3. Skill reads state, calls `panel aggregate --cycle 1` (cycle number sourced from state file).
4. Aggregator returns HOLD / SOFT / HARD / ERROR for this cycle.

Branching on the cycle-1 result:

- **HARD again** → skill updates state to `cycle: 2`, appends cycle-1 result to history, emits a new directive marked `(cycle 2 of 2 — last chance)`.
- **HOLD** → skill acts normally per `CLAUDE_PANEL` mode (recommendation eventually won panel approval). State marked resolved; `panel gc` cleans it.
- **SOFT** → skill surfaces to user with panel note. State marked resolved.
- **ERROR** → re-ask original unmodified. State marked resolved.

### Cycle 2 (final attempt; escalates only if still HARD)

1. Claude re-emits again. Hook computes `qhash`, finds state with `cycle: 2`, lets skill run.
2. Skill calls `panel aggregate --cycle 2`. Aggregator detects `cycle >= max_cycles` and, if its result is HARD-DISSENT, sets `escalate_to_user: true` in the directive (rather than emitting a re-brainstorm payload — the cap is reached).
3. Skill acts on directive:
   - **HOLD** → act normally per `CLAUDE_PANEL` mode. State marked resolved.
   - **SOFT** → surface to user with panel note. State marked resolved.
   - **HARD with `escalate_to_user: true`** → surface `AskUserQuestion` with marker swapped to `(Recommended; Panel-flagged-after-2-cycles)` and full cycle history appended to question text. User makes the final call. State marked resolved.
   - **ERROR** → re-ask original unmodified. State marked resolved.
4. JSONL captures the eventual `user_pick` regardless of branch.

### Question-hash algorithm (canonical)

The hash is computed identically by the PreToolUse hook, the PostToolUse hook, the skill, and the aggregator. Treat this as the spec contract:

```python
def question_hash(question_text: str, options: list[Option]) -> str:
    normalized = "\n".join(sorted(
        strip_recommended_marker(opt.label).strip()
        for opt in options
    ))
    payload = f"{question_text.strip()}\n---\n{normalized}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]

def strip_recommended_marker(label: str) -> str:
    # Strips "(Recommended)" or "(Recommended; Panel-flagged-...)" suffixes.
    return re.sub(r"\s*\(Recommended[^)]*\)\s*$", "", label)
```

**Consequences**:
- Same question_text + same options + Claude swapping which option is `(Recommended)` ⇒ same hash. Treated as a continuation.
- Different question_text OR different option set ⇒ different hash. Fresh decision, fresh cycle counter.

### Hook re-entry decision (pseudocode)

```
on AskUserQuestion PreToolUse:
    qhash = question_hash(question_text, options)
    state_file = ~/.claude/panel/state-<qhash>.json
    if not exists(state_file):
        write fresh state (cycle=0)
        exit 2  # → skill dispatches cycle 0
    state = read(state_file)
    if state.cycle == 0:
        # stale from a prior skill crash
        remove(state_file); exit 0  # bypass (today's re-entry guard)
    elif state.cycle <= state.max_cycles:
        exit 2  # → skill runs cycle `state.cycle`
    else:
        # orphan: cycle exceeded max but state wasn't cleaned
        remove(state_file); exit 0
```

The cycle counter is incremented by the **skill** after a dispatch (not by the hook), so `state.cycle` always names the cycle *about to run*.

### State file schema

`~/.claude/panel/state-<qhash>.json`:

```json
{
  "qhash": "7e4a3f1b2c5d6e8f",
  "session_id": "abc123",
  "question_text": "Which HTTP client...",
  "normalized_options": ["go-resty/resty", "net/http + custom loop", "retryablehttp"],
  "created_at": "2026-05-14T08:30:00Z",
  "updated_at": "2026-05-14T08:31:22Z",
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

Cleaned up by `panel gc` (default: state files older than 1h get removed; resolved state files removed immediately).

## Telemetry: `decisions.jsonl`

Append-only event log. Three event types:

```jsonl
{"event":"decision","v":1,"ts":"2026-05-14T08:30:00Z","question_id":"7e4a3f1b2c5d6e8f","cycle":0,"session_id":"abc123","question_text":"…","options":[…],"recommended_label":"retryablehttp (Recommended)","panelists":[{"id":"da-nemotron","role":"DA","backend":"http","model":"nvidia/nemotron-3-super-v3","verdict":"OVERTURN","rationale":"…","alternative":"go-resty/resty","latency_ms":4123,"tokens_in":184,"tokens_out":287}],"aggregate":{"verdict":"HARD-DISSENT","rationale_gate_passed":true,"summary":"…"}}
{"event":"user_pick","v":1,"ts":"2026-05-14T08:35:00Z","question_id":"7e4a3f1b2c5d6e8f","pick":"go-resty/resty"}
{"event":"label","v":1,"ts":"2026-05-14T09:00:00Z","question_id":"7e4a3f1b2c5d6e8f","label":"right","note":"resty's retry-condition flexibility paid off"}
```

### Event-shape rationale

- Append-only is safe under concurrent panel runs from multiple sessions.
- `user_pick` and `label` arrive at different times than `decision` — separate events avoid mutation of existing rows.
- Join on `question_id` to reconstruct a question's full timeline. In-memory dict for ~10k entries is trivial (years of usage at ~50 decisions/day).

### `user_pick` capture

New PostToolUse hook `~/.claude/hooks/panel-record-userpick.sh`:

1. Reads the tool_result from stdin (Claude Code's PostToolUse hook spec).
2. For each (question, answer) pair, computes `question_id` via the canonical `question_hash` algorithm (see *Question-hash algorithm*).
3. Calls `python -m panel record-userpick --question-id <qid> --pick <answer>`.
4. `panel record-userpick` appends a `user_pick` event row if `question_id` matches an existing `decision` row (cheap skip otherwise — most AskUserQuestion calls aren't panel-evaluated).

**Dependency note**: this assumes Claude Code's hook system supports PostToolUse on `AskUserQuestion`. v1 only used PreToolUse on this tool. If PostToolUse isn't available, fall back to capturing `user_pick` from the skill's own observation of the AskUserQuestion result (when the skill's directive ends in the question being asked, the skill can observe the answer in the next assistant turn and append `user_pick` itself). Validate hook support during Phase 6.

## `panel` CLI

| Subcommand | Purpose |
|---|---|
| `panel aggregate …` | Internal — called by SKILL.md per dispatch |
| `panel record-userpick --question-id <qid> --pick <label>` | Internal — called by PostToolUse hook |
| `panel ls [--status unlabeled\|labeled] [--label …] [--since <date>] [--cycle <n>]` | List decisions matching filters |
| `panel show <question_id>` | Show full event timeline for one question |
| `panel label [--since <date>] [--status unlabeled]` | Interactive batch labeling |
| `panel stats [--since <date>]` | Bucket counts, false-positive rate, per-panelist OVERTURN rate, latency p50/p95 |
| `panel replay <question_id> [--with-personas-dir <path>]` | Re-dispatch same prompts; diff verdicts |
| `panel lint-config [--config <path>]` | Validate config (odd N, personas exist, env vars set) |
| `panel gc [--older-than 1h]` | Clean up stale `state-<qhash>.json` files |
| `panel tune --candidate-personas-dir <path>` | (v1.x) Score candidates against labeled corpus |

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

## Persona tuning harness (v1.x)

Deferred until v1 has been running long enough to accumulate a labeled corpus.

```
panel tune \
    --candidate-personas-dir personas-experiments/ \
    --baseline-corpus ~/.claude/panel/decisions.jsonl \
    --label-filter labeled \
    --output tune-report.md
```

For each candidate persona file, replays the labeled subset of decisions using the candidate persona instead of the baseline. Computes scores:

- For `label=right` HOLDs: does candidate also HOLD? (catch-consistency rate)
- For `label=right` DISSENTs: does candidate also DISSENT and suggest same alternative? (catch-fidelity rate)
- For `label=wrong` DISSENTs: does candidate HOLD? (false-positive reduction)

Emits a Markdown report ranking candidates by composite score. Operator chooses what to promote.

## Migration plan (6 phases, each independently shippable)

| Phase | Goal | ETA |
|---|---|---|
| **1 — Foundation bug fixes** | Fix v1 bugs #1/#2/#3 in `dispatch-da.sh`. Panel works end-to-end with current 2-backend setup. | ~1 day |
| **2 — Port `aggregate.sh` to Python** | Drop-in replacement, byte-parity. pytest suite. SKILL.md calls Python. | ~1 day |
| **3 — Config + multi-panelist** | `~/.claude/panel/config.json` shipped with default 3-panelist (DA + PE + QA). SKILL.md reads config. `dispatch-http.sh` replaces `dispatch-da.sh`. Personas refactored to `personas/<role>.md`. `panel lint-config` lands. | ~2–3 days |
| **4 — Severity tiers** | Aggregator emits `SOFT-DISSENT` and `HARD-DISSENT`. SKILL.md handles new directives. HARD behaves like emphatic SOFT (no re-brainstorm yet). | ~1 day |
| **5 — Re-brainstorm cycle mechanism** | State files relocate to `~/.claude/panel/state-<qhash>.json`. Hook updated for cycle continuation. SKILL.md emits markdown directive on HARD-DISSENT. Cycle cap enforced. New hook tests. | ~2 days |
| **6 — Telemetry + labeling CLI** | `decisions.jsonl` written by aggregator. PostToolUse hook captures `user_pick`. `panel ls`/`show`/`stats`/`label` subcommands. | ~2 days |
| **7 — `panel tune`** (v1.x) | Deferred until labeled corpus exists. | — |

Total v1: ~10–14 days. Each phase ends with a clean commit, working panel, and updated tests.

## Testing strategy

| Layer | Tool | Coverage |
|---|---|---|
| Unit (Python) | pytest + hypothesis | Aggregator severity logic, vote tallies, rationale-gate regex, JSONL append/read, `qhash` computation. Property-based tests on vote → bucket transitions. |
| Unit (shell) | bash + fixtures | `dispatch-http.sh`: mocked endpoint via `CLAUDE_PANEL_DA_MOCK_FILE`, env-missing paths, malformed-response paths. Extends v1's `dispatch-da_test.sh`. |
| Hook tests | bash | Stale state file → bypass. `cycle=1` state → continuation. `cycle=max` → escalation. New question hash → fresh run. Even-N config → rejection at `panel lint-config`. |
| Integration | pytest | End-to-end via fixture-mocked panelists. Verify directive shape, JSONL records, hook interaction. |
| Mutation | `mutmut` (Python) | Aggregator must fail when severity thresholds, vote counts, gate booleans mutated. Catches theater tests. |
| E2E | Manual runbook | Real session with each verdict class. `panel/testing/e2e.md` checklist. |

## Error handling matrix

| Failure | Behavior |
|---|---|
| Panelist HTTP timeout / non-2xx / malformed | Verdict file = ERROR. `failure_mode` applied: strict at N=3 → directive ERROR; graceful at N≥5 → drop one more to stay odd. |
| Panelist returns `OVERTURN + ALTERNATIVE=n/a` | Aggregator rejects as ERROR (fixes v1 bug #3). |
| Subagent `Agent` call errors | Skill catches, writes ERROR verdict file. Same downstream handling. |
| `panel aggregate` crashes (non-zero exit) | Skill catches, falls back to re-asking original question. Hook re-entry guard prevents loop. |
| Config missing / invalid | `panel lint-config` runs in skill startup. On failure: user-visible message, AskUserQuestion re-asked unmodified. |
| Persona file missing | Same as config missing. |
| Cycle cap reached, still HARD-DISSENT | Escalate to user: marker `(Recommended; Panel-flagged-after-2-cycles)`, full cycle history appended to question text. |
| Two sessions, same `question_id`, concurrent panel | Second session sees the state file. Under 1h → uses existing cycle state (shared decision is acceptable). Over 1h → `panel gc` cleans it first. |
| `decisions.jsonl` write fails | Best-effort: log to stderr (`panel-jsonl-write-failed`), do not block panel decision. |
| PostToolUse `panel-record-userpick` hook fails | Best-effort: decision is in JSONL without `user_pick` event. `panel label` shows "(user_pick unknown)" but is still labelable. |
| Claude ignores re-brainstorm directive | State file ages out after 1h via `panel gc`. No infinite memory leak. |
| Question hash collision | sha256-16hex = 2^64 entropy. Practically impossible for one user. Documented as not-handled. |
| `$TMPDIR` write blocked by sandbox | Pre-flight canary write in skill startup. On failure: "panel disabled: $TMPDIR unwritable from sandbox" + re-ask original. Operator widens via `/sandbox`. |

## Security posture

- **API keys**: env-var only. Never written to disk, logs, argv, or trace files. `dispatch-http.sh` uses curl `-H @<file>` with `umask 077` (preserved from v1).
- **`decisions.jsonl`**: contains question text + user picks, potentially sensitive. Stored under `~/.claude/panel/` with mode 0700 directory + 0600 file. Never transmitted except for explicit `panel replay` calls to panelist endpoints (same trust boundary as original dispatch).
- **Persona files**: world-readable (no secrets).
- **Subagent calls**: same trust boundary as today's `Agent` tool usage. Persona file content is the entire prompt — review before adding new roles.
- **Aggregator sanitization**: markdown links, images, backticks stripped from panelist rationales before embedding in user-facing summary (preserved from v1; defense in depth against prompt injection in panelist responses).
- **`$TMPDIR`**: state files in `~/.claude/panel/` rather than `$TMPDIR` — survives sandbox restrictions, more durable for cycle tracking. Files mode 0600.

## Open questions / future work

- **Per-role vote weighting**: should a PE OVERTURN weight more than a DA OVERTURN on principle-related questions? Out of scope for v1 (equal weights). Revisit after `panel stats` shows per-panelist false-positive rates.
- **Cost budget enforcement**: current design has no $/decision cap. Future `panel stats` could surface cumulative spend; future config could enforce a daily budget.
- **Local-model DA via Ollama**: `dispatch-ollama.sh` not in v1, but the dispatcher contract supports it. Add when a credible local reasoning model is available.
- **Cross-session decision dedup**: if Claude asks the same question twice in different sessions, currently each session re-runs the panel. A cache keyed on `qhash` could short-circuit repeats. Out of scope for v1.
- **Persona-tuning automation**: v1.x ships manual scoring. v2.x could auto-promote winning personas with operator approval.

## Relation to v1 (2026-05-10 spec)

| v1 piece | v2 disposition |
|---|---|
| PreToolUse hook | Preserved with cycle-aware re-entry logic. |
| `personas.md` (single file, DA+PE) | Split into per-role `personas/da.md`, `personas/pe.md`; add `personas/qa.md`. |
| `dispatch-da.sh` | Renamed and generalized to `dispatch-http.sh`. Three v1 bugs fixed at this seam. |
| `aggregate.sh` | Ported to Python (`panel aggregate`). Severity logic expanded. |
| Binary HOLD/DISSENT | Replaced by HOLD/SOFT-DISSENT/HARD-DISSENT/ERROR. |
| Mode `on` / `advise` / `off` | Preserved; behavior under each updated for new severities. |
| Trace log `~/.claude/debug/panel-trace.log` | Preserved as ops telemetry (event=trigger, event=verdict). Distinct from `decisions.jsonl` (data telemetry). |
| Two-panelist composition | Generalized to N panelists with odd-N invariant. Default ships 3 (DA + PE + QA). |
| State file in `$TMPDIR/claude-panel-<session>.json` | Relocated to `~/.claude/panel/state-<qhash>.json` to support cycle tracking and survive sandbox $TMPDIR restrictions. |

---

## Amendment v2.1 — NAT integration (2026-05-15)

After Phase 1 + Phase 2 shipped (foundation bug fixes + Python aggregator port), evaluation of NVIDIA NeMo Agent Toolkit (NAT) led to a decision to use NAT as the substrate for HTTP-backed panelists. This amendment supersedes the relevant sections of v2.0 with the changes below. Sections not mentioned here are unchanged.

### Why NAT

- **Org alignment**: NAT is the public NVIDIA NeMo Agent Toolkit (PyPI: `nvidia-nat`). Building personal tooling on top aligns with how teammates will likely build agent systems.
- **Multi-LLM coordination native**: NAT abstracts over LLM providers (NIM, OpenAI, Anthropic, etc.) with a single Python API. Adding a new panelist backend becomes a config change, not a new shell script.
- **Observability**: optional OpenTelemetry / Phoenix / LangSmith integration replaces hand-rolled telemetry for production-grade tracing when wanted.

What NAT does NOT provide (so remains custom):
- Voting / consensus / debate primitives — no panel pattern in NAT.
- Re-brainstorm cycle accounting — NAT has no concept of cycles.
- Claude Code hook integration — the panel hook stays bash, qhash-keyed state stays custom.
- Severity logic and rationale gating — custom Python.

### Architectural changes from v2.0

| v2.0 component | v2.1 disposition |
|---|---|
| `dispatch-http.sh` (planned in Phase 3) | **Replaced** by `panel/dispatch.py` — calls NAT's Python API in-process. No shell-curl dispatcher. |
| `~/.claude/panel/config.json` (planned schema) | **Replaced** by `~/.claude/panel/config.yml` (YAML, NAT-compatible). |
| Default ships N=3 (DA + PE + QA, all enabled) | **Replaced** by default N=1 (DA only, enabled by default). PE/QA/other roles are **opt-in** via `enabled: true` in the YAML config. |
| Persona files per role drive backend choice | **Generalized**: per-panelist `backend` field in config explicitly names the dispatch mechanism (`nat-nim`, `nat-anthropic`, `nat-openai`, `claude-subagent`, future `nat-other`). |
| Aggregator handles N panelists | Unchanged — aggregator (`panel/aggregate.py`) already generic over N verdict files. |
| Severity, re-brainstorm, telemetry-JSONL, hook | Unchanged. |

### Updated config schema

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
    enabled: false                      # opt-in
    backend: claude-subagent
    subagent_type: principal-engineer

  - id: qa
    role: QA
    enabled: false                      # opt-in
    backend: claude-subagent
    subagent_type: qa-engineer

severity:
  hard_threshold: majority
  rationale_gate:
    requires_principle_or_alternative: true
failure_mode:
  on_panelist_error: auto
re_brainstorm:
  enabled: true
  max_cycles: 2
telemetry:
  jsonl: ~/.claude/panel/decisions.jsonl
  otel_endpoint: null                   # optional Phoenix/LangSmith endpoint
```

**Odd-N invariant** still enforced: `panel lint-config` rejects configs where the count of `enabled: true` panelists is even.

### Backend abstraction

Each panelist's `backend` field selects the dispatch mechanism:

| Backend | Implementation | Use case |
|---|---|---|
| `nat-nim` | NAT's `nat.llm.nim_llm` provider | NVIDIA NIM endpoints (Nemotron, etc.) |
| `nat-anthropic` | NAT's Anthropic provider | When you want PE/QA quality with paid Anthropic API + NAT file-reading tools for CLAUDE.md/rules/ access |
| `nat-openai` | NAT's OpenAI provider | Optional alternative DA (e.g., gpt-5) for cross-vendor diversity |
| `claude-subagent` | Claude Code's `Agent` tool, invoked inline by SKILL.md | Free PE/QA via your Claude Code session — preserves principal-engineer subagent identity with full tool access |

The skill orchestrator (`SKILL.md`) reads `config.yml`, separates enabled panelists by backend, and dispatches in a single parallel message:
- All `nat-*` panelists → one `Bash python3.12 -m panel dispatch --panelist <id>` call per panelist.
- All `claude-subagent` panelists → one `Agent` tool call per panelist.

`panel/dispatch.py` imports `nat` as a library and calls the NAT runtime in-process (no `nat run` subprocess hop — that would add ~1–2 s cold-start per call). The shell still drives parallelism; NAT only handles single-panelist LLM dispatch.

### Cost / latency implications

| Aspect | v2.0 plan | v2.1 plan |
|---|---|---|
| Default panel cost | ~$0.001/call (DA + PE + QA, last two free via Claude subagent) | ~$0.001/call (DA only by default) |
| Per-call cost when PE+QA opted in | ~$0.001 (subagents free) | ~$0.001 (subagents free) OR ~$0.01–0.05 (if backends switched to `nat-anthropic`) |
| Cold-start latency | ~50 ms (bash dispatcher) | ~100 ms (Python+NAT in-process) |
| Dependency footprint | bash, jq, Python stdlib | + `nvidia-nat[langchain]` (~200 MB pip install) |
| New backend | Write a new `dispatch-*.sh` | Add a backend type to `panel.dispatch` (Python class) |

### Migration plan adjustments

The 6-phase migration from v2.0 is partially obsolete. Phase 1 and Phase 2 still ship as-is (Python aggregator and bug fixes are foundational regardless of dispatcher). Phase 3 is rewritten; Phases 4-6 lightly adjusted.

| Phase | v2.0 scope | v2.1 disposition |
|---|---|---|
| 1 — Foundation bug fixes | dispatch-da.sh bug fixes | **Shipped.** Stays. (dispatch-da.sh will be deleted in revised Phase 3.) |
| 2 — Port aggregator to Python | Replace aggregate.sh with Python | **Shipped.** Stays. |
| 3 — Config + multi-panelist | dispatch-http.sh, config.json, personas split | **Rewritten as v2.1 Phase 3**: NAT-based `panel/dispatch.py`, YAML config, opt-in panelists. Personas split still happens. |
| 4 — Severity tiers | severity decision tree | Mostly unchanged. Aggregator reads N verdicts (NAT-emitted or subagent-emitted) the same way. |
| 5 — Re-brainstorm cycles | State files, hook re-entry, Markdown directive | Unchanged. Cycle mechanic is Claude-Code-specific, NAT doesn't touch it. |
| 6 — Telemetry + CLI | decisions.jsonl, panel-review CLI, PostToolUse hook | Unchanged in core, with optional OTel export added: `telemetry.otel_endpoint` config knob routes decision events to Phoenix/LangSmith in addition to JSONL when set. |

### Open questions tracked in v2.1

- **`nat-anthropic` for PE/QA quality**: should the default config flip PE/QA's backend to `nat-anthropic` (with file-reading tools) instead of `claude-subagent`? Trade-off: paid API tokens for uniformity, but loses the free Claude subagent path and the principal-engineer subagent identity. Defer until usage data shows whether the quality of `claude-subagent` PE/QA is materially better than `nat-anthropic` would be.
- **NAT workflow YAML mode**: NAT also supports `nat run --config_file workflow.yml` as a standalone CLI. We're using the Python library API instead (in-process). If we later want to make the panel workflow externally invokable via `nat run` (e.g., from a non-Claude context), we'd add a panel-workflow.yml file. Out of scope for v2.1.
