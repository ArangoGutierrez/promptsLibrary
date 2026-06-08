# validate-recommendation v3.1 — Phase 3c design

**Date:** 2026-05-19
**Status:** Approved
**Amends:** `2026-05-15-validate-recommendation-v3-nat-native-design.md` (commit `c80b2f6`) — file-layout note in "Directory layout" + `aggregate` CLI signature in "Aggregator and severity".
**Builds on:** `2026-05-18-validate-recommendation-v3.1-nat-heavy-amendment.md` (commit `b3b8afb`).

This is a phase-scoped design doc, not a spec rewrite. v3 + v3.1 stay authoritative for all decisions and contracts except the two file-layout / signature items called out below. Phase 3c is the cutover from the v1 2-panelist text-directive panel to the v3.1 N-panelist JSON-directive panel.

## Goal

Ship the four pieces v3 lists for Phase 3c — N-panelist aggregator rewrite, severity-tree extraction, JSON directive contract, SKILL.md rewire — plus the v1 shell-file deletions that make the cutover irreversible. After Phase 3c lands, the runtime path is:

```
hook → SKILL.md → (parallel fan-out: Bash panel dispatch for nat-* + Agent for claude-subagent)
     → panel aggregate (JSON to stdout) → SKILL.md acts on directive
```

No shell wrappers. No two-panelist hardcoding. No `personas.md`. The skill becomes config-driven via `~/.claude/panel/config.yml` (shipped Phase 3a).

## Scope

**In scope (this phase):**
- New module `panel/severity.py` — pure decision tree, no I/O.
- Rewrite `panel/aggregate.py` for N panelists with JSON output via `severity.decide()`.
- Update `panel/cli.py` `aggregate` subcommand for the new signature.
- Rewrite `SKILL.md` from scratch for N-panelist fan-out + JSON directive parsing.
- Delete five v1 files (see "File deletions").
- New + rewritten test files; see "Test surface".

**Out of scope (deferred):**
- `panel/state.py` (qhash + cycle continuation) → Phase 5.
- `panel/decisions.py` (JSONL telemetry append) → Phase 6.
- `panel ls/show/label/stats/replay/gc` subcommands → Phase 6.
- `panel tune` (NAT Eval) → Phase 7.
- PostToolUse hook for `user_pick` capture → Phase 6.
- Re-brainstorm markdown directive emission (cycle < max behavior) → Phase 5.

## Phase 3c-specific decisions

These decisions are made by this brainstorm; v3 / v3.1 do not constrain them.

### Decision A — HARD-DISSENT semantics without a state machine

v3 spec (lines 442-471) describes HARD-DISSENT as updating `state-<qhash>.json`, emitting a markdown re-think directive, and only escalating to the user after `cycle >= max_cycles`. None of that machinery exists until Phase 5.

Phase 3c choice: **HARD-DISSENT escalates to the user immediately, on cycle 0.** The aggregator emits `escalate_to_user: true` on every HARD-DISSENT it produces. The `re_brainstorm` payload is never populated in Phase 3c (the JSON shape reserves the field; emission is Phase 5 work).

Behavioral consequence: a Phase 3c HARD-DISSENT looks identical to SOFT-DISSENT from SKILL.md's perspective (re-ask augmented, marker swap to `(Recommended; Panel-flagged)`, full panel feedback appended). The `verdict` field in the JSON still says `HARD-DISSENT` so the directive carries severity for logging. SKILL.md adds a short note in the augmented question text indicating panel severity ("Panel HARD-DISSENT" vs "Panel SOFT-DISSENT") so the user sees the strength of the panel's reaction.

Rationale: state machine is non-trivial (qhash determinism across hook + skill + post-hook, state file ageing, cycle history) and pulling it into Phase 3c would double the phase's size. Escalate-immediately preserves user agency and matches v1 semantics ("the user always sees the dissent"). Phase 5 will layer cycles on top without re-amending Phase 3c.

### Decision B — `severity.decide()` accepts `cycle=None`

The pure decision tree's signature:

```python
def decide(
    config: Config,
    panelists: list[ParsedVerdict],
    cycle: int | None = None,
) -> Directive
```

`cycle=None` is the Phase 3c default — passed by `aggregate.py`. It means "no state machine; HARD-DISSENT always escalates."
`cycle=int` is the Phase 5 path — `state.py` will pass the current cycle counter, and `decide()` compares it to `config.re_brainstorm.max_cycles`.

This keeps `severity.py` Phase-5-ready without Phase 5 work landing now. The single `cycle is None or cycle >= max_cycles` predicate covers both modes.

### Decision C — File-layout deviation from v3 spec

v3 spec places verdict files at `~/.claude/panel/work/<qhash>-<id>.verdict` (flat directory, filename prefix). The aggregator signature is `--verdicts <glob>` and the aggregator parses filenames to extract panelist IDs.

Phase 3c deviates: **per-session subdirectory + simple `<id>.verdict` filename.**

```
~/.claude/panel/work/<session-id>/<id>.verdict
```

Aggregator signature becomes `--verdicts-dir <dir>`; the aggregator reads `<dir>/<id>.verdict` for each enabled panelist found in `config.yml`. No filename parsing, no glob handling.

Phase 5 will swap `<session-id>` for `<qhash>` in the path (still a per-question subdir). The aggregator signature does NOT change between Phase 3c and Phase 5 — only the directory naming SKILL.md uses to write files.

Rationale: the spec's flat-with-prefix layout was workable but brittle (filename schema becomes a hidden contract). Per-question subdir centralizes the per-question concern in the directory name, and the aggregator interface stays simple. The v3 spec's "Directory layout" section gains a forward-amendment note pointing here.

### Decision D — Aggregator handles missing verdict files by coercing to ERROR

If `<dir>/<id>.verdict` is missing for an enabled panelist when aggregate runs, the aggregator does NOT abort. It synthesizes a panelist record with `verdict="ERROR"`, `rationale="verdict file missing: <path>"`, `alternative="n/a"`. The synthesized ERROR then flows through `severity.decide()` per the existing failure-mode logic.

Rationale: dispatch.py's contract (Phase 3b) is exit-0-always-write-a-file; a missing file therefore signals an upstream bug (SKILL.md didn't write the Agent response, or dispatch.py crashed before writing). Either way, the panel can degrade per `failure_mode` rather than crashing.

### Decision E — JSON directive is single-line compact

The aggregator's stdout is `json.dumps(asdict(directive), indent=None)` — one line, no pretty-printing. SKILL.md parses fields via `jq` Bash calls (`jq -r '.verdict'`, `jq -r '.summary'`, etc.). Single-line is easier for SKILL.md to capture into a Bash variable and pipe to jq.

Rationale: SKILL.md is Claude-driven markdown; spinning up Python for JSON parsing would be heavy. `jq` is the standard tool, available everywhere.

### Decision F — SKILL.md uses jq, not embedded Python

SKILL.md's parse step is `jq` Bash calls. The skill does NOT spawn `python -m panel ...` for parsing — that's reserved for the actual heavyweight steps (`dispatch`, `aggregate`).

### Decision G — SKILL.md rewrite from scratch (not incremental edit)

The current SKILL.md (11 KB, hardcoded to DA + PE, reads `personas.md`, calls `dispatch-da.sh`) is replaced wholesale. The new SKILL.md is config-driven: it reads `config.yml`, enumerates enabled panelists, composes per-role prompts from `personas/<role>.md`, and fans out N tools in one message.

Rationale: incremental edits leave too many surfaces where hardcoded `dispatch-da.sh` / `personas.md` / "DA"/"PE" references can survive. A fresh rewrite is cleaner to review and easier to audit for stale text.

### Decision H — Approach B commit cadence in a feature branch

Five commits in `~/.claude/` on a feature branch (`feat/phase3c-aggregate-json`), atomically merged when commit 5 is done. Each commit independently green; bisect remains useful for Phase 3c regressions. The feature branch avoids leaving the panel non-functional on `main` between commits 2 and 4 (the aggregator changes JSON output before SKILL.md learns to parse it).

## JSON directive shape

Aggregator stdout. SKILL.md parses with `jq`. Shape is forward-compatible: Phase 5/6/7 add fields without breaking Phase 3c consumers.

**Always-present top-level fields:**

```json
{
  "verdict": "HOLD | SOFT-DISSENT | HARD-DISSENT | ERROR",
  "summary": "<one-line, sanitized, SKILL.md-displayable>",
  "rationale_gate_passed": true | false | null,
  "panelists": [
    {
      "id": "<panelist-id from config>",
      "role": "DA | PE | QA | ...",
      "verdict": "HOLD | OVERTURN | ERROR",
      "rationale": "<verbatim, sanitized>",
      "alternative": "<verbatim option label or 'n/a'>"
    }
  ]
}
```

Field rules:
- `summary` carries the user-facing text. For HOLD: `"DA: <abbrev>. PE: <abbrev>."`. For dissents: `"**Panel review:** ..."` (matches v1's parser sentinel). For ERROR: `"<failure reason>"`. Already sanitized by the severity-module builders.
- `rationale_gate_passed`: `true` for HOLD (trivially — no OVERTURN to gate), `true|false` for dissents (the HARD-vs-SOFT discriminator), `null` for ERROR.
- `panelists` is in `config.yml` order, filtered to `enabled: true`. Each entry records what the aggregator parsed (or synthesized, on missing-file).

**Conditional fields (Phase 3c never populates these; Phase 5 will):**

```json
{
  "re_brainstorm": {
    "cycle": 0,
    "max_cycles": 2,
    "suggested_alternatives": ["<opt label>"],
    "feedback_for_claude": "<directive text>"
  },
  "escalate_to_user": true
}
```

Phase 3c emits `escalate_to_user: true` on every HARD-DISSENT (per Decision A). `re_brainstorm` is never emitted in Phase 3c.

**Per-verdict shape examples (Phase 3c emissions):**

HOLD (default config, N=1, DA-only enabled):
```json
{"verdict":"HOLD","summary":"DA: stdlib meets the stated goal; no stronger counter found.","rationale_gate_passed":true,"panelists":[{"id":"da-nemotron","role":"DA","verdict":"HOLD","rationale":"After examining the alternatives, no stronger counter found...","alternative":"n/a"}]}
```

SOFT-DISSENT (N=3, 1 OVERTURN without principle/alternative naming):
```json
{"verdict":"SOFT-DISSENT","summary":"**Panel review:** DA flagged Option A: dependency cost may grow. PE held: aligns with YAGNI. QA held: testable as written.","rationale_gate_passed":false,"panelists":[...]}
```

HARD-DISSENT (N=3, ≥2 OVERTURN with principle/alternative):
```json
{"verdict":"HARD-DISSENT","summary":"**Panel review:** DA flagged Option A → suggests Option B: ... QA flagged Option A → suggests Option B: ...","rationale_gate_passed":true,"panelists":[...],"escalate_to_user":true}
```

ERROR (failure mode exceeded):
```json
{"verdict":"ERROR","summary":"panelist errors exceed failure-mode tolerance (strict@N=3: 1 ERROR fails the panel)","rationale_gate_passed":null,"panelists":[{"id":"da-nemotron","role":"DA","verdict":"ERROR","rationale":"panelist invocation failed: ConnectionError ...","alternative":"n/a"},...]}
```

## Module designs

### `panel/severity.py` — pure decision tree

One public function, five private helpers. Zero I/O. Pure-Python module, dataclasses only.

```python
def decide(
    config: Config,
    panelists: list[ParsedVerdict],
    cycle: int | None = None,
) -> Directive:
    """Decide the panel directive from N parsed verdicts.

    Pure: no file I/O, no logging, no network. Tests verify by feeding
    constructed ParsedVerdict lists and asserting on the returned Directive.
    """
```

**Decision flow:**

1. **Normalize each panelist.** `_validate(p)` coerces malformed panelists to ERROR:
   - `verdict ∉ {HOLD, OVERTURN, ERROR}` → ERROR
   - `OVERTURN + alternative ∈ {"n/a", ""}` → ERROR (preserves Phase 1 bug #3 fix)
   - missing rationale → ERROR

2. **Handle ERROR cascade.**
   - `n_error = sum(1 for p in panelists if p.verdict == "ERROR")`
   - `mode = _resolve_failure_mode(config, N_total)`
     - explicit `strict` → strict
     - explicit `graceful` → graceful
     - `auto` → strict if `N ∈ {1, 3}`, graceful if `N ≥ 5`
   - if `mode == "strict"` OR `N_total - 2*n_error < 1` → ERROR directive
   - else → `_degrade_keeping_odd(panelists, n_error)`: drop ERROR panelists plus one more (if needed) to keep the surviving count odd.

3. **Tally OVERTURN vs threshold.**
   - `N = len(surviving)`, `threshold = ceil(N/2)` for majority or `ceil(2N/3)` for supermajority.
   - `overturns = [p for p in surviving if p.verdict == "OVERTURN"]`
   - `len(overturns) == 0` → HOLD
   - `len(overturns) < threshold` → SOFT-DISSENT (gate not checked; threshold itself was the discriminator)

4. **Apply rationale gate.** (Reached only if threshold met.)
   - `gate_passed = any(_names_principle(p.rationale, patterns) or _has_concrete_alternative(p) for p in overturns)`
   - Not passed → SOFT-DISSENT (rationale_gate_passed=False)
   - Passed → fall through to HARD-DISSENT branch.

5. **HARD-DISSENT branch.**
   - `cycle is None or cycle >= max_cycles` → `escalate_to_user=True`, no `re_brainstorm`.
   - Else → `re_brainstorm` payload (Phase 5+).

**Summary text construction.** The directive builders (`_hold_directive`, `_soft_dissent_directive`, `_hard_dissent_directive`, `_error_directive`) call `sanitize.strip_markdown()` on each rationale and alternative before embedding, then format the v1-compatible `**Panel review:**` sentinel for dissents. SKILL.md prints `directive.summary` verbatim — no further composition.

**Edge case at N=1 (default config):** `threshold = ceil(1/2) = 1`. A single OVERTURN crosses majority. Then the rationale gate decides HARD vs SOFT — a lone DA OVERTURN with a concrete alternative becomes HARD-DISSENT; with a vague rationale and no alternative, the `_validate()` step coerced it to ERROR already, so it never reaches the gate.

### `panel/aggregate.py` — N-panelist aggregator

Reads config, reads verdict files, builds ParsedVerdict list, calls `severity.decide()`, serializes to JSON.

```python
def aggregate(
    config_path: str,
    verdicts_dir: str,
    recommended_label: str,
) -> str:
    """Build the panel directive from per-panelist verdict files.

    Returns a single-line JSON string suitable for printing to stdout.
    SKILL.md parses with jq.
    """
    cfg = load_config(config_path)
    enabled = [p for p in cfg.panelists if p.enabled]

    parsed: list[ParsedVerdict] = []
    for p in enabled:
        path = Path(verdicts_dir).expanduser() / f"{p.id}.verdict"
        if not path.is_file():
            parsed.append(ParsedVerdict(
                id=p.id, role=p.role,
                verdict="ERROR",
                rationale=f"verdict file missing: {path}",
                alternative="n/a",
            ))
            continue
        v = parse_verdict_file(path)
        parsed.append(ParsedVerdict(
            id=p.id, role=p.role,
            verdict=v.verdict,
            rationale=v.rationale,
            alternative=v.alternative,
        ))

    directive = severity.decide(cfg, parsed, cycle=None)
    log_verdict(directive.verdict, _trace_line(directive))
    return json.dumps(asdict(directive), indent=None)
```

`directive` is a `Directive` dataclass defined in `severity.py`. `asdict()` recursively flattens dataclass fields including the nested `panelists` list. Conditional fields (`re_brainstorm`, `escalate_to_user`) are dataclass fields with `default=None`; serialization omits them by setting `default_factory` and post-processing the dict to drop None values before `json.dumps`. (Implementation detail; the JSON contract is what matters.)

### `panel/cli.py` — aggregate subcommand update

Current signature (Phase 2):
```bash
panel aggregate --da <path> --pe <path> --recommended-label <text>
```

New signature (Phase 3c):
```bash
panel aggregate --config <path> --verdicts-dir <dir> --recommended-label <text>
```

The argparse subparser for `aggregate` changes. Other subcommands (`lint-config`, `dispatch`) are untouched.

### `SKILL.md` rewrite

Frontmatter description updated:

```yaml
---
name: validate-recommendation
description: Validate (Recommended) options in AskUserQuestion via N configurable panelists (~/.claude/panel/config.yml). Triggered by the validate-recommendation hook; do not invoke manually.
---
```

**Section ordering:**

1. **Inputs** — `$STATE_FILE`, `~/.claude/panel/config.yml`, env vars (`CLAUDE_PANEL`, `CLAUDE_SESSION_ID`, `TMPDIR`).
2. **Setup** — read state file; read config via `panel lint-config`; create per-session workdir `~/.claude/panel/work/${CLAUDE_SESSION_ID}/` (mkdir -p, 0700).
3. **Per-question dispatch** (per question with `(Recommended)` AND NOT `(Recommended; Panel-flagged)`):
   - 3.1 Build user prompt body (same as v1).
   - 3.2 Enumerate enabled panelists via `jq` reading config.yml.
   - 3.3 Fan out N tools in ONE message:
     - For each `backend: nat-*` panelist → Bash `panel dispatch --panelist <id> --persona personas/<role>.md --prompt-file "$PROMPT_FILE" --output "$WORKDIR/<id>.verdict"`.
     - For each `backend: claude-subagent` panelist → Agent tool call with `subagent_type: <panelist.subagent_type>`, prompt = persona's system + one-shot + user body.
     - **All tools in one message** — the parallelism point. SKILL.md emphasizes this is non-negotiable.
   - 3.4 After the message returns, write each Agent response to `$WORKDIR/<id>.verdict` via the Write tool. (nat-* verdict files were written by dispatch.py.)
   - 3.5 Call aggregator: `panel aggregate --config ~/.claude/panel/config.yml --verdicts-dir "$WORKDIR" --recommended-label "<label>"`. Capture stdout.
   - 3.6 Parse directive with `jq` — `verdict`, `summary`, `panelists[]`, `escalate_to_user`.
4. **Acting on the directive** — table mapping verdict × `CLAUDE_PANEL` to behavior (HOLD/SOFT/HARD/ERROR; on/advise). Phase 3c-specific note: HARD and SOFT take the same path in SKILL.md (re-ask augmented), but HARD adds a `Panel HARD-DISSENT` marker in the augmented note.
5. **Cleanup** — `rm -rf "$WORKDIR"` and `rm "$STATE_FILE"` after all questions processed.
6. **Failure modes** — state file missing, config missing/invalid, persona file missing, dispatch.py crashes, Agent timeout, aggregator crashes, missing API keys. All fall through to "re-issue original" with explanation.
7. **Loop safety** — hook re-entry guard makes fallback re-issues safe even without the marker swap.
8. **Multi-question parallelism** — optional optimization; defer to v1.x unless multi-question recommendations become common.
9. **What you must NOT do** — same list as v1, plus: do NOT pass API keys on argv; do NOT modify Agent response text before writing to the verdict file.

## File layout (v3 spec amendment)

v3 spec's "Directory layout" section places verdict files at `~/.claude/panel/work/<qhash>-<id>.verdict`. Phase 3c amends to:

```
~/.claude/panel/work/<session-id>/<id>.verdict
```

Per-session subdirectory; simple filename. Phase 5 swaps `<session-id>` for `<qhash>` (a per-question subdir). The aggregator interface does not change across this swap.

The v3 spec line ~125 (under "Directory layout") gets a forward-amendment note in Phase 3c's first commit if appropriate, or stays as-is and v3.2 collects layout amendments later.

## File deletions

Five files removed in the final Phase 3c commit:

| File | Reason |
|---|---|
| `dispatch-da.sh` | Replaced by `panel/dispatch.py` (shipped Phase 3b). |
| `dispatch-da_test.sh` | Replaced by `test_dispatch.py` (Phase 3b). |
| `aggregate.sh` | Shim no longer needed — SKILL.md calls `panel aggregate` directly. |
| `aggregate_test.sh` | Shell wrapper test — Python `test_aggregate.py` is the coverage. |
| `personas.md` | Replaced by per-role files in `personas/{da,pe,qa}.md` (Phase 3a). |

Pre-deletion sanity checks (Task 5):
- `grep -r 'dispatch-da\|aggregate\.sh\|aggregate_test\.sh' ~/.claude/skills/ ~/.claude/hooks/` returns no hits in non-deleted files.
- `grep -r 'personas\.md' ~/.claude/skills/` returns only matches in deleted files (or none).
- `~/.local/pipx/venvs/pytest/bin/pytest panel/tests/` passes.
- `python3.12 -m panel lint-config` returns OK.
- New SKILL.md does not reference any of the 5 deletees.

README update (in the same commit or sibling docs commit):
- Remove Phase 1/2 sections referencing v1 shell tools.
- Update Phase 3b "manual `panel dispatch` invocation" section to note it's now wired into SKILL.md.
- Add a brief Phase 3c section documenting the JSON directive shape (for users debugging panel decisions).

## Test surface

Net delta from Phase 3b baseline (77 tests):

| File | Change | Net tests |
|---|---|---|
| `panel/tests/test_severity.py` | Create | +25 |
| `panel/tests/test_aggregate.py` | Rewrite (8 old removed, 12 new added) | +4 |
| `panel/tests/test_cli_aggregate.py` | Create | +3 |
| Other test files | Unchanged | 0 |

Total after Phase 3c: **~109 tests**.

**test_severity.py coverage matrix:**

| Category | Cases |
|---|---|
| Vote tally vs. threshold | N=1 majority; N=3 majority; N=3 supermajority; N=5 supermajority; threshold edge values |
| ERROR cascade | N=3 strict@1err → ERROR; N=5 graceful@1err → degrade to 3; auto@N=3 → strict; auto@N=5 → graceful; 2*n_err ≥ N → ERROR |
| Rationale gate | Principle regex match (YAGNI, atomicity, TDD); concrete alternative; both false → SOFT; one true → HARD |
| Cycle handling | `cycle=None` → escalate; `cycle=0, max=2` → re_brainstorm payload; `cycle=2, max=2` → escalate |
| Phase 1 bug #3 preservation | OVERTURN + alt="n/a" → coerced to ERROR |
| Mutation resistance | Flip `>=` → `>` (threshold); AND → OR (gate); coverage targets these |

**test_aggregate.py coverage (~12 tests):**
- Enumerates enabled panelists from config (disabled panelists are not in `panelists[]`).
- Missing verdict file → ERROR-coerced panelist.
- HOLD / SOFT / HARD / ERROR JSON shapes match the contract.
- `summary` contains the `**Panel review:**` sentinel for dissents.
- Markdown injection in panelist rationale is stripped from `summary`.
- Trace log records one outcome per call.

**test_cli_aggregate.py coverage (~3 tests):**
- argparse → calls `aggregate()` with the right paths.
- Exit 0 on success.
- Exit 1 on config-load failure.

**Smoke test** (manual, after merge):
- `panel lint-config` returns OK.
- End-to-end invocation of an `AskUserQuestion` containing `(Recommended)`: verify the panel runs, JSON directive is emitted, SKILL.md acts on it.
- Repeat with `pe.enabled: true` (N=3 panel) to verify Bash + Agent fan-out actually parallelizes.

## Migration plan

Feature branch in `~/.claude/`: `feat/phase3c-aggregate-json`. Atomic merge to `main` when commit 5 lands.

| # | Commit | Files | Green after this commit |
|---|---|---|---|
| 1 | `feat(panel): severity.py decision tree` | `panel/severity.py`, `panel/tests/test_severity.py` | Yes (new module; old aggregate.py still passes its tests) |
| 2 | `feat(panel): aggregate.py N-panelist + JSON directive` | `panel/aggregate.py` rewrite, `panel/tests/test_aggregate.py` rewrite, `panel/cli.py` aggregate subcommand wiring | Tests green. Panel non-functional end-to-end because SKILL.md still parses text. |
| 3 | `feat(panel): cli.py JSON aggregate output` | `panel/tests/test_cli_aggregate.py` | Tests green. Panel still non-functional (waiting for SKILL.md). |
| 4 | `feat(panel): SKILL.md rewrite for N-panelist fan-out + JSON parsing` | `skills/validate-recommendation/SKILL.md` from scratch | Panel works end-to-end again. |
| 5 | `chore(panel): delete v1 shell files + personas.md` | 5 deletions + README touch | Final state. |

Each commit GPG-signed and DCO-signed-off per `~/.claude/` repo policy.

## Out of scope, with pointers

| Concern | Phase | Notes |
|---|---|---|
| qhash + state file + cycle continuation | Phase 5 | Adds `panel/state.py`, `panel record-userpick` subcommand, hook updates for cycle continuation, re-brainstorm markdown emission. |
| JSONL telemetry (`decisions.jsonl`) | Phase 6 | Adds `panel/decisions.py` (or NAT-observability per v3.1 amendment). Needs qhash → depends on Phase 5. |
| `panel ls/show/label/stats/replay/gc` | Phase 6 | Reads `decisions.jsonl`. |
| `panel tune` | Phase 7 | NAT Eval framework. Needs labeled corpus → depends on Phase 6. |
| PostToolUse hook for `user_pick` | Phase 6 | Verifies harness support; fallback in SKILL.md if unsupported. |

## Self-review

**Spec coverage:**
- v3 spec section "Aggregator and severity" → Phase 3c implementation (severity.py + aggregate.py).
- v3 spec section "Severity decision tree" → severity.py module.
- v3 spec section "Directive JSON shape" → JSON contract documented above.
- v3 spec section "SKILL.md acting on the directive" → SKILL.md section 4.
- v3 spec section "Directory layout" deletion list → Phase 3c file deletions.
- v3 spec section "Migration plan" Phase 3c row → matches this design.
- v3.1 amendment "Pattern B — Inner Function for pure logic (Phase 3c)" — NAT Function deferred; aggregate is plain Python. Decision documented inline.

**Placeholder scan:** all code snippets are the actual code an engineer types except `_validate`, `_resolve_failure_mode`, `_degrade_keeping_odd`, `_names_principle`, `_has_concrete_alternative` which are internal helpers whose implementations are TDD discoveries during Phase 3c execution. No "TBD"/"TODO" markers.

**Scope check:** Phase 3c stays bounded — no state machine, no JSONL, no NAT primitives, no tune. The "Out of scope" table is explicit about deferrals.

**Internal consistency:** the JSON shape documented in "JSON directive shape" matches the directive emission paths in "Module designs / severity.py". The SKILL.md section 4 behaviors match the verdict field values. The verdict-file convention in "File layout" matches the aggregator implementation flow.

**Ambiguity check:** `rationale_gate_passed: null` on ERROR (vs. `false`) — documented explicitly. `escalate_to_user: true` always on Phase 3c HARD-DISSENT — documented. HARD vs SOFT user-facing behavior identical in Phase 3c — documented.

**Out-of-scope decisions deferred to later phases:**
- Whether `panel/aggregate.py` becomes a NAT Function (v3.1 amendment Pattern B) → deferred; revisit after Phase 6 introduces NAT observability and the function-registration ergonomics are clearer.
- Whether multi-question parallelism becomes a default → defer to v1.x usage data.

## Relation to v3 and v3.1

| v3 / v3.1 element | Phase 3c disposition |
|---|---|
| v3 locked decisions #1-#14 | Unchanged. |
| v3.1 amendment to decision #9 (NAT primitives encouraged) | Phase 3c chooses not to use NAT Function for `aggregate.py` (plain Python is clearer for this step). Decision noted; reconsider after Phase 6. |
| v3 spec "Severity decision tree" | Implemented in `severity.py` per design above. |
| v3 spec "Directive JSON shape" | Implemented per "JSON directive shape" section. Optional fields reserved for Phase 5. |
| v3 spec "Aggregator interface" `--verdicts <glob>` | **Amended:** `--verdicts-dir <dir>` per Decision C. |
| v3 spec "Directory layout" `work/<qhash>-<id>.verdict` | **Amended:** `work/<session-id>/<id>.verdict` per Decision C. |
| v3 spec "HARD-DISSENT re-brainstorm flow" | Deferred to Phase 5 per Decision A. |
| v3 spec "qhash algorithm" / "state file schema" | Deferred to Phase 5. |
| v3 spec "Telemetry" / `decisions.jsonl` | Deferred to Phase 6. |
| v3 spec deletions (`dispatch-da.sh`, `dispatch-da_test.sh`, `aggregate.sh`, `personas.md`) | Honored, plus `aggregate_test.sh` added to the list. |
