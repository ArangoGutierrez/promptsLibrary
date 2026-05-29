# validate-recommendation v3 — Phase 3a: config + personas split

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `panel/config.py` (YAML loader, dataclass-based, odd-enabled-N invariant), `panel/personas.py` (per-role persona loader), split `personas.md` into `personas/{da,pe,qa}.md`, add `panel lint-config` and `panel dispatch` (stub) subcommands, ship the default `~/.claude/panel/config.yml`. After Phase 3a, the panel still uses the v1 shell `dispatch-da.sh` and 2-panelist `aggregate.py` at runtime — Phase 3a only adds new code; nothing existing is rewired yet.

**Architecture:** Adds three new Python modules and three persona files alongside the existing Phase 1+2 code. The new code is wired up at the CLI surface (`panel lint-config` works end-to-end) but is not yet called by `SKILL.md`. Phase 3b wires `panel dispatch` to real NAT calls; Phase 3c rewires `SKILL.md` to call the new aggregator. The odd-N invariant on enabled count is enforced at load time so misconfiguration surfaces at `panel lint-config`, not at dispatch.

**Tech Stack:** Python 3.12 (`/opt/homebrew/bin/python3.12`), PyYAML (installed via pip --break-system-packages), pytest via pipx. No NAT dependency in this phase.

**Spec:** `docs/superpowers/specs/2026-05-15-validate-recommendation-v3-nat-native-design.md` (commit `c80b2f6`).

**Pre-flight context:**
- Phase 1+2 baseline shipped today: commits `7613357` (v1 + Phase 1 fixes) and `8dcffa5` (Phase 2 Python aggregator) in the `~/.claude/` git repo.
- 21 pytest cases currently pass: `cd ~/.claude/skills/validate-recommendation && pytest panel/tests/ -v`.
- `python3.12 --version` ≥ 3.12; `pipx run pytest` works.
- `~/.claude/` git repo enforces signed commits (`-s` DCO sign-off + `-S` GPG signature).

---

## File Structure

Tasks land into `/Users/eduardoa/.claude/` (the user's `~/.claude/` git repo):

| File | Disposition | Responsibility |
|---|---|---|
| `skills/validate-recommendation/panel/config.py` | **Create** | YAML loader, dataclasses, validation. ConfigError exception. |
| `skills/validate-recommendation/panel/personas.py` | **Create** | Per-role persona file loader; Persona dataclass. |
| `skills/validate-recommendation/personas/da.md` | **Create** | DA persona (extracted from `personas.md` DA section + v3 file structure). |
| `skills/validate-recommendation/personas/pe.md` | **Create** | PE persona (restructured from `personas.md` PE section into v3 sections). |
| `skills/validate-recommendation/personas/qa.md` | **Create** | QA persona (new role, drafted per v3 spec role catalog). |
| `skills/validate-recommendation/personas.md` | **Untouched** | Stays present; still read by `dispatch-da.sh`. Deleted in Phase 3c. |
| `skills/validate-recommendation/panel/cli.py` | **Modify** | Add `lint-config` and `dispatch` subparsers + dispatch branches. Existing `aggregate` subcommand untouched. |
| `skills/validate-recommendation/panel/tests/test_config.py` | **Create** | YAML loader tests, odd-N invariant, backend whitelist, defaults. |
| `skills/validate-recommendation/panel/tests/test_personas.py` | **Create** | Persona loader tests, front-matter parsing, section split. |
| `skills/validate-recommendation/panel/tests/test_cli_lint_config.py` | **Create** | CLI integration tests for `panel lint-config`. |
| `skills/validate-recommendation/panel/tests/conftest.py` | **Modify** | Add `personas_dir` fixture pointing at real `personas/` dir. |
| `~/.claude/panel/config.yml` | **Create** | Default config: DA enabled (nat-nim), PE/QA opt-in (claude-subagent). |

Untouched (deferred to later phases): `dispatch-da.sh`, `dispatch-da_test.sh`, `aggregate.sh`, `panel/{verdict,sanitize,trace,aggregate}.py`, `SKILL.md`.

---

## Tasks

### Task 1: Pre-flight — install PyYAML for `/opt/homebrew/bin/python3.12`

**Files:** none modified. Environment setup.

- [ ] **Step 1: Verify PyYAML is not already importable**

```bash
/opt/homebrew/bin/python3.12 -c "import yaml; print(yaml.__version__)" 2>&1
```

Expected if missing: `ModuleNotFoundError: No module named 'yaml'`.
Expected if present: a version string (e.g. `6.0.1`) — skip to Step 3.

- [ ] **Step 2: Install via `pip install --user --break-system-packages`**

PEP 668 blocks unflagged `pip install` on Homebrew Python; `--break-system-packages` is the documented override for user-site installs.

```bash
/opt/homebrew/bin/python3.12 -m pip install --user --break-system-packages pyyaml
```

Expected: `Successfully installed PyYAML-6.x.x` (or similar).

- [ ] **Step 3: Verify import works from system python3.12**

```bash
/opt/homebrew/bin/python3.12 -c "import yaml; print('PyYAML', yaml.__version__)"
```

Expected: `PyYAML 6.x.x` printed, exit 0. This interpreter is what `python3.12 -m panel` will use at runtime; if import works here it works at runtime.

- [ ] **Step 4: Verify pipx pytest can also import PyYAML**

pipx runs pytest in an isolated venv. Inject PyYAML so tests can import it.

```bash
pipx inject pytest pyyaml
pipx run pytest -c /dev/null --version 2>&1 | head -2
```

Expected: `pipx run pytest --version` prints a pytest version. Then verify:

```bash
pipx run --spec pytest python -c "import yaml; print('pipx-pytest yaml:', yaml.__version__)"
```

If pipx doesn't expose the python from pytest's venv, an alternative is to install pytest+pyyaml together via pipx:

```bash
pipx install --python /opt/homebrew/bin/python3.12 pytest 2>/dev/null || true
pipx inject pytest pyyaml --force
```

The acceptance criterion is: `cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/ -v` runs without `ImportError: No module named yaml` once Task 2's tests are added.

No commit for Task 1 (environment only).

---

### Task 2: Implement `panel/config.py` with TDD

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_config.py`
- Create: `~/.claude/skills/validate-recommendation/panel/config.py`

- [ ] **Step 1: Write the failing tests** (`panel/tests/test_config.py`)

```python
"""Tests for panel.config — YAML config loader.

Covers:
- Default config (DA enabled, PE/QA opt-in) parses correctly.
- Odd-N invariant rejects 0 or 2 enabled panelists.
- 1 and 3 enabled panelists accepted.
- Unknown backend rejected at load time.
- Optional sections default to spec-defined values when omitted.
- nat-* backend requires 'model'; claude-subagent backend requires 'subagent_type'.
- severity.hard_threshold whitelist, failure_mode whitelist, max_cycles bounds.
- Missing file raises ConfigError with a clear message.
"""
import textwrap

import pytest


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
    assert enabled[0].model == "nvidia/nemotron-3-super-v3"


def test_reject_even_enabled_count(tmp_path):
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
    with pytest.raises(ConfigError, match=r"odd"):
        load_config(cfg)


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
    assert sum(1 for p in c.panelists if p.enabled) == 3


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
    with pytest.raises(ConfigError, match=r"at least one"):
        load_config(cfg)


def test_reject_unknown_backend(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: x
            role: DA
            enabled: true
            backend: not-a-real-backend
    """)
    with pytest.raises(ConfigError, match=r"backend"):
        load_config(cfg)


def test_nat_backend_requires_model(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
    """)
    with pytest.raises(ConfigError, match=r"model"):
        load_config(cfg)


def test_subagent_backend_requires_subagent_type(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: pe
            role: PE
            enabled: true
            backend: claude-subagent
    """)
    with pytest.raises(ConfigError, match=r"subagent_type"):
        load_config(cfg)


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
    assert c.severity.rationale_gate.requires_principle_or_alternative is True
    assert c.failure_mode.on_panelist_error == "auto"
    assert c.re_brainstorm.enabled is True
    assert c.re_brainstorm.max_cycles == 2
    assert c.telemetry.jsonl == "~/.claude/panel/decisions.jsonl"
    assert c.telemetry.otel_endpoint is None


def test_severity_threshold_whitelist(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: x
        severity:
          hard_threshold: bogus
    """)
    with pytest.raises(ConfigError, match=r"hard_threshold"):
        load_config(cfg)


def test_failure_mode_whitelist(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: x
        failure_mode:
          on_panelist_error: nope
    """)
    with pytest.raises(ConfigError, match=r"on_panelist_error"):
        load_config(cfg)


def test_max_cycles_out_of_range(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: x
        re_brainstorm:
          max_cycles: 6
    """)
    with pytest.raises(ConfigError, match=r"max_cycles"):
        load_config(cfg)


def test_missing_config_file(tmp_path):
    from panel.config import load_config, ConfigError
    with pytest.raises(ConfigError, match=r"config file missing"):
        load_config(tmp_path / "does-not-exist.yml")


def test_malformed_yaml(tmp_path):
    from panel.config import load_config, ConfigError
    p = tmp_path / "config.yml"
    p.write_text("panelists: [oops\n  - id: x\n")
    with pytest.raises(ConfigError, match=r"YAML"):
        load_config(p)


def test_panelist_id_required(tmp_path):
    from panel.config import load_config, ConfigError
    cfg = _write_yaml(tmp_path, """
        version: 1
        panelists:
          - role: DA
            enabled: true
            backend: nat-nim
            model: x
    """)
    with pytest.raises(ConfigError, match=r"id"):
        load_config(cfg)
```

- [ ] **Step 2: Run tests to verify failure**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/test_config.py -v
```

Expected: 14 tests collected; all FAIL with `ModuleNotFoundError: No module named 'panel.config'`.

- [ ] **Step 3: Implement `panel/config.py`**

```python
"""Load and validate ~/.claude/panel/config.yml.

YAML-based config (NAT-compatible). Enforces the odd-N invariant on the
COUNT OF ENABLED PANELISTS (not total). Whitelists backend strings so
typos surface at load time, not dispatch time. nat-* backends require
'model'; claude-subagent backend requires 'subagent_type'.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

import yaml

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
    model: str = ""           # required for nat-* backends
    subagent_type: str = ""   # required for claude-subagent backend
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
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        raise ConfigError(f"config YAML parse error: {e}") from e

    panelists_raw = raw.get("panelists") or []
    if not panelists_raw:
        raise ConfigError("config: panelists must be non-empty")

    panelists: list[Panelist] = []
    for i, p in enumerate(panelists_raw):
        pid = p.get("id")
        if not pid:
            raise ConfigError(f"config: panelists[{i}] missing 'id'")
        backend = p.get("backend")
        if backend not in VALID_BACKENDS:
            raise ConfigError(
                f"config: panelists[{i}].backend must be one of "
                f"{sorted(VALID_BACKENDS)}, got '{backend}'"
            )
        model = p.get("model", "")
        subagent_type = p.get("subagent_type", "")
        if backend.startswith("nat-") and not model:
            raise ConfigError(
                f"config: panelists[{i}].model is required for backend '{backend}'"
            )
        if backend == "claude-subagent" and not subagent_type:
            raise ConfigError(
                f"config: panelists[{i}].subagent_type is required for "
                f"backend 'claude-subagent'"
            )
        panelists.append(Panelist(
            id=pid,
            role=p.get("role", ""),
            enabled=bool(p.get("enabled", False)),
            backend=backend,
            model=model,
            subagent_type=subagent_type,
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

    severity_raw = raw.get("severity") or {}
    rg_raw = severity_raw.get("rationale_gate") or {}
    severity = Severity(
        hard_threshold=severity_raw.get("hard_threshold", "majority"),
        rationale_gate=RationaleGate(
            requires_principle_or_alternative=rg_raw.get(
                "requires_principle_or_alternative", True
            ),
            principle_patterns=rg_raw.get(
                "principle_patterns", RationaleGate().principle_patterns
            ),
        ),
    )
    if severity.hard_threshold not in VALID_HARD_THRESHOLDS:
        raise ConfigError(
            f"severity.hard_threshold must be one of "
            f"{sorted(VALID_HARD_THRESHOLDS)}, got '{severity.hard_threshold}'"
        )

    fm_raw = raw.get("failure_mode") or {}
    failure_mode = FailureMode(
        on_panelist_error=fm_raw.get("on_panelist_error", "auto")
    )
    if failure_mode.on_panelist_error not in VALID_FAILURE_MODES:
        raise ConfigError(
            f"failure_mode.on_panelist_error must be one of "
            f"{sorted(VALID_FAILURE_MODES)}, got '{failure_mode.on_panelist_error}'"
        )

    rb_raw = raw.get("re_brainstorm") or {}
    re_brainstorm = ReBrainstorm(
        enabled=bool(rb_raw.get("enabled", True)),
        max_cycles=int(rb_raw.get("max_cycles", 2)),
    )
    if not (0 <= re_brainstorm.max_cycles <= 5):
        raise ConfigError(
            f"re_brainstorm.max_cycles must be in [0, 5], got {re_brainstorm.max_cycles}"
        )

    tel_raw = raw.get("telemetry") or {}
    telemetry = Telemetry(
        jsonl=tel_raw.get("jsonl", "~/.claude/panel/decisions.jsonl"),
        otel_endpoint=tel_raw.get("otel_endpoint"),
    )

    return Config(
        version=str(raw.get("version", "1")),
        panelists=panelists,
        severity=severity,
        failure_mode=failure_mode,
        re_brainstorm=re_brainstorm,
        telemetry=telemetry,
    )
```

- [ ] **Step 4: Run tests to verify pass**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/test_config.py -v
```

Expected: 14 tests pass.

Also run the existing Phase 2 suite to confirm no regression:

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/ -v
```

Expected: 14 (new) + 21 (existing) = 35 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/config.py skills/validate-recommendation/panel/tests/test_config.py
cd ~/.claude && git commit -s -S -m "feat(panel): config.py YAML loader with odd-enabled-N invariant

Adds panel/config.py — YAML config loader with dataclass-based schema:
  - Panelist (id, role, enabled, backend, model | subagent_type, ...)
  - Severity (hard_threshold + RationaleGate)
  - FailureMode (on_panelist_error)
  - ReBrainstorm (enabled, max_cycles)
  - Telemetry (jsonl, otel_endpoint)

Validation enforced at load time (typos surface at lint, not dispatch):
  - Count of enabled panelists must be odd (1, 3, 5...) — vote-tie invariant
  - At least one panelist enabled
  - Backend in {nat-nim, nat-anthropic, nat-openai, claude-subagent}
  - nat-* backends require 'model'; claude-subagent requires 'subagent_type'
  - severity.hard_threshold in {majority, supermajority}
  - failure_mode.on_panelist_error in {strict, graceful, auto}
  - re_brainstorm.max_cycles in [0, 5]

14 pytest cases. v3 spec section 'Configuration' (c80b2f6 in promptsLibrary)."
```

---

### Task 3: Split `personas.md` into `personas/{da,pe,qa}.md`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/personas/da.md`
- Create: `~/.claude/skills/validate-recommendation/personas/pe.md`
- Create: `~/.claude/skills/validate-recommendation/personas/qa.md`

This task is pure file authoring — no test cycle. The persona content is exercised by Task 4's `panel.personas` tests and (in later phases) by the actual dispatch path.

- [ ] **Step 1: Create the `personas/` directory**

```bash
mkdir -p ~/.claude/skills/validate-recommendation/personas
```

- [ ] **Step 2: Write `personas/da.md`**

Path: `~/.claude/skills/validate-recommendation/personas/da.md`

```markdown
---
role: DA
description: Adversarial reviewer — finds strongest counter-argument
intended_backends: [nat-nim, nat-openai]
---

# System prompt

You are a devil's-advocate reviewer. Another assistant has recommended
one option in a multiple-choice question. Your job: find the strongest
reason the recommendation is wrong.

Consider:
- Hidden assumptions in the recommendation that may not hold
- Edge cases the recommendation breaks on
- Alternatives that better match the user's stated goal
- Second-order effects (maintenance burden, debugging cost, vendor
  lock-in, future flexibility)

Two possible verdicts, with exact meanings:

- VERDICT: HOLD means "no stronger counter found; the recommendation
  stands as the best choice given the stated constraints." Use this
  when you cannot identify a meaningful problem after honest scrutiny.
  Manufactured criticism wastes the user's attention.

- VERDICT: OVERTURN means "I identified a specific flaw in the
  recommendation AND a concrete alternative that addresses it." Both
  the flaw and the alternative must be named.

Output ONLY this strict format. No preamble. No markdown fencing.
No prose before VERDICT or after ALTERNATIVE.

For HOLD:
VERDICT: HOLD
RATIONALE: <one paragraph, 3-5 sentences explaining what you
considered and why no stronger counter exists>
ALTERNATIVE: n/a

For OVERTURN:
VERDICT: OVERTURN
RATIONALE: <one paragraph, 3-5 sentences naming the specific flaw>
ALTERNATIVE: <verbatim option label from the prompt>

The ALTERNATIVE value MUST be a literal copy of one of the option
labels supplied to you, with the same prefix and capitalization
(e.g., "Option B", "B. resty", "Use net/http"). Do not abbreviate.
Do not paraphrase. Do not invent new options not in the list.

# One-shot example

Example input:
Question: Which HTTP client should we use in a Go service?
Options (verbatim labels):
  Option A (Recommended) — net/http; stdlib, no deps
  Option B — resty; third-party with built-in retries
  Option C — fasthttp; faster but incompatible interface
Assistant's recommended option: Option A (Recommended)
Assistant's stated reasoning: stdlib is sufficient and avoids dependency cost.

Example output (no preamble, just the three lines):
VERDICT: HOLD
RATIONALE: After examining the alternatives, no stronger counter found.
The stdlib client meets the stated goal of minimizing dependencies.
Option B's retries can be added via a small wrapper when needed; Option
C breaks compatibility with stdlib middleware, a cost not justified by
the stated requirements. The recommendation stands.
ALTERNATIVE: n/a

# User prompt template

Question: <question text>
Options (verbatim labels and descriptions):
  <label 1> — <description 1>
  <label 2> — <description 2>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <extracted reasoning or "(no reasoning supplied)">
```

- [ ] **Step 3: Write `personas/pe.md`**

Path: `~/.claude/skills/validate-recommendation/personas/pe.md`

```markdown
---
role: PE
description: Principles-grounded reviewer — reads ~/.claude/CLAUDE.md and ~/.claude/rules/
intended_backends: [claude-subagent, nat-anthropic]
---

# System prompt

You are reviewing a recommendation against the engineering principles
in ~/.claude/CLAUDE.md and ~/.claude/rules/. USE YOUR TOOLS (Read, Grep,
Glob) to consult the actual rule files rather than relying on memory —
the rules change, and recall may be stale.

Evaluate against:

- **Atomicity**: does this bundle multiple concerns?
- **YAGNI**: any unnecessary abstractions or speculative generality?
- **Priority order**: Security > Correctness > Performance > Style.
  Does the recommendation respect this order?
- **TDD**: is the recommended option testable and verifiable?
- **Where relevant**: K8s conventions, Go conventions, container
  conventions, git workflow rules.

If the recommendation aligns with these principles, output HOLD.
If it violates one, output OVERTURN — name the principle in your
rationale and pick a specific alternative option that aligns better.

Two possible verdicts, with exact meanings:

- VERDICT: HOLD — recommendation aligns with the principles; no
  meaningful violation found.
- VERDICT: OVERTURN — at least one principle is violated; a specific
  alternative option from the list better aligns with the principles.

Output ONLY this strict format. No preamble. No markdown fencing.

For HOLD:
VERDICT: HOLD
RATIONALE: <one paragraph, 3-5 sentences citing which principles you
checked and why the recommendation is acceptable>
ALTERNATIVE: n/a

For OVERTURN:
VERDICT: OVERTURN
RATIONALE: <one paragraph, 3-5 sentences naming the principle violated>
ALTERNATIVE: <verbatim option label from the list>

The ALTERNATIVE value MUST be a literal copy of one of the option
labels (e.g., "Option B", "B. resty"). Do not abbreviate or paraphrase.

# One-shot example

Example input:
Question: How should we handle the auth migration?
Options (verbatim labels):
  Option A (Recommended) — Big-bang cutover with feature flag
  Option B — Phased migration over 3 sprints
  Option C — Run both auth systems in parallel for 30 days
Assistant's recommended option: Option A (Recommended)
Assistant's stated reasoning: Faster delivery; less code to maintain during transition.

Example output:
VERDICT: OVERTURN
RATIONALE: This violates Atomicity: a big-bang cutover bundles "ship new
auth", "migrate session data", and "decommission old system" into one
deploy. Each is its own concern with its own rollback profile. The
Priority order principle also applies — a botched auth cutover has
direct Security implications (session bypass, lockout), and a single
deploy makes recovery harder. A phased approach reduces blast radius.
ALTERNATIVE: Option B

# User prompt template

Question: <question text>
Options (verbatim labels and descriptions):
  <label 1> — <description 1>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <extracted reasoning or "(no reasoning supplied)">
```

- [ ] **Step 4: Write `personas/qa.md`**

Path: `~/.claude/skills/validate-recommendation/personas/qa.md`

```markdown
---
role: QA
description: Test quality and verifiability reviewer
intended_backends: [claude-subagent, nat-anthropic]
---

# System prompt

You are a QA engineer reviewing a recommendation. Your focus is whether
the recommendation can be verified — both during development and in
production. USE YOUR TOOLS (Read, Grep) to consult the project's test
patterns and quality gates if available.

Evaluate against:

- **Testability**: can a unit/integration test be written that fails
  when the recommended approach is broken?
- **Theater test risk**: would tests of this approach end up tautological
  (assert the implementation rather than the behavior)?
- **Failure-mode observability**: when the recommendation's edge cases
  fire, will the failure be visible (error, log, metric) or silent?
- **Mock depth**: does the approach push test design toward mocking
  multiple layers deep? (One layer max per the project constitution.)
- **Production verifiability**: can on-call observe the system to know
  the recommendation is behaving correctly?

If the recommendation can be tested with a real implementation and
fails-loudly on its edge cases, output HOLD.
If the recommendation forces theater tests, deep mocks, or hides
failure modes, output OVERTURN — name the testability gap in your
rationale and pick an alternative that's more verifiable.

Two possible verdicts, with exact meanings:

- VERDICT: HOLD — recommendation is testable and observable; failure
  modes will surface.
- VERDICT: OVERTURN — testability or observability gap; a specific
  alternative option from the list is more verifiable.

Output ONLY this strict format. No preamble. No markdown fencing.

For HOLD:
VERDICT: HOLD
RATIONALE: <one paragraph, 3-5 sentences citing the test approach you
imagined and why it would catch the recommendation's failure modes>
ALTERNATIVE: n/a

For OVERTURN:
VERDICT: OVERTURN
RATIONALE: <one paragraph, 3-5 sentences naming the testability or
observability gap>
ALTERNATIVE: <verbatim option label from the list>

The ALTERNATIVE value MUST be a literal copy of one of the option
labels (e.g., "Option B", "B. resty"). Do not abbreviate or paraphrase.

# One-shot example

Example input:
Question: How should we monitor the new payment-processing service?
Options (verbatim labels):
  Option A (Recommended) — Application-level logs only
  Option B — Logs + business-event metrics (orders/min, $/min, error-rate-by-merchant)
  Option C — Distributed tracing with span attributes
Assistant's recommended option: Option A (Recommended)
Assistant's stated reasoning: Logs are the most flexible; we can grep when needed.

Example output:
VERDICT: OVERTURN
RATIONALE: Logs alone are not failure-mode observable for a payment
service. A "merchant X is silently failing on 30% of charges" scenario
needs a per-merchant error-rate metric to page on; greppable logs only
help once you know to look. Production verifiability is the testability
gap — you can't write a synthetic test that fails when error-rate
drifts unless the rate is materialized as a metric. Option B closes
the gap by emitting business-event metrics an alert can target.
ALTERNATIVE: Option B

# User prompt template

Question: <question text>
Options (verbatim labels and descriptions):
  <label 1> — <description 1>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <extracted reasoning or "(no reasoning supplied)">
```

- [ ] **Step 5: Verify all three files exist with correct structure**

```bash
for f in ~/.claude/skills/validate-recommendation/personas/{da,pe,qa}.md; do
  echo "=== $f ==="
  head -5 "$f"
  echo "---"
  grep -c '^# System prompt$\|^# One-shot example$\|^# User prompt template$' "$f"
done
```

Expected: each file's first 5 lines show the YAML front-matter (`---`, `role: <R>`, ...); each file has exactly 3 matching headings.

- [ ] **Step 6: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/personas/da.md skills/validate-recommendation/personas/pe.md skills/validate-recommendation/personas/qa.md
cd ~/.claude && git commit -s -S -m "feat(skill): split personas into per-role files

Adds personas/{da,pe,qa}.md with v3 file structure:
  - YAML front-matter (role, description, intended_backends)
  - # System prompt section
  - # One-shot example section
  - # User prompt template section

QA is a new role (v1 had only DA + PE). QA evaluates testability,
theater-test risk, failure-mode observability, and mock-depth limits
per the project constitution.

personas.md is left in place — dispatch-da.sh still reads it; deleted
in Phase 3c after dispatch-da.sh is gone."
```

---

### Task 4: Implement `panel/personas.py` with TDD

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_personas.py`
- Create: `~/.claude/skills/validate-recommendation/panel/personas.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/tests/conftest.py` (add `personas_dir` fixture)

- [ ] **Step 1: Add the `personas_dir` fixture to `conftest.py`**

Read the existing conftest.py first:

```bash
cat ~/.claude/skills/validate-recommendation/panel/tests/conftest.py
```

It currently contains the Phase 2 fixtures-dir fixture. Append the new fixture (do not remove existing fixtures):

```python
# Appended in Phase 3a — points at the real personas/ directory shipped with the skill.

import pytest
from pathlib import Path


@pytest.fixture
def personas_dir() -> Path:
    """Path to the real personas/ directory shipped next to panel/."""
    return Path(__file__).resolve().parent.parent.parent / "personas"
```

Use the Edit tool to append (not overwrite) so the existing `fixtures_dir` fixture stays intact.

- [ ] **Step 2: Write the failing tests** (`panel/tests/test_personas.py`)

```python
"""Tests for panel.personas — per-role persona file loader.

Covers:
- Each real persona file (da/pe/qa) loads without error.
- Front-matter is parsed into role / description / intended_backends.
- Three sections are populated.
- load_persona_by_role finds the right file (case-insensitive).
- Missing file raises PersonaError.
- Malformed front-matter raises PersonaError.
- Missing required section raises PersonaError.
"""
import pytest


def test_load_da_persona(personas_dir):
    from panel.personas import load_persona
    p = load_persona(personas_dir / "da.md")
    assert p.role == "DA"
    assert "devil" in p.system_prompt.lower() or "adversari" in p.system_prompt.lower()
    assert "Question:" in p.user_prompt_template
    assert "VERDICT:" in p.one_shot_example


def test_load_pe_persona(personas_dir):
    from panel.personas import load_persona
    p = load_persona(personas_dir / "pe.md")
    assert p.role == "PE"
    assert "CLAUDE.md" in p.system_prompt
    assert "claude-subagent" in p.intended_backends


def test_load_qa_persona(personas_dir):
    from panel.personas import load_persona
    p = load_persona(personas_dir / "qa.md")
    assert p.role == "QA"
    assert "test" in p.system_prompt.lower()
    assert "Question:" in p.user_prompt_template


def test_load_persona_by_role_case_insensitive(personas_dir):
    from panel.personas import load_persona_by_role
    p_upper = load_persona_by_role("DA", personas_dir=personas_dir)
    p_lower = load_persona_by_role("da", personas_dir=personas_dir)
    assert p_upper.role == p_lower.role == "DA"


def test_missing_persona_file(tmp_path):
    from panel.personas import load_persona, PersonaError
    with pytest.raises(PersonaError, match=r"missing"):
        load_persona(tmp_path / "ghost.md")


def test_missing_frontmatter(tmp_path):
    from panel.personas import load_persona, PersonaError
    p = tmp_path / "no_fm.md"
    p.write_text("# System prompt\nhi\n# User prompt template\nq\n")
    with pytest.raises(PersonaError, match=r"front-matter"):
        load_persona(p)


def test_frontmatter_missing_role(tmp_path):
    from panel.personas import load_persona, PersonaError
    p = tmp_path / "no_role.md"
    p.write_text("---\ndescription: x\n---\n# System prompt\nhi\n# User prompt template\nq\n")
    with pytest.raises(PersonaError, match=r"role"):
        load_persona(p)


def test_missing_system_prompt_section(tmp_path):
    from panel.personas import load_persona, PersonaError
    p = tmp_path / "no_sp.md"
    p.write_text("---\nrole: DA\n---\n# User prompt template\nq\n")
    with pytest.raises(PersonaError, match=r"System prompt"):
        load_persona(p)


def test_missing_user_prompt_template_section(tmp_path):
    from panel.personas import load_persona, PersonaError
    p = tmp_path / "no_upt.md"
    p.write_text("---\nrole: DA\n---\n# System prompt\nhi\n")
    with pytest.raises(PersonaError, match=r"User prompt template"):
        load_persona(p)


def test_one_shot_example_is_optional(tmp_path):
    """One-shot example missing is allowed (some personas may not need it)."""
    from panel.personas import load_persona
    p = tmp_path / "minimal.md"
    p.write_text(
        "---\nrole: SEC\ndescription: security\nintended_backends: [nat-nim]\n---\n"
        "# System prompt\nYou check security.\n"
        "# User prompt template\nQuestion: <q>\n"
    )
    persona = load_persona(p)
    assert persona.role == "SEC"
    assert persona.one_shot_example == ""
```

- [ ] **Step 3: Run tests to verify failure**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/test_personas.py -v
```

Expected: 10 tests collected; all FAIL with `ModuleNotFoundError: No module named 'panel.personas'`.

- [ ] **Step 4: Implement `panel/personas.py`**

```python
"""Per-role persona file loader.

A persona file has YAML front-matter and three known markdown sections:
  # System prompt
  # One-shot example   (optional — empty allowed)
  # User prompt template

The loader splits these into a Persona dataclass. `load_persona_by_role`
finds the file by role name (case-insensitive: 'DA' → personas/da.md).
"""
from __future__ import annotations
import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


class PersonaError(Exception):
    pass


@dataclass
class Persona:
    role: str
    description: str = ""
    intended_backends: list[str] = field(default_factory=list)
    system_prompt: str = ""
    one_shot_example: str = ""
    user_prompt_template: str = ""


def _split_sections(body: str) -> dict[str, str]:
    """Split markdown body on `# Heading` lines into a dict keyed by heading."""
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in body.splitlines():
        if line.startswith("# "):
            current = line[2:].strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def load_persona(path: str | Path) -> Persona:
    path = Path(path).expanduser()
    if not path.is_file():
        raise PersonaError(f"persona file missing: {path}")

    text = path.read_text(encoding="utf-8")
    m = _FRONTMATTER_RE.match(text)
    if not m:
        raise PersonaError(f"{path}: missing or malformed YAML front-matter")

    frontmatter_raw, body = m.group(1), m.group(2)
    try:
        meta = yaml.safe_load(frontmatter_raw) or {}
    except yaml.YAMLError as e:
        raise PersonaError(f"{path}: front-matter parse error: {e}") from e

    role = meta.get("role")
    if not role:
        raise PersonaError(f"{path}: front-matter missing 'role'")

    sections = _split_sections(body)
    sp = sections.get("System prompt", "")
    upt = sections.get("User prompt template", "")
    if not sp:
        raise PersonaError(f"{path}: '# System prompt' section is empty or missing")
    if not upt:
        raise PersonaError(f"{path}: '# User prompt template' section is empty or missing")

    return Persona(
        role=role,
        description=meta.get("description", ""),
        intended_backends=list(meta.get("intended_backends", [])),
        system_prompt=sp,
        one_shot_example=sections.get("One-shot example", ""),
        user_prompt_template=upt,
    )


def load_persona_by_role(role: str, personas_dir: str | Path | None = None) -> Persona:
    """Load persona by role name. Looks for `<personas_dir>/<role.lower()>.md`.

    Default personas_dir is the `personas/` directory next to this panel package.
    """
    if personas_dir is None:
        personas_dir = Path(__file__).resolve().parent.parent / "personas"
    return load_persona(Path(personas_dir) / f"{role.lower()}.md")
```

- [ ] **Step 5: Run tests to verify pass**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/test_personas.py -v
```

Expected: 10 tests pass.

Run full suite to confirm no regression:

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/ -v
```

Expected: 35 + 10 = 45 tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/personas.py skills/validate-recommendation/panel/tests/test_personas.py skills/validate-recommendation/panel/tests/conftest.py
cd ~/.claude && git commit -s -S -m "feat(panel): personas.py per-role persona loader

Adds panel/personas.py with Persona dataclass + load_persona and
load_persona_by_role functions. Reads personas/<role>.md files with
YAML front-matter (role, description, intended_backends) plus three
markdown sections (System prompt, One-shot example, User prompt
template). One-shot example is optional; the other two are required.

10 pytest cases (covers all three shipped persona files plus error
paths)."
```

---

### Task 5: Add `lint-config` and `dispatch` subcommands to `panel/cli.py`

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_lint_config.py`

`dispatch` is a stub in this phase (returns exit 2 with a "Phase 3b" message). `lint-config` is fully functional.

- [ ] **Step 1: Write the failing tests** (`panel/tests/test_cli_lint_config.py`)

```python
"""Tests for panel.cli lint-config and dispatch subcommand registration.

dispatch is a stub here (real NAT integration ships in Phase 3b). The
test verifies the subparser is registered and returns a clear
'not-implemented-here' exit code so an accidental dispatch call doesn't
fail silently.
"""
import textwrap

import pytest


def _write_config(tmp_path, content):
    p = tmp_path / "config.yml"
    p.write_text(textwrap.dedent(content).strip() + "\n")
    return p


def test_lint_config_ok_for_valid_single_panelist(tmp_path, capsys):
    from panel.cli import main
    cfg = _write_config(tmp_path, """
        version: 1
        panelists:
          - id: da-nemotron
            role: DA
            enabled: true
            backend: nat-nim
            model: nvidia/nemotron-3-super-v3
    """)
    rc = main(["lint-config", "--config", str(cfg)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "OK" in out
    assert "da-nemotron" in out


def test_lint_config_reports_error_on_even_enabled(tmp_path, capsys):
    from panel.cli import main
    cfg = _write_config(tmp_path, """
        version: 1
        panelists:
          - id: a
            role: DA
            enabled: true
            backend: nat-nim
            model: x
          - id: b
            role: PE
            enabled: true
            backend: claude-subagent
            subagent_type: principal-engineer
    """)
    rc = main(["lint-config", "--config", str(cfg)])
    captured = capsys.readouterr()
    assert rc != 0
    combined = captured.out + captured.err
    assert "CONFIG ERROR" in combined or "ConfigError" in combined or "odd" in combined.lower()


def test_lint_config_reports_error_on_missing_file(tmp_path, capsys):
    from panel.cli import main
    rc = main(["lint-config", "--config", str(tmp_path / "nope.yml")])
    combined = capsys.readouterr().out + capsys.readouterr().err
    assert rc != 0


def test_dispatch_subparser_registered(capsys):
    """dispatch --help works (subparser registration check)."""
    from panel.cli import main
    with pytest.raises(SystemExit) as excinfo:
        main(["dispatch", "--help"])
    # argparse exits 0 on --help
    assert excinfo.value.code == 0
    out = capsys.readouterr().out
    assert "--panelist" in out
    assert "--output" in out


def test_dispatch_stub_returns_phase3b_message(tmp_path, capsys):
    """Calling dispatch without --help returns a 'not-yet-implemented' exit code.

    Phase 3b replaces this stub with real NAT dispatch. Until then,
    accidentally calling dispatch must fail loudly, not silently.
    """
    from panel.cli import main
    rc = main([
        "dispatch",
        "--panelist", "da-nemotron",
        "--persona", str(tmp_path / "fake.md"),
        "--prompt-file", str(tmp_path / "fake_prompt.txt"),
        "--output", str(tmp_path / "fake.verdict"),
    ])
    assert rc != 0
    combined = capsys.readouterr().out + capsys.readouterr().err
    assert "Phase 3b" in combined or "not yet implemented" in combined.lower()
```

- [ ] **Step 2: Run tests to verify failure**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/test_cli_lint_config.py -v
```

Expected: 5 tests collected; all FAIL (either with `argparse.ArgumentError` for unknown command or `SystemExit` because the subparser doesn't exist).

- [ ] **Step 3: Modify `panel/cli.py`**

Read the current cli.py first:

```bash
cat ~/.claude/skills/validate-recommendation/panel/cli.py
```

Replace its content with:

```python
"""Top-level CLI dispatch for the panel package.

Subcommands shipped so far:
- aggregate         (Phase 2 — 2-panelist byte-parity)
- lint-config       (Phase 3a — config validation)
- dispatch          (Phase 3a — stub; real NAT integration in Phase 3b)

Subcommands planned for later phases:
- record-userpick   (Phase 6)
- ls, show, label, stats, replay, gc   (Phase 6)
- tune              (deferred to v1.x)
"""
import argparse
import sys
from pathlib import Path


def _default_config_path() -> Path:
    return Path.home() / ".claude" / "panel" / "config.yml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="panel", description="validate-recommendation panel CLI"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    agg = sub.add_parser(
        "aggregate", help="Aggregate panelist verdicts into a directive"
    )
    agg.add_argument("--da", required=True, help="Path to DA verdict file")
    agg.add_argument("--pe", required=True, help="Path to PE verdict file")
    agg.add_argument(
        "--recommended-label", required=True, help="The recommended option label"
    )

    lint = sub.add_parser("lint-config", help="Validate panel config.yml")
    lint.add_argument(
        "--config", default=None,
        help="Path to config.yml (default: ~/.claude/panel/config.yml)",
    )

    disp = sub.add_parser(
        "dispatch",
        help="Run one panelist via its configured backend (stub in Phase 3a)",
    )
    disp.add_argument("--panelist", required=True, help="Panelist id from config.yml")
    disp.add_argument(
        "--config", default=None,
        help="Path to config.yml (default: ~/.claude/panel/config.yml)",
    )
    disp.add_argument("--persona", required=True, help="Path to persona file")
    disp.add_argument(
        "--prompt-file", required=True, help="Templated user prompt body"
    )
    disp.add_argument("--output", required=True, help="Verdict file output path")

    args = parser.parse_args(argv)

    if args.cmd == "aggregate":
        from panel.aggregate import aggregate
        print(aggregate(args.da, args.pe, args.recommended_label))
        return 0

    if args.cmd == "lint-config":
        from panel.config import load_config, ConfigError
        cfg_path = args.config or _default_config_path()
        try:
            cfg = load_config(cfg_path)
        except ConfigError as e:
            print(f"CONFIG ERROR: {e}", file=sys.stderr)
            return 1
        enabled = [p for p in cfg.panelists if p.enabled]
        print(
            f"OK: {len(enabled)} enabled panelist(s) "
            f"(of {len(cfg.panelists)} configured)"
        )
        for p in enabled:
            extra = f"model={p.model}" if p.model else f"subagent={p.subagent_type}"
            print(f"  - {p.id} (role={p.role}, backend={p.backend}, {extra})")
        return 0

    if args.cmd == "dispatch":
        print(
            "dispatch: not yet implemented in Phase 3a — Phase 3b adds the real "
            "NAT integration.",
            file=sys.stderr,
        )
        return 2

    parser.error(f"unknown command: {args.cmd}")
    return 2
```

- [ ] **Step 4: Run tests to verify pass**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/test_cli_lint_config.py -v
```

Expected: 5 tests pass.

Run full suite to confirm no regression:

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/ -v
```

Expected: 45 + 5 = 50 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/cli.py skills/validate-recommendation/panel/tests/test_cli_lint_config.py
cd ~/.claude && git commit -s -S -m "feat(panel): add lint-config and dispatch subcommands

lint-config:
  - Loads ~/.claude/panel/config.yml (or --config path)
  - Prints 'OK: N enabled panelist(s) (of M configured)' on success
  - Exits 1 with 'CONFIG ERROR: <reason>' on invalid config

dispatch:
  - Subparser registered with --panelist/--config/--persona/--prompt-file/--output
  - Body is a stub that exits 2 with 'not yet implemented in Phase 3a'
  - Phase 3b replaces the stub with NAT integration

5 pytest cases. aggregate subcommand untouched."
```

---

### Task 6: Ship default `~/.claude/panel/config.yml`

**Files:**
- Create: `~/.claude/panel/config.yml`

This file lives under `~/.claude/panel/` (user state directory), NOT under the skill directory. It is the user-owned config the runtime reads. Tracked in the `~/.claude/` git repo at that path.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p ~/.claude/panel && chmod 700 ~/.claude/panel
```

- [ ] **Step 2: Write the default config**

Path: `~/.claude/panel/config.yml`

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

- [ ] **Step 3: Set file mode**

```bash
chmod 600 ~/.claude/panel/config.yml
```

- [ ] **Step 4: Verify with `panel lint-config`**

```bash
cd ~/.claude/skills/validate-recommendation && /opt/homebrew/bin/python3.12 -m panel lint-config
```

Expected output (exit 0):

```
OK: 1 enabled panelist(s) (of 3 configured)
  - da-nemotron (role=DA, backend=nat-nim, model=nvidia/nemotron-3-super-v3)
```

If `python3.12 -m panel` fails with `ModuleNotFoundError: No module named 'panel'`, the working directory matters — the panel package is the `panel/` dir in the current directory. Confirm `cd ~/.claude/skills/validate-recommendation` before invoking.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add panel/config.yml
cd ~/.claude && git commit -s -S -m "feat(panel): default config.yml (DA enabled, PE/QA opt-in)

Default panel composition:
  - da-nemotron: DA via nat-nim (Nemotron) — enabled
  - pe: PE via claude-subagent (principal-engineer) — opt-in
  - qa: QA via claude-subagent (qa-engineer) — opt-in

Severity: majority + rationale_gate.
Failure mode: auto (strict @ N=3, graceful @ N≥5).
Re-brainstorm: max 2 cycles.
Telemetry: JSONL only by default.

panel lint-config validates this config.

Note: Phase 3a still uses the legacy v1 dispatch path at runtime
(SKILL.md → dispatch-da.sh → aggregate.sh). This config file is read
only by 'panel lint-config' until Phase 3c rewires SKILL.md."
```

---

### Task 7: Phase 3a sign-off — full test suite + end-to-end smoke

**Files:** none modified. Verification only.

- [ ] **Step 1: Run the full pytest suite**

```bash
cd ~/.claude/skills/validate-recommendation && pipx run pytest panel/tests/ -v
```

Expected: 50 tests pass. Breakdown:
- test_verdict.py (Phase 2) — verdict parsing
- test_sanitize.py (Phase 2) — markdown stripping
- test_trace.py (Phase 2) — trace logging
- test_aggregate.py (Phase 2) — 2-panelist aggregator
- test_config.py (Phase 3a) — 14 cases
- test_personas.py (Phase 3a) — 10 cases
- test_cli_lint_config.py (Phase 3a) — 5 cases

- [ ] **Step 2: End-to-end smoke for `panel lint-config`**

```bash
cd ~/.claude/skills/validate-recommendation && /opt/homebrew/bin/python3.12 -m panel lint-config
```

Expected: exits 0, prints `OK: 1 enabled panelist(s) (of 3 configured)` plus the da-nemotron line.

Negative smoke — confirm error path works:

```bash
cd ~/.claude/skills/validate-recommendation && /opt/homebrew/bin/python3.12 -m panel lint-config --config /tmp/does-not-exist.yml ; echo "rc=$?"
```

Expected: stderr line `CONFIG ERROR: config file missing: /tmp/does-not-exist.yml`, then `rc=1`.

- [ ] **Step 3: Confirm legacy v1 dispatch path still works**

Phase 3a adds new code only. The legacy path (SKILL.md → dispatch-da.sh → aggregate.sh shim → Python aggregate.py) must still function. Quick check:

```bash
cd ~/.claude/skills/validate-recommendation && bash aggregate_test.sh 2>&1 | tail -3
```

Expected: aggregate_test.sh passes its assertions (it covers the 2-panelist HOLD/DISSENT/ERROR paths through the Phase 2 shim).

- [ ] **Step 4: Confirm Phase 1 dispatch-da test suite still works**

```bash
cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh 2>&1 | tail -3
```

Expected: dispatch-da_test.sh passes its assertions (17 tests including the Phase 1 fix tests).

- [ ] **Step 5: Verify the `~/.claude/` git history**

```bash
cd ~/.claude && git log --oneline -8
```

Expected: 5 new commits land on top of `8dcffa5` (Phase 2 baseline):
- panel/config.py + tests
- personas/{da,pe,qa}.md
- panel/personas.py + tests + conftest fixture
- panel/cli.py + tests (lint-config + dispatch stub)
- panel/config.yml (default)

Phase 3a sign-off when all five Steps pass. Next phase (3b) replaces the dispatch stub with real NAT integration; it depends on `panel.config.Panelist` and `panel.personas.load_persona_by_role` which Phase 3a delivers.

---

## Self-review

**Spec coverage:**
- Spec section "Configuration" → Tasks 2 + 6 (config.py loader + default config.yml).
- Spec section "Validation rules (`panel lint-config`)" → Task 2 (loader-level) + Task 5 (CLI surface).
- Spec section "Persona file format" → Task 3 (file content) + Task 4 (loader code).
- Spec section "Role catalog" → Task 3 (da/pe/qa.md cover all three).
- Spec section "panel CLI" rows for lint-config + dispatch → Task 5.
- Spec section "Migration plan / Phase 3a" — all four bullets covered.

**Out-of-scope (deferred phases) and explicitly NOT touched:**
- `dispatch-da.sh` (Phase 3c deletes it)
- `aggregate.sh` (Phase 3c deletes it)
- `panel/{verdict,sanitize,trace,aggregate}.py` (carried verbatim; cli.py only gains subcommands)
- `personas.md` (Phase 3c deletes after dispatch-da.sh is gone)
- `SKILL.md` (Phase 3c rewires orchestration)

**Placeholder scan:** No `TBD`, `TODO`, or "implement later" markers. Every code block is the actual code an engineer types. Every command is an exact invocation. Every expected output is concrete.

**Type consistency:**
- `Panelist`, `Config`, `Severity`, `RationaleGate`, `FailureMode`, `ReBrainstorm`, `Telemetry` dataclasses introduced in Task 2 are referenced by tests in Task 5; field names match (`backend`, `model`, `subagent_type`, `enabled`, `hard_threshold`, `on_panelist_error`, `max_cycles`).
- `Persona` dataclass in Task 4 (`role`, `description`, `intended_backends`, `system_prompt`, `one_shot_example`, `user_prompt_template`) matches what tests expect.
- `load_config`, `ConfigError`, `load_persona`, `load_persona_by_role`, `PersonaError` names are consistent across tasks.
- `_default_config_path()` in Task 5's cli.py is internal; the public surface (`main(argv)`) matches what `__main__.py` imports.

**Test-count math:** Phase 2 baseline = 21. Task 2 adds 14 → 35. Task 4 adds 10 → 45. Task 5 adds 5 → 50. Task 7 Step 1 expects 50. Consistent.

**Phase boundaries:** Task 5 dispatch is a stub. Phase 3b replaces the stub body with real NAT integration. No code in Phase 3a calls the stub; the test only confirms registration and the "Phase 3b" exit-code path.
