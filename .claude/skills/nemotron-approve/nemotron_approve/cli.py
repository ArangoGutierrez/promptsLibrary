"""CLI entry point. Reads stdin JSON, classifies, writes stdout JSON.

ALWAYS exits 0 — Claude Code falls through to its normal permission flow
if stdout is empty or malformed. The hook never breaks the user.
"""
from __future__ import annotations
import datetime
import hashlib
import json
import os
import sys
import time
from pathlib import Path

from .config import load_config
from .classifier import Classifier
from .cache import VerdictCache
from .trace import TraceLog
from .verdict import Verdict, Decision, Category, Lane


def _session_marker() -> str:
    """Stable-ish session marker since CLAUDE_SESSION_ID is not passed to hooks.
    Uses (parent pid + date) — same shell parent within a day = same marker."""
    return f"{os.getppid()}_{datetime.date.today().isoformat()}"


def _input_hash(tool_name: str, tool_input: dict) -> str:
    canonical = json.dumps(tool_input, sort_keys=True)
    return hashlib.sha256(f"{tool_name}:{canonical}".encode()).hexdigest()[:6]


def _emit_ask(reason: str) -> None:
    v = Verdict(Decision.ASK, Category.UNKNOWN, reason, Lane.C)
    print(json.dumps(v.to_hook_output()))


def _maybe_enrich_kubectl_context(tool_name: str, tool_input: dict, context: dict) -> None:
    """Single side-channel context probe: kubectl current-context.

    Only when tool=Bash and command starts with `kubectl`. 500 ms timeout.
    Any failure (kubectl missing, KUBECONFIG misconfigured, timeout) is
    swallowed — the field is simply omitted from context.
    """
    if tool_name != "Bash":
        return
    if not tool_input.get("command", "").startswith("kubectl"):
        return
    import subprocess
    try:
        result = subprocess.run(
            ["kubectl", "config", "current-context"],
            capture_output=True, text=True, timeout=0.5,
        )
        if result.returncode == 0 and result.stdout.strip():
            context["k8s_current_context"] = result.stdout.strip()
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        pass


def main() -> int:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, OSError):
        _emit_ask("malformed_stdin")
        return 0

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {})
    context = {"cwd": payload.get("cwd", "")}
    _maybe_enrich_kubectl_context(tool_name, tool_input, context)

    cfg = load_config()

    llm = None
    if cfg.is_complete:
        try:
            from .llm_client import NemotronClassifier
            llm = NemotronClassifier(
                endpoint=cfg.endpoint,
                api_key=cfg.api_key,
                model=cfg.model,
                timeout=cfg.timeout_seconds,
                max_tokens=cfg.max_tokens,
            )
        except Exception:
            # nvidia-nat not importable or constructor failed: degrade to Lane A/B
            llm = None

    cache_path = (
        Path(os.environ.get("TMPDIR", "/tmp"))
        / "nemotron-approve-cache"
        / f"{_session_marker()}.json"
    )
    cache = VerdictCache(cache_path, ttl_seconds=cfg.cache_ttl)

    clf = Classifier(llm_client=llm, cache=cache)

    start = time.perf_counter()
    verdict = clf.classify(tool_name, tool_input, context)
    latency_ms = int((time.perf_counter() - start) * 1000)

    if cfg.trace_enabled:
        tracer = TraceLog(Path.home() / ".claude" / "debug" / "nemotron-approve-trace.log")
        tracer.write(
            tool_name=tool_name,
            verdict=verdict,
            latency_ms=latency_ms,
            input_hash=_input_hash(tool_name, tool_input),
            cache_hit=(verdict.lane == Lane.CACHE),
            session=_session_marker(),
        )

    print(json.dumps(verdict.to_hook_output()))
    return 0
