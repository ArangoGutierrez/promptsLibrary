"""NAT @register_function wrappers for the panel tools (the only NAT-coupled file).

The surgical registration imports MUST run before a WorkflowBuilder uses these
tools; importing this module performs them.

NOTE: intentionally no `from __future__ import annotations` — NAT resolves type
annotations at import time; PEP-563 lazy strings break its internal closure-based
stream-function auto-generation.
"""
from pathlib import Path

import nat.llm.register  # noqa: F401
import nat.plugins.langchain.llm  # noqa: F401
import nat.plugins.langchain.tool_wrapper  # noqa: F401
import nat.plugins.langchain.agent.react_agent.register  # noqa: F401

from pydantic import BaseModel

from nat.builder.builder import Builder
from nat.builder.framework_enum import LLMFrameworkEnum
from nat.builder.function_info import FunctionInfo
from nat.cli.register_workflow import register_function
from nat.data_models.function import FunctionBaseConfig

from panel.tools._sandbox import Sandbox
from panel.tools import files, refs, tests_static


class _NoArgs(BaseModel):
    """Empty input schema for tools that take no arguments (NAT requires exactly one param)."""
    pass

_LC = [LLMFrameworkEnum.LANGCHAIN]


class ReadFileConfig(FunctionBaseConfig, name="read_file"):
    roots: list[str] = []
    claude_md: str = "~/.claude/CLAUDE.md"
    rules_dir: str = "~/.claude/rules"


class GrepRepoConfig(FunctionBaseConfig, name="grep_repo"):
    roots: list[str] = []
    claude_md: str = "~/.claude/CLAUDE.md"
    rules_dir: str = "~/.claude/rules"


class GlobFilesConfig(FunctionBaseConfig, name="glob_files"):
    roots: list[str] = []
    claude_md: str = "~/.claude/CLAUDE.md"
    rules_dir: str = "~/.claude/rules"


class ReadRulesConfig(FunctionBaseConfig, name="read_rules"):
    roots: list[str] = []
    claude_md: str = "~/.claude/CLAUDE.md"
    rules_dir: str = "~/.claude/rules"


class CheckRefConfig(FunctionBaseConfig, name="check_reference_exists"):
    pass


class TestsExistConfig(FunctionBaseConfig, name="tests_exist"):
    roots: list[str] = []
    claude_md: str = "~/.claude/CLAUDE.md"
    rules_dir: str = "~/.claude/rules"


def _sandbox(cfg) -> Sandbox:
    return Sandbox.from_roots(list(cfg.roots) + [cfg.claude_md, cfg.rules_dir])


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

    async def fn(inp: _NoArgs) -> str:
        return files.read_rules(sb, claude_md=claude_md, rules_dir=rules_dir)

    yield FunctionInfo.from_fn(fn, description="Read the engineering CLAUDE.md + rules/*.md. No args (pass {}).")


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
    """Instantiate every tool config sharing the same roots (used by SP2 + tests)."""
    kw = dict(roots=list(roots), claude_md=claude_md, rules_dir=rules_dir)
    return {
        "read_file": ReadFileConfig(**kw),
        "grep_repo": GrepRepoConfig(**kw),
        "glob_files": GlobFilesConfig(**kw),
        "read_rules": ReadRulesConfig(**kw),
        "check_reference_exists": CheckRefConfig(),
        "tests_exist": TestsExistConfig(**kw),
    }
