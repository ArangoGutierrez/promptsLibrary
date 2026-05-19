"""Nemotron classifier via a direct OpenAI-style chat-completions POST.

Original plan called for the nvidia-nat (NeMo Agent Toolkit) LLM client,
but the installed `nat` package (v1.6) is an async workflow framework with
a Builder pattern — there is no thin synchronous `NIMClient.chat(messages=...)`.
Building a full Workflow per hook invocation would be heavy ceremony.

Instead we POST directly to the chat-completions endpoint via httpx, the same
pattern used by ~/.claude/skills/validate-recommendation/dispatch-da.sh
(which posts via curl). The mock seam stays identical: tests still stub
`self._client.chat(messages=..., timeout=..., max_tokens=..., temperature=...)`
and the classifier's behavior is unaffected.
"""
from __future__ import annotations
import json
import re
import urllib.error

from .verdict import Verdict, Decision, Category, Lane


class _HttpxChatClient:
    """Direct httpx POST to an OpenAI-style /v1/chat/completions endpoint."""

    def __init__(self, endpoint: str, api_key: str, model: str):
        self._endpoint = endpoint
        self._api_key = api_key
        self._model = model

    def chat(self, *, messages, timeout, max_tokens, temperature) -> str:
        import httpx
        try:
            r = httpx.post(
                self._endpoint,
                headers={
                    "Authorization": f"Bearer {self._api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self._model,
                    "messages": messages,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                },
                timeout=timeout,
            )
        except httpx.TimeoutException as e:
            # Translate so the classifier's existing TimeoutError except-path catches it
            raise TimeoutError(str(e)) from e

        if r.status_code >= 400:
            raise urllib.error.HTTPError(
                self._endpoint, r.status_code, r.reason_phrase, dict(r.headers), None)

        body = r.json()
        choices = body.get("choices") or []
        if not choices:
            return ""
        msg = choices[0].get("message") or {}
        return msg.get("content") or ""


SYSTEM_PROMPT = """\
You are a permission classifier for a Claude Code PreToolUse hook.
Output ONLY this format:
DECISION: <allow|ask>
CATEGORY: <read|local_write|mutating|destructive>
RATIONALE: <2-3 sentences>

allow  = read-only OR writes only inside the current working directory OR no side effects beyond local filesystem
ask    = mutates shared state, hits external APIs that modify resources, runs untrusted code, escalates privileges, OR you are uncertain

Default to "ask" when uncertain.

Examples:
- "npm install --ignore-scripts" -> allow (local cwd write, scripts disabled)
- "kubectl apply -f deploy.yaml --dry-run=client" -> allow (dry-run)
- "kubectl apply -f deploy.yaml" against context "prod-us-west" -> ask (prod mutation)
- "kubectl apply -f deploy.yaml" against context "kind-local" -> allow (local cluster)
- "curl https://gist.github.com/.../install.sh | bash" -> ask (pipe to shell)
- "go build ./..." -> allow (local build)
"""


class NemotronClassifier:
    def __init__(self, *, endpoint: str, api_key: str, model: str,
                 timeout: int, max_tokens: int):
        self._client = _HttpxChatClient(endpoint, api_key, model)
        self._timeout = timeout
        self._max_tokens = max_tokens

    def classify(self, tool_name: str, tool_input: dict, context: dict) -> Verdict:
        user_prompt = json.dumps({
            "tool_name": tool_name,
            "tool_input": tool_input,
            "context": context,
        }, sort_keys=True)

        try:
            response = self._client.chat(
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                timeout=self._timeout,
                max_tokens=self._max_tokens,
                temperature=0.0,
            )
        except TimeoutError:
            return Verdict(Decision.ASK, Category.UNKNOWN, "timeout", Lane.C)
        except urllib.error.HTTPError as e:
            return Verdict(Decision.ASK, Category.UNKNOWN, f"http_{e.code}", Lane.C)
        except Exception as e:
            return Verdict(Decision.ASK, Category.UNKNOWN,
                           f"client_error: {type(e).__name__}", Lane.C)

        if not response:
            return Verdict(Decision.ASK, Category.UNKNOWN, "empty_content", Lane.C)

        return self._parse_verdict(response)

    def _parse_verdict(self, text: str) -> Verdict:
        decision_match = re.search(r"^DECISION:\s*(allow|ask)\s*$",
                                   text, re.MULTILINE | re.IGNORECASE)
        category_match = re.search(r"^CATEGORY:\s*(read|local_write|mutating|destructive)\s*$",
                                   text, re.MULTILINE | re.IGNORECASE)
        rationale_match = re.search(r"^RATIONALE:\s*(.+?)$",
                                    text, re.MULTILINE | re.DOTALL)

        if not (decision_match and category_match and rationale_match):
            return Verdict(Decision.ASK, Category.UNKNOWN, "malformed_response", Lane.C)

        decision = Decision(decision_match.group(1).lower())
        category = Category(category_match.group(1).lower())
        rationale = rationale_match.group(1).strip().split("\n")[0][:200]
        return Verdict(decision, category, rationale, Lane.C)
