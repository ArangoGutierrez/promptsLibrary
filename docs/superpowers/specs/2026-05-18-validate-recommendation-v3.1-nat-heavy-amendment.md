# validate-recommendation v3.1 — NAT-heavy amendment

**Date:** 2026-05-18
**Status:** Approved
**Amends:** `2026-05-15-validate-recommendation-v3-nat-native-design.md` (commit `c80b2f6`)

v3.1 is an amendment, not a rewrite. The v3 canonical design stays the authoritative reference for all behavior, contracts, and architecture EXCEPT the items overridden here. The amendment reverses a single locked decision (#9), replaces one code snippet, and updates four migration-plan rows.

## Why this amendment

v3 locked decision #9: "`nvidia-nat>=1.6,<2.0` ... as LLM provider abstraction ... imported as library, in-process. **No NAT Workflow/Function/Agent primitives.**" The wording was written before the implementation team probed NAT 1.6's actual API.

End-of-day 2026-05-18 NAT API probe found:

1. `nat.llm.nim_llm` does NOT export an `NIMLLM(...).invoke(messages=...)` class. It exports `NIMModelConfig` (a pydantic config) plus a `register_llm_provider` decorator. NAT 1.6's LLM dispatch goes through `Builder().add_llm(NIMModelConfig(...))` then retrieval via the builder's runtime.
2. `nat.builder.builder.Builder` provides `add_llm`, `add_function`, `add_workflow`, `add_function_group`, `add_retriever`, plus observability hooks. Builder IS a NAT primitive — the kind v3 #9 prohibited.
3. NAT 1.6 ships an evaluation framework (`nat.experimental.test_time_compute.*`) suitable for the deferred `panel tune` subcommand.
4. NAT 1.6 has OpenTelemetry observability built in — fits the spec's optional OTel emit + canonical JSONL pattern.

v3 #9's "no primitives" restriction was based on incomplete API knowledge. With the corrected picture, the right architecture is the opposite: use NAT primitives natively for LLM dispatch, observability, and evaluation; let the panel layer on top.

The panel's **outer** orchestration (hook → SKILL.md → fan-out across panelists) stays Claude-driven because of hard constraints — Claude Code hooks are bash, `AskUserQuestion` and `Agent` are Claude-only tools, SKILL.md runs in Claude's turn loop. NAT cannot replace those. The amendment defines the **inner** orchestration (each `python -m panel <subcommand>` invocation) as NAT-native.

## Reversed decisions

### Decision #9 (revised)

| | Before (v3) | After (v3.1) |
|---|---|---|
| Substrate | `nvidia-nat>=1.6,<2.0` as LLM provider abstraction | `nvidia-nat>=1.6,<2.0` as **platform**: LLM dispatch, observability, evaluation |
| Import posture | "Library, in-process" | "Library, in-process" (unchanged — NAT runs in `python -m panel`, no external NAT service) |
| Primitive use | **Prohibited** | **Encouraged where NAT-native is clearer than custom Python** — Builder, register_llm_provider, observability spans, eval scoring |

Nothing else in decision #9 changes. The version range, in-process posture, and "Apache-2.0 from public PyPI" constraints are unchanged.

### All other v3 locked decisions

Decisions #1-#8 and #10-#14 are **unaffected**. The panel-to-user contract, severity tiers, configurable N, odd-N invariant, default N=1, re-brainstorm cycle cap, JSONL canonical telemetry, Python 3.12 runtime, YAML config at `~/.claude/panel/config.yml`, `max_tokens=32768` default, "thin Python + fat SKILL.md" orchestration, `~/.claude/panel/` state location, and Phase 1+2 module reuse all remain locked as written in v3.

## Replaced: `_invoke_nat` snippet (v3 section "Dispatchers", lines 305-328)

v3's snippet instantiated NAT LLM classes directly (`NIMLLM(...)`). That class does not exist in NAT 1.6.

A Phase 3b Task 2 spike on 2026-05-18 attempted the NAT `WorkflowBuilder` + `nvidia-nat-langchain` + `langgraph` dispatch path. It hit three layers of NAT-design friction in succession:
1. `Builder` is abstract; `WorkflowBuilder` is the concrete entry point with all methods `async`.
2. `WorkflowBuilder.get_llm(name, wrapper_type)` requires a registered framework adapter; `nat-anthropic` is missing in 1.6.0 entirely.
3. `nvidia-nat-langchain.register` requires `nvidia-nat-opentelemetry`, `openevals`, and `nat.plugins.eval` to be installed AND the register module imported explicitly before `WorkflowBuilder` knows about langchain wrappers.

The pattern of escalating install + ceremony is a smell that NAT 1.6 is not designed for "make one LLM call". NAT 1.6 is a workflow framework; its dispatch primitives serve Workflows orchestrated by NAT itself. For the per-panelist seam choice, where SKILL.md drives the orchestration and NAT runs in `python -m panel dispatch`, the appropriate LLM client is the langchain provider directly.

The snippet is therefore replaced with langchain providers (`ChatNVIDIA`, `ChatAnthropic`, `ChatOpenAI`) — synchronous, no Builder ceremony, no async bridging:

```python
def _invoke_nat(panelist: Panelist, system: str, user: str) -> object:
    """The single mockable seam — tests mock this function entirely.

    Dispatch uses langchain provider classes directly. NAT's Builder /
    WorkflowBuilder primitives are not used here: they require async,
    framework-adapter registration, and a deeper transitive-dep tree
    than the per-panelist seam justifies. NAT lives in later phases
    (Phase 6 observability, Phase 7 evaluation) where its design fits.
    """
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]
    if panelist.backend == "nat-nim":
        from langchain_nvidia_ai_endpoints import ChatNVIDIA
        llm = ChatNVIDIA(
            model=panelist.model,
            temperature=panelist.temperature,
            max_completion_tokens=panelist.max_tokens,
        )
    elif panelist.backend == "nat-anthropic":
        from langchain_anthropic import ChatAnthropic
        llm = ChatAnthropic(
            model=panelist.model,
            temperature=panelist.temperature,
            max_tokens=panelist.max_tokens,
        )
    elif panelist.backend == "nat-openai":
        from langchain_openai import ChatOpenAI
        llm = ChatOpenAI(
            model=panelist.model,
            temperature=panelist.temperature,
            max_completion_tokens=panelist.max_tokens,
        )
    else:
        raise ValueError(f"unsupported NAT backend: {panelist.backend}")
    return llm.invoke(messages)
```

The langchain provider classes expose `.invoke(messages)` synchronously and return a langchain `AIMessage` (has `.content`). Auth comes from per-provider env vars (`NVIDIA_API_KEY` / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`) — the same env-var-only posture v3's security section already specifies.

**Naming note:** the function name `_invoke_nat` is kept for continuity with the seam-mock contract in v3. The "nat" suffix is historical; the function dispatches via langchain. Renaming (`_invoke_llm`) is a v3.2-or-later cleanup, not Phase 3b scope.

Tests at the `_invoke_nat` seam are unchanged. Mocks return any object shape with `.content` / dict / string; `_extract_content()` from v3 dispatch design handles all three. Test count is unchanged from the original Phase 3b plan (15 dispatch tests).

## Updated migration-plan rows

Four rows in v3's "Migration plan" table gain explicit NAT-primitive notes:

| Phase | Goal (revised) | NAT primitives used |
|---|---|---|
| 3b — Panelist dispatch | `panel/dispatch.py` uses langchain provider classes (`ChatNVIDIA` / `ChatAnthropic` / `ChatOpenAI`) for `nat-*` backends. `_invoke_nat` is the mock seam; behind it sits langchain → HTTP. NAT 1.6's `WorkflowBuilder` was attempted in the Task 2 spike and rejected as wrong-tool-for-job (async + plugin registration + transitive-dep tree don't justify mediating one HTTP call). | None (NAT installed but unused in this phase) |
| 3c — N-panelist aggregator + severity | `panel/aggregate.py` and `panel/severity.py` may be implemented as NAT Functions (registered via `WorkflowBuilder.add_function`) for composability with later NAT Workflows; decision made during 3c brainstorm. JSON directive contract unchanged. | NAT Function (decided in 3c) |
| 6 — Telemetry + labeling CLI | `panel/decisions.py` emits via NAT's observability layer (canonical OpenTelemetry spans) → JSONL appender + optional remote OTel collector. Removes the custom-JSONL append code path; NAT's observability is the single emit. | NAT observability, OpenTelemetry instrumentation |
| 7 — `panel tune` | `panel tune --candidate-personas-dir` runs candidate personas against the labeled `decisions.jsonl` corpus using NAT's Eval framework. Brings 7 forward from "deferred v1.x" — NAT makes it cheap enough to ship. | `nat.experimental.test_time_compute.scoring.*` (or replacement; pinned during 7 brainstorm) |

Phase 5 (re-brainstorm cycles) is **not** NAT-ified in v3.1: the state machine is small, custom Python is clearer than a NAT Workflow for two cycles. v3 spec for Phase 5 stays as-written.

## New section: NAT-native patterns (forward-looking)

This section is informational. It documents the IDIOMS the panel will reuse across phases as NAT-native primitives replace custom Python. Each idiom gets pinned (file paths, exact API) during its phase brainstorm; the patterns below sketch shapes only.

### Pattern A — LLM dispatch (Phase 3b)

One `_invoke_nat` call per panelist. Uses a langchain provider class (`ChatNVIDIA` / `ChatAnthropic` / `ChatOpenAI`) per `nat-*` backend, constructed per-dispatch (no shared state), `.invoke(messages)` called synchronously. Tests mock the whole function. NAT is NOT used in this pattern — the NAT-heavy posture begins at Pattern B and after.

### Pattern B — Inner Function for pure logic (Phase 3c)

Pure-Python decision logic (severity tree, vote tallying) becomes a NAT Function registered with `Builder.add_function`. SKILL.md still calls `python -m panel aggregate ...`; that CLI internally constructs a Builder, registers the aggregator function, invokes it once, prints the JSON directive. No state, no side effects in the Function — observability spans capture inputs/outputs.

### Pattern C — Observability for telemetry (Phase 6)

NAT's observability emits OpenTelemetry spans per dispatch + per aggregate call. The `panel record-userpick` subcommand attaches `user_pick` and `label` events to the existing `question_id`-keyed trace. JSONL at `~/.claude/panel/decisions.jsonl` is generated by a built-in NAT OTel→JSONL exporter; optional remote endpoint is configured via `telemetry.otel_endpoint` in `config.yml`. Removes `panel/decisions.py` as a custom JSONL appender (NAT handles file IO).

### Pattern D — Eval harness for tuning (Phase 7)

`panel tune --candidate-personas-dir <path>` builds a NAT Eval run over the labeled `decisions.jsonl` corpus: each candidate persona replays past panel calls; scoring is NAT-native (accuracy vs. user labels, latency, OVERTURN rate). Output: persona-ranked report. Eval framework is NAT's `experimental.test_time_compute.scoring.*` family (exact module pinned during Phase 7 brainstorm).

## Phase 3b plan replan

The Phase 3b plan committed at `c7ee8d6` (`2026-05-18-validate-recommendation-v3-phase3b-nat-dispatch.md`) is **superseded by v3.1**. The plan's Task 1 (install) is still valid; Tasks 2-6 are rewritten in a new plan file:

`docs/superpowers/plans/2026-05-18-validate-recommendation-v3.1-phase3b-nat-builder-dispatch.md`

The superseded plan gets a header line linking to v3.1 and the new plan; it is not deleted (history is preserved).

The new plan's Task 2 is the **NAT Builder spike**: discover the exact 10-LOC Builder/register_llm_provider/invoke idiom for `NIMModelConfig`, document in `.nat-discovery-notes.md`. The verified idiom replaces the placeholder method names in the `_invoke_nat` snippet above before Task 3 starts.

## Relation to v3

| v3 element | v3.1 disposition |
|---|---|
| Locked decisions #1-#8, #10-#14 | Unchanged. |
| Locked decision #9 | Reversed: NAT IS a platform with primitives; the "no primitives" restriction is gone. |
| System overview diagram | Unchanged — the per-panelist seam keeps the diagram literally accurate. |
| Component responsibilities table | Unchanged. (Components mentioning "NAT integration" or "NAT-* dispatch" now mean "via Builder + register_llm_provider".) |
| Configuration (YAML schema) | Unchanged. Backend names (`nat-nim`, `nat-anthropic`, `nat-openai`, `claude-subagent`) remain stable. |
| Persona file format | Unchanged. |
| `_invoke_nat` snippet | Replaced (see above). |
| Aggregator interface + directive JSON shape | Unchanged. |
| Severity decision tree | Unchanged. |
| HARD-DISSENT re-brainstorm + qhash + state schema | Unchanged. |
| Telemetry event shapes (`decision`, `user_pick`, `label`) | Unchanged on the wire. The PRODUCER of these events shifts from custom Python to NAT observability in Phase 6. |
| `panel` CLI subcommand table | Unchanged. The `panel tune` row's "deferred to v1.x" note becomes "Phase 7 — NAT Eval-backed". |
| Testing strategy + mock discipline | Unchanged. Mock at `_invoke_nat`; never mock `requests`/`httpx`/`nat.*` directly. |
| Error handling matrix | Unchanged. |
| Security posture | Unchanged. NAT 1.6's supply-chain footprint (Apache-2.0 from PyPI) is acknowledged in v3 already. |
| Migration plan | Updated rows (3b, 3c, 6, 7) per the table in this amendment. Phase 5 row unchanged. |

## Self-review

**Coverage:** The amendment addresses the failure mode that triggered it (v3's `_invoke_nat` doesn't compile against NAT 1.6). It also pre-stages NAT-native patterns for phases 3c/6/7 without specifying them prematurely — each phase keeps its own brainstorm.

**Risk:** The placeholder method names in the new `_invoke_nat` snippet (`add_llm`, `get_llm`) are unverified. If Phase 3b Task 2's spike finds a different idiom (e.g., NAT uses `Builder().llm("id").invoke(...)` or requires async), the amendment's snippet is replaced verbatim from the spike. The plan's TDD cycle catches this at test-run time.

**Scope discipline:** v3.1 does NOT change the panel-to-user UX, the orchestration topology, the data contracts (JSONL events, directive JSON), or any CLI surface. The only externally-visible change is "Phase 7 ships earlier than v3 indicated" — and even that is a guidance, not a commitment, since the Phase 7 brainstorm happens later.

**Out-of-scope decisions deferred to later phases:**
- Whether `panel/aggregate.py` becomes a NAT Function (Phase 3c)
- Exact NAT observability module + OTel collector format (Phase 6)
- NAT Eval scoring metrics + ranking algorithm (Phase 7)
- Whether NAT's Workflow primitive eventually subsumes any SKILL.md logic (currently no; revisit after Phase 7)
