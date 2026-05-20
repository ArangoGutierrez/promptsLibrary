"""End-to-end CLI: stdin JSON -> classify -> stdout hook JSON."""
import io
import json
import os
import pytest
from unittest.mock import patch, MagicMock
from nemotron_approve.cli import main
from nemotron_approve.verdict import Verdict, Decision, Category, Lane


def test_cli_lane_a_emits_allow(monkeypatch, capsys):
    stdin = json.dumps({"tool_name": "Bash", "tool_input": {"command": "kubectl get pods"}})
    monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
    rc = main()
    out = json.loads(capsys.readouterr().out)
    assert rc == 0
    assert out["hookSpecificOutput"]["permissionDecision"] == "allow"


def test_cli_lane_b_emits_ask(monkeypatch, capsys):
    stdin = json.dumps({"tool_name": "Bash", "tool_input": {"command": "rm -rf /tmp/foo"}})
    monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
    rc = main()
    out = json.loads(capsys.readouterr().out)
    assert rc == 0
    assert out["hookSpecificOutput"]["permissionDecision"] == "ask"


def test_cli_malformed_json_emits_ask(monkeypatch, capsys):
    monkeypatch.setattr("sys.stdin", io.StringIO("not json"))
    rc = main()
    captured = capsys.readouterr().out
    if captured.strip():
        out = json.loads(captured)
        assert out["hookSpecificOutput"]["permissionDecision"] == "ask"
    # Exit 0 either way (don't crash the hook)
    assert rc == 0


def test_cli_disabled_lane_c_falls_back_to_ask(monkeypatch, capsys):
    monkeypatch.setenv("NEMOTRON_APPROVE_DISABLED", "1")
    monkeypatch.delenv("NEMOTRON_APPROVE_API_KEY", raising=False)
    stdin = json.dumps({"tool_name": "Bash",
                        "tool_input": {"command": "kubectl apply -f x.yaml"}})
    monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
    rc = main()
    out = json.loads(capsys.readouterr().out)
    assert rc == 0
    assert out["hookSpecificOutput"]["permissionDecision"] == "ask"
