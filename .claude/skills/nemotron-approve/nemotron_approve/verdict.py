"""Verdict dataclass and enums for the nemotron-approve classifier.

The Verdict is the unit of output: every lane (A, B, C, cache) produces one,
and the CLI serializes it into the Claude Code hook output JSON shape.
"""
from __future__ import annotations
import enum
from dataclasses import dataclass


class Decision(str, enum.Enum):
    ALLOW = "allow"
    ASK = "ask"


class Category(str, enum.Enum):
    READ = "read"
    LOCAL_WRITE = "local_write"
    MUTATING = "mutating"
    DESTRUCTIVE = "destructive"
    UNKNOWN = "unknown"


class Lane(str, enum.Enum):
    A = "A"
    B = "B"
    C = "C"
    CACHE = "cache"


@dataclass
class Verdict:
    decision: Decision
    category: Category
    rationale: str
    lane: Lane

    def to_hook_output(self) -> dict:
        """Format as Claude Code PreToolUse hookSpecificOutput JSON shape."""
        return {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": self.decision.value,
                "permissionDecisionReason": f"nemotron: {self.lane.value}:{self.category.value}:{self.rationale}",
            }
        }
