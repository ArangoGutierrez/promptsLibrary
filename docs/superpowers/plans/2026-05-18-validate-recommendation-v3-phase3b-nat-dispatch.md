# validate-recommendation v3 — Phase 3b: NAT dispatch

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `panel/dispatch.py` (real NAT integration with the single `_invoke_nat` mockable seam) and replace `panel/cli.py`'s Phase 3a dispatch stub. After Phase 3b, `python -m panel dispatch --panelist <id> ...` invokes nat-* backends end-to-end and writes a `VERDICT/RATIONALE/ALTERNATIVE` verdict file. The orchestrator (SKILL.md) is still wired to v1's `dispatch-da.sh` at runtime; Phase 3c does the cutover.

**Architecture:** One new Python module (`panel/dispatch.py`) with one mockable seam (`_invoke_nat`). The `dispatch()` entry-point wraps `_invoke_nat` with an ERROR-fallback so all failures (network, parse, unsupported backend, OVERTURN+ALTERNATIVE:n/a) become `VERDICT: ERROR` verdict files — never crashes. Tests mock at `_invoke_nat` only; real NAT / HTTP / models are integration territory per the spec's "Mock discipline" rule.

**Tech Stack:** Python 3.12 (`/opt/homebrew/bin/python3.12`), `nvidia-nat[langchain]` (>=1.6, <2.0) installed via `pip install --user --break-system-packages` (matches Phase 3a's PyYAML pattern, not pipx — pipx venvs are isolated and unusable from user-site Python). Tests run via `~/.local/pipx/venvs/pytest/bin/pytest` direct path — NOT `pipx run pytest` (which creates ephemeral venvs that ignore injects).

**Spec:** `docs/superpowers/specs/2026-05-15-validate-recommendation-v3-nat-native-design.md` (commit `c80b2f6`). Section: "Dispatchers → `panel/dispatch.py` (NAT integration)" and "Locked design decisions #9 (NAT substrate)".

**Pre-flight context:**
- Phase 3a shipped on `~/.claude/` `main`: commits `7e5fe79` (`config.py`), `1b909d3` (`personas/{da,pe,qa}.md`), `2b374cf` (`personas.py`), `383c8e8` (`cli.py` + dispatch stub), `d312654` (default `config.yml`), plus polish patches. 60 pytest cases pass via `~/.local/pipx/venvs/pytest/bin/pytest`.
- `~/.claude/panel/config.yml` exists with DA enabled (nat-nim, model `nvidia/nemotron-3-super-v3`). `panel lint-config` confirms.
- `~/.claude/` git repo enforces signed commits (`-s` DCO sign-off + `-S` GPG signature).
- PyYAML 6.0.3 is in `/opt/homebrew/bin/python3.12` user-site AND in `~/.local/pipx/venvs/pytest/` injects.
- Legacy v1 `dispatch-da.sh` + `dispatch-da_test.sh` + `aggregate_test.sh` all pass and remain the runtime path until Phase 3c.

---

## File Structure

Tasks land into `/Users/eduardoa/.claude/` (the user's `~/.claude/` git repo):

| File | Disposition | Responsibility |
|---|---|---|
| `skills/validate-recommendation/panel/dispatch.py` | **Create** | `dispatch()` CLI entry; `_invoke_nat()` mockable seam; `_extract_content()`, `_format_verdict()`, `_write_verdict_file()` helpers; ERROR-fallback wrapping. |
| `skills/validate-recommendation/panel/tests/test_dispatch.py` | **Create** | TDD test suite. Mocks `panel.dispatch._invoke_nat` only — no `requests`/`httpx`/`nat.*` mocking. |
| `skills/validate-recommendation/panel/cli.py` | **Modify** | Replace the Phase 3a dispatch stub body (`return 2 / "not yet implemented"`) with `from panel.dispatch import dispatch; return dispatch(...)`. argparse surface unchanged. |
| `skills/validate-recommendation/panel/tests/test_cli_lint_config.py` | **Modify** | Remove `test_dispatch_stub_returns_phase3b_message` — obsolete after the stub goes away. |
| `skills/validate-recommendation/panel/tests/test_cli_dispatch.py` | **Create** | CLI integration test: confirms `panel dispatch ...` calls `panel.dispatch.dispatch(...)` with arguments threaded correctly. Mocks `dispatch` itself (the CLI's only job is argparse → function call). |

Untouched (deferred to later phases): `dispatch-da.sh`, `dispatch-da_test.sh`, `aggregate.sh`, `panel/{verdict,sanitize,trace,aggregate,config,personas}.py`, `SKILL.md`, `personas/`, `personas.md`, `~/.claude/panel/config.yml`.

---

## Tasks

### Task 1: Pre-flight — install `nvidia-nat[langchain]` for `/opt/homebrew/bin/python3.12`

**Files:** none modified. Environment setup.

- [ ] **Step 1: Verify NAT is not already importable**

```bash
/opt/homebrew/bin/python3.12 -c "import nat; print('nat:', getattr(nat, '__version__', '(no __version__)'))" 2>&1
```

Expected if missing: `ModuleNotFoundError: No module named 'nat'`.
Expected if present: a version string — skip to Step 3.

- [ ] **Step 2: Install via `pip install --user --break-system-packages`**

PEP 668 blocks unflagged `pip install` on Homebrew Python; `--break-system-packages` is the documented override for user-site installs. `nvidia-nat[langchain]` pulls the langchain extras NAT needs for its LLM client classes.

```bash
/opt/homebrew/bin/python3.12 -m pip install --user --break-system-packages 'nvidia-nat[langchain]>=1.6,<2.0' 2>&1 | tail -5
```

Expected: `Successfully installed nvidia-nat-1.x.x ...` (plus langchain dependencies). The install may take 60-120 seconds.

- [ ] **Step 3: Verify import works from system python3.12**

```bash
/opt/homebrew/bin/python3.12 -c "import nat; print('nat:', getattr(nat, '__version__', 'present'))"
```

Expected: a version string (e.g. `nat: 1.6.0`) printed, exit 0.

- [ ] **Step 4: Verify pipx pytest can also import NAT**

Tests in Task 3 mock `_invoke_nat` so they don't actually need nat installed to run — but conftest may need to import `panel.dispatch` for fixtures, which transitively imports nat lazily. To be safe:

```bash
pipx inject pytest 'nvidia-nat[langchain]' --force 2>&1 | tail -3
~/.local/pipx/venvs/pytest/bin/python -c "import nat; print('pytest-venv nat:', getattr(nat, '__version__', 'present'))"
```

Expected: import succeeds in the pipx pytest venv. (If this step is skipped, Task 3 tests still pass because `_invoke_nat`'s `from nat.llm.*` imports are lazy and never run when `_invoke_nat` is mocked. The inject is defense-in-depth.)

No commit for Task 1 (environment only).

---

### Task 2: Discover real NAT module paths and response shape

**Files:** none modified. Research only.

The spec's example `_invoke_nat` uses `nat.llm.nim_llm.NIMLLM`, `nat.llm.anthropic_llm.AnthropicLLM`, `nat.llm.openai_llm.OpenAILLM` but notes "actual import path verified during impl". Phase 3b Task 2 IS that verification.

- [ ] **Step 1: List all importable submodules under `nat`**

```bash
/opt/homebrew/bin/python3.12 -c "
import nat, pkgutil
for m in pkgutil.walk_packages(nat.__path__, prefix='nat.'):
    print(m.name)
" 2>&1 | grep -iE '(llm|nim|anthropic|openai)' | sort
```

Expected: lines naming the LLM submodules. The spec's guesses are likely correct but the prefix (`nat.llm.*` vs `nat.builder.llm.*` vs another) is determined here.

- [ ] **Step 2: Inspect the class names and constructor signatures**

For each candidate path found in Step 1 (substitute the verified path):

```bash
/opt/homebrew/bin/python3.12 -c "
import importlib, inspect
mod = importlib.import_module('nat.llm.nim_llm')   # ← substitute verified path
print('module:', mod.__name__)
for name, obj in inspect.getmembers(mod, inspect.isclass):
    if 'LLM' in name or 'NIM' in name:
        print(' class:', name, '— init sig:', inspect.signature(obj.__init__))
"
```

Expected: a single LLM class per module (e.g. `NIMLLM`) with constructor accepting `model`, `max_tokens`, `temperature` (or near-equivalents). Note any keyword renames.

- [ ] **Step 3: Verify the `invoke()` method shape**

```bash
/opt/homebrew/bin/python3.12 -c "
import importlib, inspect
mod = importlib.import_module('nat.llm.nim_llm')
cls = mod.NIMLLM   # ← substitute verified class name
print('invoke signature:', inspect.signature(cls.invoke))
print('invoke doc:', (inspect.getdoc(cls.invoke) or '(no docstring)').splitlines()[:5])
"
```

Expected: `invoke(self, messages=..., ...)` accepting a list of `{role, content}` dicts. Return type is typically langchain's `AIMessage` (has `.content` attribute holding a string).

- [ ] **Step 4: Confirm the response shape**

Without making a real API call (no key required for the shape probe):

```bash
/opt/homebrew/bin/python3.12 -c "
# Inspect what invoke() is documented or annotated to return.
from typing import get_type_hints
import importlib
mod = importlib.import_module('nat.llm.nim_llm')
cls = mod.NIMLLM
try:
    hints = get_type_hints(cls.invoke)
    print('invoke return type:', hints.get('return', '(unannotated)'))
except Exception as e:
    print('hint extraction failed:', e)
"
```

Expected: `AIMessage` (langchain) or similar with `.content`. Record findings.

- [ ] **Step 5: Capture findings in a scratch note**

Write a brief plain-text note to `~/.claude/skills/validate-recommendation/panel/.nat-discovery-notes.md` (gitignored — informational only):

```bash
cat > ~/.claude/skills/validate-recommendation/panel/.nat-discovery-notes.md <<'EOF'
# NAT discovery notes (Phase 3b Task 2)
# Generated on: $(date -u +%Y-%m-%dT%H:%M:%SZ)

nat version: <fill in>
nim_llm path: <verified path>
anthropic_llm path: <verified path>
openai_llm path: <verified path>
Response object type: <verified>
Response content access: response.content / response['content'] / str(response)
Notable kwarg renames: <list any>
EOF
```

(This file is informational; Task 3's `_invoke_nat` uses the verified paths directly. The note exists so a future engineer can re-discover paths after NAT version bumps without re-running this whole task.)

- [ ] **Step 6: Add `.nat-discovery-notes.md` to gitignore (if not already covered)**

```bash
grep -q "^\.nat-discovery-notes\.md$\|^\*\.discovery-notes\.md$" ~/.claude/.gitignore || \
    echo "skills/validate-recommendation/panel/.nat-discovery-notes.md" >> ~/.claude/.gitignore
```

No commit for Task 2 (research; the discovery file is gitignored).

---

### Task 3: Implement `panel/dispatch.py` with TDD

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_dispatch.py`
- Create: `~/.claude/skills/validate-recommendation/panel/dispatch.py`

- [ ] **Step 1: Write the failing tests** (`panel/tests/test_dispatch.py`)

```python
"""Tests for panel.dispatch — NAT-backed panelist dispatch.

The single mock seam is `panel.dispatch._invoke_nat`. Tests never mock
requests/httpx/nat.* directly — that would couple to NAT internals and
break on every NAT version bump (per spec section 'Mock discipline').

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
- Response shape variations: AIMessage-like (.content), dict, plain string
"""
import os
import stat
import textwrap
from pathlib import Path
from unittest.mock import patch

import pytest


# Shared fixtures live in conftest.py. This file adds a per-test
# tmpdir-based config + persona + prompt file builder.

def _fixture_files(tmp_path, *, panelist_id="da", backend="nat-nim",
                   model="test-model", persona_role="DA"):
    cfg_path = tmp_path / "config.yml"
    cfg_path.write_text(textwrap.dedent(f"""
        version: 1
        panelists:
          - id: {panelist_id}
            role: {persona_role}
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
    """Shape mirrors langchain.schema.AIMessage (has .content)."""
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
    assert rc == 0  # verdict file was written → exit 0 per spec
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: ERROR" in written
    assert "backend unreachable" in written
    assert "ALTERNATIVE: n/a" in written


def test_dispatch_writes_error_verdict_on_malformed_response(tmp_path):
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    fake_response = _FakeAIMessage("This is not a verdict; the model rambled.")
    with patch("panel.dispatch._invoke_nat", return_value=fake_response):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    written = out.read_text(encoding="utf-8")
    assert "VERDICT: ERROR" in written


def test_dispatch_writes_error_on_overturn_with_alternative_na(tmp_path):
    """Phase 1 bug #3: OVERTURN + ALTERNATIVE: n/a must be rejected.

    A model that 'overturns' without naming an alternative hasn't done its
    job. This is structurally identical to a HOLD with extra theater.
    """
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
    assert "ALTERNATIVE" in written and "n/a" in written.split("ALTERNATIVE:")[1]


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
    assert not out.exists()  # caller bug → no verdict written


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
    cfg, persona, prompt, out = _fixture_files(tmp_path, panelist_id="da")
    rc = dispatch(panelist_id="not-a-real-id", config_path=cfg,
                  persona_path=persona, prompt_file=prompt, output=out)
    assert rc != 0
    assert not out.exists()


def test_dispatch_threads_system_prompt_and_user_to_invoke_nat(tmp_path):
    """The contract between dispatch() and _invoke_nat()."""
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
    assert "test reviewer" in captured["system"]   # from persona.system_prompt
    assert "Example output" in captured["system"]   # one_shot_example appended
    assert "Should we pick option A?" in captured["user"]
    assert captured["panelist_id"] == "da"


def test_dispatch_response_with_content_attribute_extracted(tmp_path):
    """langchain AIMessage shape (response.content)."""
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
    """Dict response shape: response['content']."""
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    with patch("panel.dispatch._invoke_nat",
               return_value={"content": "VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n"}):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    assert "VERDICT: HOLD" in out.read_text(encoding="utf-8")


def test_dispatch_response_as_plain_string_extracted(tmp_path):
    """Plain string response — some backends may return raw strings."""
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path)
    with patch("panel.dispatch._invoke_nat",
               return_value="VERDICT: HOLD\nRATIONALE: ok\nALTERNATIVE: n/a\n"):
        rc = dispatch(panelist_id="da", config_path=cfg, persona_path=persona,
                      prompt_file=prompt, output=out)
    assert rc == 0
    assert "VERDICT: HOLD" in out.read_text(encoding="utf-8")


def test_dispatch_unsupported_backend_returns_error_verdict(tmp_path):
    """Unsupported backend: _invoke_nat raises ValueError → ERROR verdict, exit 0."""
    from panel.dispatch import dispatch
    cfg, persona, prompt, out = _fixture_files(tmp_path, backend="claude-subagent")
    # claude-subagent isn't a nat-* backend; dispatch.py SHOULD refuse it
    # via _invoke_nat raising ValueError. But because dispatch's config
    # loader uses Phase 3a validation, claude-subagent requires subagent_type.
    # So write a config that names a bad backend that's still nat-shaped.
    cfg.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da
            role: DA
            enabled: true
            backend: claude-subagent
            subagent_type: principal-engineer
    """).strip() + "\n")
    # claude-subagent is not a NAT backend; dispatch must reject it
    # via _invoke_nat (which raises ValueError) → ERROR verdict.
    # We don't mock _invoke_nat here because we want to exercise the real
    # branch that raises ValueError for unsupported backends.
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

Substitute the verified import paths from Task 2 in the `_invoke_nat` body before saving. The paths in the snippet below are the spec's expected values — re-check against Task 2's findings.

```python
"""NAT-backed panelist dispatch.

Called per nat-* panelist via `python -m panel dispatch --panelist <id>
--config <path> --persona <path> --prompt-file <path> --output <path>`.

Contract (per v3 spec section 'Dispatchers'):
- Returns 0 if a verdict file was written (success path OR ERROR path).
- Returns non-zero only when caller-supplied paths/ids are invalid
  (missing config, missing persona, missing prompt, unknown panelist id).
- All runtime failures (network, timeout, parse error, unsupported
  backend, OVERTURN+ALTERNATIVE:n/a) become VERDICT: ERROR verdict files.
- Verdict files are written with mode 0600 (umask 077).
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

from panel.config import load_config, ConfigError, Panelist
from panel.personas import load_persona, PersonaError
from panel.verdict import parse_verdict


def _invoke_nat(panelist: Panelist, system: str, user: str) -> object:
    """The single mockable seam — tests mock this function entirely.

    Real implementation imports NAT LLM clients lazily so tests don't pay
    the NAT-import cost. Paths verified in Phase 3b Task 2.
    """
    backend = panelist.backend
    if backend == "nat-nim":
        from nat.llm.nim_llm import NIMLLM
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


def _extract_content(response: object) -> str:
    """Pull text content out of NAT/langchain response object variants."""
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
        # Phase 1 bug #3: OVERTURN without a concrete alternative is malformed.
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

**Verify the parse_verdict import path.** Phase 2's `panel/verdict.py` exposes a `parse_verdict(text) -> ParsedVerdict` function with `.verdict / .rationale / .alternative` attributes (and possibly a `VerdictError` for malformed text). Before pasting the code above, confirm by running:

```bash
/opt/homebrew/bin/python3.12 -c "
import sys; sys.path.insert(0, '/Users/eduardoa/.claude/skills/validate-recommendation')
from panel.verdict import parse_verdict
print('parse_verdict ok; signature:', parse_verdict.__doc__ or '(no doc)')
v = parse_verdict('VERDICT: HOLD\\nRATIONALE: ok\\nALTERNATIVE: n/a')
print('parsed:', v.verdict, '|', v.rationale, '|', v.alternative)
"
```

Expected: prints `HOLD | ok | n/a`. If the attribute names differ (e.g. `.verdict_type` instead of `.verdict`), adjust the dispatch.py code's parsed-field accesses accordingly.

- [ ] **Step 4: Run tests to verify pass**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_dispatch.py -v
```

Expected: 15 tests pass.

Also run the existing 60-test suite to confirm no regression:

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -v
```

Expected: 60 (existing) + 15 (new) = 75 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/dispatch.py skills/validate-recommendation/panel/tests/test_dispatch.py
cd ~/.claude && git commit -s -S -m "feat(panel): dispatch.py NAT integration with _invoke_nat seam

Adds panel/dispatch.py — replaces Phase 3a CLI stub with real NAT
dispatch. The _invoke_nat() function is the single mockable seam:
tests mock it entirely; below it lies real NAT (nat.llm.{nim,anthropic,
openai}_llm) and real HTTP, both integration territory.

Contract (v3 spec, section 'Dispatchers'):
  - Exit 0 if a verdict file was written (success OR ERROR path)
  - Exit 1 only on caller-bug paths (missing config/persona/prompt/id)
  - All runtime failures → VERDICT: ERROR file (never crashes)
  - File mode 0600 (umask 077)
  - Preserves Phase 1 bug #3 fix: OVERTURN + ALTERNATIVE: n/a → ERROR

15 pytest cases. Tests mock at _invoke_nat only — no requests/httpx/
nat.* mocking, per spec's 'Mock discipline' rule (decoupled from NAT
version bumps)."
```

---

### Task 4: Wire `cli.py` dispatch subcommand to real dispatch

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_lint_config.py`
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_dispatch.py`

- [ ] **Step 1: Write the failing test for the new CLI wiring** (`panel/tests/test_cli_dispatch.py`)

```python
"""CLI tests for `panel dispatch` after Phase 3b wiring.

The CLI's only job for dispatch is argparse → call dispatch(). We mock
panel.dispatch.dispatch and confirm the args land correctly. The dispatch
function itself is exercised by test_dispatch.py.
"""
import textwrap
from unittest.mock import patch

import pytest


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
        # called with positionals — extract by signature
        args = mock_dispatch.call_args.args
        # dispatch(panelist_id, config_path, persona_path, prompt_file, output)
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
    """CLI propagates the dispatch() return value as the process exit code."""
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


def test_cli_dispatch_uses_default_config_when_omitted(tmp_path, monkeypatch):
    """When --config omitted, falls back to ~/.claude/panel/config.yml."""
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
    # default config path is ~/.claude/panel/config.yml
    args_or_kwargs = mock_dispatch.call_args.kwargs or {
        "config_path": mock_dispatch.call_args.args[1]
    }
    config_arg = args_or_kwargs.get("config_path") or mock_dispatch.call_args.args[1]
    assert ".claude/panel/config.yml" in str(config_arg)
```

- [ ] **Step 2: Run new tests to verify failure**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_cli_dispatch.py -v
```

Expected: 3 tests collected; all FAIL because `cli.py`'s dispatch branch still returns the Phase 3a stub message (exit 2), not calling `panel.dispatch.dispatch`.

- [ ] **Step 3: Replace the stub branch in `cli.py`**

Read the current cli.py and replace the `if args.cmd == "dispatch":` block. The argparse setup at the top of the file is UNCHANGED — only the branch body changes.

Current (Phase 3a) stub body:
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

Also update the file's top docstring to reflect Phase 3b (`dispatch` is no longer "stub"):

```python
"""Top-level CLI dispatch for the panel package.

Subcommands shipped so far:
- aggregate         (Phase 2 — 2-panelist byte-parity)
- lint-config       (Phase 3a — config validation)
- dispatch          (Phase 3b — real NAT-backed panelist dispatch)

Subcommands planned for later phases:
- record-userpick   (Phase 6)
- ls, show, label, stats, replay, gc   (Phase 6)
- tune              (deferred to v1.x)
"""
```

- [ ] **Step 4: Remove the obsolete stub-message test** (`test_cli_lint_config.py`)

The test `test_dispatch_stub_returns_phase3b_message` asserts the stub's "Phase 3b" string. After Step 3, the stub is gone — the test would fail spuriously.

Edit `panel/tests/test_cli_lint_config.py`: delete the function `test_dispatch_stub_returns_phase3b_message` (and any associated helper imports if exclusively used by it). Keep `test_dispatch_subparser_registered` — that one's still valid (it just checks argparse registration via `--help`).

- [ ] **Step 5: Run all CLI tests to verify pass**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_cli_dispatch.py panel/tests/test_cli_lint_config.py panel/tests/test_cli_exit_codes.py -v
```

Expected: all tests pass. Counts:
- test_cli_dispatch.py: 3 new pass
- test_cli_lint_config.py: 4 pass (was 5; one removed)
- test_cli_exit_codes.py: 4 pass (unchanged — test_subprocess_exits_two_on_dispatch_stub still references "Phase 3b" which the dispatch function no longer prints; **verify and update this one too** in Step 6)

- [ ] **Step 6: Fix `test_cli_exit_codes.py::test_subprocess_exits_two_on_dispatch_stub`**

This subprocess test asserted exit code 2 and a "Phase 3b" message — both no longer hold. Replace it with a test that confirms `panel dispatch` now does a real dispatch (and returns whatever dispatch returns):

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
    # persona check fires before prompt check
    assert "persona" in err.lower() or "missing" in err.lower()
```

Run again to confirm green:

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -v 2>&1 | tail -5
```

Expected: full count (60 prior + 15 dispatch + 3 cli_dispatch - 1 stub-test - 0 replaced exit-code test rewritten ≈ 77 tests, all green).

- [ ] **Step 7: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/panel/cli.py skills/validate-recommendation/panel/tests/test_cli_dispatch.py skills/validate-recommendation/panel/tests/test_cli_lint_config.py skills/validate-recommendation/panel/tests/test_cli_exit_codes.py
cd ~/.claude && git commit -s -S -m "feat(panel): wire CLI dispatch to real NAT integration

Phase 3a left dispatch as a stub printing 'not yet implemented'. This
commit replaces the stub body with a call to panel.dispatch.dispatch()
and threads CLI args (--panelist, --config, --persona, --prompt-file,
--output) through to it.

Tests updated:
  - test_cli_dispatch.py (new, 3 cases) — CLI wires args to dispatch()
  - test_cli_lint_config.py — removed obsolete Phase 3a stub-message test
  - test_cli_exit_codes.py — updated subprocess-level dispatch test to
    exercise real exit codes (1 on missing persona path)

aggregate and lint-config subcommands untouched."
```

---

### Task 5: End-to-end smoke test against real Nemotron

**Files:** none modified. Verification only.

Confirms `panel dispatch` works against the real DA backend Nemotron endpoint. Requires `$PANEL_DA_API_KEY`, `$CLAUDE_PANEL_DA_ENDPOINT`, `$CLAUDE_PANEL_DA_MODEL` exported. If any is unset, skip Step 1 and document that live smoke must run before Phase 3c.

- [ ] **Step 1: Live dispatch against Nemotron**

```bash
PROMPT=$(mktemp)
OUTPUT=$(mktemp)
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

Expected: `rc=0` and the verdict file contains three lines: `VERDICT: HOLD` or `VERDICT: OVERTURN`, a `RATIONALE:` line, and `ALTERNATIVE: ...`. If the verdict is OVERTURN with `ALTERNATIVE: n/a`, the dispatch will write `VERDICT: ERROR` instead — that's the Phase 1 bug #3 fix doing its job.

- [ ] **Step 2: Confirm ERROR path also works (no API key)**

```bash
PROMPT=$(mktemp); OUTPUT=$(mktemp)
echo "Question: x?" > "$PROMPT"
(unset PANEL_DA_API_KEY; cd ~/.claude/skills/validate-recommendation && \
    /opt/homebrew/bin/python3.12 -m panel dispatch \
        --panelist da-nemotron --persona personas/da.md \
        --prompt-file "$PROMPT" --output "$OUTPUT") ; rc=$?
echo "rc=$rc"
cat "$OUTPUT"
rm -f "$PROMPT" "$OUTPUT"
```

Expected: `rc=0` (verdict file was written) and the file contains `VERDICT: ERROR` with a rationale naming the authentication/connection failure.

No commit for Task 5 (verification only).

---

### Task 6: Phase 3b sign-off

**Files:** none modified. Verification only.

- [ ] **Step 1: Full pytest suite green**

```bash
cd ~/.claude/skills/validate-recommendation && ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ 2>&1 | tail -5
```

Expected: ~77 tests pass. Breakdown:
- Phase 2 baseline (verdict / sanitize / trace / aggregate): 21
- Phase 3a (config / personas / cli_lint_config / cli_exit_codes): 39 (with 1 removed, 1 rewritten)
- Phase 3b (dispatch / cli_dispatch): 18

- [ ] **Step 2: Confirm Phase 3a + legacy v1 paths still work**

```bash
cd ~/.claude/skills/validate-recommendation && /opt/homebrew/bin/python3.12 -m panel lint-config
cd ~/.claude/skills/validate-recommendation && bash aggregate_test.sh 2>&1 | tail -3
cd ~/.claude/skills/validate-recommendation && bash dispatch-da_test.sh 2>&1 | tail -3
```

Expected:
- `lint-config` prints `OK: 1 enabled panelist(s) (of 3 configured)` plus the da-nemotron line, exit 0.
- `aggregate_test.sh` last line: PASS.
- `dispatch-da_test.sh` last line: PASS.

The v1 panel still works for the runtime path; Phase 3b ships parallel code that's not yet wired into orchestration.

- [ ] **Step 3: Verify `~/.claude/` commits**

```bash
cd ~/.claude && git log --oneline -5
```

Expected: 2 new commits land on top of the Phase 3a + cfo-skill baseline:
- `feat(panel): dispatch.py NAT integration with _invoke_nat seam`
- `feat(panel): wire CLI dispatch to real NAT integration`

- [ ] **Step 4: Document the runtime invocation in a quick smoke-test runbook**

Append a one-paragraph note to the skill's `README.md` covering how to manually invoke `panel dispatch` for future debugging. (No code change to dispatch itself; readme-only.)

The text to add (under an existing 'Manual invocation' or new 'Phase 3b smoke' section):

```markdown
## Phase 3b: manual `panel dispatch` invocation

Run one panelist end-to-end against its configured NAT backend:

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

Required env vars per backend:
- `nat-nim`: `$PANEL_DA_API_KEY` (or `$NVIDIA_API_KEY`), `$CLAUDE_PANEL_DA_ENDPOINT`, `$CLAUDE_PANEL_DA_MODEL`
- `nat-anthropic`: `$ANTHROPIC_API_KEY`
- `nat-openai`: `$OPENAI_API_KEY`

If a required env var is unset, dispatch still exits 0 — the verdict
file will contain `VERDICT: ERROR` with the auth failure in the rationale.
```

Commit:

```bash
cd ~/.claude && git add skills/validate-recommendation/README.md
cd ~/.claude && git commit -s -S -m "docs(panel): document Phase 3b panel dispatch invocation

Adds 'Phase 3b: manual panel dispatch invocation' section to the skill
README covering CLI flags, exit codes, and per-backend env-var
requirements. No code change."
```

Phase 3b sign-off when all four Steps pass. Next phase (3c) rewrites
`panel/aggregate.py` for N panelists, extracts `panel/severity.py`,
rewires `SKILL.md` to call `python -m panel dispatch` and `python -m
panel aggregate` directly, and deletes `dispatch-da.sh`, `aggregate.sh`,
`dispatch-da_test.sh`, and the old `personas.md`.

---

## Self-review

**Spec coverage:**
- Spec section "Dispatchers → `panel/dispatch.py` (NAT integration)" → Tasks 1, 2, 3.
- Spec section "Locked design decisions #9 (NAT substrate, library-mode)" → Task 1.
- Spec section "Key implementation seam: `_invoke_nat`" → Task 3, dispatch.py snippet.
- Spec section "Mock discipline" (no requests/httpx/nat.* mocks) → Task 3, test_dispatch.py docstring + test design.
- Spec section "Phase 3b — NAT dispatch" (migration plan row) → Tasks 1-6 cover the row's deliverables.
- Spec section "Security posture / API keys" → Tasks 3 and 5 (env var only; never on argv; never logged).
- Spec section "Error handling matrix" (panelist HTTP failure / malformed / OVERTURN-no-alt) → Task 3 tests 3, 4, 5.
- Spec section "Persona file format" (system_prompt + one_shot_example concat) → Task 3, dispatch.py compose step + test_dispatch_threads_system_prompt_and_user_to_invoke_nat.

**Out-of-scope (deferred phases) and explicitly NOT touched:**
- `panel/aggregate.py` (Phase 3c rewrites for N panelists)
- `panel/severity.py` (Phase 3c extracts)
- `SKILL.md` (Phase 3c rewires)
- `dispatch-da.sh`, `aggregate.sh`, `dispatch-da_test.sh`, `personas.md` (Phase 3c deletes)
- `panel/state.py`, `panel/decisions.py` (Phases 5 + 6)

**Placeholder scan:** No `TBD`, `TODO`, or "implement later" markers. Every code block is the actual code an engineer types. Every command is an exact invocation. Every expected output is concrete.

**Type consistency:**
- `Panelist` dataclass referenced from `panel.config` (defined in Phase 3a) — fields `id`, `role`, `backend`, `model`, `max_tokens`, `temperature` match.
- `Persona` dataclass from `panel.personas` (Phase 3a) — fields `system_prompt`, `one_shot_example`, `user_prompt_template` match.
- `parse_verdict` from `panel.verdict` (Phase 2) — Task 3 Step 3 includes a verification probe before relying on the API; if attribute names differ, the dispatch.py code is adjusted there.
- `dispatch()` signature in Task 3 = `(panelist_id, config_path, persona_path, prompt_file, output)`. cli.py wiring in Task 4 uses the same kwarg names.
- `_invoke_nat()` signature `(panelist, system, user) -> object` is the mock seam; tests in Task 3 use this exact signature via `patch("panel.dispatch._invoke_nat", ...)`.

**Test-count math:** Phase 3a end-of-phase = 60. Task 3 adds 15 → 75. Task 4 adds 3 new and removes 1 old (`test_dispatch_stub_returns_phase3b_message`) and rewrites 1 (the dispatch subprocess test) → 75 + 3 - 1 + 0 = 77. Task 6 Step 1 expects ~77. Consistent.

**Phase boundary:** Phase 3b ships `panel dispatch` as a self-contained CLI surface. SKILL.md does NOT call it yet; the runtime path remains the v1 `dispatch-da.sh + aggregate.sh`. Phase 3c does the cutover. This explicit isolation means Phase 3b is mergeable + signed-off independently — its only externally-visible change is `python -m panel dispatch` exiting 0 with a real verdict instead of exit 2 with a stub message.
