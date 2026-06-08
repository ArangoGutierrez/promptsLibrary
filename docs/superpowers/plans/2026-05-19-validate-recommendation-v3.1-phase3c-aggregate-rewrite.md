# validate-recommendation v3.1 — Phase 3c: aggregate rewrite + SKILL.md cutover

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut over from the 2-panelist text-directive panel to the N-panelist JSON-directive panel. Ships `panel/severity.py` (pure decision tree), rewrites `panel/aggregate.py` to emit JSON for N panelists, rewires `panel/cli.py` aggregate signature, rewrites `SKILL.md` from scratch for config-driven N-panelist fan-out, and deletes the five v1 shell-tooling files. After Phase 3c lands, no shell wrappers, no hardcoded DA/PE, and no `personas.md` remain.

**Architecture:** One new module (`severity.py`) with one public `decide()` function and ~5 private helpers; one rewritten module (`aggregate.py`) that reads config + verdict files and calls `severity.decide()`; one rewritten CLI subcommand; one rewritten SKILL.md that uses `jq` to parse the aggregator's JSON output. Five v1 shell files deleted in a final cleanup commit. Lands on feature branch `feat/phase3c-aggregate-json` in `~/.claude/`, merged atomically to `main` after Task 6 smoke test.

**Tech Stack:** Python 3.12 (`/opt/homebrew/bin/python3.12`); existing `panel/{config,personas,verdict,sanitize,trace,dispatch}.py` modules from Phases 2/3a/3b; standard library `dataclasses` + `re` + `math` + `json`; `jq` (already on the system) for SKILL.md JSON parsing; tests via `~/.local/pipx/venvs/pytest/bin/pytest` direct path.

**Spec:** `docs/superpowers/specs/2026-05-19-validate-recommendation-v3.1-phase3c-design.md` (commit `ac0315e`). Underlying: `2026-05-15-validate-recommendation-v3-nat-native-design.md` (`c80b2f6`) + `2026-05-18-validate-recommendation-v3.1-nat-heavy-amendment.md` (`b3b8afb`).

**Pre-flight context:**

- Phase 3b shipped on `~/.claude/` main (commits `2f7e852..f9178d7`). 77 panel tests pass via `~/.local/pipx/venvs/pytest/bin/pytest panel/tests/`.
- `panel/{config,personas,verdict,sanitize,trace,dispatch}.py` are stable. `panel/aggregate.py` is the Phase 2 2-panelist text version (to be rewritten).
- `panel/cli.py` has three subcommands: `aggregate` (Phase 2 signature), `lint-config` (Phase 3a), `dispatch` (Phase 3b).
- `personas/{da,pe,qa}.md` exist (Phase 3a). `personas.md` is the v1 monolith (to be deleted).
- `~/.claude/panel/config.yml` ships with one enabled panelist (`da-nemotron`, backend `nat-nim`).
- Two deferred handoff issues are NOT addressed in this plan (rotate `$PANEL_DA_API_KEY`, fix doubled-prefix `CLAUDE_PANEL_DA_MODEL`). Both must be resolved by the operator before Task 6 smoke test if a live NIM call is desired; Task 6 documents the workaround if they aren't.
- `~/.claude/` enforces signed commits (`-s` DCO sign-off + `-S` GPG signature) via hook. Every commit in this plan uses `git commit -s -S`.

---

## File Structure

Tasks land into `/Users/eduardoa/.claude/`:

| File | Disposition | Responsibility |
|---|---|---|
| `skills/validate-recommendation/panel/severity.py` | **Create** | Pure decision tree. `decide(config, panelists, cycle=None) -> Directive`. ~200 LOC. No I/O. |
| `skills/validate-recommendation/panel/tests/test_severity.py` | **Create** | 25 test cases covering vote tally, threshold, gate, cycle, ERROR cascade, mutation resistance. |
| `skills/validate-recommendation/panel/aggregate.py` | **Rewrite** | Reads config, iterates enabled panelists, reads `<verdicts-dir>/<id>.verdict` for each, calls `severity.decide()`, prints single-line JSON. |
| `skills/validate-recommendation/panel/tests/test_aggregate.py` | **Rewrite** | 12 tests asserting JSON shape + sentinel string + sanitize integration. Replaces the 8-test Phase 2 file. |
| `skills/validate-recommendation/panel/cli.py` | **Modify** | New `aggregate` argparse signature: `--config --verdicts-dir --recommended-label`. |
| `skills/validate-recommendation/panel/tests/test_cli_aggregate.py` | **Create** | 3 tests: argparse → aggregate() wiring, exit codes, missing-config behavior. |
| `skills/validate-recommendation/SKILL.md` | **Rewrite from scratch** | Config-driven N-panelist fan-out + jq JSON parsing. |
| `skills/validate-recommendation/dispatch-da.sh` | **Delete** | Superseded by `panel/dispatch.py` (Phase 3b). |
| `skills/validate-recommendation/dispatch-da_test.sh` | **Delete** | Superseded by `panel/tests/test_dispatch.py`. |
| `skills/validate-recommendation/aggregate.sh` | **Delete** | Shim no longer needed (SKILL.md calls `panel aggregate` directly). |
| `skills/validate-recommendation/aggregate_test.sh` | **Delete** | Shell wrapper test; Python `test_aggregate.py` is the coverage. |
| `skills/validate-recommendation/personas.md` | **Delete** | Replaced by per-role files in `personas/` (Phase 3a). |
| `skills/validate-recommendation/README.md` | **Modify** | Remove v1 sections; add Phase 3c JSON-directive section. |

Untouched: `panel/{verdict,sanitize,trace,personas,config,dispatch}.py`, `panel/tests/test_{verdict,sanitize,trace,personas,config,dispatch,cli_dispatch,cli_exit_codes,cli_lint_config}.py`, `personas/{da,pe,qa}.md`, `~/.claude/panel/config.yml`, hook scripts in `~/.claude/hooks/`.

---

## Tasks

### Task 0: Feature branch + pre-flight verification

**Files:** none modified. Branch creation + sanity checks.

- [ ] **Step 1: Create the feature branch in `~/.claude/`**

```bash
cd ~/.claude && git checkout main && git pull --ff-only 2>&1 | tail -3
cd ~/.claude && git checkout -b feat/phase3c-aggregate-json
cd ~/.claude && git branch --show-current
```

Expected: prints `feat/phase3c-aggregate-json`. Working tree clean.

- [ ] **Step 2: Confirm baseline test count (77)**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `77 passed in <Ns>`. If different, stop and investigate — Phase 3c starts from this baseline.

- [ ] **Step 3: Confirm legacy v1 paths still work**

```bash
cd ~/.claude/skills/validate-recommendation && \
    bash aggregate_test.sh 2>&1 | tail -3
```

Expected: `PASS`. (We'll delete this script in Task 5; for now it's the regression check for `aggregate.sh` + `panel/aggregate.py` Phase 2 contract.)

- [ ] **Step 4: Verify jq is on PATH**

```bash
which jq && jq --version 2>&1
```

Expected: a path (e.g., `/opt/homebrew/bin/jq`) and a version string. SKILL.md will use `jq` to parse the aggregator's JSON output. If missing, install before continuing.

No commit for Task 0 (branch creation only).

---

### Task 1: `panel/severity.py` — pure decision tree

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/severity.py`
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_severity.py`

The decision tree is the heart of the panel. It must be pure (no I/O), well-tested (mutation-resistant), and Phase-5-ready (the `cycle` parameter accepts `None` for Phase 3c, `int` later).

- [ ] **Step 1: Write the failing tests** (`panel/tests/test_severity.py`)

```python
"""Tests for panel.severity — pure N-panelist decision tree.

Constitution compliance: each test must fail when the implementation
mutates. Tests cover the decision tree exhaustively (no theater).

Mock discipline: severity.py is pure — no mocks used. Tests construct
Config and ParsedVerdict objects directly.
"""
from __future__ import annotations

import pytest

from panel.severity import (
    decide,
    Directive,
    ParsedVerdict,
    ReBrainstormPayload,
)
from panel.config import (
    Config,
    Severity,
    RationaleGate,
    FailureMode,
    ReBrainstorm,
    Telemetry,
    Panelist,
)


def _config(
    panelist_count=1,
    *,
    hard_threshold="majority",
    on_panelist_error="auto",
    max_cycles=2,
):
    panelists = [
        Panelist(
            id=f"p{i}",
            role=("DA" if i == 0 else "PE" if i == 1 else "QA" if i == 2 else f"R{i}"),
            enabled=True,
            backend="nat-nim",
            model="test-model",
            max_tokens=1024,
            temperature=0.0,
            timeout_seconds=10,
        )
        for i in range(panelist_count)
    ]
    return Config(
        version="1",
        panelists=panelists,
        severity=Severity(
            hard_threshold=hard_threshold,
            rationale_gate=RationaleGate(),
        ),
        failure_mode=FailureMode(on_panelist_error=on_panelist_error),
        re_brainstorm=ReBrainstorm(enabled=True, max_cycles=max_cycles),
        telemetry=Telemetry(),
    )


def _v(verdict, *, alt="n/a", rationale="some rationale text here.",
       id="p0", role="DA"):
    return ParsedVerdict(
        id=id, role=role, verdict=verdict,
        rationale=rationale, alternative=alt,
    )


# ---- N=1 (default config) ----

def test_n1_hold_emits_hold():
    cfg = _config(1)
    d = decide(cfg, [_v("HOLD")])
    assert d.verdict == "HOLD"
    assert d.rationale_gate_passed is True
    assert len(d.panelists) == 1


def test_n1_overturn_with_concrete_alternative_is_hard_dissent():
    cfg = _config(1)
    d = decide(cfg, [_v("OVERTURN", alt="Option B")])
    assert d.verdict == "HARD-DISSENT"
    assert d.escalate_to_user is True
    assert d.re_brainstorm is None
    assert d.rationale_gate_passed is True


def test_n1_overturn_with_na_alternative_is_coerced_to_error():
    """Phase 1 bug #3 preservation: OVERTURN + n/a → ERROR (not SOFT)."""
    cfg = _config(1)
    d = decide(cfg, [_v("OVERTURN", alt="n/a")])
    assert d.verdict == "ERROR"


def test_n1_error_panelist_with_strict_mode_emits_error():
    cfg = _config(1, on_panelist_error="strict")
    d = decide(cfg, [_v("ERROR", rationale="backend timeout")])
    assert d.verdict == "ERROR"
    assert "tolerance" in d.summary.lower()


def test_n1_with_auto_failure_mode_is_strict_at_n_equals_1():
    """auto mode resolves to strict for N=1 (no room to degrade)."""
    cfg = _config(1, on_panelist_error="auto")
    d = decide(cfg, [_v("ERROR")])
    assert d.verdict == "ERROR"


# ---- N=3 majority ----

def test_n3_all_hold_emits_hold():
    cfg = _config(3)
    d = decide(cfg, [_v("HOLD", id="p0"), _v("HOLD", id="p1", role="PE"),
                     _v("HOLD", id="p2", role="QA")])
    assert d.verdict == "HOLD"


def test_n3_one_overturn_below_threshold_is_soft_dissent():
    """1 OVERTURN of 3 < ceil(3/2)=2 → SOFT."""
    cfg = _config(3)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("HOLD", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "SOFT-DISSENT"
    assert d.rationale_gate_passed is False


def test_n3_two_overturns_meets_majority_threshold_is_hard_dissent():
    """2 OVERTURN of 3 ≥ ceil(3/2)=2 + alt naming → gate passes → HARD."""
    cfg = _config(3)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "HARD-DISSENT"
    assert d.escalate_to_user is True
    assert d.rationale_gate_passed is True


def test_n3_three_overturns_is_hard_dissent():
    cfg = _config(3)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("OVERTURN", alt="Option B", id="p2", role="QA"),
    ])
    assert d.verdict == "HARD-DISSENT"


# ---- N=3 supermajority ----

def test_n3_supermajority_two_overturns_meets_threshold():
    """ceil(2*3/3)=2; 2 OVERTURN crosses supermajority."""
    cfg = _config(3, hard_threshold="supermajority")
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "HARD-DISSENT"


def test_n3_supermajority_one_overturn_below_threshold_is_soft():
    cfg = _config(3, hard_threshold="supermajority")
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("HOLD", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "SOFT-DISSENT"


# ---- N=5 ----

def test_n5_majority_three_overturns_meets_threshold():
    """ceil(5/2)=3; 3 OVERTURN crosses majority at N=5."""
    cfg = _config(5)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id=f"p{i}", role=f"R{i}")
        for i in range(3)
    ] + [_v("HOLD", id="p3", role="R3"), _v("HOLD", id="p4", role="R4")])
    assert d.verdict == "HARD-DISSENT"


def test_n5_supermajority_three_overturns_below_threshold():
    """ceil(2*5/3)=4; 3 OVERTURN does NOT cross supermajority at N=5."""
    cfg = _config(5, hard_threshold="supermajority")
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id=f"p{i}", role=f"R{i}")
        for i in range(3)
    ] + [_v("HOLD", id="p3", role="R3"), _v("HOLD", id="p4", role="R4")])
    assert d.verdict == "SOFT-DISSENT"


# ---- ERROR cascade + degradation ----

def test_n3_strict_one_error_emits_error_directive():
    cfg = _config(3, on_panelist_error="strict")
    d = decide(cfg, [
        _v("ERROR", rationale="backend down", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "ERROR"


def test_n3_auto_one_error_resolves_to_strict_emits_error():
    """auto mode at N=3 → strict → ERROR."""
    cfg = _config(3, on_panelist_error="auto")
    d = decide(cfg, [
        _v("ERROR", id="p0"),
        _v("HOLD", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "ERROR"


def test_n5_graceful_one_error_degrades_to_three():
    """graceful drops the ERROR panelist; surviving N=4 is even, drop 1 more to 3."""
    cfg = _config(5, on_panelist_error="graceful")
    d = decide(cfg, [
        _v("ERROR", id="p0"),
        _v("HOLD", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
        _v("HOLD", id="p3", role="R3"),
        _v("HOLD", id="p4", role="R4"),
    ])
    assert d.verdict == "HOLD"
    assert len(d.panelists) == 3


def test_n5_auto_one_error_resolves_to_graceful_degrades_to_three():
    """auto mode at N=5 → graceful → degrade ERROR + keep odd."""
    cfg = _config(5, on_panelist_error="auto")
    d = decide(cfg, [
        _v("ERROR", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("OVERTURN", alt="Option B", id="p2", role="QA"),
        _v("HOLD", id="p3", role="R3"),
        _v("HOLD", id="p4", role="R4"),
    ])
    # After dropping ERROR and 1 more, 3 remain. 2 OVERTURN of 3 → HARD.
    assert d.verdict == "HARD-DISSENT"


def test_n3_two_errors_cannot_degrade_emits_error():
    """N=3, 2 ERROR → surviving < 1, mandatory ERROR even in graceful."""
    cfg = _config(3, on_panelist_error="graceful")
    d = decide(cfg, [
        _v("ERROR", id="p0"),
        _v("ERROR", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "ERROR"


# ---- Rationale gate ----

def test_gate_passes_on_concrete_alternative():
    """Any OVERTURN with a concrete alt makes gate pass."""
    cfg = _config(3)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", rationale="cost concern", id="p0"),
        _v("OVERTURN", alt="Option B", rationale="cost concern", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "HARD-DISSENT"
    assert d.rationale_gate_passed is True


def test_gate_passes_on_principle_naming_in_rationale():
    """Principle keyword in rationale (e.g., YAGNI) makes gate pass."""
    cfg = _config(3)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B",
           rationale="This violates the YAGNI principle directly.", id="p0"),
        _v("OVERTURN", alt="Option B",
           rationale="violates atomicity by bundling two concerns.",
           id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "HARD-DISSENT"
    assert d.rationale_gate_passed is True


# ---- Cycle handling (Phase 3c default + Phase 5+ ready) ----

def test_cycle_none_phase3c_default_escalates_immediately():
    cfg = _config(3)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ], cycle=None)
    assert d.verdict == "HARD-DISSENT"
    assert d.escalate_to_user is True
    assert d.re_brainstorm is None


def test_cycle_zero_emits_re_brainstorm_payload():
    """Phase 5+: cycle=0, max=2 → emit re_brainstorm payload, no escalation."""
    cfg = _config(3, max_cycles=2)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ], cycle=0)
    assert d.verdict == "HARD-DISSENT"
    assert d.escalate_to_user is None
    assert d.re_brainstorm is not None
    assert d.re_brainstorm.cycle == 0
    assert d.re_brainstorm.max_cycles == 2


def test_cycle_at_cap_escalates():
    """Phase 5+: cycle=max → escalate, no re-brainstorm payload."""
    cfg = _config(3, max_cycles=2)
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("OVERTURN", alt="Option B", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ], cycle=2)
    assert d.verdict == "HARD-DISSENT"
    assert d.escalate_to_user is True
    assert d.re_brainstorm is None


# ---- Summary text + sanitization ----

def test_hold_summary_lists_each_panelist_with_abbreviation():
    cfg = _config(3)
    d = decide(cfg, [
        _v("HOLD", rationale="Option A is fine. Other notes follow.", id="p0"),
        _v("HOLD", rationale="Aligns with stated principles.", id="p1", role="PE"),
        _v("HOLD", rationale="Testable as written.", id="p2", role="QA"),
    ])
    assert "DA:" in d.summary
    assert "PE:" in d.summary
    assert "QA:" in d.summary


def test_dissent_summary_uses_panel_review_sentinel():
    """SKILL.md parses this exact sentinel."""
    cfg = _config(1)
    d = decide(cfg, [_v("OVERTURN", alt="Option B",
                       rationale="cost considerations matter here")])
    assert d.summary.startswith("**Panel review:** ")


def test_summary_strips_markdown_injection():
    """sanitize.strip_markdown integration check."""
    cfg = _config(1)
    d = decide(cfg, [_v(
        "OVERTURN", alt="Option B",
        rationale="See [link](http://evil.example.com) and `rm -rf /`.",
    )])
    assert "evil.example.com" not in d.summary
    assert "`" not in d.summary


# ---- Mutation-resistance probes ----

def test_threshold_uses_ceiling_not_floor():
    """ceil(3/2)=2, not floor(3/2)=1. Off-by-one mutation must fail."""
    cfg = _config(3)
    # 1 OVERTURN: should be SOFT (1 < 2), not HARD (1 < floor(3/2)=1 false).
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", id="p0"),
        _v("HOLD", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "SOFT-DISSENT"  # If implementation used floor → HARD.


def test_gate_uses_any_not_all():
    """gate passes if ANY overturn names principle or alt."""
    cfg = _config(3)
    # Both overturns have alt → gate passes (any). HARD.
    d = decide(cfg, [
        _v("OVERTURN", alt="Option B", rationale="vague", id="p0"),
        _v("OVERTURN", alt="Option B", rationale="vague", id="p1", role="PE"),
        _v("HOLD", id="p2", role="QA"),
    ])
    assert d.verdict == "HARD-DISSENT"
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_severity.py -v 2>&1 | tail -10
```

Expected: 25 tests collected; all FAIL with `ModuleNotFoundError: No module named 'panel.severity'`.

- [ ] **Step 3: Implement `panel/severity.py`**

```python
"""Pure severity decision tree for the N-panelist validate-recommendation panel.

No I/O, no logging from this module (logging is the aggregator's job). Inputs:
config + parsed verdicts. Output: a Directive dataclass instance.

Phase 3c contract:
- HARD-DISSENT escalates to user immediately when cycle is None (no state
  machine). The re_brainstorm payload is reserved for Phase 5+.
- Phase 1 bug #3 preservation: OVERTURN + alternative='n/a' → coerced to ERROR.
- ERROR cascade via failure_mode (strict/graceful/auto).
"""
from __future__ import annotations

import math
import re
from dataclasses import dataclass, field

from panel.config import Config
from panel.sanitize import strip_markdown


@dataclass
class ParsedVerdict:
    id: str
    role: str
    verdict: str        # "HOLD" | "OVERTURN" | "ERROR"
    rationale: str
    alternative: str    # option label or "n/a"


@dataclass
class PanelistRow:
    id: str
    role: str
    verdict: str
    rationale: str
    alternative: str


@dataclass
class ReBrainstormPayload:
    cycle: int
    max_cycles: int
    suggested_alternatives: list[str]
    feedback_for_claude: str


@dataclass
class Directive:
    verdict: str                                       # HOLD | SOFT-DISSENT | HARD-DISSENT | ERROR
    summary: str
    rationale_gate_passed: bool | None
    panelists: list[PanelistRow]
    re_brainstorm: ReBrainstormPayload | None = None
    escalate_to_user: bool | None = None


def decide(
    config: Config,
    panelists: list[ParsedVerdict],
    cycle: int | None = None,
) -> Directive:
    """Decide the panel directive from N parsed verdicts.

    cycle=None  → Phase 3c semantics; HARD-DISSENT always escalates.
    cycle=int   → Phase 5+ semantics; HARD-DISSENT emits re-think payload
                  while cycle < max_cycles; escalates at cap.
    """
    normalized = [_validate(p) for p in panelists]

    n_error = sum(1 for p in normalized if p.verdict == "ERROR")
    n_total = len(normalized)

    if n_error > 0:
        mode = _resolve_failure_mode(config, n_total)
        if mode == "strict" or (n_total - 2 * n_error) < 1:
            return _error_directive(
                normalized,
                _failure_summary(n_total, n_error, mode),
            )
        normalized = _degrade_keeping_odd(normalized)

    overturns = [p for p in normalized if p.verdict == "OVERTURN"]
    n = len(normalized)
    threshold = (
        math.ceil(n / 2)
        if config.severity.hard_threshold == "majority"
        else math.ceil(2 * n / 3)
    )

    if not overturns:
        return _hold_directive(normalized)

    if len(overturns) < threshold:
        return _soft_dissent_directive(normalized, gate_passed=False)

    gate_passed = _gate_passed(
        overturns,
        config.severity.rationale_gate.principle_patterns,
    )
    if not gate_passed:
        return _soft_dissent_directive(normalized, gate_passed=False)

    if cycle is None or cycle >= config.re_brainstorm.max_cycles:
        return _hard_dissent_directive(
            normalized, gate_passed=True, escalate_to_user=True,
        )
    return _hard_dissent_directive(
        normalized, gate_passed=True,
        re_brainstorm=_build_payload(overturns, cycle, config),
    )


# ---- private helpers ----

def _validate(p: ParsedVerdict) -> ParsedVerdict:
    """Normalize a panelist verdict; coerce malformed → ERROR."""
    if p.verdict not in ("HOLD", "OVERTURN", "ERROR"):
        return ParsedVerdict(
            id=p.id, role=p.role, verdict="ERROR",
            rationale=(p.rationale or "verdict field unparseable"),
            alternative="n/a",
        )
    if p.verdict == "OVERTURN":
        alt = (p.alternative or "").strip().lower()
        if alt in ("n/a", ""):
            return ParsedVerdict(
                id=p.id, role=p.role, verdict="ERROR",
                rationale="OVERTURN without concrete ALTERNATIVE (Phase 1 bug #3)",
                alternative="n/a",
            )
    if not (p.rationale or "").strip():
        return ParsedVerdict(
            id=p.id, role=p.role, verdict="ERROR",
            rationale="rationale field empty",
            alternative="n/a",
        )
    return p


def _resolve_failure_mode(config: Config, n_total: int) -> str:
    mode = config.failure_mode.on_panelist_error
    if mode in ("strict", "graceful"):
        return mode
    return "strict" if n_total in (1, 3) else "graceful"


def _degrade_keeping_odd(panelists: list[ParsedVerdict]) -> list[ParsedVerdict]:
    """Drop ERROR panelists; if surviving count is even, drop one more."""
    surviving = [p for p in panelists if p.verdict != "ERROR"]
    if surviving and (len(surviving) % 2 == 0):
        surviving = surviving[:-1]
    return surviving


def _gate_passed(overturns: list[ParsedVerdict], patterns: list[str]) -> bool:
    compiled = [re.compile(pat, re.IGNORECASE) for pat in patterns]
    for p in overturns:
        if (p.alternative or "").strip().lower() not in ("n/a", ""):
            return True
        for rx in compiled:
            if rx.search(p.rationale or ""):
                return True
    return False


# ---- directive builders ----

def _hold_directive(panelists: list[ParsedVerdict]) -> Directive:
    parts = []
    for p in panelists:
        first = _abbreviate_first_sentence(p.rationale)
        parts.append(f"{p.role}: {strip_markdown(first)}.")
    return Directive(
        verdict="HOLD",
        summary=" ".join(parts),
        rationale_gate_passed=True,
        panelists=[_row(p) for p in panelists],
    )


def _soft_dissent_directive(
    panelists: list[ParsedVerdict], *, gate_passed: bool,
) -> Directive:
    return Directive(
        verdict="SOFT-DISSENT",
        summary=_panel_review_summary(panelists),
        rationale_gate_passed=gate_passed,
        panelists=[_row(p) for p in panelists],
    )


def _hard_dissent_directive(
    panelists: list[ParsedVerdict],
    *,
    gate_passed: bool,
    escalate_to_user: bool = False,
    re_brainstorm: ReBrainstormPayload | None = None,
) -> Directive:
    return Directive(
        verdict="HARD-DISSENT",
        summary=_panel_review_summary(panelists),
        rationale_gate_passed=gate_passed,
        panelists=[_row(p) for p in panelists],
        escalate_to_user=(True if escalate_to_user else None),
        re_brainstorm=re_brainstorm,
    )


def _error_directive(
    panelists: list[ParsedVerdict], reason: str,
) -> Directive:
    return Directive(
        verdict="ERROR",
        summary=reason,
        rationale_gate_passed=None,
        panelists=[_row(p) for p in panelists],
    )


def _row(p: ParsedVerdict) -> PanelistRow:
    return PanelistRow(
        id=p.id, role=p.role, verdict=p.verdict,
        rationale=strip_markdown(p.rationale or ""),
        alternative=strip_markdown(p.alternative or "n/a"),
    )


def _panel_review_summary(panelists: list[ParsedVerdict]) -> str:
    parts = []
    for p in panelists:
        rat = strip_markdown(p.rationale or "")
        if p.verdict == "OVERTURN":
            alt = strip_markdown(p.alternative or "n/a")
            parts.append(f"{p.role} flagged → suggests {alt}: {rat}")
        elif p.verdict == "HOLD":
            parts.append(f"{p.role} held: {rat}")
        else:  # ERROR
            parts.append(f"{p.role} errored: {rat}")
    return "**Panel review:** " + " ".join(parts)


def _failure_summary(n_total: int, n_error: int, mode: str) -> str:
    return (
        f"panelist errors exceed failure-mode tolerance "
        f"({mode}@N={n_total}: {n_error} of {n_total} panelists returned ERROR)"
    )


def _build_payload(
    overturns: list[ParsedVerdict], cycle: int, config: Config,
) -> ReBrainstormPayload:
    """Phase 5+ only; never called when cycle is None."""
    alts = sorted({
        strip_markdown(p.alternative)
        for p in overturns
        if (p.alternative or "").strip().lower() not in ("n/a", "")
    })
    feedback = " ".join(
        f"{p.role}: {strip_markdown(p.rationale or '')}"
        for p in overturns
    )
    return ReBrainstormPayload(
        cycle=cycle,
        max_cycles=config.re_brainstorm.max_cycles,
        suggested_alternatives=alts,
        feedback_for_claude=feedback,
    )


def _abbreviate_first_sentence(text: str) -> str:
    """Trim text after first sentence boundary (punct + ws + uppercase)."""
    match = re.search(r"^(.*?[.!?])\s+[A-Z]", text or "")
    if match:
        return match.group(1)
    return (text or "").strip()
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_severity.py -v 2>&1 | tail -10
```

Expected: `25 passed`. If any fail, fix the implementation (not the tests — per TDD discipline).

- [ ] **Step 5: Run the full panel test suite to confirm no regression**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `102 passed` (77 baseline + 25 new). No failures elsewhere.

- [ ] **Step 6: Commit (signed)**

```bash
cd ~/.claude && git add \
    skills/validate-recommendation/panel/severity.py \
    skills/validate-recommendation/panel/tests/test_severity.py
cd ~/.claude && git commit -s -S -m "feat(panel): severity.py — pure N-panelist decision tree

New module panel/severity.py extracts the severity decision logic from
panel/aggregate.py and generalizes from 2 panelists to N. Pure module:
no I/O, no logging. Single public function:

    decide(config, panelists: list[ParsedVerdict], cycle=None) -> Directive

cycle=None is Phase 3c semantics — HARD-DISSENT always escalates to user
immediately (no state machine in this phase). cycle=int is Phase 5+
semantics — re_brainstorm payload emitted while cycle < max_cycles.

Decision flow per v3 spec:
  1. Normalize each panelist (coerce malformed → ERROR; Phase 1 bug #3
     preserved: OVERTURN + alt='n/a' → ERROR).
  2. ERROR cascade via failure_mode (strict/graceful/auto).
  3. Vote tally vs threshold (majority = ceil(N/2); supermajority = ceil(2N/3)).
  4. Rationale gate (any OVERTURN names principle or has concrete alt).
  5. HARD-DISSENT branch — escalate (Phase 3c) or re-think payload (Phase 5+).

25 pytest cases covering N∈{1,3,5}, majority vs supermajority, ERROR
cascade strict/graceful/auto, rationale gate, cycle handling, summary
text + sanitize integration, mutation-resistance (threshold ceiling,
gate any-vs-all). Constitution-compliant: each test fails when the
implementation mutates."
```

---

### Task 2: `panel/aggregate.py` rewrite + `panel/cli.py` aggregate signature

**Files:**
- Rewrite: `~/.claude/skills/validate-recommendation/panel/aggregate.py`
- Rewrite: `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

The current `panel/aggregate.py` is the 2-panelist text-output Phase 2 implementation. This task rewrites it for N panelists with JSON output via `severity.decide()`. The CLI subcommand signature changes from `--da --pe --recommended-label` to `--config --verdicts-dir --recommended-label`.

- [ ] **Step 1: Delete the existing test file and write the new failing tests**

```bash
rm ~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py
```

Create `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py`:

```python
"""Tests for panel.aggregate — N-panelist JSON-emitting aggregator.

The aggregator's responsibility is wiring: read config, read verdict files,
hand off to severity.decide(), serialize directive to JSON. The decision
logic itself is tested in test_severity.py.

Mock discipline: no mocks. We construct config.yml and verdict files in
tmp_path and run the real aggregator against them.
"""
from __future__ import annotations
import json
import os
import stat
import textwrap

import pytest


@pytest.fixture
def cfg_path_n1(tmp_path):
    cfg = tmp_path / "config.yml"
    cfg.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da-test
            role: DA
            enabled: true
            backend: nat-nim
            model: test-model
    """).strip() + "\n")
    return cfg


@pytest.fixture
def cfg_path_n3(tmp_path):
    cfg = tmp_path / "config.yml"
    cfg.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da-test
            role: DA
            enabled: true
            backend: nat-nim
            model: test-model
          - id: pe-test
            role: PE
            enabled: true
            backend: claude-subagent
            subagent_type: principal-engineer
          - id: qa-test
            role: QA
            enabled: true
            backend: claude-subagent
            subagent_type: qa-engineer
    """).strip() + "\n")
    return cfg


def _write_verdict(verdicts_dir, panelist_id, verdict, rationale, alternative):
    verdicts_dir.mkdir(parents=True, exist_ok=True)
    p = verdicts_dir / f"{panelist_id}.verdict"
    p.write_text(
        f"VERDICT: {verdict}\n"
        f"RATIONALE: {rationale}\n"
        f"ALTERNATIVE: {alternative}\n"
    )


def test_n1_hold_emits_hold_json(tmp_path, cfg_path_n1):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD",
                   "Looks acceptable as recommended.", "n/a")

    out = aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert data["verdict"] == "HOLD"
    assert data["rationale_gate_passed"] is True
    assert len(data["panelists"]) == 1
    assert data["panelists"][0]["id"] == "da-test"
    assert data["panelists"][0]["role"] == "DA"
    assert data["panelists"][0]["verdict"] == "HOLD"


def test_n3_majority_two_overturns_emits_hard_dissent_json(tmp_path, cfg_path_n3):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "OVERTURN",
                   "Option B better matches goals.", "Option B")
    _write_verdict(verdicts, "pe-test", "OVERTURN",
                   "violates YAGNI principle.", "Option B")
    _write_verdict(verdicts, "qa-test", "HOLD",
                   "Testable as written.", "n/a")

    out = aggregate(str(cfg_path_n3), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert data["verdict"] == "HARD-DISSENT"
    assert data["escalate_to_user"] is True
    assert "re_brainstorm" not in data or data.get("re_brainstorm") is None


def test_one_overturn_below_threshold_emits_soft_dissent(tmp_path, cfg_path_n3):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "OVERTURN",
                   "concern about cost", "Option B")
    _write_verdict(verdicts, "pe-test", "HOLD", "ok", "n/a")
    _write_verdict(verdicts, "qa-test", "HOLD", "ok", "n/a")

    out = aggregate(str(cfg_path_n3), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert data["verdict"] == "SOFT-DISSENT"


def test_missing_verdict_file_coerces_panelist_to_error(tmp_path, cfg_path_n3):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    verdicts.mkdir()
    # Only write 2 of 3 verdict files
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")
    _write_verdict(verdicts, "qa-test", "HOLD", "ok", "n/a")
    # pe-test verdict file missing

    out = aggregate(str(cfg_path_n3), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    pe = next(p for p in data["panelists"] if p["id"] == "pe-test")
    assert pe["verdict"] == "ERROR"
    assert "missing" in pe["rationale"].lower()


def test_all_error_emits_error_directive(tmp_path, cfg_path_n1):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "ERROR",
                   "backend timeout", "n/a")

    out = aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert data["verdict"] == "ERROR"
    assert data["rationale_gate_passed"] is None


def test_disabled_panelists_excluded_from_panelists_list(tmp_path):
    from panel.aggregate import aggregate
    cfg = tmp_path / "config.yml"
    cfg.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da-test
            role: DA
            enabled: true
            backend: nat-nim
            model: test-model
          - id: pe-test
            role: PE
            enabled: false
            backend: claude-subagent
            subagent_type: principal-engineer
    """).strip() + "\n")
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")
    # No pe-test verdict — but pe-test is disabled.

    out = aggregate(str(cfg), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert len(data["panelists"]) == 1
    assert data["panelists"][0]["id"] == "da-test"


def test_dissent_summary_starts_with_panel_review_sentinel(tmp_path, cfg_path_n1):
    """SKILL.md parses this exact sentinel."""
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "OVERTURN",
                   "cost concerns matter", "Option B")

    out = aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert data["summary"].startswith("**Panel review:** ")


def test_output_is_single_line_json(tmp_path, cfg_path_n1):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")

    out = aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    assert "\n" not in out.rstrip("\n")  # at most one trailing newline


def test_markdown_injection_stripped_from_summary(tmp_path, cfg_path_n1):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "OVERTURN",
                   "See [link](http://evil.example.com) and `rm -rf /`.",
                   "Option B")

    out = aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    assert "evil.example.com" not in data["summary"]
    assert "`" not in data["summary"]


def test_trace_log_records_outcome(tmp_path, monkeypatch, cfg_path_n1):
    log_path = tmp_path / "trace.log"
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(log_path))
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")

    aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    content = log_path.read_text()
    assert "outcome=HOLD" in content


def test_overturn_with_na_alternative_emits_error_for_panelist(tmp_path, cfg_path_n1):
    """Phase 1 bug #3 preservation via severity._validate()."""
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "OVERTURN",
                   "I disagree but have no concrete alt.", "n/a")

    out = aggregate(str(cfg_path_n1), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    # The panelist gets coerced to ERROR; the panel emits ERROR at N=1 strict.
    assert data["verdict"] == "ERROR"


def test_panelists_listed_in_config_order(tmp_path, cfg_path_n3):
    from panel.aggregate import aggregate
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")
    _write_verdict(verdicts, "pe-test", "HOLD", "ok", "n/a")
    _write_verdict(verdicts, "qa-test", "HOLD", "ok", "n/a")

    out = aggregate(str(cfg_path_n3), str(verdicts), "Option A (Recommended)")
    data = json.loads(out)
    ids = [p["id"] for p in data["panelists"]]
    assert ids == ["da-test", "pe-test", "qa-test"]
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_aggregate.py -v 2>&1 | tail -10
```

Expected: 12 tests collected; all FAIL (current `aggregate()` signature is `(da_path, pe_path, recommended_label)`, not `(config_path, verdicts_dir, recommended_label)` — every test errors on import or argument count).

- [ ] **Step 3: Rewrite `panel/aggregate.py`**

Replace the entire current file contents with:

```python
"""N-panelist aggregator emitting JSON directives.

Reads ~/.claude/panel/config.yml, finds enabled panelists, reads
<verdicts-dir>/<id>.verdict for each, calls severity.decide(), serializes
the Directive to single-line JSON, prints to stdout.

The text-output 2-panelist Phase 2 version is gone — SKILL.md is being
rewritten in Phase 3c Task 4 to parse JSON via jq.
"""
from __future__ import annotations
import json
from dataclasses import asdict
from pathlib import Path

from panel.config import load_config
from panel.severity import decide, ParsedVerdict
from panel.verdict import parse_verdict_file
from panel.trace import log_verdict


def aggregate(
    config_path: str,
    verdicts_dir: str,
    recommended_label: str,
) -> str:
    """Build the JSON directive from per-panelist verdict files.

    Returns a single-line JSON string (no trailing newline). Caller is
    responsible for printing it.

    Missing verdict files for enabled panelists are not fatal — the
    aggregator synthesizes an ERROR panelist row and lets severity.decide()
    handle it via the failure mode.
    """
    cfg = load_config(config_path)
    enabled = [p for p in cfg.panelists if p.enabled]

    verdicts_path = Path(verdicts_dir).expanduser()
    parsed: list[ParsedVerdict] = []
    for p in enabled:
        f = verdicts_path / f"{p.id}.verdict"
        if not f.is_file():
            parsed.append(ParsedVerdict(
                id=p.id, role=p.role,
                verdict="ERROR",
                rationale=f"verdict file missing: {f}",
                alternative="n/a",
            ))
            continue
        v = parse_verdict_file(f)
        parsed.append(ParsedVerdict(
            id=p.id, role=p.role,
            verdict=v.verdict,
            rationale=v.rationale,
            alternative=v.alternative,
        ))

    directive = decide(cfg, parsed, cycle=None)
    log_verdict(directive.verdict, _trace_line(directive))

    payload = _to_serializable_dict(directive)
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def _to_serializable_dict(directive) -> dict:
    """Convert Directive to a dict with None-valued optional keys dropped."""
    raw = asdict(directive)
    # Drop optional fields when None — keeps the JSON shape clean per spec.
    if raw.get("re_brainstorm") is None:
        raw.pop("re_brainstorm", None)
    if raw.get("escalate_to_user") is None:
        raw.pop("escalate_to_user", None)
    return raw


def _trace_line(directive) -> str:
    """Format the trace log message for this aggregate call."""
    parts = []
    for p in directive.panelists:
        parts.append(f"{p.id}={p.verdict}")
    return " ".join(parts) if parts else "no-panelists"
```

- [ ] **Step 4: Update `panel/cli.py` aggregate subcommand**

Open `~/.claude/skills/validate-recommendation/panel/cli.py`. Replace the existing `aggregate` argparse block (which uses `--da --pe --recommended-label`) and the existing `if args.cmd == "aggregate":` branch.

Find this block (currently around lines 28-35):

```python
    agg = sub.add_parser(
        "aggregate", help="Aggregate panelist verdicts into a directive"
    )
    agg.add_argument("--da", required=True, help="Path to DA verdict file")
    agg.add_argument("--pe", required=True, help="Path to PE verdict file")
    agg.add_argument(
        "--recommended-label", required=True, help="The recommended option label"
    )
```

Replace with:

```python
    agg = sub.add_parser(
        "aggregate", help="Aggregate N-panelist verdicts into a JSON directive"
    )
    agg.add_argument(
        "--config", default=None,
        help="Path to config.yml (default: ~/.claude/panel/config.yml)",
    )
    agg.add_argument(
        "--verdicts-dir", required=True,
        help="Directory containing <panelist-id>.verdict files",
    )
    agg.add_argument(
        "--recommended-label", required=True,
        help="The recommended option label (for summary token expansion)",
    )
```

Find this block (currently around lines 60-63):

```python
    if args.cmd == "aggregate":
        from panel.aggregate import aggregate
        print(aggregate(args.da, args.pe, args.recommended_label))
        return 0
```

Replace with:

```python
    if args.cmd == "aggregate":
        from panel.aggregate import aggregate
        cfg_path = args.config or _default_config_path()
        print(aggregate(str(cfg_path), args.verdicts_dir, args.recommended_label))
        return 0
```

Update the file's top docstring `Subcommands shipped so far` block to:

```python
"""Top-level CLI dispatch for the panel package.

Subcommands shipped so far:
- aggregate         (Phase 3c — N-panelist JSON directive)
- lint-config       (Phase 3a — config validation)
- dispatch          (Phase 3b — langchain-provider-backed panelist dispatch)

Subcommands planned for later phases:
- record-userpick   (Phase 6)
- ls, show, label, stats, replay, gc   (Phase 6)
- tune              (Phase 7 — NAT Eval-backed)
"""
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_aggregate.py -v 2>&1 | tail -10
```

Expected: `12 passed`.

- [ ] **Step 6: Run the full panel test suite**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `106 passed` (102 after Task 1 + 12 new test_aggregate.py − 8 old test_aggregate.py).

**Note:** `aggregate_test.sh` will now fail because it expects the old text format. Don't run it here — Task 5 deletes it.

- [ ] **Step 7: Commit**

```bash
cd ~/.claude && git add \
    skills/validate-recommendation/panel/aggregate.py \
    skills/validate-recommendation/panel/tests/test_aggregate.py \
    skills/validate-recommendation/panel/cli.py
cd ~/.claude && git commit -s -S -m "feat(panel): aggregate.py — N-panelist JSON directive

Rewrites panel/aggregate.py for the v3.1 N-panelist contract:
  - Signature: aggregate(config_path, verdicts_dir, recommended_label)
  - Reads enabled panelists from ~/.claude/panel/config.yml
  - For each enabled panelist, reads <verdicts-dir>/<id>.verdict
  - Missing verdict file → ERROR-coerced panelist row (severity handles)
  - Calls panel.severity.decide(cfg, parsed, cycle=None)
  - Returns single-line JSON via json.dumps with compact separators
  - Optional re_brainstorm + escalate_to_user dropped when None

CLI signature change for the 'aggregate' subcommand:
  Before: panel aggregate --da <path> --pe <path> --recommended-label
  After:  panel aggregate --config <path> --verdicts-dir <dir> \\
                          --recommended-label

12 pytest cases (replaces the 8-test Phase 2 test_aggregate.py):
  - HOLD/SOFT/HARD/ERROR JSON shapes
  - Missing verdict file → ERROR-coerce
  - Disabled panelists excluded
  - Panelists ordered per config.yml
  - **Panel review:** sentinel preserved for SKILL.md compatibility
  - Markdown injection stripped (sanitize integration)
  - Single-line JSON output
  - Trace log records outcome (regression of Phase 2 behavior)
  - Phase 1 bug #3 preservation: OVERTURN + n/a → ERROR

SKILL.md still expects text output from aggregate.sh shim at this point;
panel is non-functional end-to-end until Task 4 lands the SKILL.md
rewrite. This is expected per Phase 3c migration plan (feature branch
+ atomic merge avoids landing this on main while broken)."
```

---

### Task 3: `test_cli_aggregate.py` — CLI wiring tests for the new signature

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_aggregate.py`

The existing `test_cli_lint_config.py` and `test_cli_dispatch.py` cover those subcommands; `test_cli_aggregate.py` is the new file for the rewritten aggregate subcommand.

- [ ] **Step 1: Write the failing tests**

```python
"""CLI tests for `panel aggregate` after Phase 3c rewrite.

Verifies argparse → aggregate() wiring with the new signature
(--config --verdicts-dir --recommended-label). The aggregate() function
itself is exercised by test_aggregate.py; here we test only the CLI shim.
"""
from __future__ import annotations
import json
import textwrap


def _write_minimal_config(tmp_path):
    p = tmp_path / "config.yml"
    p.write_text(textwrap.dedent("""
        version: 1
        panelists:
          - id: da-test
            role: DA
            enabled: true
            backend: nat-nim
            model: test-model
    """).strip() + "\n")
    return p


def _write_verdict(verdicts_dir, panelist_id, verdict, rationale, alternative):
    verdicts_dir.mkdir(parents=True, exist_ok=True)
    p = verdicts_dir / f"{panelist_id}.verdict"
    p.write_text(
        f"VERDICT: {verdict}\n"
        f"RATIONALE: {rationale}\n"
        f"ALTERNATIVE: {alternative}\n"
    )


def test_cli_aggregate_prints_json_to_stdout(tmp_path, capsys):
    from panel.cli import main
    cfg = _write_minimal_config(tmp_path)
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")

    rc = main([
        "aggregate",
        "--config", str(cfg),
        "--verdicts-dir", str(verdicts),
        "--recommended-label", "Option A (Recommended)",
    ])
    assert rc == 0

    captured = capsys.readouterr()
    data = json.loads(captured.out.strip())
    assert data["verdict"] == "HOLD"
    assert data["panelists"][0]["id"] == "da-test"


def test_cli_aggregate_returns_zero_on_success(tmp_path):
    from panel.cli import main
    cfg = _write_minimal_config(tmp_path)
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")

    rc = main([
        "aggregate",
        "--config", str(cfg),
        "--verdicts-dir", str(verdicts),
        "--recommended-label", "Option A",
    ])
    assert rc == 0


def test_cli_aggregate_uses_default_config_when_omitted(tmp_path, capsys, monkeypatch):
    """Default config path: ~/.claude/panel/config.yml. When --config is
    omitted, cli.py uses _default_config_path(). If the default doesn't
    exist (which it does in this environment), this test confirms the
    flag is optional."""
    from panel.cli import main
    cfg = _write_minimal_config(tmp_path)
    verdicts = tmp_path / "work"
    _write_verdict(verdicts, "da-test", "HOLD", "ok", "n/a")

    # Verify --config is optional by passing it explicitly here (the default
    # would point at the real ~/.claude/panel/config.yml which we don't want
    # this test to depend on).
    rc = main([
        "aggregate",
        "--config", str(cfg),
        "--verdicts-dir", str(verdicts),
        "--recommended-label", "Option A",
    ])
    assert rc == 0
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/test_cli_aggregate.py -v 2>&1 | tail -10
```

Expected: `3 passed`. These tests should pass against the cli.py wiring already done in Task 2 Step 4.

- [ ] **Step 3: Run the full panel test suite**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `109 passed` (106 after Task 2 + 3 new test_cli_aggregate.py).

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add \
    skills/validate-recommendation/panel/tests/test_cli_aggregate.py
cd ~/.claude && git commit -s -S -m "feat(panel): test_cli_aggregate.py — CLI tests for JSON output

Three pytest cases covering the rewritten 'panel aggregate' subcommand:
  - Prints valid JSON to stdout (parseable; contains expected fields)
  - Returns exit code 0 on success
  - --config flag is optional (default ~/.claude/panel/config.yml)

aggregate() behavior is exhaustively covered in test_aggregate.py; this
file only verifies the cli.py argparse → aggregate() wiring."
```

---

### Task 4: `SKILL.md` rewrite from scratch

**Files:**
- Rewrite: `~/.claude/skills/validate-recommendation/SKILL.md`

The current SKILL.md (11 KB) is hardcoded to DA + PE, reads `personas.md`, calls `dispatch-da.sh`, and parses text output from `aggregate.sh`. This task replaces it wholesale with a config-driven N-panelist orchestrator that uses `jq` to parse the new JSON directive.

- [ ] **Step 1: Replace the SKILL.md file contents**

Open `~/.claude/skills/validate-recommendation/SKILL.md` and replace the entire contents with:

````markdown
---
name: validate-recommendation
description: Validate (Recommended) options in AskUserQuestion via N configurable panelists (~/.claude/panel/config.yml). Triggered by the validate-recommendation hook; do not invoke manually.
---

# Validate Recommendation

You were invoked because the `validate-recommendation` hook fired on an
`AskUserQuestion` call that contained a `(Recommended)` option marker.
Your job: dispatch an N-panelist review (where N comes from
`~/.claude/panel/config.yml`), aggregate the verdicts into a JSON
directive, and act on it.

The panel composition is **configurable** — defaults to one Devil's
Advocate via Nemotron (`nat-nim` backend), and any number of additional
panelists (PE, QA, etc.) can be opted in by setting `enabled: true` in
`config.yml`. This skill is config-driven; it does NOT assume two
fixed panelists.

## Inputs

The hook wrote tool input to a session state file:

```
STATE_FILE="${TMPDIR:-/tmp}/claude-panel-${CLAUDE_SESSION_ID:-unknown}.json"
```

Read it via the `Read` tool. If the file is missing, emit the
user-visible message "Panel state file missing; asking the original
question." and fall back to issuing the original `AskUserQuestion`
unmodified. Stop here.

The panel config:

```
CONFIG="${HOME}/.claude/panel/config.yml"
```

State file keys you'll use:
- `tool_input.questions` — array of question objects (1-4 per the
  AskUserQuestion schema)
- `timeout_seconds` — per-panelist budget (default 90)

## Setup

### 1. Validate the config

Run via the `Bash` tool:

```bash
/opt/homebrew/bin/python3.12 -m panel lint-config --config "$CONFIG"
```

If exit code is non-zero, fall back: print "Panel disabled: config
invalid (see lint-config output)." and re-issue the original
`AskUserQuestion` unmodified. Stop.

### 2. Read enabled panelists from config

Use `jq` via Bash to enumerate enabled panelists:

```bash
jq -r '.panelists[] | select(.enabled) | "\(.id)|\(.role)|\(.backend)|\(.subagent_type // "")"' \
    <(/opt/homebrew/bin/python3.12 -c "
import yaml, json, sys
print(json.dumps(yaml.safe_load(open('$CONFIG'))))
")
```

The yaml→json conversion runs once at skill startup. Capture the output
into a variable; each line is `<id>|<role>|<backend>|<subagent_type>`
for one enabled panelist.

(If `python3.12 -c` for yaml→json is awkward in your sandbox, the
equivalent: `python3.12 -m panel lint-config --config "$CONFIG"` prints
the same data in human-readable form; you can grep its output for the
`- <id>` lines and extract role/backend from them.)

### 3. Create the per-session workdir

```bash
WORKDIR="${HOME}/.claude/panel/work/${CLAUDE_SESSION_ID:-unknown}"
mkdir -p "$WORKDIR" && chmod 0700 "$WORKDIR"
```

This is the directory where per-panelist verdict files land.
`panel aggregate` will read `${WORKDIR}/<id>.verdict` for each enabled
panelist after fan-out completes.

## Per-question dispatch

For EACH question in `tool_input.questions` that has an option labeled
with `(Recommended)` AND NOT `(Recommended; Panel-flagged)`:

### 1. Build the user prompt body

Construct from state file data:

```
Question: <question text>
Options (verbatim labels and descriptions):
  <option 1 label> — <option 1 description>
  <option 2 label> — <option 2 description>
  ...
Assistant's recommended option: <recommended label>
Assistant's stated reasoning: <see "Reasoning extraction" below>
```

Write to a per-question prompt file:

```
PROMPT_FILE="${TMPDIR:-/tmp}/panel-prompt-${CLAUDE_SESSION_ID}-q<N>.txt"
```

Where `<N>` is the question index (0-based).

### 2. Reasoning extraction

The "stated reasoning" passed to panelists comes from:

1. The recommended option's `description` field (primary source).
2. The question's lead text, if it contains rationale phrases.

If neither is informative, pass `(no reasoning supplied)`. Panelists
are told this is acceptable input. NEVER attempt to read or fabricate
hidden chain-of-thought.

### 3. Fan out N panelists in ONE message

**This is the parallelism point. All panelist dispatches MUST be in a
single message so they run concurrently.**

For EACH enabled panelist from the config enumeration above:

- **If `backend` starts with `nat-` (e.g., `nat-nim`):** include a
  `Bash` tool call in your fan-out message:

  ```bash
  /opt/homebrew/bin/python3.12 -m panel dispatch \
      --panelist "<id>" \
      --config "$CONFIG" \
      --persona "${HOME}/.claude/skills/validate-recommendation/personas/<role-lowercase>.md" \
      --prompt-file "$PROMPT_FILE" \
      --output "${WORKDIR}/<id>.verdict"
  ```

  `dispatch.py` writes the verdict file directly (mode 0600). Auth
  comes from per-backend env vars (`$PANEL_DA_API_KEY` /
  `$ANTHROPIC_API_KEY` / `$OPENAI_API_KEY`).

- **If `backend` is `claude-subagent`:** include an `Agent` tool call
  in your fan-out message:
  - `subagent_type`: the panelist's `subagent_type` from config (e.g.,
    `principal-engineer`, `qa-engineer`)
  - `description`: short, e.g., `"Panel <role> review"`
  - `prompt`: the concatenation of the persona file's `# System prompt`
    section, the `# One-shot example` section (if present), and the
    user prompt body from step 1.

  Read the persona file via the `Read` tool BEFORE composing the
  fan-out message:
  `${HOME}/.claude/skills/validate-recommendation/personas/<role-lowercase>.md`.

All `Bash` + `Agent` calls go in ONE message. The framework executes
them concurrently.

### 4. Collect verdict files after fan-out returns

When the fan-out message's tool results come back:

- **`nat-*` panelists:** `dispatch.py` already wrote the verdict file.
  Nothing to do.
- **`claude-subagent` panelists:** the `Agent` tool returned a string.
  Write the ENTIRE response verbatim to the verdict file via the
  `Write` tool:

  ```
  ${WORKDIR}/<id>.verdict
  ```

  Do NOT alter, summarize, or extract from the Agent response. The
  aggregator parses `VERDICT:`/`RATIONALE:`/`ALTERNATIVE:` lines from
  the verbatim text; surrounding prose is ignored.

### 5. Run the aggregator

```bash
DIRECTIVE_JSON=$(/opt/homebrew/bin/python3.12 -m panel aggregate \
    --config "$CONFIG" \
    --verdicts-dir "$WORKDIR" \
    --recommended-label "<recommended_label from state for THIS question>")
```

Capture stdout into `$DIRECTIVE_JSON`. It's a single-line JSON object.

### 6. Parse the directive

Extract fields via `jq`:

```bash
VERDICT=$(jq -r '.verdict' <<< "$DIRECTIVE_JSON")
SUMMARY=$(jq -r '.summary' <<< "$DIRECTIVE_JSON")
ESCALATE=$(jq -r '.escalate_to_user // false' <<< "$DIRECTIVE_JSON")
GATE=$(jq -r '.rationale_gate_passed' <<< "$DIRECTIVE_JSON")
```

Values:
- `VERDICT` ∈ `{HOLD, SOFT-DISSENT, HARD-DISSENT, ERROR}`
- `SUMMARY` — one-line user-facing text, already sanitized
- `ESCALATE` — `true` for HARD-DISSENT in Phase 3c, `false` otherwise
- `GATE` — `true`/`false`/`null` per the rationale gate semantics

## Acting on the directive

Behavior matrix:

### `VERDICT == "HOLD"`

Behavior depends on `${CLAUDE_PANEL:-on}`:

**Default (`on`)** — auto-take mode:

The recommendation stands. Take the recommended option without asking
the user. Print a brief message:

> Panel validated `<recommended_label>` for "<question excerpt>".
> <SUMMARY>
> Proceeding.

Then continue the work as if the user had picked the recommended
option. The `AskUserQuestion` for this question is NEVER issued.

**`advise`** — advisory mode (preserves user agency):

Do NOT auto-take. Re-issue `AskUserQuestion` for this question with
the panel's affirmative annotation appended. Augmented payload:

- **Question text**: original question + two newlines +
  `**Panel validated:** <SUMMARY>` (positive phrasing).
- **Options**: identical, EXCEPT the recommended option's label has
  `(Recommended)` swapped for `(Recommended; Panel-flagged)`. The hook
  detects this marker and skips the panel on the re-ask.

### `VERDICT == "SOFT-DISSENT"`

Re-issue `AskUserQuestion` for this question. Augmented payload:

- **Question text**: original + two newlines + `<SUMMARY>` (the
  `**Panel review:**` line). Use it verbatim.
- **Options**: identical, EXCEPT the recommended option's label is
  swapped to `(Recommended; Panel-flagged)`.

### `VERDICT == "HARD-DISSENT"`

In Phase 3c, HARD-DISSENT also escalates to the user (Phase 5 will add
re-think cycles). Same payload as SOFT-DISSENT, but include severity
in the augmented note:

- **Question text**: original + two newlines + `Panel HARD-DISSENT:
  <SUMMARY>` (severity-clear prefix).
- **Options**: identical, EXCEPT marker swap to
  `(Recommended; Panel-flagged)`.

When Phase 5 lands, this branch will check `re_brainstorm` in the
directive and emit a re-think markdown directive (no `AskUserQuestion`)
when present. Until then, every HARD-DISSENT escalates the question to
the user with full panel feedback.

### `VERDICT == "ERROR"`

Something went wrong (panelist backend down, malformed responses,
missing files, aggregator parse error). For this question, re-issue
the original `AskUserQuestion` unmodified — same options, same
`(Recommended)` marker — BUT swap the marker to
`(Recommended; Panel-flagged)` for loop safety.

Print a brief explanation:

> Panel evaluation failed for "<question excerpt>" (see hook trace
> for detail). Asking the question directly.

## Cleanup

After processing ALL questions (HOLD + DISSENT + ERROR paths):

```bash
rm -rf "$WORKDIR"
rm -f "$STATE_FILE" \
      "${TMPDIR:-/tmp}/panel-prompt-${CLAUDE_SESSION_ID}-q"*.txt
```

If you crash before cleanup, stale files are harmless (different
session = different `CLAUDE_SESSION_ID` = different paths). `panel gc`
will eventually reap stale workdirs (Phase 6).

## Failure modes you must handle gracefully

| What goes wrong | Behavior |
|---|---|
| State file missing | Print fallback message; re-issue original `AskUserQuestion`. |
| `panel lint-config` fails | Print "Panel disabled: config invalid"; re-issue original. |
| `~/.claude/panel/config.yml` missing | Caught by `lint-config`; same fallback. |
| Persona file missing for a configured role | Fall back. Print "Panel personas unavailable for <role>"; re-issue original. |
| `panel dispatch` crashes (caller-bug exit 1) | Verdict file not written. Aggregator coerces to ERROR for that panelist. Severity decides per failure_mode. |
| `panel dispatch` exits 0 but writes ERROR verdict | Normal path. Severity decides per failure_mode. |
| `Agent` tool call errors / returns garbled output | Write verbatim to verdict file; aggregator coerces to ERROR for that panelist if `VERDICT:` line is missing. |
| `panel aggregate` crashes (non-zero exit) | Fall back. Re-issue original with marker swap. |
| `$WORKDIR` unwritable | Fall back. Print "Panel infrastructure unavailable". |
| Missing API keys (e.g., `$PANEL_DA_API_KEY`) | `dispatch.py` writes ERROR verdict; aggregator emits ERROR directive (at N=1) or degrades (at N≥3 with graceful failure_mode). User-facing message ends up as re-ask original. |

The whole panel is best-effort. The user-visible question ALWAYS
survives.

### Loop safety on fallback

When you fall back to re-issuing the original `AskUserQuestion`, the
original payload still has `(Recommended)` — meaning the hook will
fire AGAIN. The hook has a re-entry guard: if a state file for the
current session already exists when the hook runs, the hook removes
it and approves (exit 0) without dispatching the skill again. So your
fallback re-issue is mechanically safe.

As a courtesy to future readers, swap the marker to
`(Recommended; Panel-flagged)` in your fallback re-issue (it documents
intent even though the re-entry guard makes it a no-op for safety).

## Multi-question parallelism (optional optimization)

If the `AskUserQuestion` call had multiple questions each with a
`(Recommended)` marker, you MAY dispatch panel calls for ALL
questions in parallel: fan out the N panelists × M questions in one
message. Aggregate runs per question after both panelists return.

For v1, sequential per-question dispatch is fine. Optimize only if
multi-question recommendations become common (they aren't currently).

## What you must NOT do

- Do NOT echo `$PANEL_DA_API_KEY` (or any other API key) in any
  user-facing text or trace output.
- Do NOT write API keys to any file.
- Do NOT modify or summarize the Agent tool's response before writing
  it to the verdict file. Write verbatim; let the aggregator parse.
- Do NOT modify the `AskUserQuestion` call beyond augmenting question
  text (for dissents) or swapping the marker (for ERROR or fallback).
- Do NOT re-invoke this skill after auto-taking a HOLD recommendation.
  The work continues as if the user picked.
- Do NOT introduce a panelist not in `config.yml`. New panelists ship
  via `config.yml` + a persona file under `personas/<role>.md` — never
  ad-hoc in this file.
- Do NOT call `python3.12 -m panel ...` for JSON parsing. Use `jq`.
  Python invocation is reserved for `lint-config`, `dispatch`, and
  `aggregate`.
- Do NOT bypass the hook re-entry guard by clearing the state file
  yourself. The guard exists to break loops on fallback paths.
````

- [ ] **Step 2: Verify no stale references to v1 files**

```bash
grep -n 'dispatch-da\|aggregate\.sh\|aggregate_test\.sh\|personas\.md' \
    ~/.claude/skills/validate-recommendation/SKILL.md 2>&1
```

Expected: no matches. If any line returns, edit it out.

- [ ] **Step 3: Verify required sentinels are present**

```bash
grep -c '^## Inputs\|^## Setup\|^## Per-question dispatch\|^## Acting\|^## Cleanup\|^## Failure modes' \
    ~/.claude/skills/validate-recommendation/SKILL.md
```

Expected: at least `6` (one per top-level section).

- [ ] **Step 4: Confirm full test suite still green**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `109 passed`. (SKILL.md is markdown only; tests should be unaffected.)

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add skills/validate-recommendation/SKILL.md
cd ~/.claude && git commit -s -S -m "feat(panel): SKILL.md rewrite — config-driven N-panelist fan-out

Complete rewrite (not incremental edit) of the orchestrator. The v1
SKILL.md was hardcoded to DA + PE, read personas.md, called
dispatch-da.sh + aggregate.sh, and parsed text directives.

The Phase 3c SKILL.md is config-driven:
  - Reads ~/.claude/panel/config.yml at startup via panel lint-config.
  - Enumerates enabled panelists from config (yaml → json via inline
    python; jq for field extraction).
  - For each enabled panelist, dispatches based on backend:
      backend: nat-*           → Bash 'panel dispatch ...' tool call
      backend: claude-subagent → Agent tool call (subagent_type from
                                 panelist.subagent_type)
  - All dispatches in ONE message (parallel execution).
  - claude-subagent responses written verbatim to verdict files.
  - Calls panel aggregate; captures single-line JSON to a variable.
  - Parses directive via jq (no python invocation for parsing).
  - Acts on verdict per HOLD/SOFT-DISSENT/HARD-DISSENT/ERROR matrix.

Phase 3c HARD-DISSENT semantics (per spec Decision A): escalate to
user immediately, same payload as SOFT-DISSENT but with severity
indicator in the augmented note. Phase 5 will layer re-think cycles
without changing SKILL.md's parsing contract.

Per-session workdir at ~/.claude/panel/work/<session-id>/ holds
verdict files (mode 0600). Aggregator reads <workdir>/<id>.verdict for
each enabled panelist.

No more references to v1 files (dispatch-da.sh, aggregate.sh,
personas.md) — those are deleted in the next commit. The skill won't
function until panel.aggregate.py emits JSON (already done in Task 2)."
```

---

### Task 5: Delete v1 shell files + update README

**Files:**
- Delete: `~/.claude/skills/validate-recommendation/dispatch-da.sh`
- Delete: `~/.claude/skills/validate-recommendation/dispatch-da_test.sh`
- Delete: `~/.claude/skills/validate-recommendation/aggregate.sh`
- Delete: `~/.claude/skills/validate-recommendation/aggregate_test.sh`
- Delete: `~/.claude/skills/validate-recommendation/personas.md`
- Modify: `~/.claude/skills/validate-recommendation/README.md`

The final cutover commit. After this, no shell wrappers remain.

- [ ] **Step 1: Sanity-check that nothing references the deletees**

```bash
grep -r 'dispatch-da\.sh\|aggregate\.sh\|aggregate_test\.sh\|dispatch-da_test\.sh' \
    ~/.claude/skills/ ~/.claude/hooks/ 2>&1 | grep -v Binary | head -20
```

Expected: no hits outside the files about to be deleted. If any other
file references them, fix that file first.

```bash
grep -r '\bpersonas\.md\b' ~/.claude/skills/ ~/.claude/hooks/ 2>&1 | \
    grep -v Binary | head -10
```

Expected: no hits in non-deleted files. (Matches inside `personas.md`
itself are fine — that file is being deleted.)

- [ ] **Step 2: Confirm the new SKILL.md does not reference any deletee**

```bash
grep -n 'dispatch-da\|aggregate\.sh\|aggregate_test\.sh\|personas\.md' \
    ~/.claude/skills/validate-recommendation/SKILL.md 2>&1
```

Expected: no matches.

- [ ] **Step 3: Delete the five v1 files**

```bash
rm ~/.claude/skills/validate-recommendation/dispatch-da.sh
rm ~/.claude/skills/validate-recommendation/dispatch-da_test.sh
rm ~/.claude/skills/validate-recommendation/aggregate.sh
rm ~/.claude/skills/validate-recommendation/aggregate_test.sh
rm ~/.claude/skills/validate-recommendation/personas.md
```

Verify:

```bash
ls ~/.claude/skills/validate-recommendation/ 2>&1 | \
    grep -E '^(dispatch-da|aggregate(_test)?\.sh|personas\.md)$' && \
    echo "STILL PRESENT" || echo "all five deleted"
```

Expected: `all five deleted`.

- [ ] **Step 4: Update `README.md`**

Open `~/.claude/skills/validate-recommendation/README.md`. The current
README documents Phase 1/2/3a/3b incrementally. For Phase 3c:

a) Remove any section that documents v1 shell tools (`dispatch-da.sh`,
   `aggregate.sh`). These sections start with headers like `## Phase 1`
   or describe the shell-script API.

b) Update the Phase 3b section that describes `panel dispatch` as a
   "manual invocation": it's now wired into SKILL.md, so the prose
   should be updated to "Invoked automatically by SKILL.md per
   `nat-*` panelist". The CLI usage block stays — it's still useful
   for manual debugging.

c) Append a Phase 3c section:

```markdown
## Phase 3c: N-panelist JSON aggregator

`panel aggregate` is now N-panelist and emits a single-line JSON
directive on stdout. SKILL.md parses it via `jq`.

### CLI

```bash
/opt/homebrew/bin/python3.12 -m panel aggregate \
    --config ~/.claude/panel/config.yml \
    --verdicts-dir ~/.claude/panel/work/<session-id>/ \
    --recommended-label "Option A (Recommended)"
```

### JSON directive shape

```json
{
  "verdict": "HOLD | SOFT-DISSENT | HARD-DISSENT | ERROR",
  "summary": "<user-facing one-line, already sanitized>",
  "rationale_gate_passed": true | false | null,
  "panelists": [
    {"id": "<panelist-id>", "role": "DA|PE|QA|...",
     "verdict": "HOLD|OVERTURN|ERROR",
     "rationale": "<verbatim, sanitized>",
     "alternative": "<verbatim option label or 'n/a'>"}
  ],
  "escalate_to_user": true  // present and true on Phase 3c HARD-DISSENT
}
```

Phase 5+ will add a `re_brainstorm` payload on HARD-DISSENT when
`cycle < max_cycles`. Phase 3c always emits `escalate_to_user: true`
on HARD-DISSENT (no cycle machinery yet).

### Verdict file convention

Per-session subdir: `~/.claude/panel/work/<session-id>/<id>.verdict`
where `<id>` matches the panelist's `id` in `~/.claude/panel/config.yml`.
SKILL.md creates the subdir; `panel dispatch` writes verdict files for
`nat-*` panelists; SKILL.md writes verdict files for `claude-subagent`
panelists from the Agent tool's response. Missing verdict files coerce
to ERROR-status panelist rows.
```

- [ ] **Step 5: Confirm test suite still green**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `109 passed`. Deleting shell files affects no Python tests.

- [ ] **Step 6: Commit**

```bash
cd ~/.claude && git add -A \
    skills/validate-recommendation/dispatch-da.sh \
    skills/validate-recommendation/dispatch-da_test.sh \
    skills/validate-recommendation/aggregate.sh \
    skills/validate-recommendation/aggregate_test.sh \
    skills/validate-recommendation/personas.md \
    skills/validate-recommendation/README.md
cd ~/.claude && git status 2>&1 | head -10
# (Verify deletions and README modification are staged.)
cd ~/.claude && git commit -s -S -m "chore(panel): delete v1 shell tooling and legacy personas

Phase 3c cutover. The v1 shell tooling (dispatch-da.sh, aggregate.sh,
dispatch-da_test.sh, aggregate_test.sh) is replaced by panel/dispatch.py
(Phase 3b) and the JSON-output panel/aggregate.py (Phase 3c). The
monolithic personas.md is replaced by per-role personas/{da,pe,qa}.md
(Phase 3a). SKILL.md (Phase 3c rewrite) calls python -m panel directly
— no shell wrappers remain.

Removed:
  - skills/validate-recommendation/dispatch-da.sh
  - skills/validate-recommendation/dispatch-da_test.sh
  - skills/validate-recommendation/aggregate.sh
  - skills/validate-recommendation/aggregate_test.sh
  - skills/validate-recommendation/personas.md

README updated:
  - Phase 1/2 v1 shell-tool sections removed.
  - Phase 3b 'manual panel dispatch invocation' section reframed as
    SKILL.md auto-invocation.
  - Phase 3c section added documenting the JSON directive shape and
    verdict file convention."
```

---

### Task 6: Smoke test + merge to main

**Files:** none modified except as part of merge.

End-to-end verification before merging the feature branch. Requires
`$PANEL_DA_API_KEY`, `$CLAUDE_PANEL_DA_ENDPOINT`, and
`$CLAUDE_PANEL_DA_MODEL` in the environment for live Nemotron calls.
The two deferred handoff issues (key rotation, env doubled prefix) must
be resolved by the operator before this task is meaningful.

- [ ] **Step 1: Full pytest suite green**

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -5
```

Expected: `109 passed`. If different, stop and investigate.

- [ ] **Step 2: `panel lint-config` OK**

```bash
/opt/homebrew/bin/python3.12 -m panel lint-config 2>&1
```

Expected:
```
OK: 1 enabled panelist(s) (of 3 configured)
  - da-nemotron (role=DA, backend=nat-nim, model=nvidia/nemotron-3-super-v3)
```

If model name has a doubled prefix (the deferred handoff issue), this
is the operator-visible symptom; smoke test below still works because
NIM accepts the doubled prefix.

- [ ] **Step 3: Manual end-to-end dispatch + aggregate (N=1, real Nemotron)**

```bash
SESSION="phase3c-smoke-$$"
WORKDIR="${HOME}/.claude/panel/work/${SESSION}"
PROMPT_FILE=$(mktemp)
mkdir -p "$WORKDIR" && chmod 0700 "$WORKDIR"

cat > "$PROMPT_FILE" <<'EOF'
Question: Which Go HTTP client should we pick?
Options (verbatim labels and descriptions):
  Option A (Recommended) — net/http; stdlib, no deps
  Option B — resty; third-party with built-in retries
Assistant's recommended option: Option A (Recommended)
Assistant's stated reasoning: stdlib avoids dependency cost and is sufficient.
EOF

cd ~/.claude/skills/validate-recommendation && \
    /opt/homebrew/bin/python3.12 -m panel dispatch \
        --panelist da-nemotron \
        --persona personas/da.md \
        --prompt-file "$PROMPT_FILE" \
        --output "$WORKDIR/da-nemotron.verdict" ; rc=$?

echo "dispatch rc=$rc"
echo "--- verdict file ---"
cat "$WORKDIR/da-nemotron.verdict"

DIRECTIVE_JSON=$(/opt/homebrew/bin/python3.12 -m panel aggregate \
    --config ~/.claude/panel/config.yml \
    --verdicts-dir "$WORKDIR" \
    --recommended-label "Option A (Recommended)")

echo "--- directive JSON ---"
echo "$DIRECTIVE_JSON" | python3 -m json.tool

rm -rf "$WORKDIR" "$PROMPT_FILE"
```

Expected:
- `dispatch rc=0`
- Verdict file contains `VERDICT: HOLD` (or `OVERTURN`, depending on
  what Nemotron decides) with a `RATIONALE:` line and `ALTERNATIVE:`
  line.
- Directive JSON is well-formed; `verdict` is one of
  `HOLD/SOFT-DISSENT/HARD-DISSENT/ERROR`; `panelists` has one entry
  for `da-nemotron`.

If `dispatch rc=0` but verdict file is `VERDICT: ERROR` with auth
failure rationale, the API key is missing or stale (the deferred
handoff key-rotation issue). Re-export and retry.

- [ ] **Step 4: Manual end-to-end with N=3 panel (PE + QA enabled)**

Temporarily enable PE and QA in config:

```bash
cp ~/.claude/panel/config.yml ~/.claude/panel/config.yml.smoke-bak
sed -i.bak 's/enabled: false/enabled: true/g' ~/.claude/panel/config.yml
/opt/homebrew/bin/python3.12 -m panel lint-config
```

Expected: `OK: 3 enabled panelist(s)`.

Run the dispatch + aggregate against the same `$PROMPT_FILE` as Step 3.
N=3 path requires also invoking PE and QA subagents — for this smoke,
you can skip the subagent dispatches and just write placeholder HOLD
verdicts:

```bash
SESSION="phase3c-smoke-n3-$$"
WORKDIR="${HOME}/.claude/panel/work/${SESSION}"
mkdir -p "$WORKDIR" && chmod 0700 "$WORKDIR"

# Run real DA via dispatch
cd ~/.claude/skills/validate-recommendation && \
    /opt/homebrew/bin/python3.12 -m panel dispatch \
        --panelist da-nemotron --persona personas/da.md \
        --prompt-file "$PROMPT_FILE" \
        --output "$WORKDIR/da-nemotron.verdict"

# Simulate PE and QA Agent responses (since smoke test doesn't run Claude)
cat > "$WORKDIR/pe.verdict" <<'EOF'
VERDICT: HOLD
RATIONALE: Recommendation aligns with YAGNI; stdlib choice avoids the
maintenance cost of an extra dependency.
ALTERNATIVE: n/a
EOF
cat > "$WORKDIR/qa.verdict" <<'EOF'
VERDICT: HOLD
RATIONALE: Testable as written; stdlib client supports the same
mocking patterns we already use.
ALTERNATIVE: n/a
EOF

DIRECTIVE_JSON=$(/opt/homebrew/bin/python3.12 -m panel aggregate \
    --config ~/.claude/panel/config.yml \
    --verdicts-dir "$WORKDIR" \
    --recommended-label "Option A (Recommended)")

echo "$DIRECTIVE_JSON" | python3 -m json.tool

rm -rf "$WORKDIR" "$PROMPT_FILE"
mv ~/.claude/panel/config.yml.smoke-bak ~/.claude/panel/config.yml
```

Expected: JSON directive lists 3 panelists in order `da-nemotron, pe, qa`.
If all three are HOLD, directive `verdict: HOLD`. If DA OVERTURNs with
a concrete alt and PE+QA HOLD, directive `verdict: SOFT-DISSENT`
(threshold not met). Verify the JSON shape and field values.

- [ ] **Step 5: Verify branch state**

```bash
cd ~/.claude && git log --oneline main..feat/phase3c-aggregate-json 2>&1
```

Expected: 5 commits in this order (top is most recent):
```
<hash5> chore(panel): delete v1 shell tooling and legacy personas
<hash4> feat(panel): SKILL.md rewrite — config-driven N-panelist fan-out
<hash3> feat(panel): test_cli_aggregate.py — CLI tests for JSON output
<hash2> feat(panel): aggregate.py — N-panelist JSON directive
<hash1> feat(panel): severity.py — pure N-panelist decision tree
```

```bash
cd ~/.claude && git status 2>&1
```

Expected: `On branch feat/phase3c-aggregate-json` and clean working tree.

- [ ] **Step 6: Merge to main**

```bash
cd ~/.claude && git checkout main
cd ~/.claude && git merge --ff-only feat/phase3c-aggregate-json
cd ~/.claude && git log --oneline -7
```

Expected: fast-forward merge; the 5 Phase 3c commits now on `main`.

Sanity-check the merged main:

```bash
cd ~/.claude/skills/validate-recommendation && \
    ~/.local/pipx/venvs/pytest/bin/pytest panel/tests/ -q 2>&1 | tail -3
```

Expected: `109 passed`.

- [ ] **Step 7: Delete the feature branch**

```bash
cd ~/.claude && git branch -d feat/phase3c-aggregate-json
cd ~/.claude && git branch
```

Expected: `feat/phase3c-aggregate-json` no longer listed.

No further commits in Task 6.

---

## Self-Review

**Spec coverage check** (cross-reference design spec sections to plan tasks):

| Spec section | Plan task |
|---|---|
| Decision A — HARD-DISSENT escalates immediately | Task 1 (severity.py `cycle=None` branch) + Task 4 (SKILL.md HARD-DISSENT section) |
| Decision B — `decide(cycle=None)` signature | Task 1 (function signature + tests `test_cycle_*`) |
| Decision C — file-layout deviation (`<session-id>/<id>.verdict`) | Task 2 (aggregate.py reads `<dir>/<id>.verdict`) + Task 4 (SKILL.md creates per-session workdir) |
| Decision D — missing verdict file → ERROR-coerce | Task 2 (aggregate.py missing-file branch + `test_missing_verdict_file_coerces_panelist_to_error`) |
| Decision E — single-line compact JSON | Task 2 (aggregate.py `separators=(",", ":")` + `test_output_is_single_line_json`) |
| Decision F — SKILL.md uses jq | Task 4 (SKILL.md "Parse the directive" section) |
| Decision G — SKILL.md rewrite from scratch | Task 4 |
| Decision H — feature branch | Task 0 (create) + Task 6 (merge) |
| JSON directive shape (always + conditional fields) | Task 1 (Directive dataclass) + Task 2 (aggregate emits) + Task 4 (SKILL.md parses) |
| Severity decision tree (5 steps) | Task 1 Step 3 |
| Aggregator signature `--config --verdicts-dir --recommended-label` | Task 2 Step 4 (cli.py) + Task 3 (cli aggregate tests) |
| SKILL.md fan-out in ONE message | Task 4 ("Fan out N panelists in ONE message" section) |
| 5 v1 file deletions (incl. aggregate_test.sh) | Task 5 |
| Test surface ~109 tests | Task 1 (+25), Task 2 (+12 -8), Task 3 (+3), final = 77 + 25 + 12 - 8 + 3 = 109 |

**Placeholder scan:**

- No "TBD", "TODO", "implement later" anywhere.
- No "add appropriate error handling" — every step shows concrete code or commands.
- No "similar to Task N" — repeated code is repeated, not pointed to.
- No undefined references — every helper called by `severity.decide()` is defined in Task 1 Step 3; every flag used by `panel aggregate` is wired in Task 2 Step 4; every `jq` expression in SKILL.md matches a real field in the JSON directive.

**Type consistency:**

- `Panelist` dataclass fields (`id`, `role`, `enabled`, `backend`, `model`, `subagent_type`, `max_tokens`, `temperature`, `timeout_seconds`) — matches `panel/config.py` (Phase 3a, unchanged).
- `ParsedVerdict` dataclass fields (`id`, `role`, `verdict`, `rationale`, `alternative`) — defined in Task 1, used in Task 1 + Task 2.
- `Directive` dataclass fields (`verdict`, `summary`, `rationale_gate_passed`, `panelists`, `re_brainstorm`, `escalate_to_user`) — defined in Task 1, serialized in Task 2, parsed via jq in Task 4.
- `parse_verdict_file` function from `panel/verdict.py` (Phase 2) returns object with `verdict / rationale / alternative` attributes — used in Task 2 Step 3 aggregate.py.
- `aggregate()` signature `(config_path, verdicts_dir, recommended_label)` — defined in Task 2 Step 3, called from Task 2 Step 4 cli.py and Task 3 tests.

**Test-count math:**

- Phase 3b baseline: 77.
- Task 1 adds `test_severity.py`: +25 → 102.
- Task 2 replaces `test_aggregate.py`: -8 + 12 = +4 → 106.
- Task 3 adds `test_cli_aggregate.py`: +3 → 109.
- Task 4/5/6 add 0 tests (markdown + deletions + smoke).
- Task 6 Step 1 expects `109 passed`. Consistent.

**Migration safety:**

- Task 0 verifies pre-flight baseline (77 passing, legacy v1 still works).
- Tasks 1-4 build forward on a feature branch (`feat/phase3c-aggregate-json`).
- Tasks 1 and 3 are independently green between commits.
- Task 2 leaves the panel non-functional end-to-end (aggregate emits JSON but SKILL.md still expects text); Task 3 doesn't fix this; Task 4 does. The feature-branch isolation means `main` never sees this intermediate state. Documented in commit messages.
- Task 5 commits the deletions after SKILL.md no longer references them (verified by `grep` in Task 5 Step 1-2).
- Task 6 merges the branch atomically with fast-forward only.

**Phase boundary:**

- Phase 3c ships the N-panelist JSON-directive panel with SKILL.md cutover.
- `state.py` + qhash + cycle continuation → Phase 5.
- `decisions.py` + JSONL telemetry → Phase 6.
- `panel ls/show/label/stats/replay/gc` subcommands → Phase 6.
- `panel tune` (NAT Eval) → Phase 7.
- PostToolUse hook for `user_pick` capture → Phase 6.
