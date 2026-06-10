# validate-recommendation v4 — SP1 (sandboxed tool library) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `panel/tools/` — six read-only, sandboxed NAT `@register_function` tools the v4 persona agents call to gather evidence — behind one audited security boundary.

**Architecture:** Pure-core / thin-NAT-glue split (like `severity.py` vs `cli.py`). A single `_sandbox.py` chokepoint enforces CC-3 (read-only, path-confined, secret-deny-listed, traversal/symlink-proof, capped, SSRF-guarded). Pure impls in `files.py`/`refs.py`/`tests_static.py` take a `Sandbox` and return strings. `register.py` is the only NAT-coupled file. Tests hit the pure impls against a real filesystem in `tmp_path`; httpx is the single mock seam.

**Tech Stack:** Python 3.12 in a dedicated venv (`~/.claude/panel/.venv`); `nvidia-nat-core` + langchain ReAct primitives (CC-1 idiom); `httpx`; `pytest`.

**Execution method: solo** (subagent-driven-development). Rationale: modules are sequential/coupled behind one boundary; parallel teammates would serialize on `_sandbox.py`.

**Source of truth / spec:** `docs/superpowers/specs/2026-06-10-validate-recommendation-v4-nat-agentic-design.md` (Part B).

**Execution environment:** all work happens in the worktree `.worktrees/validate-recommendation-nat` on branch `feat/validate-recommendation-nat-agents`. The skill package root is `.claude/skills/validate-recommendation/` (call it `$SKILL`). Run tests from `$SKILL` with the venv interpreter so cwd puts `panel/` on `sys.path`:

```bash
SKILL=.claude/skills/validate-recommendation
VPY="$HOME/.claude/panel/.venv/bin/python"
# tests: (cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/ -q)
```

Commits are signed (`-s -S`, hook-enforced) and use conventional `feat(panel-tools):` / `chore(panel):` scopes.

---

## File structure

| File | Responsibility |
|---|---|
| `scripts/panel-venv-bootstrap.sh` | Create `~/.claude/panel/.venv`, install the minimal dep set, smoke-test the CC-1 ReAct-build idiom. |
| `$SKILL/panel/tools/__init__.py` | Package marker. |
| `$SKILL/panel/tools/_sandbox.py` | Security boundary: `Sandbox` (roots, deny-list, realpath confinement, caps). Pure, no NAT. |
| `$SKILL/panel/tools/files.py` | Pure impls: `read_file`, `grep_repo`, `glob_files`, `read_rules`. |
| `$SKILL/panel/tools/refs.py` | Pure impl: `check_reference_exists` (HTTP HEAD + OCI manifest HEAD). httpx = mock seam. |
| `$SKILL/panel/tools/tests_static.py` | Pure impl: `tests_exist` (assertion-pattern grep; no execution). |
| `$SKILL/panel/tools/register.py` | NAT `FunctionBaseConfig` + `@register_function` async-gens wrapping the impls. |
| `$SKILL/panel/tools/tests/conftest.py` | `repo_tree` fixture building a real sandbox tree in `tmp_path`. |
| `$SKILL/panel/tools/tests/test_*.py` | One test module per source module. |

---

## Task 1: Provision the venv + CC-1 smoke

**Files:**
- Create: `scripts/panel-venv-bootstrap.sh`

- [ ] **Step 1: Write the bootstrap + smoke script**

```bash
#!/usr/bin/env bash
# panel-venv-bootstrap.sh — provision ~/.claude/panel/.venv with the v4 minimal
# dep set and smoke-test the NAT ReAct-agent build idiom (v4 spec CC-1/CC-2).
set -euo pipefail
VENV="$HOME/.claude/panel/.venv"
PY="${PYTHON:-/opt/homebrew/bin/python3.12}"

if [ ! -x "$VENV/bin/python" ]; then
  "$PY" -m venv "$VENV"
fi
VPY="$VENV/bin/python"

# Minimal closure (YAGNI): exclude langchain-huggingface/-milvus/-tavily/-litellm.
"$VPY" -m pip install --upgrade pip >/dev/null
"$VPY" -m pip install \
  nvidia-nat-core nvidia-nat-langchain \
  langchain-core langchain-classic langchain-nvidia-ai-endpoints \
  httpx pyyaml pytest

# Smoke: the CC-1 idiom must build a ReAct agent with a custom tool.
"$VPY" - <<'PYEOF'
import asyncio
import nat.llm.register
import nat.plugins.langchain.llm
import nat.plugins.langchain.tool_wrapper
import nat.plugins.langchain.agent.react_agent.register
from nat.builder.builder import Builder
from nat.builder.framework_enum import LLMFrameworkEnum
from nat.builder.function_info import FunctionInfo
from nat.builder.workflow_builder import WorkflowBuilder
from nat.cli.register_workflow import register_function
from nat.data_models.function import FunctionBaseConfig
from nat.llm.nim_llm import NIMModelConfig
from nat.plugins.langchain.agent.react_agent.register import ReActAgentWorkflowConfig

class _SmokeCfg(FunctionBaseConfig, name="smoke_tool"):
    pass

@register_function(config_type=_SmokeCfg, framework_wrappers=[LLMFrameworkEnum.LANGCHAIN])
async def _smoke(cfg: _SmokeCfg, builder: Builder):
    async def _fn(text: str) -> str:
        return f"len={len(text)}"
    yield FunctionInfo.from_fn(_fn, description="Return length of text. Args: text (str).")

async def main():
    async with WorkflowBuilder() as b:
        await b.add_llm("m", NIMModelConfig(model_name="nvidia/nvidia/nemotron-3-ultra"))
        await b.add_function("smoke_tool", _SmokeCfg())
        await b.set_workflow(ReActAgentWorkflowConfig(
            llm_name="m", tool_names=["smoke_tool"], use_native_tool_calling=False))
        wf = await b.build()
        assert type(wf).__name__ == "WorkflowImpl", type(wf).__name__
        print("SMOKE OK:", type(wf).__name__)

asyncio.run(main())
PYEOF
echo "panel venv bootstrap complete: $VENV"
```

- [ ] **Step 2: Run the bootstrap and verify the smoke passes**

Run: `bash scripts/panel-venv-bootstrap.sh` (run sandbox-disabled — network to PyPI).
Expected: ends with `SMOKE OK: WorkflowImpl` then `panel venv bootstrap complete: …`. If any install line errors, fix the dep name and re-run before proceeding.

- [ ] **Step 3: Record the resolved versions for reproducibility**

Run: `~/.claude/panel/.venv/bin/python -m pip freeze | grep -iE 'nvidia-nat|langchain|httpx|pyyaml|pytest' > scripts/panel-venv-requirements.txt`
Expected: a non-empty pinned file.

- [ ] **Step 4: Commit**

```bash
git add scripts/panel-venv-bootstrap.sh scripts/panel-venv-requirements.txt
git commit -s -S -m "chore(panel): bootstrap dedicated venv + NAT ReAct build smoke (SP1 task 1)"
```

---

## Task 2: `_sandbox.py` — the security boundary

**Files:**
- Create: `$SKILL/panel/tools/__init__.py` (empty)
- Create: `$SKILL/panel/tools/_sandbox.py`
- Create: `$SKILL/panel/tools/tests/__init__.py` (empty)
- Create: `$SKILL/panel/tools/tests/conftest.py`
- Test: `$SKILL/panel/tools/tests/test_sandbox.py`

- [ ] **Step 1: Write the conftest fixture**

```python
# conftest.py
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
```

- [ ] **Step 2: Write the failing tests**

```python
# test_sandbox.py
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_sandbox.py -q)`
Expected: FAIL — `ModuleNotFoundError: No module named 'panel.tools._sandbox'`.

- [ ] **Step 4: Write the implementation**

```python
# _sandbox.py
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_sandbox.py -q)`
Expected: PASS (8 passed).

- [ ] **Step 6: Commit**

```bash
git add "$SKILL/panel/tools/__init__.py" "$SKILL/panel/tools/_sandbox.py" \
        "$SKILL/panel/tools/tests/__init__.py" "$SKILL/panel/tools/tests/conftest.py" \
        "$SKILL/panel/tools/tests/test_sandbox.py"
git commit -s -S -m "feat(panel-tools): sandboxed filesystem boundary (SP1 CC-3)"
```

---

## Task 3: `files.py` — read_file / grep_repo / glob_files / read_rules

**Files:**
- Create: `$SKILL/panel/tools/files.py`
- Test: `$SKILL/panel/tools/tests/test_files.py`

- [ ] **Step 1: Write the failing tests**

```python
# test_files.py
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
    sb = Sandbox.from_roots([repo_tree], )  # default cap 200
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
```

- [ ] **Step 2: Run to verify fail**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_files.py -q)`
Expected: FAIL — `ModuleNotFoundError: No module named 'panel.tools.files'`.

- [ ] **Step 3: Write the implementation**

```python
# files.py
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
```

- [ ] **Step 4: Run to verify pass**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_files.py -q)`
Expected: PASS (6 passed).

- [ ] **Step 5: Commit**

```bash
git add "$SKILL/panel/tools/files.py" "$SKILL/panel/tools/tests/test_files.py"
git commit -s -S -m "feat(panel-tools): read_file/grep_repo/glob_files/read_rules"
```

---

## Task 4: `refs.py` — check_reference_exists (HTTP + OCI, SSRF-guarded)

**Files:**
- Create: `$SKILL/panel/tools/refs.py`
- Test: `$SKILL/panel/tools/tests/test_refs.py`

- [ ] **Step 1: Write the failing tests** (httpx is the single mock seam)

```python
# test_refs.py
import types
import pytest
from panel.tools import refs

class _Resp:
    def __init__(self, status): self.status_code = status; self.headers = {}

def test_http_exists(monkeypatch):
    monkeypatch.setattr(refs, "_http_head", lambda url: _Resp(200))
    assert refs.check_reference_exists("https://example.com/x") == "EXISTS"

def test_http_not_found(monkeypatch):
    monkeypatch.setattr(refs, "_http_head", lambda url: _Resp(404))
    assert refs.check_reference_exists("https://example.com/missing").startswith("NOT_FOUND")

def test_ssrf_loopback_blocked():
    assert refs.check_reference_exists("http://127.0.0.1/admin").startswith("ERROR")

def test_ssrf_link_local_blocked():
    assert refs.check_reference_exists("http://169.254.169.254/latest/meta-data").startswith("ERROR")

def test_scheme_blocked():
    assert refs.check_reference_exists("file:///etc/passwd").startswith("ERROR")

def test_oci_manifest_exists(monkeypatch):
    seen = {}
    def fake_head(url, headers=None):
        seen["url"] = url
        return _Resp(200)
    monkeypatch.setattr(refs, "_oci_head", fake_head)
    out = refs.check_reference_exists("oci://registry.example.com/library/ubuntu:24.04")
    assert out == "EXISTS"
    assert "/v2/library/ubuntu/manifests/24.04" in seen["url"]
```

- [ ] **Step 2: Run to verify fail**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_refs.py -q)`
Expected: FAIL — `ModuleNotFoundError: No module named 'panel.tools.refs'`.

- [ ] **Step 3: Write the implementation**

```python
# refs.py
"""check_reference_exists: verify a URL or OCI image ref actually exists.

SSRF-guarded: scheme allow-list, deny loopback/link-local/private/.local hosts,
HEAD only, short timeout. httpx is wrapped in _http_head/_oci_head so tests mock
those two seams without touching the network.
"""
from __future__ import annotations
import ipaddress
import socket
from urllib.parse import urlparse

_TIMEOUT = 5.0
_ALLOWED_SCHEMES = {"http", "https", "oci"}


def _host_is_blocked(host: str) -> bool:
    if not host or host.endswith(".local") or host == "localhost":
        return True
    try:
        infos = socket.getaddrinfo(host, None)
    except OSError:
        return True  # unresolvable -> treat as blocked
    for *_unused, sockaddr in infos:
        ip = ipaddress.ip_address(sockaddr[0])
        if ip.is_loopback or ip.is_link_local or ip.is_private or ip.is_reserved or ip.is_multicast:
            return True
    return False


def _http_head(url: str):
    import httpx
    return httpx.head(url, follow_redirects=False, timeout=_TIMEOUT)


def _oci_head(url: str, headers=None):
    import httpx
    return httpx.head(url, headers=headers or {}, follow_redirects=False, timeout=_TIMEOUT)


def _check_http(url: str) -> str:
    parsed = urlparse(url)
    if _host_is_blocked(parsed.hostname or ""):
        return "ERROR: blocked host (loopback/private/link-local)"
    try:
        resp = _http_head(url)
    except Exception as e:  # network error -> data, not crash
        return f"ERROR: request failed: {str(e)[:120]}"
    if resp.status_code in (404, 410):
        return f"NOT_FOUND (status={resp.status_code})"
    if 200 <= resp.status_code < 400:
        return "EXISTS"
    return f"ERROR: unexpected status={resp.status_code}"


def _check_oci(ref: str) -> str:
    body = ref[len("oci://"):] if ref.startswith("oci://") else ref
    if "@" in body:
        repo_part, tag = body.split("@", 1)
    elif ":" in body.split("/", 1)[-1]:
        repo_part, tag = body.rsplit(":", 1)
    else:
        repo_part, tag = body, "latest"
    if "/" not in repo_part:
        return "ERROR: malformed OCI ref (expected registry/repo)"
    registry, repo = repo_part.split("/", 1)
    if _host_is_blocked(registry.split(":")[0]):
        return "ERROR: blocked registry host"
    url = f"https://{registry}/v2/{repo}/manifests/{tag}"
    accept = ("application/vnd.oci.image.index.v1+json,"
              "application/vnd.oci.image.manifest.v1+json,"
              "application/vnd.docker.distribution.manifest.v2+json")
    try:
        resp = _oci_head(url, headers={"Accept": accept})
        if resp.status_code == 401:
            token = _oci_anon_token(resp, registry, repo)
            if token is None:
                return "ERROR: registry requires non-anonymous auth"
            resp = _oci_head(url, headers={"Accept": accept, "Authorization": f"Bearer {token}"})
    except Exception as e:
        return f"ERROR: registry request failed: {str(e)[:120]}"
    if resp.status_code == 404:
        return "NOT_FOUND (status=404)"
    if 200 <= resp.status_code < 300:
        return "EXISTS"
    return f"ERROR: unexpected status={resp.status_code}"


def _oci_anon_token(resp_401, registry: str, repo: str):
    import httpx
    www = resp_401.headers.get("Www-Authenticate", "")
    if "Bearer" not in www:
        return None
    parts = {}
    for kv in www[www.find("Bearer") + 6:].split(","):
        if "=" in kv:
            k, v = kv.strip().split("=", 1)
            parts[k] = v.strip('"')
    realm = parts.get("realm", "")
    if not realm or _host_is_blocked(urlparse(realm).hostname or ""):
        return None
    params = {k: v for k, v in parts.items() if k in ("service", "scope")}
    if "scope" not in params:
        params["scope"] = f"repository:{repo}:pull"
    r = httpx.get(realm, params=params, timeout=_TIMEOUT)
    if r.status_code != 200:
        return None
    return r.json().get("token") or r.json().get("access_token")


def check_reference_exists(ref: str) -> str:
    scheme = urlparse(ref).scheme or ("oci" if "/" in ref and ":" in ref else "")
    if ref.startswith("oci://") or (scheme == "oci"):
        return _check_oci(ref)
    if scheme not in _ALLOWED_SCHEMES:
        return f"ERROR: blocked or missing scheme '{scheme}'"
    return _check_http(ref)
```

- [ ] **Step 4: Run to verify pass**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_refs.py -q)`
Expected: PASS (6 passed).

- [ ] **Step 5: Commit**

```bash
git add "$SKILL/panel/tools/refs.py" "$SKILL/panel/tools/tests/test_refs.py"
git commit -s -S -m "feat(panel-tools): check_reference_exists (http+OCI, SSRF-guarded)"
```

---

## Task 5: `tests_static.py` — tests_exist (no execution)

**Files:**
- Create: `$SKILL/panel/tools/tests_static.py`
- Test: `$SKILL/panel/tools/tests/test_tests_static.py`

- [ ] **Step 1: Write the failing tests**

```python
# test_tests_static.py
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
```

- [ ] **Step 2: Run to verify fail**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_tests_static.py -q)`
Expected: FAIL — `ModuleNotFoundError: No module named 'panel.tools.tests_static'`.

- [ ] **Step 3: Write the implementation**

```python
# tests_static.py
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
```

- [ ] **Step 4: Run to verify pass**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_tests_static.py -q)`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add "$SKILL/panel/tools/tests_static.py" "$SKILL/panel/tools/tests/test_tests_static.py"
git commit -s -S -m "feat(panel-tools): tests_exist static coverage check (no execution)"
```

---

## Task 6: `register.py` — NAT registration + build-into-agent test

**Files:**
- Create: `$SKILL/panel/tools/register.py`
- Test: `$SKILL/panel/tools/tests/test_register.py`

- [ ] **Step 1: Write the failing test** (builds a real ReAct agent with the tools; no LLM call)

```python
# test_register.py
import asyncio
import pytest

def test_tools_register_and_build_into_react_agent(tmp_path):
    import panel.tools.register as reg
    from nat.builder.framework_enum import LLMFrameworkEnum
    from nat.builder.workflow_builder import WorkflowBuilder
    from nat.llm.nim_llm import NIMModelConfig
    from nat.plugins.langchain.agent.react_agent.register import ReActAgentWorkflowConfig

    async def build():
        async with WorkflowBuilder() as b:
            await b.add_llm("m", NIMModelConfig(model_name="nvidia/nvidia/nemotron-3-ultra"))
            for name, cfg in reg.tool_configs(roots=[str(tmp_path)]).items():
                await b.add_function(name, cfg)
            await b.set_workflow(ReActAgentWorkflowConfig(
                llm_name="m",
                tool_names=["read_file", "grep_repo", "glob_files", "check_reference_exists", "tests_exist"],
                use_native_tool_calling=False))
            return await b.build()
    wf = asyncio.run(build())
    assert type(wf).__name__ == "WorkflowImpl"
```

- [ ] **Step 2: Run to verify fail**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_register.py -q)`
Expected: FAIL — `ModuleNotFoundError: No module named 'panel.tools.register'` (or `tool_configs` missing).

- [ ] **Step 3: Write the implementation**

```python
# register.py
"""NAT @register_function wrappers for the panel tools (the only NAT-coupled file).

The CC-1 surgical registration imports MUST run before a WorkflowBuilder uses
these tools; importing this module performs them.
"""
from __future__ import annotations
from pathlib import Path

import nat.llm.register  # noqa: F401
import nat.plugins.langchain.llm  # noqa: F401
import nat.plugins.langchain.tool_wrapper  # noqa: F401
import nat.plugins.langchain.agent.react_agent.register  # noqa: F401

from nat.builder.builder import Builder
from nat.builder.framework_enum import LLMFrameworkEnum
from nat.builder.function_info import FunctionInfo
from nat.cli.register_workflow import register_function
from nat.data_models.function import FunctionBaseConfig

from panel.tools._sandbox import Sandbox
from panel.tools import files, refs, tests_static

_LC = [LLMFrameworkEnum.LANGCHAIN]


class _RootsConfig(FunctionBaseConfig):
    roots: list[str] = []
    claude_md: str = "~/.claude/CLAUDE.md"
    rules_dir: str = "~/.claude/rules"


class ReadFileConfig(_RootsConfig, name="read_file"):
    pass

class GrepRepoConfig(_RootsConfig, name="grep_repo"):
    pass

class GlobFilesConfig(_RootsConfig, name="glob_files"):
    pass

class ReadRulesConfig(_RootsConfig, name="read_rules"):
    pass

class CheckRefConfig(FunctionBaseConfig, name="check_reference_exists"):
    pass

class TestsExistConfig(_RootsConfig, name="tests_exist"):
    pass


def _sandbox(cfg: _RootsConfig) -> Sandbox:
    roots = list(cfg.roots) + [cfg.claude_md, cfg.rules_dir]
    return Sandbox.from_roots(roots)


@register_function(config_type=ReadFileConfig, framework_wrappers=_LC)
async def _read_file(cfg: ReadFileConfig, builder: Builder):
    sb = _sandbox(cfg)
    async def fn(path: str) -> str:
        return files.read_file(sb, path)
    yield FunctionInfo.from_fn(fn, description="Read a repo file (<=256KB, text). Args: path (str, repo-relative).")


@register_function(config_type=GrepRepoConfig, framework_wrappers=_LC)
async def _grep_repo(cfg: GrepRepoConfig, builder: Builder):
    sb = _sandbox(cfg)
    async def fn(pattern: str) -> str:
        return files.grep_repo(sb, pattern)
    yield FunctionInfo.from_fn(fn, description="Regex-search repo text files. Args: pattern (str, Python regex).")


@register_function(config_type=GlobFilesConfig, framework_wrappers=_LC)
async def _glob_files(cfg: GlobFilesConfig, builder: Builder):
    sb = _sandbox(cfg)
    async def fn(pattern: str) -> str:
        return files.glob_files(sb, pattern)
    yield FunctionInfo.from_fn(fn, description="List repo files matching a glob. Args: pattern (str, e.g. 'pkg/*.py').")


@register_function(config_type=ReadRulesConfig, framework_wrappers=_LC)
async def _read_rules(cfg: ReadRulesConfig, builder: Builder):
    sb = _sandbox(cfg)
    claude_md = Path(cfg.claude_md).expanduser()
    rules_dir = Path(cfg.rules_dir).expanduser()
    async def fn() -> str:
        return files.read_rules(sb, claude_md=claude_md, rules_dir=rules_dir)
    yield FunctionInfo.from_fn(fn, description="Read the engineering CLAUDE.md + rules/*.md. No args.")


@register_function(config_type=CheckRefConfig, framework_wrappers=_LC)
async def _check_ref(cfg: CheckRefConfig, builder: Builder):
    async def fn(ref: str) -> str:
        return refs.check_reference_exists(ref)
    yield FunctionInfo.from_fn(fn, description="Verify a URL or OCI image ref exists. Args: ref (str, http(s):// or oci://reg/repo:tag).")


@register_function(config_type=TestsExistConfig, framework_wrappers=_LC)
async def _tests_exist(cfg: TestsExistConfig, builder: Builder):
    sb = _sandbox(cfg)
    async def fn(subject: str) -> str:
        return tests_static.tests_exist(sb, subject)
    yield FunctionInfo.from_fn(fn, description="Static check: do tests reference `subject`? Args: subject (str, symbol/file).")


def tool_configs(roots: list, claude_md: str = "~/.claude/CLAUDE.md",
                 rules_dir: str = "~/.claude/rules") -> dict:
    """Helper: instantiate every tool config sharing the same roots (used by SP2 + tests)."""
    kw = dict(roots=list(roots), claude_md=claude_md, rules_dir=rules_dir)
    return {
        "read_file": ReadFileConfig(**kw),
        "grep_repo": GrepRepoConfig(**kw),
        "glob_files": GlobFilesConfig(**kw),
        "read_rules": ReadRulesConfig(**kw),
        "check_reference_exists": CheckRefConfig(),
        "tests_exist": TestsExistConfig(**kw),
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/tools/tests/test_register.py -q)`
Expected: PASS (1 passed). If `FunctionBaseConfig` rejects extra fields, adjust `_RootsConfig` to the NAT-sanctioned config-field pattern surfaced by the error, keeping field names stable.

- [ ] **Step 5: Commit**

```bash
git add "$SKILL/panel/tools/register.py" "$SKILL/panel/tools/tests/test_register.py"
git commit -s -S -m "feat(panel-tools): NAT @register_function wrappers + agent-build test"
```

---

## Task 7: Full-suite green + retire the stale discovery note

**Files:**
- Modify: `$SKILL/panel/.nat-discovery-notes.md` (replace the false "BLOCKED" verdict)

- [ ] **Step 1: Run the FULL panel suite (no regression in the 115-test core)**

Run: `(cd "$SKILL" && "$VPY" -m pytest panel/ -q)`
Expected: the prior 115 + the new SP1 tests all pass. Paste the summary line into the commit body.

- [ ] **Step 2: Replace the stale discovery note**

Overwrite `$SKILL/panel/.nat-discovery-notes.md` with a short pointer (the old "BLOCKED" content is false as of nvidia-nat 1.6.0):

```markdown
# NAT discovery notes — SUPERSEDED 2026-06-10

The prior "WorkflowBuilder dispatch BLOCKED" verdict is WRONG as of nvidia-nat 1.6.0.
The working ReAct-agent + custom-tool build idiom is the v4 spec, CC-1:
  docs/superpowers/specs/2026-06-10-validate-recommendation-v4-nat-agentic-design.md
Provisioning: scripts/panel-venv-bootstrap.sh (dedicated venv at ~/.claude/panel/.venv).
```

- [ ] **Step 3: Commit**

```bash
git add "$SKILL/panel/.nat-discovery-notes.md"
git commit -s -S -m "docs(panel): retire stale NAT 'BLOCKED' note; point to v4 CC-1

Full panel suite green: <paste pytest summary>."
```

---

## Self-Review

**1. Spec coverage (Part B):**
- Module layout → Tasks 2–6 create every file in the spec's layout. ✓
- Security model CC-3: roots+confinement+deny-list+traversal/symlink (Task 2); caps (Task 2 `read_text`, Task 3 grep/glob); SSRF (Task 4); no-exec (Task 5 is grep-only; no exec tool anywhere); failure-as-string (every impl returns `ERROR:`). ✓
- Tool contracts: `read_file`/`grep_repo`/`glob_files`/`read_rules` (Task 3), `check_reference_exists` http+OCI (Task 4), `tests_exist` static (Task 5). ✓
- NAT registration + per-persona-subset deferral to SP2 (Task 6: `tool_configs` helper; subsets not assigned here). ✓
- Provisioning venv + CC-1 smoke as task 1 (Task 1). ✓
- Test surface, each test names the bug (Tasks 2–6 tests map to the spec's bullet list). ✓
- `.nat-discovery-notes.md` retirement (Task 7). ✓

**2. Placeholder scan:** No TBD/TODO. Every code step shows complete, runnable code. The only conditional ("if `FunctionBaseConfig` rejects extra fields…", Task 6 step 4) is a real NAT-API contingency with a concrete instruction, not a placeholder.

**3. Type consistency:** `Sandbox.from_roots(list)`, `Sandbox(roots=..., max_matches=...)`, `read_text`, `resolve`, `is_denied` are used identically across `files.py`, `tests_static.py`, and tests. `files.read_rules(sb, claude_md=, rules_dir=)` signature matches its call in `register.py` and `test_files.py`. `refs._http_head`/`_oci_head` are the exact names monkeypatched in `test_refs.py`. `reg.tool_configs(roots=...)` keys match the `tool_names` list in `test_register.py`.

**Residual risk pinned for execution:** (a) NAT `FunctionBaseConfig` may constrain custom fields (`roots`) — Task 6 step 4 notes the adjust-in-place path; (b) `p.match(path_glob)` semantics for `grep_repo`'s optional glob are pathlib-style — the default `**/*` short-circuits, so the common path is unaffected.
