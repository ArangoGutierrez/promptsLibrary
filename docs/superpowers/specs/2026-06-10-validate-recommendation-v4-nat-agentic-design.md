# validate-recommendation v4 — NAT-agentic redesign + SP1 (tool library)

**Date:** 2026-06-10
**Status:** Draft — pending user review
**Builds on:** `2026-05-15-validate-recommendation-v3-nat-native-design.md` (canonical), `2026-05-18-validate-recommendation-v3.1-nat-heavy-amendment.md`, `2026-05-19-validate-recommendation-v3.1-phase3c-design.md`
**Supersedes:** v3.1's deferral of NAT primitives (Patterns A–D), *for the agentic use case only*.

This doc has two parts. **Part A** is the v4 program framing: why NAT primitives are adopted now, which locked decisions change, and the sub-project decomposition. **Part B** is the detailed design for **SP1 — the sandboxed tool library**, the first sub-project to be planned and implemented. SP2–SP6 are roadmapped in Part A and each gets its own spec at its own brainstorm.

---

# Part A — v4 program framing

## Why v4

v3 (decision #9) banned NAT Workflow/Function/Agent primitives, treating `nvidia-nat` as a thin LLM-provider abstraction. v3.1 reversed #9 in principle ("NAT is a platform"), but the 2026-05-18 Phase 3b spike then found NAT's `WorkflowBuilder` to be "wrong-tool-for-job **for making one HTTP call**" and fell back to langchain single-shot providers (`ChatNVIDIA` etc.), deferring real NAT use to Phase 6 (observability) and Phase 7 (eval). That conclusion was correct **for its use case** — a single, stateless LLM call does not justify the Builder/async/adapter ceremony.

**The use case has changed.** The v4 requirement is a panel of **independent, tool-using reviewers** that gather evidence (read files, grep the repo, verify references, consult the rules) across a multi-step loop before voting. That is precisely NAT's design center — agents + tools + workflows — not "one HTTP call." The friction that made NAT the wrong tool in v3.1 is the value NAT adds in v4.

**The blocker is gone.** The 2026-05-18 spike recorded NAT Builder dispatch as blocked (`registered providers: set()`). The **SP0 spike (2026-06-10)** proved otherwise: with the correct, surgical plugin-registration idiom, a NAT ReAct agent with a custom `@register_function` tool **builds end-to-end** (`WorkflowImpl`). See [Cross-cutting decision CC-1](#cc-1--nat-registration-idiom). The old `.nat-discovery-notes.md` "BLOCKED" verdict is wrong as of nvidia-nat 1.6.0 and is replaced by this doc + SP0's findings.

### User-set product decisions (2026-06-10)

| Axis | Decision |
|---|---|
| Execution substrate | **All panelists are NAT agents with tools** (ReAct, NVIDIA models) — not Claude subagents, not single-shot. |
| Safety layer ("Nemo-relay") | **NeMo Guardrails** wrapping panelist I/O (input jailbreak/injection, tool-return content, output format+safety). |
| Default panel | **N=3, always** (DA + PE + QA, all tool-using, every Recommend event). |
| Implementation strategy | **A3 — full NAT workflow orchestrator + OpenTelemetry observability + NAT Eval tuning loop.** |
| Python environment | **Dedicated venv** at `~/.claude/panel/.venv` (clean, pinnable; no `--break-system-packages`). |
| QA exec capability (SP1) | **Static-only** — `tests_exist` + assertion-pattern grep; no code execution in SP1. |
| Reference checking (SP1) | **http(s) HEAD + OCI registry v2 manifest HEAD**, SSRF-guarded. |

## Locked-decision deltas vs. v3/v3.1

**Revised:**

- **#5 Default panel size: N=1 → N=3.** DA+PE+QA all `enabled: true` by default. Invariant #4 (odd enabled-N) is preserved — 3 is odd.
- **#9 NAT substrate: LLM-provider-only → full primitive adoption.** v3.1 reversed the prohibition in principle; v4 *exercises* it: tools are NAT Functions (`@register_function`), panelists are NAT ReAct agents, the panel is a NAT workflow. Justified by the use-case change above, not a reversal of v3.1's reasoning (which remains correct for single-shot).
- **#12 Orchestration model.** The **outer** loop is unchanged and stays Claude-driven (hook → `SKILL.md` → act on directive via `AskUserQuestion`) — `AskUserQuestion`/`Agent` are Claude-only and `SKILL.md` is the turn loop; NAT cannot replace them. The **inner** orchestration changes: `SKILL.md`'s parallel fan-out of N dispatch processes becomes a single `panel run` invocation that runs a NAT workflow orchestrating the 3 persona agents internally. This realizes v3.1's stated "inner orchestration is NAT-native" intent (detailed in SP2/SP4, not here).

**Preserved (unchanged):** #1 panel-to-user contract (`HOLD`/`SOFT-DISSENT`/`HARD-DISSENT`/`ERROR`); #2 severity source (majority OVERTURN + rationale-strength gate); #3 heterogeneous roles + extensible backends; #4 odd enabled-N; #6 re-brainstorm cap (≤2); #7 always-on JSONL telemetry + optional OTel; #8 Python 3.12; #10 YAML config at `~/.claude/panel/config.yml`; #11 `max_tokens=32768` default; #13 state under `~/.claude/panel/`; #14 reuse `verdict.py`/`sanitize.py`/`trace.py`/`cli.py` + the `severity.py` decision tree. **The JSON directive shape, the severity tree, and the 115-test core are untouched by v4.**

## Sub-project decomposition (the roadmap)

A3 is a program, decomposed into six sequential sub-projects; each gets its own spec → plan → TDD implementation.

| SP | Deliverable | Depends on |
|----|-------------|------------|
| **SP0** | NAT plumbing spike — registration idiom, `get_llm` proof, ReAct-agent build proof, dep-gap enumeration. **DONE 2026-06-10.** | — |
| **SP1** | **Sandboxed tool library** (`panel/tools/`). Detailed in Part B. | SP0 |
| **SP2** | ReAct persona agents (DA/PE/QA) + NAT workflow orchestrator; persona rewrite for tool use; `VERDICT/RATIONALE/ALTERNATIVE` contract preserved. | SP0, SP1 |
| **SP3** | NeMo Guardrails layer (`panel/guardrails/`): input, tool-return, and output rails; graceful fallback to `sanitize.py`. | SP0, SP2 |
| **SP4** | Dispatch/skill/config rewiring: new `nat-react` backend, `config.yml` enables N=3, `SKILL.md` calls `panel run`, `aggregate`/`severity` reused. **First end-to-end value.** Lands behind a default-off flag; flipped on only after SP3. | SP1–SP3 |
| **SP5** | NAT OpenTelemetry observability — spans for orchestrator + each agent + each tool call + guardrails; honors `telemetry.otel_endpoint`. | SP2, SP4 |
| **SP6** | NAT Eval tuning loop — evaluator scoring panel verdicts vs. user-picks on the existing `decisions.jsonl`; `panel tune` CLI. | SP4, SP5 |

**MVP boundary:** SP0→SP4 = a tool-using NAT-agent panel live with guardrails. SP5–SP6 = observability + self-tuning.

## Cross-cutting decisions

### CC-1 — NAT registration idiom

`nat` is a PEP-420 namespace package (split across `nvidia-nat`, `-core`, `-langchain`, `-atif`); `nat.__file__` is `None`. The umbrella `nat.plugins.langchain.register` import fails (it pulls the uninstalled `nat.plugins.eval`). The working idiom imports four submodules surgically before constructing a `WorkflowBuilder`:

```python
import nat.llm.register                                  # NIM/OpenAI LLM providers
import nat.plugins.langchain.llm                          # provider -> langchain conversion (ChatNVIDIA)
import nat.plugins.langchain.tool_wrapper                 # @register_tool_wrapper(LANGCHAIN)
import nat.plugins.langchain.agent.react_agent.register   # react_agent workflow fn
```

Verified by SP0: `get_llm(..., wrapper_type=LLMFrameworkEnum.LANGCHAIN)` resolves to `ChatNVIDIA` (`bind_tools=True`); a custom tool + `ReActAgentWorkflowConfig` builds into a `WorkflowImpl`. `ReActAgentWorkflowConfig` exposes `use_native_tool_calling` (default-on; set `False` for model-agnostic text-ReAct), `tool_names`, `max_tool_calls` (default 15), `system_prompt`, and parse-retry knobs.

### CC-2 — Python environment

Dedicated venv at `~/.claude/panel/.venv` (created from `/opt/homebrew/bin/python3.12`). A `scripts/panel-venv-bootstrap.sh` provisions it and smoke-tests the CC-1 idiom green before any tool code is written (SP1 plan task 1). **Minimal dep closure** (YAGNI): `nvidia-nat-core`, `nvidia-nat-langchain`'s *runtime* imports only — explicitly **excluding** `langchain-huggingface` (pulls torch), `-milvus`, `-tavily`, `-litellm` — plus `langchain-classic` (ReAct output parser), `langchain-nvidia-ai-endpoints`, `httpx`, `pyyaml`, `pytest`. `nemoguardrails` (SP3), `nvidia-nat-opentelemetry` (SP5), `nvidia-nat-eval` + `openevals` (SP6) are added by their sub-projects. `SKILL.md`/dispatch switch from `/opt/homebrew/bin/python3.12` to `~/.claude/panel/.venv/bin/python` (SP4). Final versions pinned via `pip freeze` into the bootstrap script.

### CC-3 — Security model for tools (applies to all current and future tools)

Tools are a new attack surface: an LLM (steerable by untrusted question text / file content) decides their arguments. The model below is **non-negotiable** (Security > Correctness):

- **Read-only.** No tool mutates the filesystem, spawns shells, or executes code in SP1.
- **Path-confined.** File access is restricted to a configured set of *allowed roots*; default `[<repo cwd at Recommend time>, ~/.claude/rules, ~/.claude/CLAUDE.md]`.
- **Secret deny-list** (denied even inside allowed roots): `**/.env*`, `**/*secret*`, `**/*credential*`, `**/*token*`, `**/*.pem`, `**/*.key`, `**/*id_rsa*`, `**/.ssh/*`, `**/.aws/*`, `**/.kube/config`, `**/*password*`. Mirrors the harness deny-list.
- **Traversal/symlink defense.** Every path is resolved to its realpath and rejected unless it remains within an allowed root — defeating `../` escapes and symlinks pointing outside.
- **Bounded output.** `read_file` ≤ 256 KB, text-only (reject NUL/binary); grep/glob cap match count; all tools time-bound. An agent cannot exhaust context or hang the loop.
- **SSRF guard** (network tools): scheme allow-list (`http`/`https`/`oci`); deny loopback, link-local (169.254/fe80::), private (10/172.16/192.168/fc00::), and `.local`; `HEAD` only; do not follow redirects to a denied host; short timeout.
- **Failure as data.** Tools return a structured **error string** (e.g. `ERROR: path outside allowed roots`); they never raise into the agent loop (an exception would derail ReAct).

---

# Part B — SP1 detailed design: sandboxed tool library

## Goal

A library of NAT `@register_function` tools the persona agents (SP2) call to gather evidence, behind a single audited security boundary (CC-3). Independently buildable and testable without any LLM. Static-only (no execution).

## Scope

**In scope:** the six tools below; the shared `_sandbox` boundary; their NAT registration; the venv bootstrap (plan task 1); the test suite.

**Out of scope (later SPs):** which persona gets which tool subset (SP2); the agents/workflow that call them (SP2); guardrails wrapping (SP3); wiring into `SKILL.md`/config (SP4); `run_pytest`/any exec tool (deferred hardening pass).

## Module layout

Mirrors the existing pure-core / thin-framework-glue split (cf. `severity.py` pure vs. `cli.py` glue):

```
panel/tools/
  __init__.py
  _sandbox.py      # SECURITY CHOKEPOINT (CC-3). Pure, no NAT. The single audited boundary.
  files.py         # pure impls: read_file, grep_repo, glob_files, read_rules  (Sandbox -> str)
  refs.py          # pure impl: check_reference_exists (HTTP HEAD + OCI manifest HEAD). httpx = 1 mock seam.
  tests_static.py  # pure impl: tests_exist (assertion/test-pattern grep; NO execution)
  register.py      # ONLY NAT-coupled file: FunctionBaseConfig subclasses + @register_function async-gens
  tests/
    conftest.py
    test_sandbox.py        # traversal, symlink, deny-list, root-confinement, caps
    test_files.py          # read/grep/glob/read_rules behavior + error strings
    test_refs.py           # HTTP + OCI happy/NOT_FOUND/SSRF-denied (httpx mocked)
    test_tests_static.py   # tests_exist finds / does-not-falsely-report assertion patterns
    test_register.py       # each tool registers + builds into a ReAct agent (CC-1 idiom)
```

## `_sandbox.py` — the security boundary

```python
@dataclass(frozen=True)
class Sandbox:
    roots: tuple[Path, ...]            # absolute, realpath-resolved allowed roots
    max_bytes: int = 262_144           # 256 KB read cap
    max_matches: int = 200             # grep/glob result cap

    def resolve(self, path: str) -> Path | None:     # realpath; None if outside roots or denied
    def is_denied(self, p: Path) -> bool:            # secret deny-glob match
    def read_text(self, path: str) -> str | _Err:    # confined + capped + binary-reject
    def iter_files(self, glob: str) -> list[Path] | _Err
```

- `resolve()`: `Path(path)` → if relative, resolve against each root → `os.path.realpath` → accept iff the resolved path is `== root or has root as parent` for some root, AND `not is_denied`. Reject (`None`) otherwise.
- Deny-list compiled once from the CC-3 globs via `fnmatch`/`PurePath.match` against the path's full string and each component.
- `read_text()`: stat-size check before read (reject > `max_bytes`); read bytes; reject if a NUL byte is present (binary); decode utf-8 with `errors="replace"`.
- Roots are realpath-resolved at construction so symlinked roots are normalized once.

`_Err` is a tiny wrapper carrying a stable, greppable message; impls convert it to the tool's `ERROR: …` return string.

## Tool contracts

Each tool's `description` (what the agent sees) is written imperatively with an explicit `Args:` block, like NAT's `wiki_search` example. Returns are plain strings.

| Tool | Args | Returns | Notes |
|---|---|---|---|
| `read_file` | `path: str` | file text (≤256 KB) or `ERROR: …` | confined + capped + binary-reject |
| `grep_repo` | `pattern: str, path_glob: str = "**/*"` | up to 200 `relpath:lineno:line` hits, or `ERROR: …` | regex on text files within roots; per-call timeout |
| `glob_files` | `pattern: str` | up to 200 matching relpaths, or `ERROR: …` | within roots |
| `read_rules` | *(none)* | concatenated `~/.claude/CLAUDE.md` + `~/.claude/rules/*.md`, section-headed | PE convenience; capped per file |
| `check_reference_exists` | `ref: str` | `EXISTS` / `NOT_FOUND (status=<n>)` / `ERROR: <reason>` | http(s) HEAD or OCI registry v2 manifest HEAD; SSRF-guarded |
| `tests_exist` | `subject: str` | summary: test files referencing `subject` + count of assertion-pattern lines, or `none found` | static grep only; **no execution** |

### `check_reference_exists` detail

- Parse `ref`. If scheme ∈ {`http`,`https`}: `httpx.head(ref, follow_redirects=False, timeout=5)` after the SSRF host check; map 2xx/3xx→`EXISTS`, 404/410→`NOT_FOUND`, else `ERROR`.
- If `oci://<registry>/<repo>:<tag>` or a bare `<registry>/<repo>@sha256:…`: HEAD `https://<registry>/v2/<repo>/manifests/<ref>` with `Accept: application/vnd.oci.image.index.v1+json, …manifest.v1+json`. On `401` with a `Www-Authenticate: Bearer realm=…` pointing at a **public** host, fetch an anonymous token and retry once. 2xx→`EXISTS`, 404→`NOT_FOUND`.
- SSRF host check runs before *every* outbound request (including the token fetch and any redirect target).
- `httpx` is the **single** mock seam for `refs.py` tests.

## NAT registration (`register.py`)

Each tool = a `FunctionBaseConfig` subclass (with `name=`, and any config fields such as `roots`) + an `@register_function(config_type=…, framework_wrappers=[LLMFrameworkEnum.LANGCHAIN])` async generator that builds a `Sandbox` from config and `yield`s `FunctionInfo.from_fn(impl, description=…)`. The CC-1 import idiom lives at the top of this module. Per-persona tool *subsets* are assigned in SP2.

## Provisioning (SP1 plan task 1, TDD-first)

`scripts/panel-venv-bootstrap.sh`: create `~/.claude/panel/.venv`; `pip install` the CC-2 minimal set; run a smoke script asserting the CC-1 idiom builds a ReAct agent (`WorkflowImpl`). This task is **Red→Green before any tool code**: the smoke script is the first failing check; green unblocks tool work.

## Test surface (constitution-compliant)

Tests target the **pure impls** against a **real filesystem** in `tmp_path` — no fs mocking. The only mock seam is `httpx` in `refs.py` (one layer deep). Each test names the bug it catches:

- `test_sandbox`: `resolve("../../etc/passwd")` → `None` (fails if traversal guard removed); a symlink inside a root pointing outside → rejected (fails if realpath check removed); `.env`/`*.key` within a root → denied (fails if deny-list removed); a 300 KB file → cap error (fails if `max_bytes` removed); valid in-root file → returned.
- `test_files`: grep finds a known literal and respects the 200-cap; glob matches; `read_file` on a binary fixture → `ERROR`; missing file → `ERROR: …` (not an exception).
- `test_refs`: mocked 200→`EXISTS`, 404→`NOT_FOUND`; `http://127.0.0.1`/`http://169.254.169.254`/`file://…` → `ERROR: blocked host/scheme` (fails if SSRF guard removed); OCI manifest 200→`EXISTS`.
- `test_tests_static`: a fixture with `def test_x(): assert foo(...)` referencing `subject` → reported with assertion count; unrelated subject → `none found` (fails if it returns happy-path noise).
- `test_register`: each registered tool builds into a ReAct agent via the CC-1 idiom (fails if a registration/description is malformed). No live LLM call.

Mock discipline: never mock the filesystem, `nat.*`, or `langchain.*`; mock only `httpx` in `refs`. Real impls everywhere else.

## Relation to v3 / v3.1

- Reuses v3 decision #14 module set unchanged; adds `panel/tools/` as a **new** package — no edits to `severity.py`, `aggregate.py`, `verdict.py`, `sanitize.py`, `trace.py` in SP1.
- The persona files, `config.yml` schema, directive JSON, and `SKILL.md` are **untouched in SP1** (SP2/SP4 touch them).
- Honors v3 security posture (env-var-only keys, `~/.claude/panel/` 0700/0600) and extends it with CC-3 for the new tool surface.

## Self-review

- **Placeholders:** none. Every tool, its args/returns, the sandbox API, and the test-to-bug mapping are concrete.
- **Consistency:** SP1 changes no existing module; the N=3 / orchestration / backend changes are explicitly deferred to SP2–SP4, so SP1 cannot break the 115-test core. The static-only and http(s)+OCI decisions match the user's 2026-06-10 answers.
- **Scope:** SP1 is a single, isolated package with no LLM dependency at test time — appropriately sized for one plan.
- **Ambiguity:** "allowed roots" is pinned to a concrete default and is config-injected; "reference" handles both URL and OCI forms explicitly; "tests_exist" is explicitly grep-only to remove any execution ambiguity.
- **Residual risk:** the OCI anonymous-token path is the most complex branch; its SSRF re-check and single-retry bound are specified, and it is fully covered by a mocked test. `read_rules` reading `~/.claude/CLAUDE.md` crosses outside the repo root by design — it is an explicit allowed root, not a traversal.
