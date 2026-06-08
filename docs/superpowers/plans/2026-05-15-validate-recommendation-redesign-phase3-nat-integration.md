# validate-recommendation v2.1 — Phase 3: NAT integration + opt-in panelists

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Supersedes:** `2026-05-14-validate-recommendation-redesign-phase3-config-multi-panelist.md` (v2.0).

**Goal:** Replace v2.0's `dispatch-http.sh` shell dispatcher with a NAT-based Python dispatcher. Replace `config.json` with `config.yml` (NAT-compatible). Make panelists **opt-in** (default config enables only DA via NAT-NIM; user opts in PE/QA/others). Split monolithic `personas.md` into per-role files. Aggregator continues to handle N panelists regardless of backend.

**Architecture:** SKILL.md reads YAML config, separates enabled panelists by backend (`nat-*` vs `claude-subagent`), dispatches all in parallel:
- `nat-*` backends → one `Bash python3.12 -m panel dispatch --panelist <id> --output <file>` call per panelist. `panel/dispatch.py` imports NAT as a library (in-process; no `nat run` subprocess hop) and calls the appropriate NAT LLM provider.
- `claude-subagent` backends → one `Agent` tool call per panelist, response captured by skill, written to verdict file.

After all verdicts emitted, `python3.12 -m panel aggregate --verdicts ... --recommended-label ...` runs (the Python aggregator from Phase 2 with no changes).

**Tech Stack:** Python 3.12, `nvidia-nat[langchain]` (installed via pipx), YAML via stdlib `tomllib`/`yaml` (use PyYAML — small dep, well-known). Existing `panel/` Python module from Phase 2 stays intact.

**Pre-flight:**
- Phase 1 and Phase 2 shipped (current Python panel module + 21 tests pass; aggregate.sh shim works).
- `python3.12 --version` ≥ 3.12.
- Network access to `pypi.org` (for nvidia-nat install).
- `$NVIDIA_API_KEY` or equivalent env var set for NIM access. (Reuse `$PANEL_DA_API_KEY` if NAT NIM provider accepts it.)

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/skills/validate-recommendation/personas/da.md` | **Create** (extracted from `personas.md` DA section). |
| `~/.claude/skills/validate-recommendation/personas/pe.md` | **Create** (PE section). |
| `~/.claude/skills/validate-recommendation/personas/qa.md` | **Create** (new role, per v2.0 Phase 3). |
| `~/.claude/skills/validate-recommendation/personas.md` | **Delete** after split is verified. |
| `~/.claude/panel/config.yml` | **Create** — default config (DA enabled, PE/QA opt-in). |
| `~/.claude/skills/validate-recommendation/panel/config.py` | **Create** — YAML loader + odd-N enabled-count validation + backend whitelist. |
| `~/.claude/skills/validate-recommendation/panel/personas.py` | **Create** — per-role persona loader (Phase 2 design). |
| `~/.claude/skills/validate-recommendation/panel/dispatch.py` | **Create** — NAT-based dispatcher for `nat-*` backends. |
| `~/.claude/skills/validate-recommendation/panel/cli.py` | **Modify** — add `lint-config`, `dispatch` subcommands; `aggregate` accepts `--verdicts <path>...` and `--question-id`. |
| `~/.claude/skills/validate-recommendation/panel/aggregate.py` | **Modify** — generalize to N verdicts via new `aggregate_n` function. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_config.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_personas.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_dispatch.py` | **Create** (NAT mocked via monkeypatch). |
| `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py` | **Modify** — add N-panelist tests. |
| `~/.claude/skills/validate-recommendation/dispatch-da.sh` | **Delete** — superseded by `panel/dispatch.py`. |
| `~/.claude/skills/validate-recommendation/dispatch-da_test.sh` | **Delete** — superseded by `test_dispatch.py`. |
| `~/.claude/skills/validate-recommendation/aggregate.sh` | **Delete** — SKILL.md now calls Python directly. |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify** — config-driven orchestration with NAT + Agent inline dispatch. |

---

## Tasks

### Task 1: Pre-flight — install `nvidia-nat[langchain]` for Python 3.12

**Files:** none modified. Environment setup.

- [ ] **Step 1: Install via pipx (recommended) or pip --break-system-packages**

```bash
pipx install --python /opt/homebrew/bin/python3.12 nvidia-nat[langchain]
```

If pipx route fails (e.g., extras not supported), fall back to:

```bash
/opt/homebrew/bin/python3.12 -m pip install --user --break-system-packages "nvidia-nat[langchain]"
```

- [ ] **Step 2: Verify import works**

```bash
python3.12 -c "import nat; print('nat version:', getattr(nat, '__version__', 'unknown'))"
```

Expected: prints a version string, exit 0. If `ImportError`, the install failed — re-check pipx output.

- [ ] **Step 3: Verify NIM provider is importable**

```bash
python3.12 -c "from nat.llm.nim_llm import NIMLLM; print('NIM provider available')"
```

If the import path differs (NAT may have renamed modules between versions), grep the installed package for the actual NIM class location:

```bash
pipx run --spec nvidia-nat python3 -c "import nat; import pkgutil; [print(m.name) for m in pkgutil.walk_packages(nat.__path__, prefix='nat.')]" | grep -i nim
```

Record the actual import path; use it in `panel/dispatch.py` later.

- [ ] **Step 4: Document the install in a top-level note**

Append a `## Dependencies` section to `~/.claude/skills/validate-recommendation/SKILL.md`:

```markdown
## Dependencies

- Python 3.12+ (`/opt/homebrew/bin/python3.12`)
- `nvidia-nat[langchain]` installed via pipx (or equivalent). See [Phase 3 plan](../../../../docs/superpowers/plans/2026-05-15-validate-recommendation-redesign-phase3-nat-integration.md) for install commands.
- pytest (already installed via pipx) for running the test suite.
```

---

### Task 2: Failing tests for `panel.config` (YAML loader)

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_config.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.config — YAML config loader with opt-in panelists and odd-N invariant."""
import textwrap


def _write_yaml(tmp_path, content):
    p = tmp_path / "config.yml"
    p.write_text(textwrap.dedent(content).strip() + "\n")
    return p


def test_load_default_config_only_da_enabled(tmp_path):
    from panel.config import load_config
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da-nemotron
            role: DA
            enabled: true
            backend: nat-nim
            model: nvidia/nemotron-3-super-v3
          - id: pe
            role: PE
            enabled: false
            backend: claude-subagent
            subagent_type: principal-engineer
          - id: qa
            role: QA
            enabled: false
            backend: claude-subagent
            subagent_type: qa-engineer
    """)
    c = load_config(cfg)
    enabled = [p for p in c.panelists if p.enabled]
    assert len(enabled) == 1
    assert enabled[0].id == "da-nemotron"
    assert enabled[0].backend == "nat-nim"


def test_reject_even_enabled_count(tmp_path):
    """Enabled-count must be odd (vote-tie invariant)."""
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: x
          - id: pe
            role: PE
            enabled: true
            backend: claude-subagent
            subagent_type: principal-engineer
    """)
    try:
        load_config(cfg)
        assert False, "expected ConfigError for 2 enabled panelists (even N)"
    except ConfigError as e:
        assert "odd" in str(e).lower()


def test_accept_three_enabled(tmp_path):
    from panel.config import load_config
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: x
          - id: pe
            role: PE
            enabled: true
            backend: claude-subagent
            subagent_type: principal-engineer
          - id: qa
            role: QA
            enabled: true
            backend: claude-subagent
            subagent_type: qa-engineer
    """)
    c = load_config(cfg)
    enabled = [p for p in c.panelists if p.enabled]
    assert len(enabled) == 3


def test_reject_zero_enabled(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: false
            backend: nat-nim
            model: x
    """)
    try:
        load_config(cfg)
        assert False, "expected ConfigError for zero enabled panelists"
    except ConfigError:
        pass


def test_reject_unknown_backend(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: x
            role: DA
            enabled: true
            backend: definitely-not-a-real-backend
    """)
    try:
        load_config(cfg)
        assert False, "expected ConfigError for unknown backend"
    except ConfigError:
        pass


def test_defaults_for_optional_sections(tmp_path):
    from panel.config import load_config
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: x
    """)
    c = load_config(cfg)
    assert c.severity.hard_threshold == "majority"
    assert c.failure_mode.on_panelist_error == "auto"
    assert c.re_brainstorm.max_cycles == 2
```

- [ ] **Step 2: Run — should FAIL** with ModuleNotFoundError.

---

### Task 3: Implement `panel/config.py` (YAML loader)

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/config.py`

- [ ] **Step 1: Write `config.py`**

```python
"""Load and validate ~/.claude/panel/config.yml.

YAML-based config (NAT-compatible). Enforces the odd-N invariant on the
COUNT OF ENABLED PANELISTS (not total). Whitelists backend strings so
typos surface at load time, not dispatch time.
"""
from __future__ import annotations
import yaml
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

VALID_BACKENDS = {"nat-nim", "nat-anthropic", "nat-openai", "claude-subagent"}
VALID_HARD_THRESHOLDS = {"majority", "supermajority"}
VALID_FAILURE_MODES = {"strict", "graceful", "auto"}


class ConfigError(Exception):
    pass


@dataclass
class Panelist:
    id: str
    role: str
    enabled: bool
    backend: str
    model: str = ""           # for nat-* backends
    subagent_type: str = ""   # for claude-subagent backend
    max_tokens: int = 32768
    temperature: float = 0.3
    timeout_seconds: int = 60


@dataclass
class RationaleGate:
    requires_principle_or_alternative: bool = True
    principle_patterns: list[str] = field(default_factory=lambda: [
        r"\b(YAGNI|atomicity|TDD|priority order|conventions?)\b",
        r"\bviolates? (the )?(principle|convention|rule)\b",
        r"\bbreaks?\b.*\b(rule|convention|invariant)\b",
    ])


@dataclass
class Severity:
    hard_threshold: Literal["majority", "supermajority"] = "majority"
    rationale_gate: RationaleGate = field(default_factory=RationaleGate)


@dataclass
class FailureMode:
    on_panelist_error: Literal["strict", "graceful", "auto"] = "auto"


@dataclass
class ReBrainstorm:
    enabled: bool = True
    max_cycles: int = 2


@dataclass
class Telemetry:
    jsonl: str = "~/.claude/panel/decisions.jsonl"
    otel_endpoint: str | None = None


@dataclass
class Config:
    version: str
    panelists: list[Panelist]
    severity: Severity = field(default_factory=Severity)
    failure_mode: FailureMode = field(default_factory=FailureMode)
    re_brainstorm: ReBrainstorm = field(default_factory=ReBrainstorm)
    telemetry: Telemetry = field(default_factory=Telemetry)


def load_config(path: str | Path) -> Config:
    path = Path(path).expanduser()
    if not path.is_file():
        raise ConfigError(f"config file missing: {path}")
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        raise ConfigError(f"config YAML parse error: {e}") from e

    panelists_raw = raw.get("panelists") or []
    if not panelists_raw:
        raise ConfigError("config: panelists must be non-empty")

    panelists: list[Panelist] = []
    for i, p in enumerate(panelists_raw):
        if not p.get("id"):
            raise ConfigError(f"config: panelists[{i}] missing 'id'")
        backend = p.get("backend")
        if backend not in VALID_BACKENDS:
            raise ConfigError(
                f"config: panelists[{i}].backend must be one of {sorted(VALID_BACKENDS)}, got '{backend}'"
            )
        panelists.append(Panelist(
            id=p["id"],
            role=p.get("role", ""),
            enabled=bool(p.get("enabled", False)),
            backend=backend,
            model=p.get("model", ""),
            subagent_type=p.get("subagent_type", ""),
            max_tokens=int(p.get("max_tokens", 32768)),
            temperature=float(p.get("temperature", 0.3)),
            timeout_seconds=int(p.get("timeout_seconds", 60)),
        ))

    enabled_count = sum(1 for p in panelists if p.enabled)
    if enabled_count == 0:
        raise ConfigError("config: at least one panelist must be enabled")
    if enabled_count % 2 == 0:
        raise ConfigError(
            f"config: enabled-panelist count must be odd (got {enabled_count}). "
            "Even N produces tie-prone votes; the odd-N invariant is required."
        )

    severity_raw = raw.get("severity", {})
    rg_raw = severity_raw.get("rationale_gate", {})
    severity = Severity(
        hard_threshold=severity_raw.get("hard_threshold", "majority"),
        rationale_gate=RationaleGate(
            requires_principle_or_alternative=rg_raw.get("requires_principle_or_alternative", True),
            principle_patterns=rg_raw.get("principle_patterns", RationaleGate().principle_patterns),
        ),
    )
    if severity.hard_threshold not in VALID_HARD_THRESHOLDS:
        raise ConfigError(f"severity.hard_threshold must be one of {sorted(VALID_HARD_THRESHOLDS)}")

    fm_raw = raw.get("failure_mode", {})
    failure_mode = FailureMode(on_panelist_error=fm_raw.get("on_panelist_error", "auto"))
    if failure_mode.on_panelist_error not in VALID_FAILURE_MODES:
        raise ConfigError(f"failure_mode.on_panelist_error must be one of {sorted(VALID_FAILURE_MODES)}")

    rb_raw = raw.get("re_brainstorm", {})
    re_brainstorm = ReBrainstorm(
        enabled=rb_raw.get("enabled", True),
        max_cycles=int(rb_raw.get("max_cycles", 2)),
    )
    if not (0 <= re_brainstorm.max_cycles <= 5):
        raise ConfigError("re_brainstorm.max_cycles must be in [0, 5]")

    tel_raw = raw.get("telemetry", {})
    telemetry = Telemetry(
        jsonl=tel_raw.get("jsonl", "~/.claude/panel/decisions.jsonl"),
        otel_endpoint=tel_raw.get("otel_endpoint"),
    )

    return Config(
        version=raw.get("version", "1"),
        panelists=panelists,
        severity=severity,
        failure_mode=failure_mode,
        re_brainstorm=re_brainstorm,
        telemetry=telemetry,
    )
```

- [ ] **Step 2: Install PyYAML** (if not present)

```bash
pipx inject pytest pyyaml 2>/dev/null || /opt/homebrew/bin/python3.12 -m pip install --break-system-packages pyyaml
```

(PyYAML is a runtime dep — installing into pipx's pytest venv lets test execution import it. For SKILL invocations, ensure PyYAML is available where `python3.12 -m panel` runs. If `nvidia-nat[langchain]` install in Task 1 already brought PyYAML transitively, this step is a no-op.)

- [ ] **Step 3: Run tests — should PASS**

```bash
cd ~/.claude/skills/validate-recommendation && pytest panel/tests/test_config.py -v
```

Expected: 6 tests pass.

---

### Task 4: Personas split — create `personas/da.md`, `personas/pe.md`, `personas/qa.md`

(Same content as v2.0 Phase 3 plan tasks 1–3.) See the v2.0 plan for the exact persona file contents; this task carries them over unchanged. Each persona file has YAML front-matter (`role`, `description`, `intended_backends`) plus `# System prompt`, `# One-shot example`, `# User prompt template` sections.

- [ ] **Step 1**: Create `personas/` dir; populate `da.md`, `pe.md`, `qa.md` per v2.0 Phase 3 Tasks 1–3. Persona content is identical to v2.0; backend metadata changes:
  - DA: `intended_backends: [nat-nim, nat-openai]`
  - PE: `intended_backends: [claude-subagent, nat-anthropic]`
  - QA: `intended_backends: [claude-subagent, nat-anthropic]`

- [ ] **Step 2**: Don't delete `personas.md` yet — Phase 2's `dispatch-da.sh` still reads it. It gets deleted in Task 11 after `dispatch-da.sh` is gone.

---

### Task 5: Failing tests for `panel.personas`

Per v2.0 Phase 3 Task 4. 5 tests; expect ModuleNotFoundError.

---

### Task 6: Implement `panel/personas.py`

Per v2.0 Phase 3 Task 5. Front-matter + section parser. Tests pass.

---

### Task 7: Failing tests for `panel.dispatch` (NAT integration)

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_dispatch.py`

The dispatch module integrates with NAT, which is a heavy external dependency. Tests mock NAT's NIM provider to avoid real API calls.

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.dispatch — NAT-based panelist dispatcher.

NAT is mocked via monkeypatch on the NIM provider class. The dispatch
module's responsibility is:
1. Read panelist config + persona file
2. Build the NAT request (system + user messages)
3. Call NAT's provider
4. Parse the response into a Verdict-formatted file

Tests verify the request shape and the output-file format. Real NAT
call paths are covered by the live verification step in Task 13.
"""
from pathlib import Path
from unittest.mock import MagicMock


def _mock_nat_response(content: str):
    """Build a stub object that mimics NAT's NIM provider response shape.

    The test doesn't depend on NAT's actual response object structure;
    panel/dispatch.py's `dispatch()` reads .content (or similar). We
    mock that exact attribute access. If NAT's API differs from this
    assumption, the dispatch implementation adapts and the test is
    updated to match.
    """
    resp = MagicMock()
    resp.content = content
    return resp


def test_dispatch_writes_verdict_file_for_hold(tmp_path, monkeypatch, fixtures_dir):
    """A HOLD response from the model produces a parseable verdict file."""
    from panel import dispatch as dispatch_module
    fake_invoke = MagicMock(return_value=_mock_nat_response(
        "VERDICT: HOLD\nRATIONALE: All considered; no stronger counter found.\nALTERNATIVE: n/a"
    ))
    # The dispatch implementation calls a single function `_invoke_nat(panelist, system, user)`.
    # Monkeypatch that function so we don't hit real NAT.
    monkeypatch.setattr(dispatch_module, "_invoke_nat", fake_invoke)

    persona = tmp_path / "da.md"
    persona.write_text(
        "---\nrole: DA\n---\n"
        "# System prompt\nYou are a devil's-advocate reviewer.\n"
        "# User prompt template\n<templated>\n"
    )
    prompt = tmp_path / "prompt.txt"
    prompt.write_text("Question: x?\nOptions: ...")
    out = tmp_path / "verdict.txt"

    from panel.config import Panelist
    p = Panelist(id="da", role="DA", enabled=True, backend="nat-nim",
                 model="nvidia/nemotron-3-super-v3")
    dispatch_module.dispatch(p, persona, prompt, out)

    text = out.read_text()
    assert "VERDICT: HOLD" in text
    assert "RATIONALE: All considered" in text
    assert "ALTERNATIVE: n/a" in text
    fake_invoke.assert_called_once()


def test_dispatch_rejects_overturn_with_no_alternative(tmp_path, monkeypatch):
    """Phase 1 bug #3 fix is preserved: OVERTURN + n/a ALTERNATIVE → ERROR verdict."""
    from panel import dispatch as dispatch_module
    fake_invoke = MagicMock(return_value=_mock_nat_response(
        "VERDICT: OVERTURN\nRATIONALE: bad rec\nALTERNATIVE: n/a"
    ))
    monkeypatch.setattr(dispatch_module, "_invoke_nat", fake_invoke)

    persona = tmp_path / "da.md"
    persona.write_text("---\nrole: DA\n---\n# System prompt\nx\n# User prompt template\n<y>\n")
    prompt = tmp_path / "prompt.txt"
    prompt.write_text("Q?")
    out = tmp_path / "verdict.txt"

    from panel.config import Panelist
    p = Panelist(id="da", role="DA", enabled=True, backend="nat-nim", model="x")
    dispatch_module.dispatch(p, persona, prompt, out)

    text = out.read_text()
    assert "VERDICT: ERROR" in text
    assert "alternative" in text.lower()


def test_dispatch_rejects_unparseable_content(tmp_path, monkeypatch):
    """If the model returns prose without a VERDICT: line → ERROR verdict."""
    from panel import dispatch as dispatch_module
    fake_invoke = MagicMock(return_value=_mock_nat_response(
        "I think the recommendation is fine but I have some concerns about..."
    ))
    monkeypatch.setattr(dispatch_module, "_invoke_nat", fake_invoke)

    persona = tmp_path / "da.md"
    persona.write_text("---\nrole: DA\n---\n# System prompt\nx\n# User prompt template\n<y>\n")
    prompt = tmp_path / "prompt.txt"
    prompt.write_text("Q?")
    out = tmp_path / "verdict.txt"

    from panel.config import Panelist
    p = Panelist(id="da", role="DA", enabled=True, backend="nat-nim", model="x")
    dispatch_module.dispatch(p, persona, prompt, out)

    text = out.read_text()
    assert "VERDICT: ERROR" in text


def test_dispatch_emits_error_on_nat_exception(tmp_path, monkeypatch):
    """NAT exceptions become ERROR verdicts; dispatcher does not crash."""
    from panel import dispatch as dispatch_module
    def boom(*a, **k):
        raise RuntimeError("simulated NAT failure")
    monkeypatch.setattr(dispatch_module, "_invoke_nat", boom)

    persona = tmp_path / "da.md"
    persona.write_text("---\nrole: DA\n---\n# System prompt\nx\n# User prompt template\n<y>\n")
    prompt = tmp_path / "prompt.txt"
    prompt.write_text("Q?")
    out = tmp_path / "verdict.txt"

    from panel.config import Panelist
    p = Panelist(id="da", role="DA", enabled=True, backend="nat-nim", model="x")
    dispatch_module.dispatch(p, persona, prompt, out)

    text = out.read_text()
    assert "VERDICT: ERROR" in text
    assert "simulated NAT failure" in text or "NAT" in text or "exception" in text.lower()
```

- [ ] **Step 2: Run — should FAIL** with ModuleNotFoundError.

---

### Task 8: Implement `panel/dispatch.py` (NAT integration)

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/dispatch.py`

- [ ] **Step 1: Write `dispatch.py`**

```python
"""NAT-based panelist dispatcher.

Imports NAT as a library and calls the configured LLM provider in-process.
Three v1 bug fixes preserved at this seam:
  - System prompt embedded in the request (read from persona file)
  - max_tokens raised to 32768 default (configurable per panelist)
  - OVERTURN + missing/n/a ALTERNATIVE → ERROR verdict

Failures (network errors, unparseable content, panel exceptions) become
ERROR verdicts — never crash. The user-visible question always survives.
"""
from __future__ import annotations
import re
from pathlib import Path

from panel.config import Panelist
from panel.personas import load_persona


def _read_persona_from_file(persona_path: Path) -> tuple[str, str]:
    """Return (system_prompt, user_template) read directly from a persona file.

    This is a simpler reader than panel.personas.load_persona — that function
    looks up by role name from the personas/ directory. Here we accept a
    direct file path because dispatch is called per-panelist with its own
    persona file.
    """
    text = persona_path.read_text(encoding="utf-8")
    # Strip front-matter
    if text.startswith("---"):
        _, _, after = text.partition("\n---\n")
        text = after
    # Sections separated by `# Heading` lines
    sections: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        if line.startswith("# "):
            current = line[2:].strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    system = "\n".join(sections.get("System prompt", [])).strip()
    one_shot = "\n".join(sections.get("One-shot example", [])).strip()
    user_template = "\n".join(sections.get("User prompt template", [])).strip()
    system_msg = system + ("\n\n" + one_shot if one_shot else "")
    return system_msg, user_template


def _invoke_nat(panelist: Panelist, system: str, user: str) -> object:
    """Call the appropriate NAT provider based on panelist.backend.

    Returns a response object that has a `.content` attribute holding the
    visible model output. NAT's exact provider class may live at
    `nat.llm.nim_llm.NIMLLM` or a similar path — adjust the import if
    NAT's module layout differs from this assumption. The test suite
    mocks this function, so the import only matters at runtime.
    """
    backend = panelist.backend
    if backend == "nat-nim":
        from nat.llm.nim_llm import NIMLLM  # type: ignore
        llm = NIMLLM(model=panelist.model, max_tokens=panelist.max_tokens,
                     temperature=panelist.temperature)
    elif backend == "nat-openai":
        from nat.llm.openai_llm import OpenAILLM  # type: ignore
        llm = OpenAILLM(model=panelist.model, max_tokens=panelist.max_tokens,
                        temperature=panelist.temperature)
    elif backend == "nat-anthropic":
        from nat.llm.anthropic_llm import AnthropicLLM  # type: ignore
        llm = AnthropicLLM(model=panelist.model, max_tokens=panelist.max_tokens,
                           temperature=panelist.temperature)
    else:
        raise ValueError(f"unsupported NAT backend: {backend}")

    return llm.invoke(messages=[
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ])


def _write_error_verdict(reason: str, output_path: Path) -> None:
    output_path.write_text(
        f"VERDICT: ERROR\nRATIONALE: {reason}\nALTERNATIVE: n/a\n",
        encoding="utf-8",
    )


def _parse_verdict_response(content: str) -> tuple[str, str, str] | None:
    """Extract VERDICT/RATIONALE/ALTERNATIVE from the model's content.

    Returns (verdict, rationale, alternative) on success; None if any
    required field is missing.
    """
    def first(field: str) -> str:
        m = re.search(rf"^{field}: (.+?)$", content, flags=re.MULTILINE)
        return m.group(1).strip() if m else ""
    v = first("VERDICT")
    r = first("RATIONALE")
    a = first("ALTERNATIVE")
    if not v or not r:
        return None
    return v, r, a


def dispatch(panelist: Panelist, persona_file: Path, user_prompt_file: Path, output_path: Path) -> None:
    """Run one panelist via NAT; write a verdict file to `output_path`.

    Output paths:
      - On success: VERDICT/RATIONALE/ALTERNATIVE format (per panelist spec)
      - On any failure: ERROR verdict with diagnostic reason

    File is always created. Function never raises (best-effort).
    """
    try:
        system, _user_template = _read_persona_from_file(persona_file)
        user = user_prompt_file.read_text(encoding="utf-8")
        response = _invoke_nat(panelist, system, user)
        content = getattr(response, "content", "") or ""
        parsed = _parse_verdict_response(content)
        if not parsed:
            _write_error_verdict(
                "response content missing VERDICT or RATIONALE line",
                output_path,
            )
            return
        verdict, rationale, alternative = parsed
        if verdict == "OVERTURN" and (not alternative or alternative == "n/a"):
            _write_error_verdict(
                "OVERTURN with missing/n/a ALTERNATIVE is a contradictory verdict",
                output_path,
            )
            return
        output_path.write_text(
            f"VERDICT: {verdict}\nRATIONALE: {rationale}\nALTERNATIVE: {alternative or 'n/a'}\n",
            encoding="utf-8",
        )
    except Exception as e:
        # Defensive: any exception becomes an ERROR verdict.
        _write_error_verdict(f"NAT dispatch raised: {type(e).__name__}: {e}"[:200], output_path)
```

- [ ] **Step 2: Run tests — should PASS**

`pytest panel/tests/test_dispatch.py -v` → 4 tests pass.

---

### Task 9: Add `dispatch` and `lint-config` subcommands to CLI

**Files:** Modify `panel/cli.py`.

- [ ] **Step 1: Add subparsers and dispatch branches**

```python
    disp = sub.add_parser("dispatch", help="Run one panelist via its configured backend")
    disp.add_argument("--panelist", required=True, help="Panelist id from config.yml")
    disp.add_argument("--config", default=None, help="Path to config.yml (default: ~/.claude/panel/config.yml)")
    disp.add_argument("--persona", required=True, help="Path to persona file (markdown)")
    disp.add_argument("--prompt-file", required=True, help="Templated user prompt body")
    disp.add_argument("--output", required=True, help="Verdict file output path")

    lint = sub.add_parser("lint-config", help="Validate panel config.yml")
    lint.add_argument("--config", default=None)
```

Add dispatch branches in `main()`:

```python
    if args.cmd == "dispatch":
        from panel.config import load_config
        from panel.dispatch import dispatch as dispatch_fn
        from pathlib import Path
        cfg_path = args.config or Path.home() / ".claude" / "panel" / "config.yml"
        cfg = load_config(cfg_path)
        panelist = next((p for p in cfg.panelists if p.id == args.panelist), None)
        if panelist is None:
            print(f"unknown panelist id: {args.panelist}", file=sys.stderr)
            return 1
        dispatch_fn(panelist, Path(args.persona), Path(args.prompt_file), Path(args.output))
        return 0

    if args.cmd == "lint-config":
        from panel.config import load_config, ConfigError
        from pathlib import Path
        cfg_path = args.config or Path.home() / ".claude" / "panel" / "config.yml"
        try:
            cfg = load_config(cfg_path)
            enabled = [p for p in cfg.panelists if p.enabled]
            print(f"OK: {len(enabled)} enabled panelists (of {len(cfg.panelists)} configured)")
            for p in enabled:
                print(f"  - {p.id} (role={p.role}, backend={p.backend})")
            return 0
        except ConfigError as e:
            print(f"CONFIG ERROR: {e}", file=sys.stderr)
            return 1
```

- [ ] **Step 2: Manual smoke**

```bash
python3.12 -m panel lint-config --help
python3.12 -m panel dispatch --help
```

Both should print usage.

---

### Task 10: Ship default `~/.claude/panel/config.yml`

**Files:** Create `~/.claude/panel/config.yml`.

- [ ] **Step 1: Create directory and file**

```bash
mkdir -p ~/.claude/panel
```

Write `~/.claude/panel/config.yml`:

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
  otel_endpoint: null
```

- [ ] **Step 2: Verify with `lint-config`**

```bash
python3.12 -m panel lint-config
```

Expected output:
```
OK: 1 enabled panelists (of 3 configured)
  - da-nemotron (role=DA, backend=nat-nim)
```

---

### Task 11: Update `aggregate.py` for N panelists

Per v2.0 Phase 3 Task 12. Add `aggregate_n(verdict_paths, recommended_label, config_path=None, cycle=0)`. CLI's `aggregate` subcommand takes `--verdicts <path>...`. Existing 2-panelist tests stay (they use the legacy 2-panelist `aggregate()`, which becomes a thin wrapper around `aggregate_n` for backward compat OR is removed once SKILL.md is updated).

---

### Task 12: Update `SKILL.md` for NAT orchestration

**Files:** Modify SKILL.md substantively.

- [ ] **Step 1: Replace the "Per-question dispatch" section**

Key changes:
1. Skill reads `~/.claude/panel/config.yml` via `python3.12 -m panel lint-config` at startup (fail-open on invalid config).
2. For each enabled panelist:
   - If `backend.startswith("nat-")`: emit a Bash call to `python3.12 -m panel dispatch --panelist <id> --persona personas/<role>.md --prompt-file <body> --output <verdict>`.
   - If `backend == "claude-subagent"`: emit an `Agent` tool call with `subagent_type` from config.
3. All dispatch calls in ONE message (parallelism).
4. Run `python3.12 -m panel aggregate --verdicts ... --recommended-label ... --question-id <qhash>`.
5. Act on directive.

Refer to the v2.1 spec amendment in the design doc for the canonical orchestration narrative; SKILL.md mirrors that.

- [ ] **Step 2: Delete the v2.0 Phase 1+2 era step that mentions `aggregate.sh`**

Replace the `### 7. Run aggregate.sh` heading with `### 7. Run panel aggregate`, with body that invokes `python3.12 -m panel aggregate` directly.

---

### Task 13: Delete superseded files + end-to-end verification

- [ ] **Step 1: Delete superseded files**

```bash
cd ~/.claude/skills/validate-recommendation
rm dispatch-da.sh dispatch-da_test.sh aggregate.sh personas.md
```

- [ ] **Step 2: Full pytest suite**

```bash
pytest panel/ -v
```

Expected: all pre-existing + new tests pass (verdict, sanitize, trace, aggregate parity, config, personas, dispatch).

- [ ] **Step 3: Live verification with the default config (DA only)**

Trigger an `AskUserQuestion` with a `(Recommended)` option in a real Claude Code session. The skill should:
1. Read `config.yml`, find 1 enabled panelist (DA via NAT-NIM).
2. Dispatch DA via `python3.12 -m panel dispatch ...`.
3. NAT calls the NIM endpoint with Nemotron.
4. Aggregator sees 1 verdict → emits HOLD or DISSENT directive (severity tiers exercise; HARD-DISSENT cycle stays unused at N=1 since majority is trivial).
5. Trace log records `outcome=HOLD|DISSENT|ERROR`.

- [ ] **Step 4: Verify opt-in flow**

Edit `~/.claude/panel/config.yml` to set `pe: enabled: true` and `qa: enabled: true`. Run `panel lint-config` → must accept (3 enabled = odd N). Trigger another panel call. Skill should dispatch DA via NAT + PE/QA via Claude subagents in parallel, aggregator sees 3 verdicts.

- [ ] **Step 5: Phase 3 v2.1 sign-off**

When all 4 steps above pass with the new NAT integration visible (look for NAT-emitted log lines in stdout/trace), Phase 3 v2.1 is done. Phases 4-6 plans need only minor terminology updates (`dispatch-http.sh` → `panel/dispatch.py` references); their core logic is unaffected.

---

## Self-review

**Spec coverage**: Phase 3 v2.1 maps to the spec amendment in the design doc. Tasks 1-13 cover: NAT install (1), config (2-3), personas split (4), persona loader (5-6), NAT dispatcher (7-8), CLI surface (9), default config (10), aggregator generalization (11), SKILL.md (12), cleanup + verification (13).

**Placeholder scan**: Task 4 references v2.0 Phase 3 Tasks 1–3 for persona content (cross-plan reference is acceptable since the persona text doesn't change). Task 11 references v2.0 Phase 3 Task 12. These are intentional cross-references to avoid duplication; the v2.0 plan is checked into git history and remains accessible.

**Type consistency**: `Panelist`, `Config`, `Severity`, `RationaleGate`, `FailureMode`, `ReBrainstorm`, `Telemetry` dataclasses match across Tasks 2, 3, 7, 8, 9. `dispatch()`, `_invoke_nat()`, `_parse_verdict_response()` function names consistent in Task 7 (tests) and Task 8 (implementation). Backend strings (`nat-nim`, `nat-anthropic`, `nat-openai`, `claude-subagent`) consistent.

**Risk**: NAT's exact module/class paths (e.g., `nat.llm.nim_llm.NIMLLM`) may differ from this plan's assumption. Task 1 includes a discovery step (`pkgutil.walk_packages` grep for "nim") to surface the actual paths before implementing Task 8. If the layout differs, update `panel/dispatch.py`'s imports accordingly — the test suite mocks `_invoke_nat` so import-path correctness is verified only at live-run time (Task 13 Step 3).
