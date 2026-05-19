"""Nemotron classifier via nvidia-nat LLM client.

KNOWN: The exact NAT API surface evolves fast. The import path and class
name below (`NIMClient`) is a placeholder; verify at deploy time against
the installed nvidia-nat version and update.

The seam for testing is `self._client.chat(messages=...)`. As long as that
interface stays stable, the classifier's behavior is mockable. If NAT's
API changes, only this file (and its tests) need updating.
"""
from __future__ import annotations
import json
import re
import urllib.error

from .verdict import Verdict, Decision, Category, Lane


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
        # VERIFY at deploy time — exact import path depends on nvidia-nat version
        from aiq.llm import NIMClient  # type: ignore
        self._client = NIMClient(endpoint=endpoint, api_key=api_key, model=model)
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
