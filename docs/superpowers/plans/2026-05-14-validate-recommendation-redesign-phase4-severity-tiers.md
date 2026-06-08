# validate-recommendation v2 — Phase 4: Severity tiers

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the binary HOLD/DISSENT contract with a four-state contract: `HOLD` / `SOFT-DISSENT` / `HARD-DISSENT` / `ERROR`. Severity comes from vote count + rationale-strength gate (regex match against `severity.rationale_gate.principle_patterns` OR concrete alternative present). In this phase, HARD-DISSENT is treated as an emphatic SOFT-DISSENT (different marker text, bolder warning) — the actual re-brainstorm mechanic is **deferred to Phase 5**.

**Architecture:** Add `panel.severity` module containing `decide(config, panelists, cycle=0)`. Existing `aggregate_n` becomes a thin wrapper that calls `decide()` then formats output. Failure mode (`strict` / `graceful` / `auto`) preserves odd-N invariant when a panelist errors. SKILL.md learns to dispatch HOLD/SOFT/HARD/ERROR — for HARD, it surfaces with a `(Recommended; Panel-flagged-HARD)` marker and an emphatic note.

**Tech Stack:** Python stdlib only (`re` for principle patterns, `math.ceil` for thresholds).

**Pre-flight:**
- Phase 3 has shipped: `python3 -m panel aggregate --verdicts ...` works against the 3-panelist default config.
- All Phase 3 pytest tests pass.
- The default `~/.claude/panel/config.json` includes the `severity` section.

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/skills/validate-recommendation/panel/severity.py` | **Create**: severity decision tree. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_severity.py` | **Create**: severity logic tests. |
| `~/.claude/skills/validate-recommendation/panel/aggregate.py` | **Modify**: `aggregate_n` calls `severity.decide()`. Output format extends with HARD/SOFT branching. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py` | **Modify**: assertion strings updated for new outputs. |
| `~/.claude/skills/validate-recommendation/panel/cli.py` | **Modify**: `aggregate` subcommand takes optional `--cycle <N>` (always 0 in Phase 4; Phase 5 makes it meaningful). |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify**: act on SOFT-DISSENT / HARD-DISSENT directives. |

---

## Tasks

### Task 1: Failing tests for `panel.severity`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_severity.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.severity.decide() — vote + rationale-gate decision tree."""
from panel.config import Config, Panelist, Severity, RationaleGate, FailureMode, ReBrainstorm, Telemetry
from panel.verdict import Verdict


def _cfg(n_panelists=3, hard_threshold="majority"):
    return Config(
        version="1",
        panelists=[Panelist(id=f"p{i}", role="DA", backend="http") for i in range(n_panelists)],
        severity=Severity(hard_threshold=hard_threshold, rationale_gate=RationaleGate()),
        failure_mode=FailureMode(on_panelist_error="auto"),
        re_brainstorm=ReBrainstorm(),
        telemetry=Telemetry(),
    )


def test_all_hold_returns_hold():
    from panel.severity import decide
    panelists = [Verdict("HOLD", "fine", "n/a") for _ in range(3)]
    d = decide(_cfg(3), panelists, cycle=0)
    assert d["verdict"] == "HOLD"


def test_minority_overturn_returns_soft_dissent():
    from panel.severity import decide
    panelists = [
        Verdict("OVERTURN", "the alternative is more idiomatic — violates YAGNI", "Option B"),
        Verdict("HOLD", "fine", "n/a"),
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(_cfg(3), panelists, cycle=0)
    assert d["verdict"] == "SOFT-DISSENT"


def test_majority_overturn_with_principle_returns_hard_dissent():
    from panel.severity import decide
    panelists = [
        Verdict("OVERTURN", "violates the YAGNI principle in the constitution", "Option B"),
        Verdict("OVERTURN", "atomicity broken — multiple concerns bundled", "Option B"),
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(_cfg(3), panelists, cycle=0)
    assert d["verdict"] == "HARD-DISSENT"
    assert d.get("rationale_gate_passed") is True


def test_majority_overturn_without_principle_returns_soft_dissent():
    """Gate failure: vibes-only OVERTURN majority degrades to SOFT-DISSENT."""
    from panel.severity import decide
    panelists = [
        Verdict("OVERTURN", "feels wrong to me intuitively", ""),       # no alt, no principle
        Verdict("OVERTURN", "I don't really like this option", ""),     # no alt, no principle
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(_cfg(3), panelists, cycle=0)
    assert d["verdict"] == "SOFT-DISSENT"
    assert d.get("rationale_gate_passed") is False


def test_majority_overturn_with_alternative_passes_gate():
    """Concrete ALTERNATIVE label satisfies the gate even without principle phrasing."""
    from panel.severity import decide
    panelists = [
        Verdict("OVERTURN", "Option B works better.", "Option B"),
        Verdict("OVERTURN", "Option B simpler.", "Option B"),
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(_cfg(3), panelists, cycle=0)
    assert d["verdict"] == "HARD-DISSENT"


def test_supermajority_threshold_at_n5(monkeypatch):
    """At N=5 with hard_threshold=supermajority, 3/5 OVERTURN is SOFT not HARD."""
    from panel.severity import decide
    cfg = _cfg(5, hard_threshold="supermajority")
    panelists = [
        Verdict("OVERTURN", "violates YAGNI", "Option B"),
        Verdict("OVERTURN", "violates atomicity", "Option B"),
        Verdict("OVERTURN", "violates priority order", "Option B"),
        Verdict("HOLD", "fine", "n/a"),
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(cfg, panelists, cycle=0)
    # 3/5 is simple majority but NOT supermajority (which needs ceil(2*5/3) = 4).
    assert d["verdict"] == "SOFT-DISSENT"


def test_error_panelist_strict_at_n3(monkeypatch):
    """At N=3 with failure_mode=auto, any panelist ERROR → directive ERROR."""
    from panel.severity import decide
    panelists = [
        Verdict("", "", ""),  # unparseable → treated as ERROR
        Verdict("HOLD", "fine", "n/a"),
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(_cfg(3), panelists, cycle=0)
    assert d["verdict"] == "ERROR"


def test_hard_dissent_at_max_cycle_sets_escalate_flag():
    """When cycle >= max_cycles, HARD-DISSENT directive includes escalate_to_user=True."""
    from panel.severity import decide
    cfg = _cfg(3)
    panelists = [
        Verdict("OVERTURN", "violates YAGNI", "Option B"),
        Verdict("OVERTURN", "violates YAGNI", "Option B"),
        Verdict("HOLD", "fine", "n/a"),
    ]
    d = decide(cfg, panelists, cycle=cfg.re_brainstorm.max_cycles)
    assert d["verdict"] == "HARD-DISSENT"
    assert d.get("escalate_to_user") is True
```

- [ ] **Step 2: Run — should FAIL**

`python3 -m pytest panel/tests/test_severity.py -v` → ModuleNotFoundError.

---

### Task 2: Implement `panel/severity.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/severity.py`

- [ ] **Step 1: Write `severity.py`**

```python
"""Severity decision tree for the validate-recommendation panel.

Inputs: config, list of Verdict objects (already parsed), cycle number.
Output: directive dict with at least `verdict`, plus optional fields
depending on the path taken.

Phase 4 introduces:
  - HOLD       (0 OVERTURN)
  - SOFT-DISSENT (minority OVERTURN, OR majority OVERTURN with rationale-gate failure)
  - HARD-DISSENT (majority OVERTURN AND rationale-gate passed)
  - ERROR      (panelist failure beyond failure_mode tolerance)

`escalate_to_user` is set on HARD-DISSENT when cycle >= max_cycles
(Phase 5 uses this to skip emitting a re-brainstorm payload and route
directly to user surfacing).
"""
from __future__ import annotations
import math
import re
from typing import Any

from panel.config import Config
from panel.verdict import Verdict


def _normalize_panelists(verdicts: list[Verdict]) -> tuple[list[Verdict], int]:
    """Return (valid_panelists, error_count).

    A panelist is invalid if VERDICT is not HOLD or OVERTURN, or if
    RATIONALE is empty, or if OVERTURN has empty/n/a ALTERNATIVE.
    """
    valid: list[Verdict] = []
    errors = 0
    for v in verdicts:
        if v.verdict not in ("HOLD", "OVERTURN"):
            errors += 1
            continue
        if not v.rationale:
            errors += 1
            continue
        if v.verdict == "OVERTURN" and (not v.alternative or v.alternative == "n/a"):
            errors += 1
            continue
        valid.append(v)
    return valid, errors


def _resolve_failure_mode(cfg: Config, n_panelists: int) -> str:
    mode = cfg.failure_mode.on_panelist_error
    if mode != "auto":
        return mode
    return "strict" if n_panelists <= 3 else "graceful"


def _principle_or_alternative(verdict: Verdict, patterns: list[str]) -> bool:
    """True if the verdict's rationale matches a principle pattern OR ALTERNATIVE is concrete."""
    if verdict.alternative and verdict.alternative != "n/a":
        return True
    for pat in patterns:
        if re.search(pat, verdict.rationale, flags=re.IGNORECASE):
            return True
    return False


def decide(cfg: Config, verdicts: list[Verdict], cycle: int = 0) -> dict[str, Any]:
    """Return a directive dict for the given panelist verdicts and cycle.

    Always returns a dict with at minimum a `verdict` key. Additional
    keys depend on the path taken.
    """
    panelists, n_errors = _normalize_panelists(verdicts)
    original_n = len(verdicts)

    if n_errors > 0:
        mode = _resolve_failure_mode(cfg, original_n)
        # Strict at N<=3 or if dropping leaves the panel too small.
        if mode == "strict" or (original_n - 2 * n_errors) < 1:
            return {
                "verdict": "ERROR",
                "reason": f"{n_errors} panelist(s) returned malformed verdicts",
                "n_errors": n_errors,
            }
        # Graceful: drop one HOLD per error to keep N odd. Conservative — bias
        # toward HOLD because dissent without all panelists is less trustworthy.
        # We drop from the HOLD side (or arbitrary if no HOLDs to drop) to
        # preserve OVERTURN signal.
        for _ in range(n_errors):
            holds = [i for i, v in enumerate(panelists) if v.verdict == "HOLD"]
            if not holds:
                break
            panelists.pop(holds[0])

    if not panelists:
        return {"verdict": "ERROR", "reason": "no valid panelists after failure-mode application"}

    overturn = [v for v in panelists if v.verdict == "OVERTURN"]
    n = len(panelists)

    if not overturn:
        return {"verdict": "HOLD", "panelists": [v.__dict__ for v in panelists]}

    # Threshold computation.
    if cfg.severity.hard_threshold == "supermajority":
        threshold = math.ceil(2 * n / 3)
    else:  # "majority"
        threshold = math.ceil(n / 2)

    if len(overturn) < threshold:
        return {
            "verdict": "SOFT-DISSENT",
            "reason": f"minority OVERTURN ({len(overturn)}/{n})",
            "panelists": [v.__dict__ for v in panelists],
            "overturn_alternatives": [v.alternative for v in overturn if v.alternative and v.alternative != "n/a"],
        }

    # Majority OVERTURN — check rationale gate.
    patterns = cfg.severity.rationale_gate.principle_patterns
    if cfg.severity.rationale_gate.requires_principle_or_alternative:
        gate_passed = any(_principle_or_alternative(v, patterns) for v in overturn)
        if not gate_passed:
            return {
                "verdict": "SOFT-DISSENT",
                "rationale_gate_passed": False,
                "reason": f"majority OVERTURN ({len(overturn)}/{n}) but rationale gate failed",
                "panelists": [v.__dict__ for v in panelists],
            }

    # HARD-DISSENT.
    directive: dict[str, Any] = {
        "verdict": "HARD-DISSENT",
        "rationale_gate_passed": True,
        "panelists": [v.__dict__ for v in panelists],
        "overturn_alternatives": [v.alternative for v in overturn if v.alternative and v.alternative != "n/a"],
    }
    if cycle >= cfg.re_brainstorm.max_cycles:
        directive["escalate_to_user"] = True
    return directive
```

- [ ] **Step 2: Run tests — should PASS**

`python3 -m pytest panel/tests/test_severity.py -v` → all 8 pass.

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/severity.py panel/tests/test_severity.py
git commit -s -S -m "feat(panel): severity decision tree

Implements the Phase 4 verdict contract:
  HOLD / SOFT-DISSENT / HARD-DISSENT / ERROR

Vote count + rationale-strength gate. Failure mode auto-resolves to
strict at N<=3 and graceful at N>=5 (preserves odd-N invariant by
dropping HOLDs when panelists error). escalate_to_user set when
cycle >= max_cycles (used in Phase 5 to skip re-brainstorm payload)."
```

---

### Task 3: Wire `severity.decide()` into `aggregate_n`

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/aggregate.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/tests/test_aggregate.py`

- [ ] **Step 1: Add failing tests for Phase 4 output format**

Append to `panel/tests/test_aggregate.py`:

```python
def test_aggregate_emits_soft_dissent_verdict_line(fixtures_dir, monkeypatch, tmp_path):
    """Aggregator output must include PANEL_VERDICT: SOFT-DISSENT line."""
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    qa_hold = tmp_path / "qa_hold.txt"
    qa_hold.write_text("VERDICT: HOLD\nRATIONALE: QA is fine.\nALTERNATIVE: n/a\n")
    from panel.aggregate import aggregate_n
    out = aggregate_n(
        [str(fixtures_dir / "da_overturn_b.txt"), str(fixtures_dir / "pe_hold.txt"), str(qa_hold)],
        "Option A",
        config_path=None,  # use default config bundled with skill
    )
    assert "PANEL_VERDICT: SOFT-DISSENT" in out


def test_aggregate_emits_hard_dissent_verdict_line(fixtures_dir, monkeypatch, tmp_path):
    """Two OVERTURNs with principles → PANEL_VERDICT: HARD-DISSENT."""
    monkeypatch.setenv("CLAUDE_PANEL_TRACE_LOG", str(tmp_path / "trace.log"))
    qa_overturn = tmp_path / "qa_overturn.txt"
    qa_overturn.write_text(
        "VERDICT: OVERTURN\n"
        "RATIONALE: Option A risks theater tests — encourages tautological assertions.\n"
        "ALTERNATIVE: Option B\n"
    )
    from panel.aggregate import aggregate_n
    out = aggregate_n(
        [str(fixtures_dir / "da_overturn_b.txt"), str(fixtures_dir / "pe_hold.txt"), str(qa_overturn)],
        "Option A",
        config_path=None,
    )
    assert "PANEL_VERDICT: HARD-DISSENT" in out
```

- [ ] **Step 2: Run — should FAIL (Phase 3 aggregator still emits DISSENT not SOFT/HARD)**

- [ ] **Step 3: Update `aggregate_n` to call `severity.decide`**

Replace the body of `aggregate_n` in `panel/aggregate.py` with:

```python
def aggregate_n(
    verdict_paths: list[str],
    recommended_label: str,
    config_path: str | None = None,
    cycle: int = 0,
) -> str:
    """Aggregate N verdict files into a Phase-4 directive.

    Uses panel.severity.decide() for the bucket. Output format:
      Line 1: PANEL_VERDICT: <HOLD|SOFT-DISSENT|HARD-DISSENT|ERROR>
      Lines 2+: per-bucket detail (DA:/PE: rationale lines for HOLD;
                **Panel review:** summary for dissent; reason for ERROR).
    """
    from panel.config import load_config
    from panel.severity import decide

    verdicts = [parse_verdict_file(p) for p in verdict_paths]

    cfg_path = config_path or Path.home() / ".claude" / "panel" / "config.json"
    try:
        cfg = load_config(cfg_path)
    except Exception as e:
        log_verdict("ERROR", f"config load failed: {e}")
        return f"PANEL_VERDICT: ERROR\nconfig load failed: {e}"

    directive = decide(cfg, verdicts, cycle=cycle)
    verdict = directive["verdict"]

    if verdict == "ERROR":
        log_verdict("ERROR", directive.get("reason", "unknown"))
        return f"PANEL_VERDICT: ERROR\n{directive.get('reason', 'unknown error')}"

    if verdict == "HOLD":
        lines = ["PANEL_VERDICT: HOLD"]
        for i, v in enumerate(verdicts):
            short = _abbreviate_first_sentence(v.rationale)
            lines.append(f"P{i+1}: {short}")
        log_verdict("HOLD", " | ".join(f"P{i+1}: {_abbreviate_first_sentence(v.rationale)}" for i, v in enumerate(verdicts)))
        return "\n".join(lines)

    # SOFT-DISSENT or HARD-DISSENT — build a Panel review summary.
    pieces = ["**Panel review:** "]
    for i, v in enumerate(verdicts):
        rat = strip_markdown(v.rationale)
        if v.verdict == "OVERTURN":
            alt = strip_markdown(v.alternative or "n/a")
            pieces.append(f"P{i+1} flagged {recommended_label} → suggests {alt}: {rat} ")
        elif v.verdict == "HOLD":
            pieces.append(f"P{i+1} held {recommended_label}: {rat} ")
        else:
            pieces.append(f"P{i+1} errored: {v.verdict or 'unparseable'} ")
    summary = "".join(pieces).rstrip()
    alts_log = "/".join(v.alternative or "n/a" for v in verdicts)
    verdicts_log = " ".join(f"P{i+1}={v.verdict or 'ERROR'}" for i, v in enumerate(verdicts))
    log_verdict(verdict, f"{verdicts_log} alts={alts_log} cycle={cycle}")
    return f"PANEL_VERDICT: {verdict}\n{summary}"
```

Also import `Path` at the top of the file if not already there:

```python
from pathlib import Path
```

- [ ] **Step 4: Run all aggregate tests — should PASS**

`python3 -m pytest panel/tests/test_aggregate.py panel/tests/test_severity.py -v`

Note: Tests from Phase 3 may need string updates — e.g., a test asserting `PANEL_VERDICT: DISSENT` should now assert `PANEL_VERDICT: SOFT-DISSENT` for the corresponding inputs. Update those assertions in-place.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/aggregate.py panel/tests/test_aggregate.py
git commit -s -S -m "feat(panel): aggregate_n returns severity-tiered verdicts

Replaces binary HOLD/DISSENT with HOLD/SOFT-DISSENT/HARD-DISSENT/ERROR.
Output format extended; SKILL.md updated in next task to handle the
new directives."
```

---

### Task 4: Add `--cycle` and `--config` to the `aggregate` CLI

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

- [ ] **Step 1: Extend `aggregate` subparser**

In `cli.py`, modify the `aggregate` subparser block:

```python
    agg.add_argument("--verdicts", required=True, nargs="+",
                     help="Paths to N panelist verdict files (any order)")
    agg.add_argument("--recommended-label", required=True,
                     help="The recommended option label")
    agg.add_argument("--config", default=None,
                     help="Path to panel config.json (default: ~/.claude/panel/config.json)")
    agg.add_argument("--cycle", type=int, default=0,
                     help="Re-brainstorm cycle number (Phase 5 uses this; Phase 4 always 0)")
```

Update the dispatch branch:

```python
    if args.cmd == "aggregate":
        from panel.aggregate import aggregate_n
        print(aggregate_n(
            args.verdicts,
            args.recommended_label,
            config_path=args.config,
            cycle=args.cycle,
        ))
        return 0
```

- [ ] **Step 2: Manual smoke test**

Run: `cd ~/.claude/skills/validate-recommendation && python3 -m panel aggregate --help`
Expected: help text shows `--verdicts`, `--recommended-label`, `--config`, `--cycle`.

- [ ] **Step 3: Commit**

```bash
git add panel/cli.py
git commit -s -S -m "feat(panel): aggregate CLI accepts --config and --cycle"
```

---

### Task 5: Update `SKILL.md` to handle SOFT-DISSENT / HARD-DISSENT

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/SKILL.md`

- [ ] **Step 1: Replace the "Acting on verdicts" section in SKILL.md**

Find `## Acting on verdicts` (or equivalent — Phase 3 SKILL.md may have folded this into "Per-question dispatch"). Add or rewrite:

```markdown
## Acting on verdicts

After `panel aggregate` returns, parse the first line for `PANEL_VERDICT: <bucket>` and act:

### `PANEL_VERDICT: HOLD`

Behavior depends on `${CLAUDE_PANEL:-on}`:
- `on` (default): auto-take the recommendation without asking the user. Print a one-paragraph note with abbreviated rationales.
- `advise`: re-issue `AskUserQuestion` with `(Recommended)` → `(Recommended; Panel-flagged)` and a `**Panel validated:**` note appended to the question text.

### `PANEL_VERDICT: SOFT-DISSENT`

Re-issue `AskUserQuestion` for this question:
- Question text: original + two newlines + the `**Panel review:**` line from aggregate stdout.
- Options: identical to original, EXCEPT the recommended option's label has `(Recommended)` replaced with `(Recommended; Panel-flagged)`.

The hook detects the swapped marker and skips the panel on the re-ask (no infinite loop).

### `PANEL_VERDICT: HARD-DISSENT`

**Phase 4 behavior**: treat like SOFT-DISSENT but with a stronger marker and prefix. Re-issue `AskUserQuestion`:
- Question text: original + two newlines + the `**Panel review:**` line, prefixed with `⚠️ **HARD DISSENT:** the majority of the panel rejected this recommendation with concrete grounds.` (no emoji if the codebase rejects emoji — match repo conventions).
- Options: recommended label swapped to `(Recommended; Panel-flagged-HARD)`.

Phase 5 will replace this Phase-4 stub with the auto re-brainstorm flow.

### `PANEL_VERDICT: ERROR`

Re-issue the original `AskUserQuestion` unmodified — but swap the marker to `(Recommended; Panel-flagged)` so the hook doesn't fire again. Print a brief note: "Panel evaluation failed (see hook trace for detail). Asking the question directly."
```

- [ ] **Step 2: Commit**

```bash
git add SKILL.md
git commit -s -S -m "docs(panel): SKILL.md handles SOFT-DISSENT and HARD-DISSENT

Phase 4 surfaces both as user-asked questions with severity-marked
markers. Phase 5 will replace the HARD-DISSENT path with auto
re-brainstorm; the surfaced-to-user behavior in Phase 4 is the cap
behavior."
```

---

### Task 6: Phase 4 end-to-end verification

- [ ] **Step 1: Full pytest**

`cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v` → all pass.

- [ ] **Step 2: Trigger a live panel call and verify the trace log**

Trigger an `AskUserQuestion` with `(Recommended)`. Check `tail -1 ~/.claude/debug/panel-trace.log` — outcome should be one of `HOLD | SOFT-DISSENT | HARD-DISSENT | ERROR` (the v2 four-bucket vocabulary, not the v1 `HOLD | DISSENT | ERROR`).

- [ ] **Step 3: Phase 4 sign-off**

When pytest passes and a live call shows a Phase-4-shaped outcome, Phase 4 is done.

---

## Self-review

**Spec coverage**: Phase 4 maps to Tasks 1-6. Severity module (1-2), aggregator integration (3), CLI surface (4), SKILL.md handling (5), verification (6).

**Placeholder scan**: No TBD/TODO. All code blocks compile and run. Test fixture content is concrete strings.

**Type consistency**: `decide()` signature in Task 2 matches calls in Task 3. `Verdict` dataclass (from Phase 2) reused. `Config` and nested dataclasses (from Phase 3) reused. The `escalate_to_user` flag set in Task 2 is read by Phase 5 (not Phase 4) — Phase 4 currently ignores it because the cap-handling logic lives in Phase 5.

**Spec coverage gap intentionally deferred**: the actual re-brainstorm directive (`re_brainstorm.feedback_for_claude` payload, cycle accounting via state file, markdown directive emission) is Phase 5. Phase 4 sets the stage by producing the correct verdict bucket; Phase 5 makes HARD-DISSENT do something different from SOFT.
