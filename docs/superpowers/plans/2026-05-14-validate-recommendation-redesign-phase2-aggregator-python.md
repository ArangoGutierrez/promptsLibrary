# validate-recommendation v2 — Phase 2: Port aggregator to Python

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `aggregate.sh` with a Python implementation (`python -m panel aggregate`) at byte-for-byte parity. Keep `aggregate.sh` as a thin shim for one release. Existing `aggregate_test.sh` must continue to pass against the new Python implementation routed through the shim.

**Architecture:** Stdlib-only Python package at `~/.claude/skills/validate-recommendation/panel/`. Subcommand pattern (`argparse`-based dispatch in `cli.py`). One file per concern: `verdict.py` (parsing + validation), `aggregate.py` (decide logic), `sanitize.py` (markdown stripper), `trace.py` (append-only log). `__main__.py` makes `python -m panel` invocable. Tests under `panel/tests/` use `pytest`.

**Tech Stack:** Python 3.11+ (stdlib only — `argparse`, `re`, `pathlib`, `json`, `hashlib`, `datetime`). `pytest` for tests (installed in user env; no project-level dep file in Phase 2). Bash shim retained.

**Pre-flight (verify before starting):**
- Phase 1 has shipped (`dispatch-da.sh` produces well-formed verdicts).
- `python3 --version` ≥ 3.11.
- `pytest --version` works (install via `pipx install pytest` or `python3 -m pip install --user pytest` if missing).
- `~/.claude/skills/validate-recommendation/aggregate_test.sh` passes.

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/skills/validate-recommendation/panel/__init__.py` | **Create**: empty module marker. |
| `~/.claude/skills/validate-recommendation/panel/__main__.py` | **Create**: `from panel.cli import main; main()` so `python -m panel` works. |
| `~/.claude/skills/validate-recommendation/panel/cli.py` | **Create**: top-level argparse with `aggregate` subcommand. Other subcommands stubbed `NotImplemented` for Phase 2. |
| `~/.claude/skills/validate-recommendation/panel/verdict.py` | **Create**: `parse_verdict_file()`, `Verdict` dataclass, validation helpers. |
| `~/.claude/skills/validate-recommendation/panel/aggregate.py` | **Create**: `aggregate(da_path, pe_path, recommended_label)` returns directive string identical to `aggregate.sh` output. |
| `~/.claude/skills/validate-recommendation/panel/sanitize.py` | **Create**: `strip_markdown(text)` — same patterns as `aggregate.sh`'s `sanitize()`. |
| `~/.claude/skills/validate-recommendation/panel/trace.py` | **Create**: `log_verdict(outcome, detail)` writes to `$CLAUDE_PANEL_TRACE_LOG` or `~/.claude/debug/panel-trace.log`. |
| `~/.claude/skills/validate-recommendation/panel/tests/__init__.py` | **Create**: empty. |
| `~/.claude/skills/validate-recommendation/panel/tests/conftest.py` | **Create**: pytest fixtures — temp dirs, fixture-file paths, monkeypatched trace log. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_verdict.py` | **Create**: tests for `verdict.py`. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py` | **Create**: tests for `aggregate.py` — parity coverage with `aggregate_test.sh`. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_sanitize.py` | **Create**: tests for `sanitize.py` — markdown-injection vectors. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_trace.py` | **Create**: tests for `trace.py` — append behavior, env override. |
| `~/.claude/skills/validate-recommendation/aggregate.sh` | **Replace** with a 5-line shim that execs `python3 -m panel aggregate "$@"` from the skill dir. The shim signals deprecation in a comment and is removed in Phase 3. |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify**: step 7 ("Run aggregate.sh") updated to mention the shim is now Python under the hood. No behavior change visible to the orchestrating skill. |

---

## Tasks

### Task 1: Bootstrap `panel/` package skeleton

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/__init__.py`
- Create: `~/.claude/skills/validate-recommendation/panel/__main__.py`
- Create: `~/.claude/skills/validate-recommendation/panel/cli.py`

- [ ] **Step 1: Create `__init__.py`**

```python
"""validate-recommendation panel — Python implementation."""

__version__ = "0.2.0"
```

- [ ] **Step 2: Create `__main__.py`**

```python
from panel.cli import main

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Create `cli.py` with argparse skeleton**

```python
"""Top-level CLI dispatch for the panel package.

Subcommands added incrementally across Phases 2-6:
- aggregate         (Phase 2 — port of aggregate.sh)
- record-userpick   (Phase 6)
- ls, show, label, stats, replay, lint-config, gc   (Phase 6)
- tune              (v1.x deferred)
"""
import argparse
import sys


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="panel", description="validate-recommendation panel CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    agg = sub.add_parser("aggregate", help="Aggregate panelist verdicts into a directive")
    agg.add_argument("--da", required=True, help="Path to DA verdict file")
    agg.add_argument("--pe", required=True, help="Path to PE verdict file")
    agg.add_argument("--recommended-label", required=True, help="The recommended option label")

    args = parser.parse_args(argv)

    if args.cmd == "aggregate":
        from panel.aggregate import aggregate
        print(aggregate(args.da, args.pe, args.recommended_label))
        return 0

    parser.error(f"unknown command: {args.cmd}")
    return 2
```

- [ ] **Step 4: Verify the skeleton invokes**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m panel aggregate --help`
Expected: argparse help text with `--da`, `--pe`, `--recommended-label` arguments listed. Exit 0.

If you get `ModuleNotFoundError: No module named 'panel'`, ensure CWD is the skill directory (which contains `panel/`).

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/__init__.py panel/__main__.py panel/cli.py
git commit -s -S -m "feat(panel): bootstrap panel/ Python package skeleton"
```

---

### Task 2: Write failing test for `parse_verdict_file()`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/__init__.py` (empty)
- Create: `~/.claude/skills/validate-recommendation/panel/tests/conftest.py`
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_verdict.py`

- [ ] **Step 1: Create `tests/__init__.py`**

```python
```

(Empty file; just marks the directory as a package.)

- [ ] **Step 2: Create `tests/conftest.py` with fixture path helper**

```python
"""Shared pytest fixtures for panel tests."""
from pathlib import Path
import pytest

SKILL_DIR = Path(__file__).resolve().parent.parent.parent  # .../validate-recommendation/
FIXTURES_DIR = SKILL_DIR / "fixtures"


@pytest.fixture
def fixtures_dir() -> Path:
    """Path to the validate-recommendation skill's fixtures directory.

    Used by aggregate-parity tests that reuse the same fixtures as
    aggregate_test.sh (da_hold.txt, da_overturn_b.txt, etc).
    """
    return FIXTURES_DIR
```

- [ ] **Step 3: Create `tests/test_verdict.py`**

```python
"""Tests for panel.verdict — verdict file parsing and validation."""
import pytest
from pathlib import Path


def test_parse_hold_verdict(fixtures_dir, tmp_path):
    from panel.verdict import parse_verdict_file
    v = parse_verdict_file(fixtures_dir / "da_hold.txt")
    assert v.verdict == "HOLD"
    assert v.rationale != ""
    assert v.alternative == "n/a"


def test_parse_overturn_verdict(fixtures_dir, tmp_path):
    from panel.verdict import parse_verdict_file
    v = parse_verdict_file(fixtures_dir / "da_overturn_b.txt")
    assert v.verdict == "OVERTURN"
    assert v.rationale != ""
    assert v.alternative == "Option B"


def test_parse_malformed_returns_unknown_verdict(fixtures_dir, tmp_path):
    """A file without VERDICT/RATIONALE/ALTERNATIVE lines is unparseable.

    The parser returns an empty-verdict object; validation happens at the
    aggregator level. This mirrors aggregate.sh's behavior (parse_field
    returns empty, then the case statement classifies as ERROR).
    """
    from panel.verdict import parse_verdict_file
    v = parse_verdict_file(fixtures_dir / "malformed.txt")
    assert v.verdict == ""  # not one of HOLD/OVERTURN; caller treats as ERROR
    assert v.rationale == ""


def test_parse_strips_field_prefix(tmp_path):
    """parse_verdict_file strips 'FIELD: ' from each line, preserving the rest."""
    from panel.verdict import parse_verdict_file
    p = tmp_path / "v.txt"
    p.write_text("VERDICT: HOLD\nRATIONALE: A short reason here.\nALTERNATIVE: n/a\n")
    v = parse_verdict_file(p)
    assert v.verdict == "HOLD"
    assert v.rationale == "A short reason here."
    assert v.alternative == "n/a"
```

- [ ] **Step 4: Run the tests — they should FAIL because `verdict.py` doesn't exist**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_verdict.py -v`
Expected: `ModuleNotFoundError: No module named 'panel.verdict'` for each test.

---

### Task 3: Implement `panel/verdict.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/verdict.py`

- [ ] **Step 1: Create `verdict.py`**

```python
"""Verdict file parsing.

A verdict file is a plain text file with three known fields:

    VERDICT: HOLD|OVERTURN
    RATIONALE: <one paragraph>
    ALTERNATIVE: <option label or n/a>

`parse_verdict_file` returns a `Verdict` object. It does NOT validate the
values — that's the aggregator's job. Unknown or missing fields come back
as empty strings; the aggregator treats them as ERROR.

Matches the field-extraction behavior of aggregate.sh's `parse_field` (uses
`grep -m1` semantics — first matching line, strip the field prefix).
"""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Verdict:
    verdict: str  # "HOLD" | "OVERTURN" | "" (empty means unparseable)
    rationale: str
    alternative: str


def _first_field(lines: list[str], field: str) -> str:
    prefix = f"{field}: "
    for line in lines:
        if line.startswith(prefix):
            return line[len(prefix):].rstrip("\n")
    return ""


def parse_verdict_file(path: str | Path) -> Verdict:
    """Read a verdict file and extract VERDICT/RATIONALE/ALTERNATIVE.

    Missing fields come back as empty strings. The aggregator decides
    what to do with malformed verdicts.
    """
    text = Path(path).read_text(encoding="utf-8")
    lines = text.splitlines()
    return Verdict(
        verdict=_first_field(lines, "VERDICT"),
        rationale=_first_field(lines, "RATIONALE"),
        alternative=_first_field(lines, "ALTERNATIVE"),
    )
```

- [ ] **Step 2: Run the tests — they should now PASS**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_verdict.py -v`
Expected: all 4 tests pass.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/verdict.py panel/tests/__init__.py panel/tests/conftest.py panel/tests/test_verdict.py
git commit -s -S -m "feat(panel): port verdict-file parser to Python"
```

---

### Task 4: Write failing tests for `panel/sanitize.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_sanitize.py`

- [ ] **Step 1: Create `test_sanitize.py`**

```python
"""Tests for panel.sanitize — strips markdown injection vectors from
panelist rationale text before embedding in user-visible summary.

Parity with aggregate.sh's sanitize() function: strips image syntax,
link syntax, and backticks. These vectors could otherwise let a
prompt-injected DA backend inject clickable links or inline code into
the augmented AskUserQuestion text the user sees.
"""


def test_strips_image_syntax():
    from panel.sanitize import strip_markdown
    assert strip_markdown("see ![alt](http://evil.example.com/track.png) pixel") == "see  pixel"


def test_strips_link_syntax():
    from panel.sanitize import strip_markdown
    assert strip_markdown("[click](http://evil.example.com) here") == " here"


def test_strips_backticks():
    from panel.sanitize import strip_markdown
    assert strip_markdown("run `rm -rf /` now") == "run rm -rf / now"


def test_preserves_plain_text():
    from panel.sanitize import strip_markdown
    assert strip_markdown("a perfectly normal rationale.") == "a perfectly normal rationale."


def test_strips_combination():
    from panel.sanitize import strip_markdown
    src = "Check [docs](http://x) for `cmd` and ![pic](http://y) details"
    assert strip_markdown(src) == "Check  for cmd and  details"
```

- [ ] **Step 2: Run tests — they should FAIL**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_sanitize.py -v`
Expected: `ModuleNotFoundError: No module named 'panel.sanitize'`.

---

### Task 5: Implement `panel/sanitize.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/sanitize.py`

- [ ] **Step 1: Create `sanitize.py`**

```python
"""Sanitize markdown injection vectors from panelist text.

Parity with aggregate.sh's sanitize() function:
    sed -e 's/!\\[[^]]*\\]([^)]*)//g' \\
        -e 's/\\[[^]]*\\]([^)]*)//g' \\
        -e 's/`//g'

Applied to rationale + alternative text before embedding in the
user-visible Panel review summary. Defense in depth — format
compliance is the first line of defense; a prompt-injected DA backend
that does pass format validation might still try to inject HTML-ish
markdown.
"""
import re

# Image first (longest match) — !\[alt](url)
_IMAGE_RE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
# Then link — [text](url)
_LINK_RE = re.compile(r"\[[^\]]*\]\([^)]*\)")
# Then backticks (any backtick character)
_BACKTICK_RE = re.compile(r"`")


def strip_markdown(text: str) -> str:
    """Remove image syntax, link syntax, and backticks from `text`."""
    text = _IMAGE_RE.sub("", text)
    text = _LINK_RE.sub("", text)
    text = _BACKTICK_RE.sub("", text)
    return text
```

- [ ] **Step 2: Run tests — should PASS**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_sanitize.py -v`
Expected: all 5 tests pass.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/sanitize.py panel/tests/test_sanitize.py
git commit -s -S -m "feat(panel): port markdown sanitizer to Python"
```

---

### Task 6: Write failing tests for `panel/trace.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_trace.py`

- [ ] **Step 1: Create `test_trace.py`**

```python
"""Tests for panel.trace — append-only verdict trace log.

Parity with aggregate.sh's log_verdict(): writes a single-line entry
with timestamp, session id, outcome, and detail. Default path is
~/.claude/debug/panel-trace.log; override via $CLAUDE_PANEL_TRACE_LOG
(used by tests and ops to redirect).
"""
import os
from pathlib import Path


def test_log_verdict_appends_line(tmp_path, monkeypatch):
    from panel.trace import log_verdict
    log_path = tmp_path / "trace.log"
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(log_path))
    monkeypatch.setenv("CLAUDE_SESSION_ID", "test-session")
    log_verdict("HOLD", "DA: foo | PE: bar")
    content = log_path.read_text()
    assert "outcome=HOLD" in content
    assert 'detail="DA: foo | PE: bar"' in content
    assert "session=test-session" in content


def test_log_verdict_creates_parent_dir(tmp_path, monkeypatch):
    from panel.trace import log_verdict
    log_path = tmp_path / "nested" / "deeper" / "trace.log"
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(log_path))
    log_verdict("DISSENT", "test")
    assert log_path.exists()


def test_log_verdict_sanitizes_newlines_in_detail(tmp_path, monkeypatch):
    """log entry must remain single-line — newlines in detail get replaced."""
    from panel.trace import log_verdict
    log_path = tmp_path / "trace.log"
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(log_path))
    log_verdict("ERROR", "multi\nline\ndetail")
    lines = log_path.read_text().rstrip("\n").split("\n")
    assert len(lines) == 1
    # Newlines must be replaced with spaces (aggregate.sh used tr '\n' ' ').
    assert "multi line line detail" in lines[0] or "multi line detail" in lines[0]


def test_log_verdict_appends_not_overwrites(tmp_path, monkeypatch):
    from panel.trace import log_verdict
    log_path = tmp_path / "trace.log"
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(log_path))
    log_verdict("HOLD", "first")
    log_verdict("DISSENT", "second")
    content = log_path.read_text()
    assert "first" in content
    assert "second" in content
    assert content.count("outcome=") == 2
```

- [ ] **Step 2: Run tests — should FAIL**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_trace.py -v`
Expected: `ModuleNotFoundError: No module named 'panel.trace'`.

---

### Task 7: Implement `panel/trace.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/trace.py`

- [ ] **Step 1: Create `trace.py`**

```python
"""Append-only verdict trace log.

Parity with aggregate.sh's log_verdict(). Default-on telemetry: a
silently-broken panel is invisible to the operator without it (every
recommendation hits ERROR and the user sees no behavioral change).
Override path via $CLAUDE_PANEL_TRACE_LOG for tests and alternative
log routing.
"""
import os
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_TRACE_LOG = Path.home() / ".claude" / "debug" / "panel-trace.log"


def _resolve_log_path() -> Path:
    env_value = os.environ.get("CLAUDE_PANEL_TRACE_LOG")
    if env_value:
        return Path(env_value).expanduser()
    return DEFAULT_TRACE_LOG


def log_verdict(outcome: str, detail: str) -> None:
    """Append one verdict line to the trace log.

    Failures are silently swallowed — telemetry must never block the
    panel decision path. The user-visible question always survives.
    """
    log_path = _resolve_log_path()
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        return

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    sid = os.environ.get("CLAUDE_SESSION_ID", "unknown")
    # Sanitize detail to a single line, cap length so logs stay greppable.
    safe_detail = detail.replace("\n", " ").replace("\r", " ")[:160]
    line = f'[{ts}] event=verdict session={sid} outcome={outcome} detail="{safe_detail}"\n'
    try:
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(line)
        # Match aggregate.sh's umask 077 (file mode 0600 on creation).
        try:
            os.chmod(log_path, 0o600)
        except OSError:
            pass
    except OSError:
        return
```

- [ ] **Step 2: Run tests — should PASS**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_trace.py -v`
Expected: all 4 tests pass.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/trace.py panel/tests/test_trace.py
git commit -s -S -m "feat(panel): port trace logger to Python"
```

---

### Task 8: Write failing tests for `panel/aggregate.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py`

- [ ] **Step 1: Create `test_aggregate.py`**

```python
"""Tests for panel.aggregate — parity with aggregate_test.sh.

The Python aggregator's stdout format MUST match aggregate.sh exactly
so that SKILL.md's parser (which looks for `^PANEL_VERDICT:` lines)
continues to work unchanged.
"""


def test_both_hold_emits_hold(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate
    out = aggregate(
        str(fixtures_dir / "da_hold.txt"),
        str(fixtures_dir / "pe_hold.txt"),
        "Option A",
    )
    lines = out.split("\n")
    assert lines[0] == "PANEL_VERDICT: HOLD"
    # DA: and PE: rationale lines must be present and non-empty.
    da_line = next((l for l in lines if l.startswith("DA: ")), "")
    pe_line = next((l for l in lines if l.startswith("PE: ")), "")
    assert da_line.strip("DA: ") != ""
    assert pe_line.strip("PE: ") != ""
    # First-sentence abbreviation must preserve paths like ~/.claude/CLAUDE.md
    # in the PE rationale (aggregate_test.sh test 1 verifies this).
    assert "~/.claude/CLAUDE.md" in pe_line
    # Must NOT have truncated at the dot inside the path:
    assert not pe_line.endswith("per ~/.")


def test_da_overturn_emits_dissent_with_alternative(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate
    out = aggregate(
        str(fixtures_dir / "da_overturn_b.txt"),
        str(fixtures_dir / "pe_hold.txt"),
        "Option A",
    )
    assert "PANEL_VERDICT: DISSENT" in out
    panel_line = next((l for l in out.split("\n") if l.startswith("**Panel review:**")), "")
    assert "Option B" in panel_line


def test_pe_overturn_emits_dissent_with_alternative(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate
    out = aggregate(
        str(fixtures_dir / "da_hold.txt"),
        str(fixtures_dir / "pe_overturn_c.txt"),
        "Option A",
    )
    assert "PANEL_VERDICT: DISSENT" in out
    panel_line = next((l for l in out.split("\n") if l.startswith("**Panel review:**")), "")
    assert "Option C" in panel_line


def test_both_overturn_emits_both_alternatives(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate
    out = aggregate(
        str(fixtures_dir / "da_overturn_b.txt"),
        str(fixtures_dir / "pe_overturn_c.txt"),
        "Option A",
    )
    assert "PANEL_VERDICT: DISSENT" in out
    panel_line = next((l for l in out.split("\n") if l.startswith("**Panel review:**")), "")
    assert "Option B" in panel_line
    assert "Option C" in panel_line


def test_malformed_da_emits_error(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate
    out = aggregate(
        str(fixtures_dir / "malformed.txt"),
        str(fixtures_dir / "pe_hold.txt"),
        "Option A",
    )
    assert "PANEL_VERDICT: ERROR" in out


def test_malformed_pe_emits_error(fixtures_dir, monkeypatch, tmp_path):
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    from panel.aggregate import aggregate
    out = aggregate(
        str(fixtures_dir / "da_hold.txt"),
        str(fixtures_dir / "malformed.txt"),
        "Option A",
    )
    assert "PANEL_VERDICT: ERROR" in out


def test_dissent_sanitizes_markdown_injection(monkeypatch, tmp_path, fixtures_dir):
    """Parity with aggregate_test.sh test 7 — sanitize malicious DA rationale."""
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    malicious = tmp_path / "malicious_da.txt"
    malicious.write_text(
        "VERDICT: OVERTURN\n"
        "RATIONALE: This recommendation is wrong [click](http://evil.example.com/x) per "
        "![pixel](http://evil.example.com/p.png) — also `rm -rf /` is what they want.\n"
        "ALTERNATIVE: Option B\n"
    )
    from panel.aggregate import aggregate
    out = aggregate(str(malicious), str(fixtures_dir / "pe_hold.txt"), "Option A")
    assert "evil.example.com" not in out
    assert "`" not in out


def test_trace_log_records_outcome(fixtures_dir, monkeypatch, tmp_path):
    log_path = tmp_path / "trace.log"
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(log_path))
    from panel.aggregate import aggregate
    aggregate(
        str(fixtures_dir / "da_hold.txt"),
        str(fixtures_dir / "pe_hold.txt"),
        "Option A",
    )
    content = log_path.read_text()
    assert "outcome=HOLD" in content
```

- [ ] **Step 2: Run tests — should FAIL**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_aggregate.py -v`
Expected: `ImportError: cannot import name 'aggregate' from 'panel.aggregate'` (the module doesn't have the function yet).

---

### Task 9: Implement `panel/aggregate.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/aggregate.py`

- [ ] **Step 1: Create `aggregate.py`**

```python
"""Aggregate DA + PE verdicts into a panel directive.

Parity with aggregate.sh: stdout format MUST match so SKILL.md's
parser (which looks for `^PANEL_VERDICT:` and `^**Panel review:**`)
continues to work.

Phase 2 only handles the 2-panelist case (DA + PE) at byte-parity.
Phases 3-4 generalize to N panelists with severity tiers.
"""
from __future__ import annotations
import re

from panel.verdict import Verdict, parse_verdict_file
from panel.sanitize import strip_markdown
from panel.trace import log_verdict


# First-sentence abbreviation regex (parity with aggregate.sh line 104-105):
#   sed 's/\([.!?]\)[[:space:]]\{1,\}[[:upper:]].*/\1/'
# Keeps everything up through the FIRST sentence-ending punctuation that
# is followed by whitespace and an uppercase letter. Prevents misfiring
# on dots inside file paths (~/.claude) or abbreviations (e.g., i.e.).
_SENTENCE_END_RE = re.compile(r"([.!?])\s+[A-Z].*")


def _abbreviate_first_sentence(text: str) -> str:
    """Trim `text` after the first sentence boundary (punct + ws + uppercase)."""
    return _SENTENCE_END_RE.sub(r"\1", text)


def aggregate(da_path: str, pe_path: str, recommended_label: str) -> str:
    """Produce the panel directive string for the given verdict files.

    Returns multi-line string suitable for printing to stdout. Mirrors
    aggregate.sh exactly so SKILL.md's parser is unchanged.
    """
    da = parse_verdict_file(da_path)
    pe = parse_verdict_file(pe_path)

    # Validation: each verdict must be HOLD or OVERTURN with non-empty rationale.
    if da.verdict not in ("HOLD", "OVERTURN"):
        log_verdict("ERROR", "DA verdict unparseable")
        return "PANEL_VERDICT: ERROR\nDA verdict unparseable"
    if pe.verdict not in ("HOLD", "OVERTURN"):
        log_verdict("ERROR", "PE verdict unparseable")
        return "PANEL_VERDICT: ERROR\nPE verdict unparseable"
    if not da.rationale or not pe.rationale:
        log_verdict("ERROR", "rationale missing")
        return "PANEL_VERDICT: ERROR\nrationale missing"

    # Both HOLD → HOLD directive.
    if da.verdict == "HOLD" and pe.verdict == "HOLD":
        da_short = _abbreviate_first_sentence(da.rationale)
        pe_short = _abbreviate_first_sentence(pe.rationale)
        log_verdict("HOLD", f"DA: {da_short} | PE: {pe_short}")
        return f"PANEL_VERDICT: HOLD\nDA: {da_short}\nPE: {pe_short}"

    # Otherwise DISSENT. Sanitize before embedding in user-visible text.
    da_rat = strip_markdown(da.rationale)
    pe_rat = strip_markdown(pe.rationale)
    da_alt = strip_markdown(da.alternative)
    pe_alt = strip_markdown(pe.alternative)

    summary = "**Panel review:** "
    if da.verdict == "OVERTURN":
        summary += f"DA flagged {recommended_label} → suggests {da_alt}: {da_rat} "
    else:
        summary += f"DA held {recommended_label}: {da_rat} "
    if pe.verdict == "OVERTURN":
        summary += f"PE flagged {recommended_label} → suggests {pe_alt}: {pe_rat}"
    else:
        summary += f"PE held {recommended_label}: {pe_rat}"

    log_verdict(
        "DISSENT",
        f"DA={da.verdict} PE={pe.verdict} alts={da.alternative or 'n/a'}/{pe.alternative or 'n/a'}",
    )
    return f"PANEL_VERDICT: DISSENT\n{summary}"
```

- [ ] **Step 2: Run tests — should PASS**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/tests/test_aggregate.py -v`
Expected: all 8 tests pass.

- [ ] **Step 3: Run the full pytest suite to confirm parity**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v`
Expected: all tests across `test_verdict.py`, `test_sanitize.py`, `test_trace.py`, `test_aggregate.py` pass.

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/aggregate.py panel/tests/test_aggregate.py
git commit -s -S -m "feat(panel): port aggregate.sh to Python (byte-parity)

Phase 2 of v2 redesign — same stdout format as aggregate.sh so
SKILL.md's parser is unchanged. Logic:
  - both HOLD → PANEL_VERDICT: HOLD + first-sentence abbreviated rationales
  - any OVERTURN → PANEL_VERDICT: DISSENT + Panel review line (sanitized)
  - any malformed verdict/missing rationale → PANEL_VERDICT: ERROR
Trace log records outcome=HOLD|DISSENT|ERROR per call.
The bash aggregate.sh remains in place as a shim (next task)."
```

---

### Task 10: Replace `aggregate.sh` with a shim that forwards to Python

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/aggregate.sh` (full rewrite, ~10 lines).

- [ ] **Step 1: Replace `aggregate.sh` content**

Open `aggregate.sh` and replace the entire file content with:

```bash
#!/bin/bash
# aggregate.sh - SHIM. Forwards to `python3 -m panel aggregate`.
#
# v2 Phase 2 ported aggregator logic to Python (panel/aggregate.py).
# This shim preserves the existing CLI contract so SKILL.md continues to
# invoke aggregate.sh unchanged for one release. It will be removed in
# Phase 3 when SKILL.md is updated to call python3 -m panel directly.
#
# The Python implementation MUST emit the same stdout format
# (PANEL_VERDICT: lines, DA:/PE: lines, **Panel review:** line) so this
# shim is fully transparent.
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -m panel aggregate "$@" 2>&1
```

- [ ] **Step 2: Make sure it's executable**

Run: `chmod +x ~/.claude/skills/validate-recommendation/aggregate.sh`

- [ ] **Step 3: Run the existing bash test suite — must still PASS**

Run: `cd ~/.claude/skills/validate-recommendation && bash aggregate_test.sh`
Expected: final line is `PASS`. All 7 bash tests pass against the Python implementation via the shim.

If any test fails, the Python output is not byte-parity. Re-check `aggregate.py` against `aggregate.sh`'s exact stdout format (line endings, spacing, ordering).

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add aggregate.sh
git commit -s -S -m "refactor(panel): aggregate.sh becomes Python shim

The bash aggregator logic moved to panel/aggregate.py in the previous
commit. aggregate.sh is now a 5-line forwarder so SKILL.md's existing
invocation continues to work unchanged. Existing aggregate_test.sh
passes against the Python implementation via this shim — confirming
byte-parity of stdout.

Phase 3 will update SKILL.md to call python3 -m panel directly and
remove this shim."
```

---

### Task 11: Light update to `SKILL.md` for Phase 2

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/SKILL.md`

- [ ] **Step 1: Add a note to step 7 ("Run aggregate.sh")**

Find the `### 7. Run aggregate.sh` section. Add a short note at the end of the section's prose:

```markdown
Note (v2 Phase 2): `aggregate.sh` is now a thin shim that forwards to
`python3 -m panel aggregate`. The CLI contract and stdout format are
unchanged. Phase 3 will update this step to invoke `python3 -m panel
aggregate` directly.
```

- [ ] **Step 2: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add SKILL.md
git commit -s -S -m "docs(panel): SKILL.md — note aggregator now lives in Python"
```

---

### Task 12: Phase 2 verification

- [ ] **Step 1: Full pytest suite**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v`
Expected: all tests pass (≥20 tests).

- [ ] **Step 2: Full bash test suite (covers the shim)**

Run: `cd ~/.claude/skills/validate-recommendation && bash aggregate_test.sh && bash dispatch-da_test.sh`
Expected: both end with `PASS`.

- [ ] **Step 3: End-to-end live invocation**

Trigger a real `AskUserQuestion` with a `(Recommended)` option. Verify the trace log shows a Phase-2-stamped outcome (HOLD or DISSENT, NOT ERROR). The user-facing behavior should be unchanged from Phase 1 — this phase is a refactor, not a feature.

- [ ] **Step 4: Phase 2 sign-off**

When all three steps above pass, Phase 2 is done. Next: Phase 3 — config + multi-panelist.

---

## Self-review

**Spec coverage**: Phase 2 of the spec maps to Tasks 1-12. Subcommand pattern (Task 1), per-concern module split (Tasks 3, 5, 7, 9), parity with `aggregate.sh` (Tasks 8-10), bash test compatibility via shim (Task 10).

**Placeholder scan**: no TBD/TODO. All code blocks contain real, runnable code. All commit messages are concrete.

**Type consistency**: `Verdict` dataclass is created in Task 3 and consumed in Task 9. `strip_markdown` from Task 5 used by Task 9. `log_verdict` from Task 7 used by Task 9. Test fixture `fixtures_dir` defined in Task 2's `conftest.py` and used by Tasks 2, 4, 6, 8. The `_SENTENCE_END_RE` regex in Task 9 matches `aggregate.sh:104` exactly (`\([.!?]\)[[:space:]]\{1,\}[[:upper:]].*` → Python `([.!?])\s+[A-Z].*`).

**Open dependency**: `pytest` must be on PATH. Pre-flight calls this out. If not installed: `pipx install pytest` is the recommended fix on macOS.
