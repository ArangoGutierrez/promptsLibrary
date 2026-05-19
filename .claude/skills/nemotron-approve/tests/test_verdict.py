"""Tests for verdict dataclasses and enums."""
import pytest
from nemotron_approve.verdict import Verdict, Decision, Category, Lane


def test_decision_enum_values():
    assert Decision.ALLOW.value == "allow"
    assert Decision.ASK.value == "ask"


def test_category_enum_values():
    assert Category.READ.value == "read"
    assert Category.LOCAL_WRITE.value == "local_write"
    assert Category.MUTATING.value == "mutating"
    assert Category.DESTRUCTIVE.value == "destructive"
    assert Category.UNKNOWN.value == "unknown"


def test_lane_enum_values():
    assert Lane.A.value == "A"
    assert Lane.B.value == "B"
    assert Lane.C.value == "C"
    assert Lane.CACHE.value == "cache"


def test_verdict_construction_minimal():
    v = Verdict(decision=Decision.ALLOW, category=Category.READ, rationale="kubectl get", lane=Lane.A)
    assert v.decision == Decision.ALLOW
    assert v.category == Category.READ
    assert v.rationale == "kubectl get"
    assert v.lane == Lane.A


def test_verdict_to_hook_output_allow():
    v = Verdict(decision=Decision.ALLOW, category=Category.READ, rationale="kubectl get", lane=Lane.A)
    out = v.to_hook_output()
    assert out == {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": "nemotron: A:read:kubectl get",
        }
    }


def test_verdict_to_hook_output_ask():
    v = Verdict(decision=Decision.ASK, category=Category.MUTATING, rationale="prod cluster", lane=Lane.C)
    out = v.to_hook_output()
    assert out["hookSpecificOutput"]["permissionDecision"] == "ask"
    assert "C:mutating:prod cluster" in out["hookSpecificOutput"]["permissionDecisionReason"]
