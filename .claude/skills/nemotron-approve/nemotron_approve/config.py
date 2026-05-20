"""Env var loading.

If required vars (API_KEY, ENDPOINT, MODEL) are unset, return a Config with
`is_complete=False`. The classifier treats this the same as `DISABLED=1`:
Lane A/B still run, Lane C falls back to ASK.
"""
from __future__ import annotations
import os
from dataclasses import dataclass


@dataclass
class Config:
    api_key: str
    endpoint: str
    model: str
    timeout_seconds: int
    max_tokens: int
    disabled: bool
    cache_ttl: int
    trace_enabled: bool

    @property
    def is_complete(self) -> bool:
        """True iff required vars are non-empty AND not disabled."""
        return (
            bool(self.api_key)
            and bool(self.endpoint)
            and bool(self.model)
            and not self.disabled
        )


def _truthy(val: str) -> bool:
    return val.lower() in ("1", "true", "yes", "on")


def load_config() -> Config:
    return Config(
        api_key=os.environ.get("NEMOTRON_APPROVE_API_KEY", ""),
        endpoint=os.environ.get("NEMOTRON_APPROVE_ENDPOINT", ""),
        model=os.environ.get("NEMOTRON_APPROVE_MODEL", ""),
        timeout_seconds=int(os.environ.get("NEMOTRON_APPROVE_TIMEOUT", "10")),
        max_tokens=int(os.environ.get("NEMOTRON_APPROVE_MAX_TOKENS", "512")),
        disabled=_truthy(os.environ.get("NEMOTRON_APPROVE_DISABLED", "0")),
        cache_ttl=int(os.environ.get("NEMOTRON_APPROVE_CACHE_TTL", "3600")),
        trace_enabled=_truthy(os.environ.get("NEMOTRON_APPROVE_TRACE", "1")),
    )
