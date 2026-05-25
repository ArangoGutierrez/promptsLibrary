"""done/eval.py — NAT-backed goal evidence evaluator.

Mirrors the validate-recommendation v3 panel/dispatch.py pattern:
one mockable _invoke_nat seam + ERROR-fallback wrapping.
"""
from __future__ import annotations

import json
import pathlib
import sys
from typing import Any, Literal

Verdict = Literal["AGREE", "DISAGREE", "INSUFFICIENT_EVIDENCE", "ERROR"]

PERSONA_PATH = pathlib.Path(__file__).parent / "personas" / "goal-evaluator.md"


def _invoke_nat(prompt: str, model: str, max_tokens: int = 32768) -> str:
    """Single mockable seam. Raises on any failure — caller wraps in ERROR-fallback.

    Uses langchain_nvidia_ai_endpoints.ChatNVIDIA directly (mirrors
    panel/dispatch.py). NAT's WorkflowBuilder primitives are NOT used —
    they require async + adapter registration that's overkill for a
    single mockable seam.
    """
    import os
    from langchain_nvidia_ai_endpoints import ChatNVIDIA  # type: ignore[import-not-found]
    kwargs: dict = {
        "model": model,
        "temperature": 0.1,
        "max_completion_tokens": max_tokens,
    }
    api_key = os.environ.get("DONE_NAT_API_KEY") or os.environ.get("NVIDIA_API_KEY") or os.environ.get("PANEL_DA_API_KEY")
    if api_key:
        kwargs["nvidia_api_key"] = api_key
    base_url = os.environ.get("DONE_NAT_ENDPOINT")
    if base_url:
        # Normalize: strip /chat/completions suffix if present (ChatNVIDIA appends it).
        suffix = "/chat/completions"
        if base_url.endswith(suffix):
            base_url = base_url[: -len(suffix)]
        kwargs["base_url"] = base_url
    llm = ChatNVIDIA(**kwargs)
    messages = [{"role": "user", "content": prompt}]
    response = llm.invoke(messages)
    # langchain AIMessage has .content; could be str or list[dict].
    content = getattr(response, "content", None)
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        # Flatten list-of-dicts to text
        parts = []
        for item in content:
            if isinstance(item, dict) and "text" in item:
                parts.append(item["text"])
            else:
                parts.append(str(item))
        return "".join(parts)
    return str(content) if content is not None else ""


def _parse_verdict(raw: str) -> dict[str, Any]:
    """Parse the strict 'VERDICT: ... / RATIONALE: ... / GAPS: ...' format."""
    lines = raw.strip().splitlines()
    out: dict[str, Any] = {"verdict": "ERROR", "rationale": "", "gaps": []}
    for line in lines:
        if line.startswith("VERDICT:"):
            v = line.split(":", 1)[1].strip()
            if v in ("AGREE", "DISAGREE", "INSUFFICIENT_EVIDENCE"):
                out["verdict"] = v
        elif line.startswith("RATIONALE:"):
            out["rationale"] = line.split(":", 1)[1].strip()
        elif line.startswith("GAPS:"):
            g = line.split(":", 1)[1].strip()
            out["gaps"] = [] if g == "n/a" else [x.strip() for x in g.split(",")]
    return out


def evaluate(
    goal_stanza: str,
    evidence: list[dict[str, Any]],
    user_claim: str,
    model: str = "nvidia/nemotron-3-super-v3",
) -> dict[str, Any]:
    """Evaluate evidence against goal; return {verdict, rationale, gaps}.

    On any internal failure (NAT unavailable, parse error, model error),
    returns {verdict: "ERROR", rationale: "<reason>", gaps: []}. The caller
    falls through to user_only.
    """
    try:
        persona = PERSONA_PATH.read_text()
    except OSError as exc:
        return {"verdict": "ERROR", "rationale": f"persona load failed: {exc}", "gaps": []}

    prompt = (
        f"{persona}\n\n"
        f"## Goal stanza\n{goal_stanza}\n\n"
        f"## Evidence collected\n{json.dumps(evidence, indent=2)}\n\n"
        f"## User claims\n{user_claim}\n"
    )
    try:
        raw = _invoke_nat(prompt, model=model)
        result = _parse_verdict(raw)
        if result["verdict"] == "ERROR":
            result["rationale"] = "parse failed: no VERDICT line"
        return result
    except Exception as exc:  # noqa: BLE001 — ERROR fallback per spec
        return {"verdict": "ERROR", "rationale": f"NAT dispatch failed: {exc}", "gaps": []}


def main(argv: list[str]) -> int:
    """CLI entry. Reads JSON from stdin, prints JSON to stdout."""
    payload = json.load(sys.stdin)
    result = evaluate(
        goal_stanza=payload["goal_stanza"],
        evidence=payload["evidence"],
        user_claim=payload.get("user_claim", "MET"),
        model=payload.get("model", "nvidia/nemotron-3-super-v3"),
    )
    json.dump(result, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
