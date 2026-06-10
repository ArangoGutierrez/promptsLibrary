#!/usr/bin/env bash
# panel-venv-bootstrap.sh — provision ~/.claude/panel/.venv for the v4 NAT-agentic panel.
#
# Lean closure: nvidia-nat-langchain and the nvidia-nat meta package are installed
# with --no-deps to avoid their heavy, UNUSED declared tree (langchain-huggingface
# -> torch, langchain-milvus, langchain-tavily, langchain-litellm, nvidia-nat-eval,
# nvidia-nat-opentelemetry, openevals). Only the runtime imports our ReAct-agent +
# tools path actually needs are installed. nvidia-nat-core's own deps come along.
# Verified 2026-06-10: builds a ReAct agent with a custom tool (WorkflowImpl), no torch.
#
# SP5 (OTel) and SP6 (Eval) will add nvidia-nat-opentelemetry / nvidia-nat-eval here.
set -euo pipefail

VENV="${PANEL_VENV:-$HOME/.claude/panel/.venv}"
PY="${PYTHON:-/opt/homebrew/bin/python3.12}"

[ -x "$VENV/bin/python" ] || "$PY" -m venv "$VENV"
VPY="$VENV/bin/python"
"$VPY" -m pip install --upgrade -q pip

# Runtime closure, pinned to the known-good set (matches the SP0-verified user-site).
"$VPY" -m pip install -q \
  nvidia-nat-core==1.6.0 \
  langchain-core==1.4.0 langchain-classic==1.0.7 \
  langchain-nvidia-ai-endpoints==1.3.0 langchain-text-splitters==1.1.2 \
  langgraph==1.2.0 \
  httpx==0.28.1 "PyYAML==6.0.3" pytest

# Plugin + meta package WITHOUT their heavy declared deps.
"$VPY" -m pip install -q --no-deps nvidia-nat-langchain==1.6.0 nvidia-nat==1.6.0

# Guard: fail loudly if the heavy ML tree somehow got pulled in.
if "$VPY" -m pip list 2>/dev/null | grep -qiE '^(torch|transformers|sentence-transformers|faiss)'; then
  echo "ERROR: heavy ML dep present; expected lean closure" >&2
  exit 1
fi

# Smoke: the v4 CC-1 idiom must build a ReAct agent with a custom tool.
"$VPY" - <<'PYEOF'
import asyncio
import nat.llm.register                                   # noqa: F401
import nat.plugins.langchain.llm                           # noqa: F401
import nat.plugins.langchain.tool_wrapper                  # noqa: F401
import nat.plugins.langchain.agent.react_agent.register    # noqa: F401
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
async def _smoke(cfg, builder):
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
echo "panel venv ready: $VENV"
