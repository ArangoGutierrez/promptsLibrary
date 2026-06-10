"""Pure file/search impls over a Sandbox. Each returns a string (data or 'ERROR: ...')."""
from __future__ import annotations
import os
import re
from pathlib import Path
from panel.tools._sandbox import Sandbox


def read_file(sb: Sandbox, path: str) -> str:
    return sb.read_text(path)


def _rel(sb: Sandbox, p: Path) -> str:
    for r in sb.roots:
        try:
            return str(p.relative_to(r))
        except ValueError:
            continue
    return str(p)


def _iter_text_files(sb: Sandbox):
    for root in sb.roots:
        if root.is_file():
            yield root
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
            for fn in filenames:
                p = Path(dirpath) / fn
                if sb.resolve(str(p)) is None:
                    continue
                yield p


def grep_repo(sb: Sandbox, pattern: str, path_glob: str = "**/*") -> str:
    try:
        rx = re.compile(pattern)
    except re.error as e:
        return f"ERROR: invalid regex: {e}"
    hits: list[str] = []
    for p in _iter_text_files(sb):
        if path_glob != "**/*" and not p.match(path_glob):
            continue
        try:
            size = p.stat().st_size
        except OSError:
            continue
        if size > sb.max_bytes:
            continue
        data = p.read_bytes()
        if b"\x00" in data:
            continue
        for i, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
            if rx.search(line):
                hits.append(f"{_rel(sb, p)}:{i}:{line.strip()}")
                if len(hits) >= sb.max_matches:
                    return "\n".join(hits) + f"\n(truncated at {sb.max_matches} matches)"
    return "\n".join(hits) if hits else "(no matches)"


def glob_files(sb: Sandbox, pattern: str) -> str:
    out: list[str] = []
    for root in sb.roots:
        if root.is_file():
            continue
        for p in sorted(root.glob(pattern)):
            if {".git", "__pycache__"} & set(p.parts):
                continue  # parity with grep_repo: VCS/cache internals are not results
            if p.is_file() and sb.resolve(str(p)) is not None:
                out.append(_rel(sb, p))
                if len(out) >= sb.max_matches:
                    return "\n".join(out) + f"\n(truncated at {sb.max_matches})"
    return "\n".join(out) if out else "(no matches)"


def read_rules(sb: Sandbox, claude_md: Path, rules_dir: Path) -> str:
    sections: list[str] = []
    cm = sb.read_text(str(claude_md))
    if not cm.startswith("ERROR:"):
        sections.append(f"===== {claude_md.name} =====\n{cm}")
    if rules_dir.is_dir():
        for md in sorted(rules_dir.glob("*.md")):
            body = sb.read_text(str(md))
            if not body.startswith("ERROR:"):
                sections.append(f"===== rules/{md.name} =====\n{body}")
    return "\n\n".join(sections) if sections else "ERROR: no rule files readable"
