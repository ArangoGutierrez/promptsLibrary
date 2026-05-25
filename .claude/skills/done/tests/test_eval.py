"""Tests for done/eval.py — mocks _invoke_nat only."""
from __future__ import annotations

import json
from unittest.mock import patch

import pytest

# Add the parent dir to sys.path so `import eval` works.
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
import eval as done_eval  # noqa: E402


def _make_goal() -> str:
    return (
        "## Initial 2026-05-18T10:00:00Z\n"
        "Goal: ship done-hook v1\n"
        "Acceptance:\n"
        "- ./done-hook_test.sh passes\n"
        "- shellcheck clean\n"
        "- spec committed\n"
    )


def _make_evidence(complete: bool) -> list[dict]:
    base = [
        {"cmd": "./done-hook_test.sh", "exit": 0, "ts": "2026-05-18T14:32Z"},
        {"cmd": "shellcheck ~/.claude/hooks/done-hook.sh", "exit": 0, "ts": "2026-05-18T14:33Z"},
    ]
    if complete:
        base.append({"cmd": "git commit", "subject": "docs(specs): add design", "sha": "f3a4b5c", "ts": "2026-05-18T14:15Z"})
    return base


def test_agree_path_returns_met():
    """When NAT returns AGREE, evaluate() yields verdict=AGREE + non-empty rationale."""
    fake_response = (
        "VERDICT: AGREE\n"
        "RATIONALE: All three bullets have supporting evidence.\n"
        "GAPS: n/a"
    )
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
    assert result["verdict"] == "AGREE"
    assert "All three bullets" in result["rationale"]
    assert result["gaps"] == []
