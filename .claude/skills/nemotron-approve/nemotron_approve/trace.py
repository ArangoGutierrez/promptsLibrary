"""Telemetry log writer.

One line per hook invocation. Format chosen for grep-ability:
[ISO8601] session=X tool=Y lane=Z decision=W category=V rationale="..."
latency_ms=N input_hash=H cache_hit=true|false
"""
from __future__ import annotations
import datetime
from pathlib import Path

from .verdict import Verdict


class TraceLog:
    def __init__(self, path: Path):
        self._path = path

    def write(self, *, tool_name: str, verdict: Verdict, latency_ms: int,
              input_hash: str, cache_hit: bool, session: str = "default") -> None:
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        safe_rationale = verdict.rationale.replace('"', '\\"').replace("\n", " ")
        line = (
            f"[{ts}] session={session} tool={tool_name} "
            f"lane={verdict.lane.value} decision={verdict.decision.value} "
            f"category={verdict.category.value} rationale=\"{safe_rationale}\" "
            f"latency_ms={latency_ms} input_hash={input_hash} "
            f"cache_hit={'true' if cache_hit else 'false'}\n"
        )
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            with open(self._path, "a") as f:
                f.write(line)
        except OSError:
            # Telemetry must never crash the hook
            pass
