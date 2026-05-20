"""Secret redaction.

Patterns redact URL-embedded credentials, --token/--password/--api-key style
flag values, and Authorization headers (Bearer or plain). Mirrors the
canonical shell pattern set in ~/.claude/hooks/bash-audit-log.sh — keep
them aligned across both locations.
"""
from __future__ import annotations
import re


_PATTERNS: list[tuple[re.Pattern, str]] = [
    # URL-embedded credentials: scheme://user:pass@host → scheme://<redacted>@host
    (re.compile(r"(\w+://)[^/]*:[^@/]*@"), r"\1<redacted>@"),
    # URL-embedded user (no password): scheme://user@host → scheme://<redacted>@host
    (re.compile(r"(\w+://)[^/@:]+@"), r"\1<redacted>@"),
    # --token=X, --password=X, --api-key=X, --api_key=X, --secret=X (or space-separated)
    (re.compile(r"(--?(?:token|password|api[-_]?key|secret)[= ])(\S+)", re.IGNORECASE),
     r"\1<redacted>"),
    # Authorization: [Bearer ]X — single pattern, Bearer prefix optional, prevents
    # the over-redaction that arises from running two separate Auth patterns in
    # sequence (the second would re-match "Bearer" itself after the first redacts).
    (re.compile(r"(Authorization:\s*(?:Bearer\s+)?)(\S+)", re.IGNORECASE),
     r"\1<redacted>"),
]


def sanitize(text: str) -> str:
    """Return text with credential-shaped substrings replaced by <redacted>.

    Idempotent: sanitize(sanitize(x)) == sanitize(x).
    Multiline-safe.
    """
    for pattern, replacement in _PATTERNS:
        text = pattern.sub(replacement, text)
    return text
