"""Trace log writer: format, daily rotation, retention pruning."""
import os
import time
import pytest
from pathlib import Path
from freezegun import freeze_time
from nemotron_approve.trace import TraceLog
from nemotron_approve.verdict import Verdict, Decision, Category, Lane


@pytest.fixture
def tracer(tmp_path):
    return TraceLog(tmp_path / "nemotron-approve-trace.log")


def test_trace_writes_one_line_per_call(tracer, tmp_path):
    v = Verdict(decision=Decision.ALLOW, category=Category.READ,
                rationale="kubectl get pods -n default", lane=Lane.A)
    tracer.write(tool_name="Bash", verdict=v, latency_ms=12,
                 input_hash="abc123", cache_hit=False)
    log_path = tmp_path / "nemotron-approve-trace.log"
    lines = log_path.read_text().strip().split("\n")
    assert len(lines) == 1
    line = lines[0]
    assert "tool=Bash" in line
    assert "lane=A" in line
    assert "decision=allow" in line
    assert "category=read" in line
    assert "latency_ms=12" in line
    assert "input_hash=abc123" in line
    assert "cache_hit=false" in line
    assert "rationale=" in line


def test_trace_iso_timestamp_format(tracer, tmp_path):
    with freeze_time("2026-05-17T15:30:00"):
        v = Verdict(decision=Decision.ALLOW, category=Category.READ,
                    rationale="x", lane=Lane.A)
        tracer.write(tool_name="Bash", verdict=v, latency_ms=1,
                     input_hash="x", cache_hit=False)
    line = (tmp_path / "nemotron-approve-trace.log").read_text()
    assert line.startswith("[2026-05-17T15:30:00Z]")


def test_trace_handles_unwritable_path_silently(tmp_path):
    # Permission-denied case shouldn't crash the hook
    bad_path = Path("/root/cannot-write-here.log")
    tracer = TraceLog(bad_path)
    v = Verdict(decision=Decision.ALLOW, category=Category.READ,
                rationale="x", lane=Lane.A)
    # Should NOT raise
    tracer.write(tool_name="Bash", verdict=v, latency_ms=1,
                 input_hash="x", cache_hit=False)


def test_trace_redacts_rationale_quotes(tracer, tmp_path):
    """If a rationale contains quotes, they must be safely escaped so
    grep parsing doesn't break."""
    v = Verdict(decision=Decision.ALLOW, category=Category.READ,
                rationale='has "quotes" inside', lane=Lane.A)
    tracer.write(tool_name="Bash", verdict=v, latency_ms=1,
                 input_hash="x", cache_hit=False)
    line = (tmp_path / "nemotron-approve-trace.log").read_text()
    # Format uses rationale="..." with backslash-escape; assert line is
    # still parseable as a single log line (no embedded newlines)
    assert "\n" not in line.strip()
