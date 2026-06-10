"""tests_exist: STATIC evidence that `subject` is covered by tests. No execution."""
from __future__ import annotations
import re
from panel.tools._sandbox import Sandbox
from panel.tools import files

_ASSERT_RE = re.compile(r"\b(assert|assertEqual|assertTrue|require\.|expect\()")


def tests_exist(sb: Sandbox, subject: str) -> str:
    if not subject.strip():
        return "ERROR: empty subject"
    hits = files.grep_repo(sb, re.escape(subject), path_glob="**/*test*")
    if hits.startswith("ERROR:") or hits == "(no matches)":
        # fall back to assertion-pattern scan in test files mentioning the subject
        broad = files.grep_repo(sb, re.escape(subject))
        test_lines = [ln for ln in broad.splitlines() if "test" in ln.lower()]
        if not test_lines:
            return f"none found: no test files reference '{subject}'"
        hits = "\n".join(test_lines)
    files_seen = sorted({ln.split(":", 1)[0] for ln in hits.splitlines() if ":" in ln})
    assert_count = sum(1 for ln in hits.splitlines() if _ASSERT_RE.search(ln))
    return (f"test files referencing '{subject}': {len(files_seen)} "
            f"({', '.join(files_seen[:10])})\n"
            f"assertion-pattern lines among matches: {assert_count}")
