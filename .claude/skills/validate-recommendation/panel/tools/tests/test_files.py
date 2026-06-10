from pathlib import Path
import pytest
from panel.tools._sandbox import Sandbox
from panel.tools import files

def test_read_file_delegates_to_sandbox(sandbox):
    assert "def add" in files.read_file(sandbox, "pkg/app.py")
    assert files.read_file(sandbox, ".env").startswith("ERROR:")

def test_grep_repo_finds_literal_with_location(sandbox):
    out = files.grep_repo(sandbox, r"def add")
    assert "pkg/app.py:1:" in out

def test_grep_repo_caps_results(repo_tree):
    d = repo_tree / "many"
    d.mkdir()
    for i in range(50):
        (d / f"f{i}.txt").write_text("needle\n", encoding="utf-8")
    sb = Sandbox.from_roots([repo_tree])
    sb = Sandbox(roots=sb.roots, max_matches=10)
    out = files.grep_repo(sb, "needle")
    assert out.count("\n") <= 11  # 10 hits + optional truncation notice line

def test_grep_repo_skips_binary_and_secrets(sandbox):
    out = files.grep_repo(sandbox, "topsecret")
    assert "topsecret" not in out  # .env is denied; never grepped

def test_glob_files_lists_relpaths(sandbox):
    out = files.glob_files(sandbox, "pkg/*.py")
    assert "pkg/app.py" in out

def test_read_rules_concatenates(tmp_path):
    rules = tmp_path / "rules"
    rules.mkdir()
    (rules / "go.md").write_text("# Go\nwrap errors\n", encoding="utf-8")
    claude = tmp_path / "CLAUDE.md"
    claude.write_text("# Standards\n", encoding="utf-8")
    sb = Sandbox.from_roots([rules, claude])
    out = files.read_rules(sb, claude_md=claude, rules_dir=rules)
    assert "wrap errors" in out and "Standards" in out
