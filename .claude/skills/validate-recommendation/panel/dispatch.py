"""langchain-provider-backed panelist dispatch.

Called per nat-* panelist via `python -m panel dispatch --panelist <id>
--config <path> --persona <path> --prompt-file <path> --output <path>`.

Contract:
- Returns 0 if a verdict file was written (success path OR ERROR path).
- Returns 1 only when caller-supplied paths/ids are invalid.
- All runtime failures (network, timeout, parse error, unsupported
  backend, OVERTURN + ALTERNATIVE:n/a) become VERDICT: ERROR verdict files.
- Verdict files are written with mode 0600 (umask 077).

The single mockable seam is `_invoke_nat(panelist, system, user)`. Tests
mock it entirely. Below it lies langchain (ChatNVIDIA / ChatAnthropic /
ChatOpenAI) and below langchain, real HTTP. Tests never mock requests/
httpx/nat.*/langchain.* directly (decoupled from upstream version bumps).
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

from panel.config import load_config, ConfigError, Panelist
from panel.personas import load_persona, PersonaError
from panel.verdict import parse_verdict


def _invoke_nat(panelist: Panelist, system: str, user: str) -> object:
    """The single mockable seam — tests mock this function entirely.

    Dispatch uses langchain provider classes directly. NAT's WorkflowBuilder
    primitives are NOT used here: they require async + framework-adapter
    registration + a deeper transitive-dep tree than per-panelist seam
    justifies. NAT lives in later phases (Phase 6 observability, Phase 7
    evaluation) where its design fits.
    """
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]
    if panelist.backend == "nat-nim":
        from langchain_nvidia_ai_endpoints import ChatNVIDIA
        api_key = os.environ.get("PANEL_DA_API_KEY") or os.environ.get("NVIDIA_API_KEY")
        kwargs = {
            "model": panelist.model,
            "temperature": panelist.temperature,
            "max_completion_tokens": panelist.max_tokens,
        }
        if api_key:
            kwargs["nvidia_api_key"] = api_key
        base_url = os.environ.get("CLAUDE_PANEL_DA_ENDPOINT")
        if base_url:
            # CLAUDE_PANEL_DA_ENDPOINT historically holds the full chat-completions
            # URL the v1 shell client POSTed to. ChatNVIDIA wants the v1 base
            # (no /chat/completions suffix) and appends the path itself.
            kwargs["base_url"] = _strip_chat_completions(base_url)
        llm = ChatNVIDIA(**kwargs)
    elif panelist.backend == "nat-anthropic":
        from langchain_anthropic import ChatAnthropic
        llm = ChatAnthropic(
            model=panelist.model,
            temperature=panelist.temperature,
            max_tokens=panelist.max_tokens,
        )
    elif panelist.backend == "nat-openai":
        from langchain_openai import ChatOpenAI
        llm = ChatOpenAI(
            model=panelist.model,
            temperature=panelist.temperature,
            max_completion_tokens=panelist.max_tokens,
        )
    else:
        raise ValueError(f"unsupported NAT backend: {panelist.backend}")
    return llm.invoke(messages)


def dispatch(
    panelist_id: str,
    config_path: str | Path,
    persona_path: str | Path,
    prompt_file: str | Path,
    output: str | Path,
) -> int:
    """Run one panelist via its langchain backend and write a verdict file.

    Returns:
        0 — verdict file written (HOLD/OVERTURN/ERROR — any structured outcome)
        1 — caller-supplied path/id invalid (no verdict written)
    """
    output_path = Path(output).expanduser()

    try:
        cfg = load_config(config_path)
    except ConfigError as e:
        print(f"dispatch: config error: {e}", file=sys.stderr)
        return 1

    panelist = next((p for p in cfg.panelists if p.id == panelist_id), None)
    if panelist is None:
        print(f"dispatch: panelist id '{panelist_id}' not found in config",
              file=sys.stderr)
        return 1

    try:
        persona = load_persona(persona_path)
    except PersonaError as e:
        print(f"dispatch: persona error: {e}", file=sys.stderr)
        return 1

    prompt_path = Path(prompt_file).expanduser()
    if not prompt_path.is_file():
        print(f"dispatch: prompt file missing: {prompt_path}", file=sys.stderr)
        return 1
    user_prompt = prompt_path.read_text(encoding="utf-8")

    system = persona.system_prompt
    if persona.one_shot_example:
        system = system + "\n\n" + persona.one_shot_example

    try:
        response = _invoke_nat(panelist, system, user_prompt)
        text = _extract_content(response)
        parsed = parse_verdict(text)
        if not parsed.verdict:
            _write_verdict_file(output_path, _format_verdict(
                "ERROR",
                "panelist response missing VERDICT field",
                "n/a",
            ))
            return 0
        if parsed.verdict == "OVERTURN" and parsed.alternative.strip().lower() in ("n/a", ""):
            _write_verdict_file(output_path, _format_verdict(
                "ERROR",
                "panelist returned OVERTURN without a concrete ALTERNATIVE",
                "n/a",
            ))
            return 0
        _write_verdict_file(output_path, _format_verdict(
            parsed.verdict, parsed.rationale, parsed.alternative,
        ))
        return 0
    except Exception as e:
        msg = " ".join(str(e).split())[:200]
        _write_verdict_file(output_path, _format_verdict(
            "ERROR", f"panelist invocation failed: {msg}", "n/a",
        ))
        return 0


def _extract_content(response: object) -> str:
    """Pull text content out of langchain AIMessage / dict / str variants."""
    if hasattr(response, "content"):
        c = response.content
        return c if isinstance(c, str) else str(c)
    if isinstance(response, dict) and "content" in response:
        return str(response["content"])
    if isinstance(response, str):
        return response
    return str(response)


def _format_verdict(verdict: str, rationale: str, alternative: str) -> str:
    rationale_one_line = " ".join(rationale.split())
    alt_one_line = " ".join(alternative.split()) if alternative else "n/a"
    return (
        f"VERDICT: {verdict}\n"
        f"RATIONALE: {rationale_one_line}\n"
        f"ALTERNATIVE: {alt_one_line}\n"
    )


def _write_verdict_file(path: Path, content: str) -> None:
    """Write verdict file with mode 0600 (umask 077)."""
    old_umask = os.umask(0o077)
    try:
        path.write_text(content, encoding="utf-8")
    finally:
        os.umask(old_umask)


def _strip_chat_completions(url: str) -> str:
    """Normalize the historical $CLAUDE_PANEL_DA_ENDPOINT format into a
    ChatNVIDIA-compatible base_url.

    The v1 dispatch-da.sh used the full chat-completions URL
    (https://host/v1/chat/completions). ChatNVIDIA wants the v1 base
    (https://host/v1) and appends /chat/completions itself. This helper
    strips the suffix if present; otherwise returns the URL unchanged.
    """
    suffix = "/chat/completions"
    if url.endswith(suffix):
        return url[: -len(suffix)]
    return url
