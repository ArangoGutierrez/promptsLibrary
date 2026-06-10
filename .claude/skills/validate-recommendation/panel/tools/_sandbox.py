"""Security boundary for panel tools (v4 spec CC-3). Pure, no NAT.

Every filesystem access by a tool routes through a Sandbox: read-only,
confined to allowed roots, secret-deny-listed, traversal/symlink-proof via
realpath, size/result-capped. Failures are returned as 'ERROR: ...' strings,
never raised (a raised exception would derail the ReAct loop).
"""
from __future__ import annotations
import os
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path

DENY_NAME_GLOBS = (
    ".env", "*.env", ".env.*", "*secret*", "*credential*", "*token*",
    "*.pem", "*.key", "*id_rsa*", "*password*",
)
DENY_DIRS = (".ssh", ".aws")
DENY_PATH_SUFFIXES = (".kube/config",)

DEFAULT_MAX_BYTES = 262_144
DEFAULT_MAX_MATCHES = 200


@dataclass(frozen=True)
class Sandbox:
    roots: tuple[Path, ...]
    max_bytes: int = DEFAULT_MAX_BYTES
    max_matches: int = DEFAULT_MAX_MATCHES

    @staticmethod
    def from_roots(paths: list) -> "Sandbox":
        resolved = tuple(Path(os.path.realpath(Path(p).expanduser())) for p in paths)
        return Sandbox(roots=resolved)

    def _within_roots(self, real: Path) -> bool:
        return any(real == r or r in real.parents for r in self.roots)

    def is_denied(self, p: Path) -> bool:
        if any(fnmatch(p.name, g) for g in DENY_NAME_GLOBS):
            return True
        if set(p.parts) & set(DENY_DIRS):
            return True
        s = str(p)
        return any(s.endswith(suf) for suf in DENY_PATH_SUFFIXES)

    def resolve(self, path: str) -> Path | None:
        """Realpath-resolve; return Path iff within a root and not denied, else None."""
        cand = Path(path).expanduser()
        base = self.roots[0] if self.roots else Path.cwd()
        raw = cand if cand.is_absolute() else (base / cand)
        real = Path(os.path.realpath(raw))
        if not self._within_roots(real) or self.is_denied(real):
            return None
        return real

    def read_text(self, path: str) -> str:
        real = self.resolve(path)
        if real is None:
            return "ERROR: path outside allowed roots or denied"
        if not real.is_file():
            return f"ERROR: not a readable file: {path}"
        try:
            size = real.stat().st_size
        except OSError as e:
            return f"ERROR: stat failed: {e}"
        if size > self.max_bytes:
            return f"ERROR: file exceeds size cap ({size} > {self.max_bytes} bytes)"
        data = real.read_bytes()
        if b"\x00" in data:
            return "ERROR: binary file (NUL byte); refusing to read"
        return data.decode("utf-8", errors="replace")
