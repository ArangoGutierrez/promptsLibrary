# validate-recommendation v2 — Phase 3: Config + multi-panelist

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move panel composition out of code into `~/.claude/panel/config.json`. Default config ships with **3 panelists** (1 DA + 1 PE + 1 QA), enforcing the odd-N invariant. Generalize `dispatch-da.sh` → `dispatch-http.sh`. Refactor monolithic `personas.md` into per-role `personas/<role>.md`. Add `panel lint-config` subcommand. Aggregator updated to handle N panelists.

**Architecture:** Config-driven orchestration: SKILL.md reads `config.json`, separates panelists by backend (`http` vs `subagent`), dispatches all in parallel in a single message (Bash + Agent tool calls). Each panelist writes a verdict file under `$TMPDIR/panelist-<id>-<qhash>.verdict`. `panel aggregate` reads ALL verdict files (no longer just DA + PE).

**Tech Stack:** Bash for `dispatch-http.sh` (HTTP wrapper). Python (stdlib) for `panel.config`, `panel.personas`, generalized `panel.aggregate`. The `aggregate.sh` shim from Phase 2 is **removed** in this phase — SKILL.md calls `python3 -m panel aggregate` directly.

**Pre-flight (verify before starting):**
- Phase 2 has shipped (`python3 -m panel aggregate` works; `aggregate.sh` shim forwards to it).
- All Phase 2 pytest tests pass.
- `~/.claude/skills/validate-recommendation/personas.md` exists and contains both `## Devil's Advocate (DA)` and `## Principal Engineer (PE)` sections.

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/panel/config.json` | **Create**: default 3-panelist config (da-nemotron + pe + qa). |
| `~/.claude/skills/validate-recommendation/personas/da.md` | **Create**: DA persona, extracted from personas.md. Front-matter format. |
| `~/.claude/skills/validate-recommendation/personas/pe.md` | **Create**: PE persona, extracted from personas.md. |
| `~/.claude/skills/validate-recommendation/personas/qa.md` | **Create**: new QA persona — test-quality + verifiability reviewer. |
| `~/.claude/skills/validate-recommendation/personas.md` | **Delete** after personas/ split is verified. |
| `~/.claude/skills/validate-recommendation/dispatch-http.sh` | **Create** (renamed from `dispatch-da.sh`, generalized). Takes `--panelist-config <path>` instead of env-only config. |
| `~/.claude/skills/validate-recommendation/dispatch-da.sh` | **Delete** after `dispatch-http.sh` is verified. |
| `~/.claude/skills/validate-recommendation/dispatch-http_test.sh` | **Create** (renamed from `dispatch-da_test.sh`, updated assertions). |
| `~/.claude/skills/validate-recommendation/dispatch-da_test.sh` | **Delete** after rename. |
| `~/.claude/skills/validate-recommendation/aggregate.sh` | **Delete** (Phase 2 shim no longer needed). |
| `~/.claude/skills/validate-recommendation/panel/config.py` | **Create**: load + validate config.json. |
| `~/.claude/skills/validate-recommendation/panel/personas.py` | **Create**: parse persona files (front-matter + sections). |
| `~/.claude/skills/validate-recommendation/panel/aggregate.py` | **Modify**: accept N verdict files instead of just `--da` and `--pe`. |
| `~/.claude/skills/validate-recommendation/panel/cli.py` | **Modify**: `aggregate` subcommand takes `--verdicts <path> [<path> ...]`. Add `lint-config` subcommand. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_config.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_personas.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py` | **Modify**: add tests for N-panelist cases. |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify**: config-driven N-panelist orchestration; document new state file path for `--verdicts`. |

---

## Tasks

### Task 1: Create `personas/da.md` (extracted from personas.md)

**Files:**
- Create: `~/.claude/skills/validate-recommendation/personas/da.md`

- [ ] **Step 1: Make the personas directory**

Run: `mkdir -p ~/.claude/skills/validate-recommendation/personas`

- [ ] **Step 2: Write `personas/da.md`**

```markdown
---
role: DA
description: Adversarial reviewer — finds the strongest counter-argument
intended_backends: [http]
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
RATIONALE: <one paragraph, 3-5 sentences explaining what you considered and why no stronger counter exists>
ALTERNATIVE: n/a

For OVERTURN:
VERDICT: OVERTURN
RATIONALE: <one paragraph, 3-5 sentences naming the specific flaw>
ALTERNATIVE: <verbatim option label from the prompt>

The ALTERNATIVE value MUST be a literal copy of one of the option
labels supplied to you. Do not abbreviate. Do not paraphrase. Do not
invent new options not in the list.

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
RATIONALE: After examining the alternatives, no stronger counter found. The stdlib client meets the stated goal of minimizing dependencies. Option B's retries can be added via a small wrapper when needed; Option C breaks compatibility with stdlib middleware, a cost not justified by the stated requirements. The recommendation stands.
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

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add personas/da.md
git commit -s -S -m "feat(panel): personas/da.md (DA persona, front-matter format)"
```

---

### Task 2: Create `personas/pe.md`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/personas/pe.md`

- [ ] **Step 1: Write `personas/pe.md`**

```markdown
---
role: PE
description: Principal-engineer reviewer — checks recommendation against ~/.claude/CLAUDE.md and ~/.claude/rules/
intended_backends: [subagent]
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
RATIONALE: <one paragraph, 3-5 sentences citing which principles you checked and why the recommendation is acceptable>
ALTERNATIVE: n/a

For OVERTURN:
VERDICT: OVERTURN
RATIONALE: <one paragraph, 3-5 sentences naming the principle violated>
ALTERNATIVE: <verbatim option label from the list>

The ALTERNATIVE value MUST be a literal copy of one of the option
labels. Do not abbreviate or paraphrase.

# One-shot example

(omitted — PE-subagent receives full CLAUDE.md context via tool access; one-shot anchoring is less critical than for HTTP-backed panelists)

# User prompt template

Question: <question text>
Options (verbatim labels and descriptions):
  <label 1> — <description 1>
  <label 2> — <description 2>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <extracted reasoning or "(no reasoning supplied)">
```

- [ ] **Step 2: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add personas/pe.md
git commit -s -S -m "feat(panel): personas/pe.md (PE persona, front-matter format)"
```

---

### Task 3: Create `personas/qa.md` (new role)

**Files:**
- Create: `~/.claude/skills/validate-recommendation/personas/qa.md`

- [ ] **Step 1: Write `personas/qa.md`**

```markdown
---
role: QA
description: QA-engineer reviewer — test quality, verifiability, observability of failure modes
intended_backends: [subagent]
---

# System prompt

You are a QA-Engineer reviewer. You evaluate a recommendation against
test-quality principles. Would the recommendation be testable in
practice? Would tests written against this option actually fail when
the implementation breaks, or would they be theater?

USE YOUR TOOLS (Read, Grep, Glob) to consult
~/.claude/rules/constitution.md (especially the "Theater Tests" and
"Test Quality Gate" sections) when judging the recommendation.

Evaluate against:

- **Theater tests risk**: would tests written for this option be
  tautological (asserting `x == x`), over-mocked (mocking the actual
  layer under test), or duplicate the implementation's logic in the
  test (testing nothing)?
- **Verifiability**: can the recommendation's behavior be asserted with
  literal expected values, or only by mirroring the implementation in
  the test?
- **Failure observability**: are failures of this option detectable
  through tests, logs, traces, or other ops signals?
- **Test-contract integrity**: would adopting this option encourage
  modifying tests to fit implementation later — a constitution
  violation?

If the recommendation is testable and verifiable, output HOLD.
If it has serious test-quality problems, output OVERTURN with a
specific alternative that is more verifiable.

Two possible verdicts:

- VERDICT: HOLD — recommendation is testable and observable; no
  test-quality concern significant enough to overturn.
- VERDICT: OVERTURN — the option is untestable, encourages theater
  tests, or hides failure modes; a specific alternative from the list
  is more verifiable.

Output ONLY this strict format. No preamble. No markdown fencing.

For HOLD:
VERDICT: HOLD
RATIONALE: <one paragraph, 3-5 sentences naming test-quality factors and why the recommendation is acceptable>
ALTERNATIVE: n/a

For OVERTURN:
VERDICT: OVERTURN
RATIONALE: <one paragraph, 3-5 sentences naming the test-quality concern>
ALTERNATIVE: <verbatim option label from the list>

ALTERNATIVE must be a literal option label. Do not abbreviate or paraphrase.

# One-shot example

(omitted — QA subagent receives constitution.md via tool access)

# User prompt template

Question: <question text>
Options (verbatim labels and descriptions):
  <label 1> — <description 1>
  <label 2> — <description 2>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <extracted reasoning or "(no reasoning supplied)">
```

- [ ] **Step 2: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add personas/qa.md
git commit -s -S -m "feat(panel): personas/qa.md (new QA reviewer role)

Default v2 panel composition is 1 DA + 1 PE + 1 QA. The QA reviewer
checks for theater tests, verifiability, and failure observability —
extending the panel beyond DA's adversarial framing and PE's
principles-compliance framing."
```

---

### Task 4: Failing test for `panel/personas.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_personas.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.personas — parse persona files with front-matter."""
from pathlib import Path


def test_load_da_persona(monkeypatch):
    from panel.personas import load_persona
    p = load_persona("da")
    assert p.role == "DA"
    assert "devil's-advocate" in p.system_prompt.lower()
    assert "VERDICT: HOLD" in p.system_prompt or "VERDICT: HOLD" in p.one_shot
    assert "<question text>" in p.user_prompt_template


def test_load_pe_persona():
    from panel.personas import load_persona
    p = load_persona("pe")
    assert p.role == "PE"
    assert "~/.claude/CLAUDE.md" in p.system_prompt or "~/.claude/rules/" in p.system_prompt


def test_load_qa_persona():
    from panel.personas import load_persona
    p = load_persona("qa")
    assert p.role == "QA"
    assert "theater" in p.system_prompt.lower() or "test quality" in p.system_prompt.lower()


def test_missing_persona_raises():
    from panel.personas import load_persona, PersonaNotFound
    try:
        load_persona("nonexistent")
        assert False, "expected PersonaNotFound"
    except PersonaNotFound:
        pass


def test_build_full_prompt_combines_sections():
    """The 'full prompt' (used as system message) combines system_prompt + one-shot."""
    from panel.personas import load_persona
    p = load_persona("da")
    full = p.build_system_message()
    assert "devil's-advocate" in full.lower()
    # Sections are joined with a delimiter — body must contain both.
    assert len(full) > len(p.system_prompt)
```

- [ ] **Step 2: Run — should FAIL**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_personas.py -v`
Expected: ModuleNotFoundError for `panel.personas`.

---

### Task 5: Implement `panel/personas.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/personas.py`

- [ ] **Step 1: Write `personas.py`**

```python
"""Load and parse persona files.

Each persona file is a Markdown document with YAML-ish front-matter:

    ---
    role: DA
    description: ...
    intended_backends: [http]
    ---

    # System prompt
    ...

    # One-shot example
    ...

    # User prompt template
    ...

This module returns a `Persona` object with system_prompt, one_shot,
and user_prompt_template strings. `build_system_message()` concatenates
system_prompt + one_shot (the combined system message sent to the
backend).
"""
from __future__ import annotations
import re
from dataclasses import dataclass
from pathlib import Path

PERSONAS_DIR = Path(__file__).resolve().parent.parent / "personas"


class PersonaNotFound(Exception):
    pass


@dataclass
class Persona:
    role: str
    description: str
    intended_backends: list[str]
    system_prompt: str
    one_shot: str
    user_prompt_template: str

    def build_system_message(self) -> str:
        """Return the text that becomes the chat-completions system message."""
        parts = [self.system_prompt.strip()]
        if self.one_shot.strip():
            parts.append(self.one_shot.strip())
        return "\n\n".join(parts)


_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_SECTION_RE = re.compile(r"^# (.+?)$", re.MULTILINE)


def _parse_frontmatter(text: str) -> tuple[dict, str]:
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    raw = m.group(1)
    body = text[m.end():]
    fm: dict[str, object] = {}
    for line in raw.split("\n"):
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        # Tiny YAML subset: lists like `[a, b, c]`, bare strings, scalars.
        if value.startswith("[") and value.endswith("]"):
            fm[key] = [v.strip() for v in value[1:-1].split(",") if v.strip()]
        else:
            fm[key] = value
    return fm, body


def _split_sections(body: str) -> dict[str, str]:
    """Split a markdown body on `# <Heading>` boundaries.

    Returns dict mapping heading → body-after-heading-until-next-heading.
    """
    sections: dict[str, str] = {}
    matches = list(_SECTION_RE.finditer(body))
    for i, m in enumerate(matches):
        heading = m.group(1).strip()
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        sections[heading] = body[start:end].strip()
    return sections


def load_persona(role: str) -> Persona:
    """Load and parse the persona file for `role` (lowercase, e.g., 'da').

    Raises PersonaNotFound if the file is missing.
    """
    path = PERSONAS_DIR / f"{role.lower()}.md"
    if not path.is_file():
        raise PersonaNotFound(f"persona file missing: {path}")
    text = path.read_text(encoding="utf-8")
    fm, body = _parse_frontmatter(text)
    sections = _split_sections(body)
    return Persona(
        role=fm.get("role", role.upper()),
        description=fm.get("description", ""),
        intended_backends=fm.get("intended_backends", []),
        system_prompt=sections.get("System prompt", ""),
        one_shot=sections.get("One-shot example", ""),
        user_prompt_template=sections.get("User prompt template", ""),
    )
```

- [ ] **Step 2: Run tests — should PASS**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_personas.py -v`
Expected: 5 tests pass.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/personas.py panel/tests/test_personas.py
git commit -s -S -m "feat(panel): personas.py loads per-role persona files"
```

---

### Task 6: Failing test for `panel/config.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_config.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.config — load and validate ~/.claude/panel/config.json."""
import json


def test_load_valid_default_config(tmp_path):
    from panel.config import load_config
    cfg_path = tmp_path / "config.json"
    cfg_path.write_text(json.dumps({
        "version": "1",
        "panelists": [
            {"id": "da-nemotron", "role": "DA", "backend": "http",
             "endpoint_env": "CLAUDE_PANEL_DA_ENDPOINT",
             "api_key_env": "PANEL_DA_API_KEY",
             "model_env": "CLAUDE_PANEL_DA_MODEL"},
            {"id": "pe", "role": "PE", "backend": "subagent",
             "subagent_type": "principal-engineer"},
            {"id": "qa", "role": "QA", "backend": "subagent",
             "subagent_type": "qa-engineer"},
        ],
        "severity": {"hard_threshold": "majority",
                     "rationale_gate": {"requires_principle_or_alternative": True}},
        "failure_mode": {"on_panelist_error": "auto"},
        "re_brainstorm": {"enabled": True, "max_cycles": 2},
        "telemetry": {"enabled": True, "decisions_jsonl": "~/.claude/panel/decisions.jsonl"},
    }))
    cfg = load_config(cfg_path)
    assert len(cfg.panelists) == 3


def test_reject_even_panelist_count(tmp_path):
    """Odd-N invariant is enforced at config-load time."""
    from panel.config import load_config, ConfigError
    cfg_path = tmp_path / "config.json"
    cfg_path.write_text(json.dumps({
        "version": "1",
        "panelists": [
            {"id": "da", "role": "DA", "backend": "http",
             "endpoint_env": "X", "api_key_env": "Y", "model_env": "Z"},
            {"id": "pe", "role": "PE", "backend": "subagent",
             "subagent_type": "principal-engineer"},
        ],
    }))
    try:
        load_config(cfg_path)
        assert False, "expected ConfigError for even N"
    except ConfigError as e:
        assert "odd" in str(e).lower()


def test_reject_zero_panelists(tmp_path):
    from panel.config import load_config, ConfigError
    cfg_path = tmp_path / "config.json"
    cfg_path.write_text(json.dumps({"version": "1", "panelists": []}))
    try:
        load_config(cfg_path)
        assert False, "expected ConfigError for empty panelists"
    except ConfigError:
        pass


def test_reject_invalid_backend(tmp_path):
    from panel.config import load_config, ConfigError
    cfg_path = tmp_path / "config.json"
    cfg_path.write_text(json.dumps({
        "version": "1",
        "panelists": [
            {"id": "x", "role": "DA", "backend": "unknown-backend"},
        ],
    }))
    try:
        load_config(cfg_path)
        assert False, "expected ConfigError for unknown backend"
    except ConfigError:
        pass


def test_default_paths_for_missing_optional_sections(tmp_path):
    """Optional sections (severity, failure_mode, telemetry, re_brainstorm) get defaults."""
    from panel.config import load_config
    cfg_path = tmp_path / "config.json"
    cfg_path.write_text(json.dumps({
        "version": "1",
        "panelists": [
            {"id": "da", "role": "DA", "backend": "http",
             "endpoint_env": "X", "api_key_env": "Y", "model_env": "Z"},
            {"id": "pe", "role": "PE", "backend": "subagent",
             "subagent_type": "principal-engineer"},
            {"id": "qa", "role": "QA", "backend": "subagent",
             "subagent_type": "qa-engineer"},
        ],
    }))
    cfg = load_config(cfg_path)
    assert cfg.severity.hard_threshold == "majority"
    assert cfg.failure_mode.on_panelist_error == "auto"
    assert cfg.re_brainstorm.max_cycles == 2
```

- [ ] **Step 2: Run — should FAIL**

---

### Task 7: Implement `panel/config.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/config.py`

- [ ] **Step 1: Write `config.py`**

```python
"""Load and validate ~/.claude/panel/config.json.

Defines the in-memory config schema and validation rules. The odd-N
invariant is enforced here so it can't be bypassed by callers.
"""
from __future__ import annotations
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

VALID_BACKENDS = {"http", "subagent"}
VALID_HARD_THRESHOLDS = {"majority", "supermajority"}
VALID_FAILURE_MODES = {"strict", "graceful", "auto"}


class ConfigError(Exception):
    pass


@dataclass
class Panelist:
    id: str
    role: str
    backend: Literal["http", "subagent"]
    # http-only
    endpoint_env: str = ""
    api_key_env: str = ""
    model_env: str = ""
    max_tokens: int = 4096
    temperature: float = 0.3
    timeout_seconds: int = 60
    # subagent-only
    subagent_type: str = ""


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
    enabled: bool = True
    decisions_jsonl: str = "~/.claude/panel/decisions.jsonl"


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
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ConfigError(f"config JSON parse error: {e}") from e

    panelists_raw = raw.get("panelists") or []
    if len(panelists_raw) == 0:
        raise ConfigError("config: panelists must be non-empty")
    if len(panelists_raw) % 2 == 0:
        raise ConfigError(
            f"config: panelist count must be odd (got {len(panelists_raw)}). "
            "Even N produces tie-prone votes; the odd-N invariant is required."
        )

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
            backend=backend,
            endpoint_env=p.get("endpoint_env", ""),
            api_key_env=p.get("api_key_env", ""),
            model_env=p.get("model_env", ""),
            max_tokens=int(p.get("max_tokens", 4096)),
            temperature=float(p.get("temperature", 0.3)),
            timeout_seconds=int(p.get("timeout_seconds", 60)),
            subagent_type=p.get("subagent_type", ""),
        ))

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
        raise ConfigError(
            f"failure_mode.on_panelist_error must be one of {sorted(VALID_FAILURE_MODES)}"
        )

    rb_raw = raw.get("re_brainstorm", {})
    re_brainstorm = ReBrainstorm(
        enabled=rb_raw.get("enabled", True),
        max_cycles=int(rb_raw.get("max_cycles", 2)),
    )
    if not (0 <= re_brainstorm.max_cycles <= 5):
        raise ConfigError("re_brainstorm.max_cycles must be in [0, 5]")

    tel_raw = raw.get("telemetry", {})
    telemetry = Telemetry(
        enabled=tel_raw.get("enabled", True),
        decisions_jsonl=tel_raw.get("decisions_jsonl", "~/.claude/panel/decisions.jsonl"),
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

- [ ] **Step 2: Run tests — should PASS**

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/config.py panel/tests/test_config.py
git commit -s -S -m "feat(panel): config.py — load+validate config.json with odd-N invariant"
```

---

### Task 8: Add `lint-config` CLI subcommand

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

- [ ] **Step 1: Extend `cli.py`'s subparser table**

In `cli.py`, add a new subparser after the `aggregate` block:

```python
    lint = sub.add_parser("lint-config", help="Validate the panel config")
    lint.add_argument("--config", default="~/.claude/panel/config.json",
                      help="Path to config.json (default: ~/.claude/panel/config.json)")
```

And add a new dispatch branch:

```python
    if args.cmd == "lint-config":
        from panel.config import load_config, ConfigError
        try:
            cfg = load_config(args.config)
            print(f"OK: {len(cfg.panelists)} panelists configured")
            for p in cfg.panelists:
                print(f"  - {p.id} (role={p.role}, backend={p.backend})")
            return 0
        except ConfigError as e:
            print(f"CONFIG ERROR: {e}", file=sys.stderr)
            return 1
```

- [ ] **Step 2: Manual smoke test**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m panel lint-config --config /dev/null`
Expected: prints `CONFIG ERROR: config file missing: /dev/null` to stderr, exits 1.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/cli.py
git commit -s -S -m "feat(panel): add lint-config subcommand"
```

---

### Task 9: Ship default `~/.claude/panel/config.json`

**Files:**
- Create: `~/.claude/panel/config.json`

- [ ] **Step 1: Make the directory and file**

```bash
mkdir -p ~/.claude/panel
```

Then write `~/.claude/panel/config.json`:

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
    "rationale_gate": { "requires_principle_or_alternative": true }
  },
  "failure_mode": { "on_panelist_error": "auto" },
  "re_brainstorm": { "enabled": true, "max_cycles": 2 },
  "telemetry": { "enabled": true, "decisions_jsonl": "~/.claude/panel/decisions.jsonl" }
}
```

- [ ] **Step 2: Verify with lint-config**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m panel lint-config`
Expected stdout:
```
OK: 3 panelists configured
  - da-nemotron (role=DA, backend=http)
  - pe (role=PE, backend=subagent)
  - qa (role=QA, backend=subagent)
```

---

### Task 10: Generalize `dispatch-da.sh` → `dispatch-http.sh`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/dispatch-http.sh` (copy + modify from `dispatch-da.sh`)

- [ ] **Step 1: Copy and rename**

```bash
cd ~/.claude/skills/validate-recommendation
cp dispatch-da.sh dispatch-http.sh
chmod +x dispatch-http.sh
```

- [ ] **Step 2: Update `dispatch-http.sh` CLI surface**

Open `dispatch-http.sh`. Replace the CLI argument parsing block and the env-var resolution block:

Find the existing argument parsing (`PROMPT_FILE=""; OUTPUT=""; while [ $# -gt 0 ]; do case "$1" in ...`). Replace with:

```bash
PROMPT_FILE=""
OUTPUT=""
PERSONA_FILE=""
ENDPOINT=""
API_KEY=""
MODEL=""
MAX_TOKENS="4096"
TEMPERATURE="0.3"
TIMEOUT="60"

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)    PROMPT_FILE="$2"; shift 2 ;;
        --output)         OUTPUT="$2"; shift 2 ;;
        --persona-file)   PERSONA_FILE="$2"; shift 2 ;;
        --endpoint)       ENDPOINT="$2"; shift 2 ;;
        --api-key-env)    eval "API_KEY=\${$2:-}"; shift 2 ;;
        --model)          MODEL="$2"; shift 2 ;;
        --max-tokens)     MAX_TOKENS="$2"; shift 2 ;;
        --temperature)    TEMPERATURE="$2"; shift 2 ;;
        --timeout)        TIMEOUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 --prompt-file <path> --output <path> --persona-file <path> --endpoint <url> --api-key-env <varname> --model <id> [--max-tokens N] [--temperature F] [--timeout N]" >&2
            exit 1
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$PROMPT_FILE" ] || [ -z "$OUTPUT" ] || [ -z "$PERSONA_FILE" ] || [ -z "$ENDPOINT" ] || [ -z "$API_KEY" ] || [ -z "$MODEL" ]; then
    echo "Missing required arg. Usage: $0 --prompt-file <path> --output <path> --persona-file <path> --endpoint <url> --api-key-env <varname> --model <id>" >&2
    exit 1
fi

# Persona file must exist; read it as the system message.
if [ ! -r "$PERSONA_FILE" ]; then
    write_error "persona file unreadable: $PERSONA_FILE"
fi
# Slice out everything between '# System prompt' and '# User prompt template'.
# Same logic as dispatch-da.sh's extract_da_system_prompt, generalized.
SYSTEM_PROMPT=$(awk '
    /^# User prompt template/ { exit }
    /^# (System prompt|One-shot example)/ { capture=1; next }
    capture && /^# / { capture=0 }
    capture { print }
' "$PERSONA_FILE")
if [ -z "$SYSTEM_PROMPT" ]; then
    write_error "failed to extract system prompt from $PERSONA_FILE"
fi
```

(Remove the old `extract_da_system_prompt` function and the env-var resolution block they replaced.)

- [ ] **Step 3: Update payload builder to use `MAX_TOKENS` arg**

Find the payload `jq -n` block. Replace `--argjson max_tokens "$MAX_TOKENS"` line to use the CLI value (already named `$MAX_TOKENS`). Confirm the system message uses `$SYSTEM_PROMPT`. Update temperature to use `--argjson temperature "$TEMPERATURE"`.

- [ ] **Step 4: Verify it loads without error**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-http.sh --help 2>&1 | head -3`
Expected: usage line printed.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add dispatch-http.sh
git commit -s -S -m "feat(panel): dispatch-http.sh — generalized HTTP panelist dispatcher

Renamed and generalized from dispatch-da.sh. Now takes:
  --persona-file <path>  : the persona file (was hardcoded personas.md DA section)
  --endpoint <url>       : the chat-completions URL (was env-only)
  --api-key-env <var>    : env-var name holding the bearer token
  --model <id>           : model identifier (was env-only)
  --max-tokens N         : configurable per panelist
Per-panelist config replaces the global env-var triple. Persona file
is sliced for system prompt + one-shot at call time."
```

---

### Task 11: Extend dispatch-http_test.sh

**Files:**
- Create: `~/.claude/skills/validate-recommendation/dispatch-http_test.sh` (copy from `dispatch-da_test.sh`, update for new CLI)

- [ ] **Step 1: Copy and update**

```bash
cd ~/.claude/skills/validate-recommendation
cp dispatch-da_test.sh dispatch-http_test.sh
chmod +x dispatch-http_test.sh
```

- [ ] **Step 2: Update tests for new CLI**

In `dispatch-http_test.sh`, find each test's dispatcher invocation. Replace env-var setup with `--endpoint`, `--api-key-env`, `--model`, `--persona-file` flags. Specifically:

Replace `DISPATCH="$SCRIPT_DIR/dispatch-da.sh"` with `DISPATCH="$SCRIPT_DIR/dispatch-http.sh"`.

Add a fixed persona file path used by all tests:
```bash
PERSONA="$SCRIPT_DIR/personas/da.md"
```

Update every dispatcher call to include `--persona-file "$PERSONA" --endpoint "$CLAUDE_PANEL_DA_ENDPOINT" --api-key-env PANEL_DA_API_KEY --model "$CLAUDE_PANEL_DA_MODEL"`.

(For tests checking missing-env, change the assertion: the CLI now uses `--api-key-env` so the env var name is explicit; tests should unset the named env var, not the literal `PANEL_DA_API_KEY`.)

- [ ] **Step 3: Run the test suite**

Run: `cd ~/.claude/skills/validate-recommendation && bash dispatch-http_test.sh`
Expected: `PASS` at the end.

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add dispatch-http_test.sh
git commit -s -S -m "test(panel): dispatch-http_test.sh updated for new CLI"
```

---

### Task 12: Generalize `panel aggregate` to N panelists

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/aggregate.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py`

- [ ] **Step 1: Update test file to cover 3-panelist case**

In `panel/tests/test_aggregate.py`, append:

```python
def test_three_panelists_all_hold(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate_n
    qa_hold = tmp_path / "qa_hold.txt"
    qa_hold.write_text("VERDICT: HOLD\nRATIONALE: QA found no theater-test risk in Option A.\nALTERNATIVE: n/a\n")
    out = aggregate_n(
        [str(fixtures_dir / "da_hold.txt"), str(fixtures_dir / "pe_hold.txt"), str(qa_hold)],
        "Option A",
    )
    assert "PANEL_VERDICT: HOLD" in out


def test_three_panelists_one_overturn(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate_n
    qa_hold = tmp_path / "qa_hold.txt"
    qa_hold.write_text("VERDICT: HOLD\nRATIONALE: QA found no theater-test risk.\nALTERNATIVE: n/a\n")
    out = aggregate_n(
        [str(fixtures_dir / "da_overturn_b.txt"), str(fixtures_dir / "pe_hold.txt"), str(qa_hold)],
        "Option A",
    )
    # Phase 3: minority OVERTURN still → DISSENT (severity tiers come in Phase 4).
    assert "PANEL_VERDICT: DISSENT" in out
```

- [ ] **Step 2: Add `aggregate_n` to `panel/aggregate.py`**

Append to `aggregate.py`:

```python
def aggregate_n(verdict_paths: list[str], recommended_label: str) -> str:
    """Aggregate N verdict files into a Phase-3 directive.

    Phase 3 semantics (pre-severity-tiers):
      - All HOLD → PANEL_VERDICT: HOLD with per-panelist abbreviated rationales.
      - Any OVERTURN → PANEL_VERDICT: DISSENT with sanitized Panel review line.
      - Any malformed verdict → PANEL_VERDICT: ERROR.

    Phase 4 will replace this with severity-tiered logic.
    """
    verdicts = [parse_verdict_file(p) for p in verdict_paths]

    # Validation.
    for i, v in enumerate(verdicts):
        if v.verdict not in ("HOLD", "OVERTURN"):
            log_verdict("ERROR", f"panelist[{i}] verdict unparseable")
            return f"PANEL_VERDICT: ERROR\npanelist[{i}] verdict unparseable"
        if not v.rationale:
            log_verdict("ERROR", f"panelist[{i}] rationale missing")
            return f"PANEL_VERDICT: ERROR\npanelist[{i}] rationale missing"

    holds = [v for v in verdicts if v.verdict == "HOLD"]
    overturns = [v for v in verdicts if v.verdict == "OVERTURN"]

    if not overturns:
        # All HOLD.
        lines = ["PANEL_VERDICT: HOLD"]
        for i, v in enumerate(verdicts):
            short = _abbreviate_first_sentence(v.rationale)
            lines.append(f"P{i+1}: {short}")
        log_verdict("HOLD", " | ".join(f"P{i+1}: {_abbreviate_first_sentence(v.rationale)}" for i, v in enumerate(verdicts)))
        return "\n".join(lines)

    # DISSENT.
    pieces = ["**Panel review:** "]
    for i, v in enumerate(verdicts):
        rat = strip_markdown(v.rationale)
        if v.verdict == "OVERTURN":
            alt = strip_markdown(v.alternative)
            pieces.append(f"P{i+1} flagged {recommended_label} → suggests {alt}: {rat} ")
        else:
            pieces.append(f"P{i+1} held {recommended_label}: {rat} ")
    summary = "".join(pieces).rstrip()
    alts_log = "/".join(v.alternative or "n/a" for v in verdicts)
    verdicts_log = " ".join(f"P{i+1}={v.verdict}" for i, v in enumerate(verdicts))
    log_verdict("DISSENT", f"{verdicts_log} alts={alts_log}")
    return f"PANEL_VERDICT: DISSENT\n{summary}"
```

(Keep the old `aggregate()` 2-panelist function alongside `aggregate_n()` for one release. Phase 4 deletes the old one.)

- [ ] **Step 3: Update CLI's `aggregate` subcommand to accept `--verdicts`**

In `cli.py`, change the `aggregate` argparser block from:

```python
    agg.add_argument("--da", required=True, ...)
    agg.add_argument("--pe", required=True, ...)
```

To:

```python
    agg.add_argument("--verdicts", required=True, nargs="+",
                     help="Paths to N panelist verdict files (any order)")
```

Change the dispatch branch to:

```python
    if args.cmd == "aggregate":
        from panel.aggregate import aggregate_n
        print(aggregate_n(args.verdicts, args.recommended_label))
        return 0
```

- [ ] **Step 4: Run pytest**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v`
Expected: all tests (including new N-panelist tests) pass.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/aggregate.py panel/cli.py panel/tests/test_aggregate.py
git commit -s -S -m "feat(panel): aggregate handles N panelists via --verdicts

Adds aggregate_n() alongside the legacy 2-panelist aggregate().
CLI surface changes: 'panel aggregate' now takes --verdicts <path>...
instead of --da/--pe. SKILL.md updated next."
```

---

### Task 13: Update `SKILL.md` for config-driven, N-panelist orchestration

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/SKILL.md`

This is a substantial rewrite of SKILL.md. The high-level changes:

1. Skill reads `~/.claude/panel/config.json` at startup.
2. For each panelist in config, build a per-panelist prompt body (templated user message).
3. Separate panelists by backend: HTTP-backed → Bash tool call to `dispatch-http.sh`; subagent-backed → Agent tool call.
4. Issue ALL panelist calls in a single message (parallel dispatch).
5. After all return, write subagent responses to verdict files (HTTP responses are already on disk via the shell script).
6. Run `python3 -m panel aggregate --verdicts <path> ... --recommended-label <label>`.
7. Act on directive.

- [ ] **Step 1: Replace the "Per-question dispatch" section in SKILL.md**

In `SKILL.md`, find `## Per-question dispatch`. Replace its entire body (down to but not including the next `##` heading) with the content shown below. The exact text to insert is long; produce it as a Markdown block and write to the file. Refer to the spec document at `docs/superpowers/specs/2026-05-14-validate-recommendation-redesign-design.md` ("Component responsibilities" + "Configuration" sections) for the canonical phrasing; mirror that language in SKILL.md so the two documents stay aligned.

The new SKILL.md "Per-question dispatch" section should cover, in order:

1. Read `~/.claude/panel/config.json` via the `panel lint-config` subcommand first (fail-open: if config invalid, fall back to original AskUserQuestion).
2. For each question in `tool_input.questions` with a `(Recommended)` option not already Panel-flagged:
   a. Compute `question_id` = sha256(question_text + sorted normalized option labels)[:16].
   b. For each panelist in config:
      - Load persona via `python3 -c "from panel.personas import load_persona; print(load_persona('<role>').build_system_message())"` — or call `dispatch-http.sh` which loads persona itself.
      - Build templated user prompt body (question + options + recommended label + reasoning).
      - HTTP panelists: write prompt body to `$TMPDIR/panelist-<id>-<qhash>.user.txt`. Call `dispatch-http.sh` with the panelist's config fields as CLI args.
      - Subagent panelists: invoke `Agent` tool with `subagent_type=<subagent_type>`, prompt=system+one-shot+templated_body.
   c. Dispatch all panelists in a SINGLE message (one Bash per HTTP panelist + one Agent per subagent panelist).
   d. For subagent panelists, write the returned Agent response to `$TMPDIR/panelist-<id>-<qhash>.verdict`.
   e. Call `python3 -m panel aggregate --verdicts $TMPDIR/panelist-*-<qhash>.verdict --recommended-label "<label>" --question-id <qhash>`.
   f. Capture stdout — that's the directive.
3. Acting on directives: keep the existing HOLD / DISSENT / ERROR semantics for Phase 3. Phase 4 introduces SOFT-DISSENT / HARD-DISSENT branches.

- [ ] **Step 2: Add a Configuration section to SKILL.md**

Add a new top-level section near the top of SKILL.md (after Inputs):

```markdown
## Configuration

The skill reads `~/.claude/panel/config.json` to determine which panelists to dispatch. See the v2 redesign spec for the schema. Each session, before dispatching, the skill validates the config via:

    python3 -m panel lint-config

If the config is missing or invalid, the skill emits a user-visible note ("panel disabled: config invalid; asking the original question") and falls back to issuing the original `AskUserQuestion` unmodified.
```

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add SKILL.md
git commit -s -S -m "docs(panel): SKILL.md — config-driven N-panelist orchestration"
```

---

### Task 14: Remove deprecated files

**Files:**
- Delete: `~/.claude/skills/validate-recommendation/dispatch-da.sh`
- Delete: `~/.claude/skills/validate-recommendation/dispatch-da_test.sh`
- Delete: `~/.claude/skills/validate-recommendation/aggregate.sh`
- Delete: `~/.claude/skills/validate-recommendation/personas.md`

- [ ] **Step 1: Run all tests one more time to confirm nothing references the deprecated files**

```bash
cd ~/.claude/skills/validate-recommendation
python3 -m pytest panel/ -v
bash dispatch-http_test.sh
python3 -m panel lint-config
```

All three must pass.

- [ ] **Step 2: Delete the deprecated files**

```bash
cd ~/.claude/skills/validate-recommendation
git rm dispatch-da.sh dispatch-da_test.sh aggregate.sh personas.md
```

- [ ] **Step 3: Commit**

```bash
git commit -s -S -m "chore(panel): remove v1 dispatch-da.sh, aggregate.sh, monolithic personas.md

All functionality migrated to:
  - dispatch-http.sh (generalized dispatcher)
  - panel/aggregate.py (Python aggregator, no shim needed)
  - personas/<role>.md (per-role persona files)"
```

---

### Task 15: Phase 3 end-to-end verification

- [ ] **Step 1: Full pytest suite**

`cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v` — expect all pass.

- [ ] **Step 2: Shell test suite**

`bash dispatch-http_test.sh` — expect PASS.

- [ ] **Step 3: Live invocation**

Trigger `AskUserQuestion` with a `(Recommended)` option. Inspect trace log: expect three panelists invoked (da-nemotron + pe + qa) and a single PANEL_VERDICT outcome.

If only 1-2 panelists run, the SKILL.md orchestration isn't reading config properly. Re-check Task 13.

- [ ] **Step 4: Phase 3 sign-off**

When all three steps pass with a 3-panelist run visible in the trace log, Phase 3 is done. Next: Phase 4 — severity tiers.

---

## Self-review

**Spec coverage**: Phase 3 in the spec maps to Tasks 1-15. Personas split (1-3), persona loader (4-5), config loader (6-7), lint-config (8), default config shipped (9), dispatcher generalized (10-11), aggregator generalized (12), SKILL.md updated (13), cleanup (14), verification (15).

**Placeholder scan**: Task 13 step 1 is intentionally less prescriptive than other steps — SKILL.md is a freeform document and the exact phrasing is a judgment call. The bullet list of required content removes ambiguity about WHAT goes in the section.

**Type consistency**: `Panelist`, `Config`, `Severity`, `RationaleGate`, `FailureMode`, `ReBrainstorm`, `Telemetry` dataclass names match across Tasks 6 and 7. `aggregate_n` function name used in Tasks 12 and 13 consistently. `load_persona` function name used in Tasks 4-5. Persona file format (front-matter + `# System prompt` + `# One-shot example` + `# User prompt template`) consistent across Tasks 1-3, 5, and 10.
