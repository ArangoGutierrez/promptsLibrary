"""Three-lane orchestration.

Flow:
  1. Extract the command string from tool_input (shape depends on tool_name).
  2. Lane A regex on the command — match -> ALLOW.
  3. Lane B regex on the command — match -> ASK.
  4. Cache lookup — hit -> return cached verdict (lane is CACHE).
  5. Lane C LLM (if configured) -> ALLOW or ASK.
  6. If Lane C returns ALLOW, re-apply Lane B against the original command —
     match -> override to ASK. This is the prompt-injection defense.
  7. Cache the resulting verdict (allow or ask).
"""
from __future__ import annotations
import json
from typing import Optional

from .patterns import lane_a_match, lane_b_match
from .verdict import Verdict, Decision, Category, Lane


def _input_to_command(tool_name: str, tool_input: dict) -> str:
    """Extract the command-shaped string from tool_input for regex matching."""
    if tool_name == "Bash":
        return tool_input.get("command", "")
    if tool_name == "WebFetch":
        return tool_input.get("url", "")
    if tool_name.startswith("mcp__"):
        return tool_name  # MCP regex matches the tool name itself
    return json.dumps(tool_input, sort_keys=True)


class Classifier:
    def __init__(self, llm_client, cache):
        self._llm = llm_client
        self._cache = cache

    def classify(self, tool_name: str, tool_input: dict, context: dict) -> Verdict:
        command = _input_to_command(tool_name, tool_input)

        if name := lane_a_match(command):
            return Verdict(Decision.ALLOW, Category.READ, name, Lane.A)

        if name := lane_b_match(command):
            return Verdict(Decision.ASK, Category.DESTRUCTIVE, name, Lane.B)

        cached = self._cache.get(tool_name, tool_input)
        if cached is not None:
            return cached

        verdict = self._lane_c_with_recheck(tool_name, tool_input, context)
        self._cache.put(tool_name, tool_input, verdict)
        return verdict

    def _lane_c_with_recheck(self, tool_name: str, tool_input: dict,
                              context: dict) -> Verdict:
        if self._llm is None:
            return Verdict(Decision.ASK, Category.UNKNOWN, "llm_unconfigured", Lane.C)

        verdict = self._llm.classify(tool_name, tool_input, context)

        if verdict.decision == Decision.ALLOW:
            # Defense-in-depth: even if the LLM was fooled, a DENY regex match
            # against the original command body overrides the allow.
            command = _input_to_command(tool_name, tool_input)
            if name := lane_b_match(command):
                return Verdict(Decision.ASK, Category.DESTRUCTIVE,
                               f"recheck_override:{name}", Lane.B)

        return verdict
