"""File-backed verdict cache.

Only Lane C (LLM-classified) verdicts are cached. Lane A/B are <10ms regex —
caching them would add complexity for no win. The cache key is sha256 of
(tool_name + canonical_json(tool_input)).
"""
from __future__ import annotations
import hashlib
import json
import time
from pathlib import Path
from typing import Optional

from .verdict import Verdict, Decision, Category, Lane


class VerdictCache:
    def __init__(self, path: Path, ttl_seconds: int):
        self._path = path
        self._ttl = ttl_seconds

    def _key(self, tool_name: str, tool_input: dict) -> str:
        canonical = json.dumps(tool_input, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(f"{tool_name}:{canonical}".encode()).hexdigest()

    def _load(self) -> dict:
        if not self._path.exists():
            return {}
        try:
            return json.loads(self._path.read_text())
        except (json.JSONDecodeError, OSError):
            return {}

    def _save(self, data: dict) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(json.dumps(data))

    def get(self, tool_name: str, tool_input: dict) -> Optional[Verdict]:
        data = self._load()
        entry = data.get(self._key(tool_name, tool_input))
        if entry is None:
            return None
        if entry["expires_at"] < time.time():
            return None
        return Verdict(
            decision=Decision(entry["decision"]),
            category=Category(entry["category"]),
            rationale=entry["rationale"],
            lane=Lane.CACHE,
        )

    def put(self, tool_name: str, tool_input: dict, verdict: Verdict) -> None:
        data = self._load()
        data[self._key(tool_name, tool_input)] = {
            "decision": verdict.decision.value,
            "category": verdict.category.value,
            "rationale": verdict.rationale,
            "expires_at": time.time() + self._ttl,
        }
        self._save(data)
