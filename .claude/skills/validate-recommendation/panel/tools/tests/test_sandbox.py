from pathlib import Path
from panel.tools._sandbox import Sandbox

def test_resolve_in_root_returns_realpath(sandbox, repo_tree):
    p = sandbox.resolve("pkg/app.py")
    assert p == (repo_tree / "pkg" / "app.py").resolve()

def test_traversal_escape_rejected(sandbox):
    assert sandbox.resolve("../outside/loot.txt") is None
    assert sandbox.resolve("../../etc/passwd") is None

def test_symlink_escape_rejected(sandbox):
    # escape.txt is inside the root but symlinks OUT — realpath must catch it
    assert sandbox.resolve("escape.txt") is None

def test_secret_denylist_rejected(sandbox):
    assert sandbox.resolve(".env") is None

def test_read_text_caps_size(sandbox):
    err = sandbox.read_text("big.txt")
    assert err.startswith("ERROR:") and "size" in err.lower()

def test_read_text_rejects_binary(sandbox):
    err = sandbox.read_text("bin.dat")
    assert err.startswith("ERROR:") and "binary" in err.lower()

def test_read_text_happy(sandbox):
    out = sandbox.read_text("pkg/app.py")
    assert "def add" in out and not out.startswith("ERROR:")

def test_missing_file_is_error_string_not_exception(sandbox):
    out = sandbox.read_text("pkg/nope.py")
    assert out.startswith("ERROR:")

def test_secret_dir_component_denied(tmp_path):
    # **/*secret* denies at ANY depth, not just the filename
    root = tmp_path / "repo"
    (root / "secrets").mkdir(parents=True)
    (root / "secrets" / "prod.yaml").write_text("api: xyz\n", encoding="utf-8")
    sb = Sandbox.from_roots([root])
    assert sb.resolve("secrets/prod.yaml") is None

def test_denyword_in_root_path_not_overdenied(tmp_path):
    # Root's OWN path contains a deny-word ("mytokens"); a benign file under it
    # must stay readable — deny-substring checks apply to the in-sandbox
    # (relative) portion only, not the absolute root prefix.
    root = tmp_path / "mytokens" / "repo"
    root.mkdir(parents=True)
    (root / "app.py").write_text("x = 1\n", encoding="utf-8")
    sb = Sandbox.from_roots([root])
    assert sb.resolve("app.py") is not None
