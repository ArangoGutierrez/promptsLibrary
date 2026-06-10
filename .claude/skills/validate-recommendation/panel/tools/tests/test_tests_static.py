from panel.tools._sandbox import Sandbox
from panel.tools import tests_static

def test_reports_tests_and_assertions(repo_tree):
    t = repo_tree / "tests"; t.mkdir()
    (t / "test_app.py").write_text(
        "from pkg.app import add\n\ndef test_add():\n    assert add(2, 3) == 5\n", encoding="utf-8")
    sb = Sandbox.from_roots([repo_tree])
    out = tests_static.tests_exist(sb, "add")
    assert "test_app.py" in out and "assert" in out.lower()

def test_no_false_positive(repo_tree):
    sb = Sandbox.from_roots([repo_tree])
    out = tests_static.tests_exist(sb, "nonexistent_symbol_xyz")
    assert out.strip().lower().startswith("none found")
