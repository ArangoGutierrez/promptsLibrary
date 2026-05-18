# validate-recommendation v3.1 — Phase 3b: NAT Builder dispatch

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `panel/dispatch.py` — the NAT-Builder-backed dispatcher that replaces Phase 3a's CLI stub. Each `nat-*` panelist invokes `python -m panel dispatch`, which internally uses NAT 1.6's `NIMModelConfig` / `AnthropicModelConfig` / `OpenAIModelConfig` + `Builder` + `register_llm_provider` pattern. The single mockable seam is `_invoke_nat(panelist, system, user) -> object`. All runtime failures land as `VERDICT: ERROR` verdict files; the file is always written (exit 0). SKILL.md still uses v1's `dispatch-da.sh` at runtime; Phase 3c does the cutover.

**Architecture:** One new Python module (`panel/dispatch.py`) with one mockable seam. The implementation uses NAT's Builder pattern: per-dispatch, construct a `Builder`, register the panelist's `*ModelConfig`, retrieve the configured LLM, invoke with `[{role, content}, ...]` messages. Tests mock at `_invoke_nat` only; below that lies NAT (and below NAT, real HTTP). Test count, error-handling matrix, and CLI surface match the superseded v3 plan; only the body of `_invoke_nat` changes.

**Tech Stack:** Python 3.12 (`/opt/homebrew/bin/python3.12`), `nvidia-nat` (==1.6.0, installed via `pip install --user --break-system-packages`). Tests run via `~/.local/pipx/venvs/pytest/bin/pytest` direct path — NOT `pipx run pytest` (creates ephemeral venvs without injects).

**Spec:** Primary — `docs/superpowers/specs/2026-05-18-validate-recommendation-v3.1-nat-heavy-amendment.md`. Underlying — `docs/superpowers/specs/2026-05-15-validate-recommendation-v3-nat-native-design.md` (sections not amended by v3.1 still apply).

**Supersedes:** `docs/superpowers/plans/2026-05-18-validate-recommendation-v3-phase3b-nat-dispatch.md` (commit `c7ee8d6`).

**Pre-flight context:**
- Phase 3a shipped on `~/.claude/` main: `panel/{config,personas,cli}.py` + `personas/{da,pe,qa}.md` + `~/.claude/panel/config.yml`. 60 tests pass via `~/.local/pipx/venvs/pytest/bin/pytest`.
- `nvidia-nat==1.6.0` already installed in `/opt/homebrew/bin/python3.12` user-site (Phase 3b Task 1 already done in the superseded plan execution). `import nat` works; `nat.llm.nim_llm.NIMModelConfig` is the entry point.
- `~/.claude/` git repo enforces signed commits (`-s` DCO sign-off + `-S` GPG signature).
- Legacy v1 `dispatch-da.sh + aggregate_test.sh + dispatch-da_test.sh` all pass; remain the runtime path until Phase 3c.
- The `panel/personas.py` loader composes a system prompt via `persona.system_prompt + persona.one_shot_example` and a user prompt body from `--prompt-file`. dispatch.py reuses this composition.

---

## File Structure

Tasks land into `/Users/eduardoa/.claude/`:

| File | Disposition | Responsibility |
|---|---|---|
| `skills/validate-recommendation/panel/dispatch.py` | **Create** | `dispatch()` CLI entry; `_invoke_nat()` NAT-Builder seam; `_extract_content()`, `_format_verdict()`, `_write_verdict_file()` helpers; ERROR-fallback wrapping. |
| `skills/validate-recommendation/panel/tests/test_dispatch.py` | **Create** | TDD suite. 15 tests, mocks `panel.dispatch._invoke_nat` only. |
| `skills/validate-recommendation/panel/cli.py` | **Modify** | Replace Phase 3a dispatch-branch stub body with `from panel.dispatch import dispatch; return dispatch(...)`. argparse unchanged. |
| `skills/validate-recommendation/panel/tests/test_cli_lint_config.py` | **Modify** | Remove `test_dispatch_stub_returns_phase3b_message` — obsolete after stub goes away. |
| `skills/validate-recommendation/panel/tests/test_cli_dispatch.py` | **Create** | CLI integration tests: argparse → `panel.dispatch.dispatch(...)` wiring. |
| `skills/validate-recommendation/panel/tests/test_cli_exit_codes.py` | **Modify** | Rewrite the subprocess-level dispatch test (was asserting Phase 3a stub exit code 2 + "Phase 3b" message — now asserts exit 1 on missing persona). |
| `skills/validate-recommendation/panel/.nat-discovery-notes.md` | **Create (gitignored)** | NAT Builder idiom + verified module/class/method names from Task 2 spike. Reference for future engineers after NAT version bumps. |

Untouched (deferred): `dispatch-da.sh`, `dispatch-da_test.sh`, `aggregate.sh`, `panel/{verdict,sanitize,trace,aggregate,config,personas}.py`, `SKILL.md`, `personas/`, `personas.md`, `~/.claude/panel/config.yml`.

---

## Tasks

### Task 1: Pre-flight — confirm `nvidia-nat` install state

**Files:** none modified. Environment verification only.

The superseded v3 plan's Task 1 already ran (`nvidia-nat==1.6.0` installed via `pip install --user --break-system-packages`). This task confirms the install survives.

- [ ] **Step 1: Verify NAT imports**

```bash
/opt/homebrew/bin/python3.12 -c "
import nat
import nat.builder.builder
import nat.llm.nim_llm
print('nat package: namespace, __file__ =', nat.__file__)
print('Builder class:', nat.builder.builder.Builder)
print('NIMModelConfig:', nat.llm.nim_llm.NIMModelConfig)
"
```

Expected: prints `nat package: namespace, __file__ = None`, the `Builder` and `NIMModelConfig` class references resolve. No exception.

If `import nat` fails: run the superseded plan's Task 1 (reproduced below) to install:

```bash
/opt/homebrew/bin/python3.12 -m pip install --user --break-system-packages 'nvidia-nat==1.6.0' 'jmespath>=1.0.0'
```

(Exact pin + jmespath lower bound to bypass pip 26's resolution-too-deep error on the open range.)

- [ ] **Step 2: Verify pytest venv can import the panel package**

```bash
cd ~/.claude/skills/validate-recommendation && \
  ~/.local/pipx/venvs/pytest/bin/python -c "
import sys; sys.path.insert(0, '.')
from panel.config import load_config
from panel.personas import load_persona
print('panel.config + panel.personas import OK')
"
```

Expected: prints OK. (NAT imports in `_invoke_nat` are lazy and won't run during this check.)

No commit (verification only).

---

### Task 2: NAT Builder idiom spike

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/.nat-discovery-notes.md` (gitignored)

Goal: find the canonical ~10-LOC dispatch idiom using `NIMModelConfig` + `Builder` + retrieve + invoke. Without this, Task 3's `_invoke_nat` is guesswork.

- [ ] **Step 1: Inspect Builder's API surface**

```bash
/opt/homebrew/bin/python3.12 -c "
from nat.builder.builder import Builder
import inspect
print('Builder.__init__:', inspect.signature(Builder.__init__))
print()
for name in sorted(dir(Builder)):
    if name.startswith('_'):
        continue
    member = getattr(Builder, name)
    if callable(member):
        try:
            sig = inspect.signature(member)
        except (TypeError, ValueError):
            sig = '(no sig)'
        print(f'  Builder.{name}{sig}')
"
```

Record: how `Builder` is constructed (args? config object?), the exact `add_llm` signature (`add_llm(name, config)` vs `add_llm(config)` vs other), and any `get_llm` / `llm` / `get_llm_provider` method.

- [ ] **Step 2: Inspect `NIMModelConfig` field names**

```bash
/opt/homebrew/bin/python3.12 -c "
from nat.llm.nim_llm import NIMModelConfig
print('Required fields:', NIMModelConfig.model_fields)
print()
print('Schema:', NIMModelConfig.model_json_schema()['properties'].keys())
" 2>&1 | head -30
```

Record: the exact field names used by `NIMModelConfig` for model name, max_tokens, temperature, api_key. (Phase 3a's `Panelist` dataclass uses `model`, `max_tokens`, `temperature`; if NAT uses `model_name`, `max_new_tokens`, etc., dispatch.py adapts in `_invoke_nat`.)

- [ ] **Step 3: Try the end-to-end Builder dispatch (no API key required for shape verification)**

```bash
/opt/homebrew/bin/python3.12 <<'EOF'
from nat.builder.builder import Builder
from nat.llm.nim_llm import NIMModelConfig

# Field names from Step 2 — adjust if NAT uses different keys
cfg = NIMModelConfig(model_name="nvidia/nemotron-3-super-v3", max_tokens=8, temperature=0.0)
print("config built OK")

b = Builder()
print("builder constructed OK")

# Try several plausible registration paths
try:
    b.add_llm("test", cfg)
    print("add_llm(name, cfg) ACCEPTED")
except TypeError as e:
    print("add_llm(name, cfg) rejected:", e)
    try:
        b.add_llm(cfg)
        print("add_llm(cfg) ACCEPTED")
    except TypeError as e2:
        print("add_llm(cfg) also rejected:", e2)

# Inspect what's registered
print("builder state:", dir(b))
EOF
```

Try-and-fail probe — the EXACT signature of `add_llm` and the retrieval method are the two unknowns. The Step 1 inspection narrowed candidates; this step nails them down.

If `Builder` requires a config dict at construction (NAT-Workflow style), the call sequence might be `Builder({...})` instead of `Builder()`. Iterate until the dispatch shape compiles.

- [ ] **Step 4: Run a real invoke (with API key) to verify the response shape**

Only run this step if `$PANEL_DA_API_KEY` (or `$NVIDIA_API_KEY`) is exported. Otherwise skip — Task 5 catches this later.

```bash
/opt/homebrew/bin/python3.12 <<EOF
from nat.builder.builder import Builder
from nat.llm.nim_llm import NIMModelConfig
import os

api_key = os.environ.get("PANEL_DA_API_KEY") or os.environ.get("NVIDIA_API_KEY")
if not api_key:
    raise SystemExit("Skipping: no API key in env")

# Substitute the idiom verified in Step 3
cfg = NIMModelConfig(
    model_name="nvidia/nemotron-3-super-v3",
    max_tokens=64,
    temperature=0.0,
    api_key=api_key,
)
b = Builder()
b.add_llm("test", cfg)
llm = b.get_llm("test")   # adjust per Step 1 findings

response = llm.invoke(messages=[
    {"role": "user", "content": "Say HELLO and only HELLO."},
])
print("response type:", type(response).__name__)
print("response.__dict__:", getattr(response, '__dict__', '(no dict)'))
print("response.content:", getattr(response, 'content', '(no .content)'))
print("repr:", repr(response)[:200])
EOF
```

Record: the response object's type, the attribute (`content`? `text`? `output`?) that holds the model's text reply. The existing `_extract_content()` helper handles `.content` / `dict` / `str` — confirm one of these branches matches.

- [ ] **Step 5: Write `.nat-discovery-notes.md`**

```bash
cat > ~/.claude/skills/validate-recommendation/panel/.nat-discovery-notes.md <<'EOF'
# NAT Builder dispatch idiom — discovery notes (Phase 3b Task 2)
# Verified: 2026-05-18

## Versions
nvidia-nat: 1.6.0
Python: /opt/homebrew/bin/python3.12 (3.12.x)

## Imports
from nat.builder.builder import Builder
from nat.llm.nim_llm import NIMModelConfig
from nat.llm.anthropic_llm import <CLASSNAME_FROM_STEP_1>
from nat.llm.openai_llm import <CLASSNAME_FROM_STEP_1>

## Builder construction
<exact constructor signature from Step 1, e.g. `Builder()` or `Builder(config={...})`>

## Register-and-retrieve idiom (NIM)
cfg = NIMModelConfig(
    model_name=<panelist.model>,           # NAT field: <verified key>
    max_tokens=<panelist.max_tokens>,      # NAT field: <verified key>
    temperature=<panelist.temperature>,    # NAT field: <verified key>
    api_key=<env-or-arg>,                  # NAT field: <verified key>, source: <env var name>
)
b = Builder()
b.<verified register method>("test", cfg)
llm = b.<verified retrieve method>("test")
response = llm.invoke(messages=[
    {"role": "system", "content": ...},
    {"role": "user", "content": ...},
])

## Response shape
type(response): <verified, e.g. "AIMessage" or "BaseMessage">
response text attribute: <verified, e.g. ".content" or ".text">
example response.content: "<short paste>"

## Anthropic / OpenAI parallels
AnthropicModelConfig and OpenAIModelConfig follow the same shape with field names <list any diffs>.

## Field-name adaptation
The panel's Panelist dataclass uses {id, role, backend, model, max_tokens, temperature}.
NAT's *ModelConfig classes use {<verified field names>}. dispatch.py's _invoke_nat
maps Panelist.model → NIMModelConfig.<field>, etc.
EOF
```

Substitute every `<...>` with the verified value before saving.

- [ ] **Step 6: Ensure `.nat-discovery-notes.md` is gitignored**

The `~/.claude/.gitignore` already has `__pycache__/` and `*.pyc` (from the Phase 3a closure). Add an entry for the discovery notes file:

```bash
grep -q '\.nat-discovery-notes\.md$' ~/.claude/.gitignore || \
    echo "skills/validate-recommendation/panel/.nat-discovery-notes.md" >> ~/.claude/.gitignore
```

The `.gitignore` change is a separate concern from Phase 3b. Commit it standalone (no body needed):

```bash
cd ~/.claude && git add .gitignore && git commit -s -S -m "chore(.gitignore): ignore panel NAT discovery notes

skills/validate-recommendation/panel/.nat-discovery-notes.md holds
NAT-API spike output (Phase 3b Task 2). Local engineering notes, not
spec content — keep out of git."
```

No other commit for Task 2.

---

### Task 3: Implement `panel/dispatch.py` with TDD

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_dispatch.py`
- Create: `~/.claude/skills/validate-recommendation/panel/dispatch.py`

- [ ] **Step 1: Write the failing tests** (`panel/tests/test_dispatch.py`)

The 15 test cases below match the superseded v3 plan's test design. Test BEHAVIOR is identical (mock the `_invoke_nat` seam, verify outputs); only the IMPLEMENTATION behind the seam changed. Tests don't know NAT exists.

```python
"""Tests for panel.dispatch — NAT-Builder-backed panelist dispatch.

The single mock seam is `panel.dispatch._invoke_nat`. Tests never mock
requests/httpx/nat.* directly — that couples to NAT internals and breaks
on NAT version bumps (per v3 spec section 'Mock discipline').

Test surface:
- Happy path: well-formed response → verdict file with HOLD/OVERTURN
- Error paths (all write VERDICT: ERROR; all exit 0):
  - _invoke_nat raises (network, timeout)
  - Response missing VERDICT/RATIONALE/ALTERNATIVE lines
  - Response has OVERTURN + ALTERNATIVE: n/a (Phase 1 bug #3 preservation)
  - Unsupported backend (ValueError from _invoke_nat)
- Caller-bug paths (exit non-zero, no verdict written):
  - Missing config file
  - Missing persona file
  - Missing prompt file
  - panelist_id not in config
- File mode 0600 (umask 077)
- Response shape variations: object with .content / dict / plain string
"""
import os
import stat
import textwrap
from pathlib import Path
from unittest.mock import patch

import pytest


def _fixture_files(tmp_path, *, panelist_id="da", backend="nat-nim",
                   model="test-model"):
    cfg_path = tmp_path / "config.yml"
    cfg_path.write_text(textwrap.dedent(f"""
        version: 1
        panelists:
          - id: {panelist_id}
            role: DA
            enabled: true
            backend: {backend}
            model: {model}
    """).strip() + "\n")

    persona_path = tmp_path / "persona.md"
    persona_path.write_text(textwrap.dedent("""
        ---
        role: DA
        description: test persona
        intended_backends: [nat-nim]
        ---

        # System prompt

        You are a test reviewer. Output VERDICT: ... etc.

        # One-shot example

        Example output:
        VERDICT: HOLD
        RATIONALE: nothing to add
        ALTERNATIVE: n/a

        # User prompt template

        Question: <q>
    """).strip() + "\n")

    prompt_path = tmp_path / "prompt.txt"
    prompt_path.write_text("Question: Should we pick option A?\n")

    output_path = tmp_path / "verdict.txt"
    return cfg_path, persona_path, prompt_path, output_path


class _FakeAIMessage:
    """Shape mirrors langchain.schema.AIMessage / NAT response (has .content)."""
    def __init__(self, content: str):
        self.content = content


def test_dispatch_writes_well_formed_hold_verdict_on_happy_path(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    fake_response = _FakeAIMessage(
        "VERDICT: HOLD\n"
        "RATIONALE: The recommendation aligns with stated goals.\n"
        "ALTERNATIVE: n/a\n"
    )
    with patch("panel.dispatch._invoke_nat", return_value=fake_response):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: HOLD" in written
    assert "RATIONALE: " in written
    assert "ALTERNATIVE: n/a" in written


def test_dispatch_writes_overturn_verdict_with_alternative(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    fake_response = _FakeAIMessage(
        "VERDICT: OVERTURN\n"
        "RATIONALE: Option B better matches stated constraints.\n"
        "ALTERNATIVE: Option B\n"
    )
    with patch("panel.dispatch._invoke_nat", return_value=fake_response):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: OVERTURN" in written
    assert "ALTERNATIVE: Option B" in written


def test_dispatch_writes_error_verdict_on_network_exception(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    with patch("panel.dispatch._invoke_nat",
               side_effect=ConnectionError("backend unreachable")):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: ERROR" in written
    assert "backend unreachable" in written


def test_dispatch_writes_error_verdict_on_malformed_response(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    fake_response = _FakeAIMessage("This is not a verdict; the model rambled.")
    with patch("panel.dispatch._invoke_nat", return_value=fake_response):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    assert "VERDICT: ERROR" in out.read_text(encoding="utf-8")


def test_dispatch_writes_error_on_overturn_with_alternative_na(tmp_path):
    """Phase 1 bug #3: OVERTURN + ALTERNATIVE: n/a must be rejected."""
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    fake_response = _FakeAIMessage(
        "VERDICT: OVERTURN\n"
        "RATIONALE: I disagree but have no concrete suggestion.\n"
        "ALTERNATIVE: n/a\n"
    )
    with patch("panel.dispatch._invoke_nat", return_value=fake_response):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: ERROR" in written


def test_dispatch_writes_verdict_file_mode_0600(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    fake_response = _FakeAIMessage(
        "VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n"
    )
    with patch("panel.dispatch._invoke_nat", return_value=fake_response):
        dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                 prompt_file=prompt, output=out)
    mode = stat.S_IMODE(os.stat(out).st_mode)
    assert mode == 0o600, f"expected 0o600, got 0o{mode:o}"


def test_dispatch_returns_nonzero_on_missing_config(tmp_path):
    from panel.dispatch import dispatch
    _, persona, prompt, out = _fixture_files(tmp_path)
    rc = dispatch(panelist_id="da",
                  config_path=tmp_path / "no-config.yml",
                  persona_path=persona, prompt_file=prompt, output=out)
    assert rc != 0
    assert not out.exists()


def test_dispatch_returns_nonzero_on_missing_persona(tmp_path):
    from panel.dispatch import dispatch
    cfg, _, prompt, out = _fixture_files(tmp_path)
    rc = dispatch(panelist_id="da", config_path=cfg,
                  persona_path=tmp_path / "no-persona.md",
                  prompt_file=prompt, output=out)
    assert rc != 0
    assert not out.exists()


def test_dispatch_returns_nonzero_on_missing_prompt(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, _, out = _fixture_files(tmp_path)
    rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                  prompt_file=tmp_path / "no-prompt.txt", output=out)
    assert rc != 0
    assert not out.exists()


def test_dispatch_returns_nonzero_on_panelist_id_not_in_config(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    rc = dispatch(panelist_id="not-a-real-id", config_path=cfg,
                  persona_path=persona, prompt_file=prompt, output=out)
    assert rc != 0
    assert not out.exists()


def test_dispatch_threads_system_prompt_and_user_to_invoke_nat(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    captured = {}
    def fake_invoke(panelist, system, user):
        captured["system"] = system
        captured["user"] = user
        captured["panelist_id"] = panelist.id
        return _FakeAIMessage("VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n")
    with patch("panel.dispatch._invoke_nat", side_effect=fake_invoke):
        dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                 prompt_file=prompt, output=out)
    assert "test reviewer" in captured["system"]
    assert "Example output" in captured["system"]
    assert "Should we pick option A?" in captured["user"]
    assert captured["panelist_id"] == "da"


def test_dispatch_response_with_content_attribute_extracted(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    with patch("panel.dispatch._invoke_nat",
               return_value=_FakeAIMessage(
                   "VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n")):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    assert "VERDICT: HOLD" in out.read_text(encoding="utf-8")


def test_dispatch_response_as_dict_extracted(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    with patch("panel.dispatch._invoke_nat",
               return_value={"content": "VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n"}):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    assert "VERDICT: HOLD" in out.read_text(encoding="utf-8")


def test_dispatch_response_as_plain_string_extracted(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    with patch("panel.dispatch._invoke_nat",
               return_value="VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n"):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    assert "VERDICT: HOLD" in out.read_text(encoding="utf-8")


def test_dispatch_unsupported_backend_returns_error_verdict(tmp_path):
    """Unsupported backend → _invoke_nat raises ValueError → ERROR verdict, exit 0."""
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    cfg.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: claude-subagent
            subagent_type: principal-engineer
    """).strip() + "\n")
    rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                  prompt_file=prompt, output=out)
    assert rc == 0
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: ERROR" in written
    assert "claude-subagent" in written or "unsupported" in written.lower()
```

- [ ] **Step 2: Run tests to verify failure**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_dispatch.py -v
```

Expected: 15 tests collected; all FAIL with `ModuleNotFoundError: No module named 'panel.dispatch'`.

- [ ] **Step 3: Implement `panel/dispatch.py`**

Substitute the Builder method names verified in Task 2 Step 1-3 (`add_llm` / `get_llm` are placeholders below — replace with the verified API) before saving. The map from `Panelist.{model, max_tokens, temperature}` to `*ModelConfig.{<verified field>}` comes from Task 2 Step 2.

```python
"""NAT-Builder-backed panelist dispatch.

Called per nat-* panelist via `python -m panel dispatch --panelist <id>
--config <path> --persona <path> --prompt-file <path> --output <path>`.

Contract (per v3 spec section 'Dispatchers', v3.1 amendment section
'Replaced: _invoke_nat snippet'):
- Returns 0 if a verdict file was written (success path OR ERROR path).
- Returns non-zero only when caller-supplied paths/ids are invalid
  (missing config, missing persona, missing prompt, unknown panelist id).
- All runtime failures (network, timeout, parse error, unsupported
  backend, OVERTURN+ALTERNATIVE:n/a) become VERDICT: ERROR verdict files.
- Verdict files are written with mode 0600 (umask 077).

The single mockable seam is `_invoke_nat(panelist, system, user)`. Tests
mock it entirely; below it lies NAT's Builder + register_llm_provider
runtime. Tests never mock requests/httpx/nat.* directly (per spec's
'Mock discipline' rule).
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

from panel.config import load_config, ConfigError, Panelist
from panel.personas import load_persona, PersonaError
from panel.verdict import parse_verdict


def _invoke_nat(panelist: Panelist, system: str, user: str) -> object:
    """NAT-Builder dispatch — the single mock seam.

    Real implementation imports NAT lazily so tests don't pay the
    NAT-import cost when the function is mocked.
    """
    from nat.builder.builder import Builder

    backend = panelist.backend
    if backend == "nat-nim":
        from nat.llm.nim_llm import NIMModelConfig
        cfg = NIMModelConfig(
            model_name=panelist.model,                # NAT field, verified Task 2 Step 2
            max_tokens=panelist.max_tokens,
            temperature=panelist.temperature,
        )
    elif backend == "nat-anthropic":
        # Class name verified in Task 2 Step 1 (likely AnthropicModelConfig).
        from nat.llm.anthropic_llm import AnthropicModelConfig
        cfg = AnthropicModelConfig(
            model_name=panelist.model,
            max_tokens=panelist.max_tokens,
            temperature=panelist.temperature,
        )
    elif backend == "nat-openai":
        from nat.llm.openai_llm import OpenAIModelConfig
        cfg = OpenAIModelConfig(
            model_name=panelist.model,
            max_tokens=panelist.max_tokens,
            temperature=panelist.temperature,
        )
    else:
        raise ValueError(f"unsupported NAT backend: {backend}")

    # Builder pattern — register the panelist's config, retrieve, invoke.
    # Exact method names verified in Task 2 spike.
    builder = Builder()
    builder.add_llm(panelist.id, cfg)
    llm = builder.get_llm(panelist.id)
    return llm.invoke(messages=[
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ])


def _extract_content(response: object) -> str:
    """Pull text content out of NAT response object variants."""
    if hasattr(response, "content"):
        c = response.content
        return c if isinstance(c, str) else str(c)
    if isinstance(response, dict) and "content" in response:
        return str(response["content"])
    if isinstance(response, str):
        return response
    return str(response)


def _format_verdict(verdict: str, rationale: str, alternative: str) -> str:
    """Format the canonical VERDICT/RATIONALE/ALTERNATIVE text (line-oriented)."""
    rationale_one_line = " ".join(rationale.split())
    alt_one_line = " ".join(alternative.split()) if alternative else "n/a"
    return (
        f"VERDICT: {verdict}\n"
        f"RATIONALE: {rationale_one_line}\n"
        f"ALTERNATIVE: {alt_one_line}\n"
    )


def _write_verdict_file(path: Path, content: str) -> None:
    """Write verdict file with mode 0600."""
    old_umask = os.umask(0o077)
    try:
        path.write_text(content, encoding="utf-8")
    finally:
        os.umask(old_umask)


def dispatch(
    panelist_id: str,
    config_path,
    persona_path,
    prompt_file,
    output,
) -> int:
    """Run one panelist via its NAT backend and write a verdict file.

    Returns:
        0 — verdict file written (HOLD/OVERTURN/ERROR — any structured outcome)
        1 — caller-supplied path/id invalid (no verdict written)
    """
    output_path = Path(output).expanduser()

    # Caller-bug paths: report to stderr, return 1, do NOT write verdict.
    try:
        cfg = load_config(config_path)
    except ConfigError as e:
        print(f"dispatch: config error: {e}", file=sys.stderr)
        return 1

    panelist = next((p for p in cfg.panelists if p.id == panelist_id), None)
    if panelist is None:
        print(f"dispatch: panelist id '{panelist_id}' not found in config",
              file=sys.stderr)
        return 1

    try:
        persona = load_persona(persona_path)
    except PersonaError as e:
        print(f"dispatch: persona error: {e}", file=sys.stderr)
        return 1

    prompt_path = Path(prompt_file).expanduser()
    if not prompt_path.is_file():
        print(f"dispatch: prompt file missing: {prompt_path}", file=sys.stderr)
        return 1
    user_prompt = prompt_path.read_text(encoding="utf-8")

    # Compose system prompt = persona system + one-shot example.
    system = persona.system_prompt
    if persona.one_shot_example:
        system = system + "\n\n" + persona.one_shot_example

    # Runtime path: any failure here becomes VERDICT: ERROR. Never crash.
    try:
        response = _invoke_nat(panelist, system, user_prompt)
        text = _extract_content(response)
        parsed = parse_verdict(text)
        if parsed.verdict == "OVERTURN" and parsed.alternative.strip().lower() in ("n/a", ""):
            _write_verdict_file(output_path, _format_verdict(
                "ERROR",
                "panelist returned OVERTURN without a concrete ALTERNATIVE",
                "n/a",
            ))
            return 0
        _write_verdict_file(output_path, _format_verdict(
            parsed.verdict, parsed.rationale, parsed.alternative,
        ))
        return 0
    except Exception as e:
        msg = " ".join(str(e).split())[:200]
        _write_verdict_file(output_path, _format_verdict(
            "ERROR", f"panelist invocation failed: {msg}", "n/a",
        ))
        return 0
```

**Verify the `parse_verdict` import path.** Phase 2's `panel/verdict.py` exposes a `parse_verdict(text)` function returning an object with `.verdict / .rationale / .alternative` attributes. Before pasting the code above, run:

```bash
/opt/homebrew/bin/python3.12 -c "
import sys; sys.path.insert(0, '/Users/eduardoa/.claude/skills/validate-recommendation')
from panel.verdict import parse_verdict
v = parse_verdict('VERDICT: HOLD\\nRATIONALE: ok\\nALTERNATIVE: n/a')
print('parsed:', v.verdict, '|', v.rationale, '|', v.alternative)
"
```

Expected: prints `HOLD | ok | n/a`. If attribute names differ, adjust dispatch.py's `parsed.verdict / parsed.rationale / parsed.alternative` accesses.

- [ ] **Step 4: Run tests to verify pass**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_dispatch.py -v
```

Expected: 15 tests pass.

Run the full Phase 3a + new dispatch suite to confirm no regression:

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -v 2>&1 | tail -5
```

Expected: 60 (Phase 3a) + 15 (Phase 3b) = 75 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/dispatch.py skills/validate-recommendation/panel/tests/test_dispatch.py
cd ~/.claude && git commit -s -S -m "feat(panel): dispatch.py NAT-Builder integration with _invoke_nat seam

Implements panel/dispatch.py using NAT 1.6's Builder + register_llm_provider
pattern (per v3.1 amendment). The _invoke_nat() function is the single
mockable seam: tests mock it entirely; behind it lies NAT (Builder +
NIMModelConfig / AnthropicModelConfig / OpenAIModelConfig) and below NAT,
real HTTP — both integration territory.

Contract (v3 spec 'Dispatchers' + v3.1 amendment '_invoke_nat snippet'):
  - Exit 0 if a verdict file was written (success OR ERROR path)
  - Exit 1 only on caller-bug paths (missing config/persona/prompt/id)
  - All runtime failures → VERDICT: ERROR file (never crashes)
  - File mode 0600 (umask 077)
  - Preserves Phase 1 bug #3 fix: OVERTURN + ALTERNATIVE: n/a → ERROR

15 pytest cases. Tests mock at _invoke_nat only — no requests/httpx/
nat.* mocking, per spec's 'Mock discipline' rule. Builder API verified
in Phase 3b Task 2 spike; idiom recorded in .nat-discovery-notes.md."
```

---

### Task 4: Wire `cli.py` dispatch subcommand to real dispatch

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_lint_config.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_exit_codes.py`
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_dispatch.py`

Behavior identical to the superseded plan's Task 4. The CLI wiring is implementation-agnostic — it doesn't know whether dispatch uses NAT, langchain, or direct HTTP.

- [ ] **Step 1: Write the failing tests** (`panel/tests/test_cli_dispatch.py`)

```python
"""CLI tests for `panel dispatch` after v3.1 Phase 3b wiring.

The CLI's only job for dispatch is argparse → call dispatch(). We mock
panel.dispatch.dispatch and confirm the args land correctly. The dispatch
function itself is exercised by test_dispatch.py.
"""
import textwrap
from unittest.mock import patch


def _write_minimal_config(tmp_path):
    p = tmp_path / "config.yml"
    p.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: test-model
    """).strip() + "\n")
    return p


def test_cli_dispatch_calls_dispatch_with_threaded_args(tmp_path):
    from panel.cli import main
    cfg = _write_minimal_config(tmp_path)
    persona = tmp_path / "p.md"
    persona.write_text("---\nrole: DA\n---\n# System prompt\nx\n# User prompt template\nq\n")
    prompt = tmp_path / "u.txt"
    prompt.write_text("Question: x?\n")
    out = tmp_path / "v.txt"

    with patch("panel.dispatch.dispatch", return_value=0) as mock_dispatch:
        rc = main([
            "dispatch",
            "--panelist", "da",
            "--config", str(cfg),
            "--persona", str(persona),
            "--prompt-file", str(prompt),
            "--output", str(out),
        ])
    assert rc == 0
    mock_dispatch.assert_called_once()
    kwargs = mock_dispatch.call_args.kwargs
    if not kwargs:
        args = mock_dispatch.call_args.args
        assert args[0] == "da"
        assert str(args[1]) == str(cfg)
        assert str(args[2]) == str(persona)
        assert str(args[3]) == str(prompt)
        assert str(args[4]) == str(out)
    else:
        assert kwargs["panelist_id"] == "da"
        assert str(kwargs["config_path"]) == str(cfg)
        assert str(kwargs["persona_path"]) == str(persona)
        assert str(kwargs["prompt_file"]) == str(prompt)
        assert str(kwargs["output"]) == str(out)


def test_cli_dispatch_returns_dispatch_exit_code(tmp_path):
    from panel.cli import main
    cfg = _write_minimal_config(tmp_path)
    persona = tmp_path / "p.md"
    persona.write_text("---\nrole: DA\n---\n# System prompt\nx\n# User prompt template\nq\n")
    prompt = tmp_path / "u.txt"
    prompt.write_text("q\n")
    out = tmp_path / "v.txt"

    with patch("panel.dispatch.dispatch", return_value=1):
        rc = main([
            "dispatch", "--panelist", "da", "--config", str(cfg),
            "--persona", str(persona), "--prompt-file", str(prompt),
            "--output", str(out),
        ])
    assert rc == 1


def test_cli_dispatch_uses_default_config_when_omitted(tmp_path):
    from panel.cli import main
    persona = tmp_path / "p.md"
    persona.write_text("---\nrole: DA\n---\n# System prompt\nx\n# User prompt template\nq\n")
    prompt = tmp_path / "u.txt"
    prompt.write_text("q\n")
    out = tmp_path / "v.txt"

    with patch("panel.dispatch.dispatch", return_value=0) as mock_dispatch:
        main([
            "dispatch", "--panelist", "da",
            "--persona", str(persona), "--prompt-file", str(prompt),
            "--output", str(out),
        ])
    kwargs = mock_dispatch.call_args.kwargs
    config_arg = kwargs.get("config_path") if kwargs else mock_dispatch.call_args.args[1]
    assert ".claude/panel/config.yml" in str(config_arg)
```

- [ ] **Step 2: Run new tests to verify failure**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_cli_dispatch.py -v
```

Expected: 3 tests collected; all FAIL because cli.py's dispatch branch still returns the Phase 3a stub message (exit 2).

- [ ] **Step 3: Replace the stub branch in `cli.py`**

Current Phase 3a stub body (`if args.cmd == "dispatch":` branch):

```python
if args.cmd == "dispatch":
    print(
        "dispatch: not yet implemented in Phase 3a — Phase 3b adds the real "
        "NAT integration.",
        file=sys.stderr,
    )
    return 2
```

Replace with:

```python
if args.cmd == "dispatch":
    from panel.dispatch import dispatch
    return dispatch(
        panelist_id=args.panelist,
        config_path=args.config or _default_config_path(),
        persona_path=args.persona,
        prompt_file=args.prompt_file,
        output=args.output,
    )
```

Update the file's top docstring to reflect Phase 3b status:

```python
"""Top-level CLI dispatch for the panel package.

Subcommands shipped so far:
- aggregate         (Phase 2 — 2-panelist byte-parity)
- lint-config       (Phase 3a — config validation)
- dispatch          (Phase 3b — NAT-Builder-backed panelist dispatch)

Subcommands planned for later phases:
- record-userpick   (Phase 6)
- ls, show, label, stats, replay, gc   (Phase 6)
- tune              (Phase 7 — NAT Eval-backed)
"""
```

- [ ] **Step 4: Remove the obsolete stub-message test** (`test_cli_lint_config.py`)

Delete the test function `test_dispatch_stub_returns_phase3b_message` (and any helpers used exclusively by it). Keep `test_dispatch_subparser_registered` — that one is still valid (argparse `--help` registration check).

- [ ] **Step 5: Rewrite the subprocess dispatch test** (`test_cli_exit_codes.py`)

Replace `test_subprocess_exits_two_on_dispatch_stub` with:

```python
def test_subprocess_exits_one_on_dispatch_missing_persona(tmp_path):
    """Phase 3b: dispatch is real; missing persona is a caller-bug → exit 1."""
    cfg = tmp_path / "config.yml"
    cfg.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: nat-nim
            model: test-model
    """).strip() + "\n")
    rc, out, err = _run([
        "dispatch",
        "--panelist", "da",
        "--config", str(cfg),
        "--persona", str(tmp_path / "no-persona.md"),
        "--prompt-file", str(tmp_path / "no-prompt.txt"),
        "--output", str(tmp_path / "verdict.txt"),
    ])
    assert rc == 1, f"expected 1, got {rc}; stdout={out!r}; stderr={err!r}"
    assert "persona" in err.lower() or "missing" in err.lower()
```

- [ ] **Step 6: Run all CLI tests to verify green**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ 2>&1 | tail -5
```

Expected: 60 (Phase 3a baseline) + 15 (dispatch) + 3 (cli_dispatch) - 1 (stub-test removed) + 0 (exit_codes rewritten in place) = 77 tests pass.

- [ ] **Step 7: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/cli.py skills/validate-recommendation/panel/tests/test_cli_dispatch.py skills/validate-recommendation/panel/tests/test_cli_lint_config.py skills/validate-recommendation/panel/tests/test_cli_exit_codes.py
cd ~/.claude && git commit -s -S -m "feat(panel): wire CLI dispatch to NAT-Builder integration

Phase 3a left dispatch as a stub printing 'not yet implemented'. This
commit replaces the stub body with a call to panel.dispatch.dispatch()
and threads CLI args through to it.

Tests updated:
  - test_cli_dispatch.py (new, 3 cases) — CLI wires args to dispatch()
  - test_cli_lint_config.py — removed obsolete Phase 3a stub-message test
  - test_cli_exit_codes.py — replaced subprocess stub test with missing-
    persona exit-code test

aggregate and lint-config subcommands untouched."
```

---

### Task 5: End-to-end smoke test against real Nemotron

**Files:** none modified. Verification only.

Same behavior as the superseded plan's Task 5 — runs `panel dispatch` against real Nemotron via NAT Builder. Requires `$PANEL_DA_API_KEY` (or `$NVIDIA_API_KEY` per NAT's env-var conventions), `$CLAUDE_PANEL_DA_ENDPOINT`, `$CLAUDE_PANEL_DA_MODEL`. (Task 2 Step 4 verified the response shape; this is the live-traffic version.)

- [ ] **Step 1: Live dispatch against Nemotron**

```bash
PROMPT=$(mktemp); OUTPUT=$(mktemp)
cat > "$PROMPT" <<'EOF'
Question: Which Go HTTP client should we pick?
Options (verbatim labels and descriptions):
  Option A (Recommended) — net/http; stdlib, no deps
  Option B — resty; third-party with built-in retries
Assistant's recommended option: Option A (Recommended)
Assistant's stated reasoning: stdlib avoids dependency cost and is sufficient.
EOF

cd ~/.claude/skills/validate-recommendation && /opt/homebrew/bin/python3.12 -m panel dispatch \
    --panelist da-nemotron \
    --persona personas/da.md \
    --prompt-file "$PROMPT" \
    --output "$OUTPUT" ; rc=$?

echo "rc=$rc"
echo "--- verdict file ---"
cat "$OUTPUT"
rm -f "$PROMPT" "$OUTPUT"
```

Expected: `rc=0`; verdict file contains `VERDICT: HOLD` or `VERDICT: OVERTURN`, a `RATIONALE:` line, and `ALTERNATIVE: ...`. (OVERTURN + ALTERNATIVE: n/a → ERROR — that's the Phase 1 bug #3 fix.)

- [ ] **Step 2: ERROR path (no API key)**

```bash
PROMPT=$(mktemp); OUTPUT=$(mktemp)
echo "Question: x?" > "$PROMPT"
(unset PANEL_DA_API_KEY NVIDIA_API_KEY; cd ~/.claude/skills/validate-recommendation && \
    /opt/homebrew/bin/python3.12 -m panel dispatch \
        --panelist da-nemotron --persona personas/da.md \
        --prompt-file "$PROMPT" --output "$OUTPUT") ; rc=$?
echo "rc=$rc"
cat "$OUTPUT"
rm -f "$PROMPT" "$OUTPUT"
```

Expected: `rc=0`, verdict file contains `VERDICT: ERROR` with auth/connection failure rationale.

No commit for Task 5.

---

### Task 6: Phase 3b sign-off

**Files:** none modified except README.

- [ ] **Step 1: Full pytest suite green**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ 2>&1 | tail -5
```

Expected: 77 tests pass. Breakdown:
- Phase 2 baseline: 21
- Phase 3a (config / personas / cli_lint_config / cli_exit_codes): 39 (1 removed, 1 rewritten)
- Phase 3b (dispatch / cli_dispatch): 18

- [ ] **Step 2: Legacy v1 paths still work**

```bash
cd ~/.claude/skills/validate-recommendation && /opt/homebrew/bin/python3.12 -m panel lint-config
cd ~/.claude/skills/validate-recommendation && bash aggregate_test.sh 2>&1 | tail -3
cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh 2>&1 | tail -3
```

Expected:
- `lint-config`: `OK: 1 enabled panelist(s) (of 3 configured)` + da-nemotron line, exit 0.
- `aggregate_test.sh`: last line PASS.
- `dispatch-da_test.sh`: last line PASS.

The v1 panel still works for the runtime path; Phase 3b ships parallel code not yet wired into orchestration.

- [ ] **Step 3: Verify `~/.claude/` commits**

```bash
cd ~/.claude && git log --oneline -5
```

Expected: at least the two Phase 3b commits at the top — `feat(panel): dispatch.py NAT-Builder integration` and `feat(panel): wire CLI dispatch to NAT-Builder integration`. (The `chore(.gitignore)` commit from Task 2 Step 6 may also appear.)

- [ ] **Step 4: README update**

Append a `Phase 3b` section to `~/.claude/skills/validate-recommendation/README.md`:

```markdown
## Phase 3b: manual `panel dispatch` invocation

Run one panelist end-to-end against its NAT backend:

```bash
/opt/homebrew/bin/python3.12 -m panel dispatch \
    --panelist <id-from-config.yml> \
    --persona personas/<role>.md \
    --prompt-file /path/to/templated-user-body.txt \
    --output /tmp/panelist.verdict
cat /tmp/panelist.verdict
```

Exit codes:
- `0` — verdict file written (HOLD, OVERTURN, or ERROR — any structured outcome)
- `1` — caller-supplied path/id invalid (no verdict file written)

Backend implementation uses NAT 1.6 Builder pattern internally
(`NIMModelConfig` / `AnthropicModelConfig` / `OpenAIModelConfig` + `Builder.add_llm` + retrieve).
The single mockable seam is `panel.dispatch._invoke_nat`; tests
mock at that boundary only.

Required env vars per backend:
- `nat-nim`: `$PANEL_DA_API_KEY` (or `$NVIDIA_API_KEY`), `$CLAUDE_PANEL_DA_ENDPOINT`, `$CLAUDE_PANEL_DA_MODEL`
- `nat-anthropic`: `$ANTHROPIC_API_KEY`
- `nat-openai`: `$OPENAI_API_KEY`

Missing env vars → dispatch still exits 0; verdict file contains
`VERDICT: ERROR` with the auth failure in the rationale.

Internal NAT-API idiom (Builder/register methods, *ModelConfig field
names) is recorded in `panel/.nat-discovery-notes.md` (gitignored).
```

Commit:

```bash
cd ~/.claude && git add skills/validate-recommendation/README.md
cd ~/.claude && git commit -s -S -m "docs(panel): document Phase 3b panel dispatch invocation

Adds 'Phase 3b: manual panel dispatch invocation' section to the skill
README covering CLI flags, exit codes, NAT Builder-pattern internals,
and per-backend env-var requirements. No code change."
```

Phase 3b sign-off when all four Steps pass.

---

## Self-review

**Spec coverage:**
- v3.1 amendment section "Replaced: _invoke_nat snippet" → Task 3 implementation.
- v3.1 amendment section "Phase 3b plan replan" → this plan's Task 2 (Builder spike) + Task 3 (dispatch.py).
- v3 spec section "Dispatchers → panel/dispatch.py (NAT integration)" → Tasks 2 + 3.
- v3 spec section "Mock discipline" (no requests/httpx/nat.* mocks) → Task 3 test docstring + test design.
- v3 spec section "Error handling matrix" (HTTP failure / malformed / OVERTURN-no-alt) → Task 3 tests 3, 4, 5.
- v3 spec section "Security posture / API keys" → Task 3's lazy NAT import + Task 5's env-var-only verification.
- v3 spec section "Persona file format" → Task 3 dispatch.py compose step + test `_threads_system_prompt_and_user`.

**Out-of-scope and explicitly NOT touched:**
- `panel/aggregate.py` (Phase 3c rewrites for N panelists; v3.1 marks this as a NAT-Function candidate)
- `panel/severity.py` (Phase 3c extracts)
- `SKILL.md` (Phase 3c rewires)
- `dispatch-da.sh`, `aggregate.sh`, `dispatch-da_test.sh`, `personas.md` (Phase 3c deletes)
- `panel/state.py`, `panel/decisions.py` (Phases 5 + 6)
- NAT observability / OTel emit (Phase 6 per v3.1)
- NAT Eval / `panel tune` (Phase 7 per v3.1)

**Placeholder scan:** Every code block is the actual code an engineer types except the `add_llm` / `get_llm` method names in the dispatch.py snippet, which are explicitly flagged as "verify in Task 2 Step 1-3 spike". Substituting verified values is part of Task 3 Step 3. No `TBD` / `TODO` markers.

**Type consistency:**
- `Panelist` dataclass from `panel.config` (Phase 3a) — `id`, `role`, `backend`, `model`, `max_tokens`, `temperature` referenced consistently in dispatch.py and tests.
- `Persona` dataclass from `panel.personas` (Phase 3a) — `system_prompt`, `one_shot_example`, `user_prompt_template` referenced consistently.
- `parse_verdict` from `panel.verdict` (Phase 2) — verified before use in Task 3 Step 3.
- `dispatch()` signature = `(panelist_id, config_path, persona_path, prompt_file, output)`. cli.py wiring in Task 4 uses these exact kwargs.
- `_invoke_nat()` signature `(panelist, system, user) -> object` — the mock seam; tests `patch("panel.dispatch._invoke_nat", ...)` use this signature.

**Test-count math:** Phase 3a baseline = 60. Task 3 adds 15 → 75. Task 4 adds 3 new, removes 1 (`test_dispatch_stub_returns_phase3b_message`), rewrites 1 in place (subprocess test) → 75 + 3 - 1 + 0 = 77. Task 6 Step 1 expects 77. Consistent.

**Risk:** Task 3's dispatch.py snippet has placeholder NAT method names (`add_llm`, `get_llm`). If Task 2's spike finds a different idiom (e.g., async `await`, or no separate `add_llm`/`get_llm`), the snippet is updated before Task 3 Step 2's test run. The TDD red-green cycle catches signature mismatches immediately.

**Phase boundary:** Phase 3b ships `panel dispatch` as a self-contained CLI surface using NAT Builder. SKILL.md does NOT call it yet; the runtime path remains the v1 `dispatch-da.sh + aggregate.sh`. Phase 3c does the cutover.
