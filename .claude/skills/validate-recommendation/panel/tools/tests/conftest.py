import os
from pathlib import Path
import pytest
from panel.tools._sandbox import Sandbox

@pytest.fixture
def repo_tree(tmp_path: Path):
    """A realistic sandboxed repo: a readable file, a secret, a nested dir, a symlink escape."""
    repo = tmp_path / "repo"
    (repo / "pkg").mkdir(parents=True)
    (repo / "pkg" / "app.py").write_text("def add(a, b):\n    return a + b\n", encoding="utf-8")
    (repo / ".env").write_text("PANEL_DA_API_KEY=topsecret\n", encoding="utf-8")
    (repo / "big.txt").write_text("x" * 300_000, encoding="utf-8")
    (repo / "bin.dat").write_bytes(b"\x00\x01\x02BINARY")
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "loot.txt").write_text("exfil", encoding="utf-8")
    os.symlink(outside / "loot.txt", repo / "escape.txt")
    return repo

@pytest.fixture
def sandbox(repo_tree):
    return Sandbox.from_roots([repo_tree])
