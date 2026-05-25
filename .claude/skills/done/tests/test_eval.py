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


def test_disagree_path_returns_disagree_with_gaps():
    """When NAT returns DISAGREE, evaluate() yields verdict=DISAGREE + GAPS list."""
    fake_response = (
        "VERDICT: DISAGREE\n"
        "RATIONALE: Spec committed but no evidence for shellcheck run.\n"
        "GAPS: shellcheck clean"
    )
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=False), "MET")
    assert result["verdict"] == "DISAGREE"
    assert "shellcheck clean" in result["gaps"]


def test_insufficient_path_returns_insufficient():
    """When NAT returns INSUFFICIENT_EVIDENCE, evaluate() preserves that label."""
    fake_response = (
        "VERDICT: INSUFFICIENT_EVIDENCE\n"
        "RATIONALE: Bullets are vague; cannot judge.\n"
        "GAPS: n/a"
    )
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), [], "MET")
    assert result["verdict"] == "INSUFFICIENT_EVIDENCE"


def test_error_fallback_when_nat_raises():
    """When _invoke_nat raises any exception, evaluate() returns verdict=ERROR."""
    def boom(*args, **kwargs):
        raise RuntimeError("NIM endpoint unreachable")
    with patch.object(done_eval, "_invoke_nat", side_effect=boom):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
    assert result["verdict"] == "ERROR"
    assert "NIM endpoint unreachable" in result["rationale"]


def test_error_fallback_when_response_lacks_verdict_line():
    """Malformed NAT response (no VERDICT line) → verdict=ERROR with parse-failed reason."""
    fake_response = "I think the goal might be met but I'm not sure."  # no strict format
    with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
        result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
    assert result["verdict"] == "ERROR"
    assert "parse failed" in result["rationale"]


def test_lazy_import_langchain_not_required_when_mocked():
    """If a test mocks _invoke_nat, the langchain package need not be installed.

    Protects against accidental top-level imports of langchain_nvidia_ai_endpoints
    that would make tests fragile or slow.
    """
    fake_response = "VERDICT: AGREE\nRATIONALE: ok\nGAPS: n/a"
    # Save and clear any cached langchain import
    saved = sys.modules.pop("langchain_nvidia_ai_endpoints", None)
    try:
        with patch.object(done_eval, "_invoke_nat", return_value=fake_response):
            result = done_eval.evaluate(_make_goal(), _make_evidence(complete=True), "MET")
        assert result["verdict"] == "AGREE"
        assert "langchain_nvidia_ai_endpoints" not in sys.modules, (
            "evaluate() pulled in langchain even though _invoke_nat was mocked"
        )
    finally:
        if saved is not None:
            sys.modules["langchain_nvidia_ai_endpoints"] = saved
