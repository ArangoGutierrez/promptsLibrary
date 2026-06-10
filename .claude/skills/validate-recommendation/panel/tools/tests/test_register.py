import asyncio


def test_tools_register_and_build_into_react_agent(tmp_path):
    import panel.tools.register as reg
    from nat.builder.framework_enum import LLMFrameworkEnum
    from nat.builder.workflow_builder import WorkflowBuilder
    from nat.llm.nim_llm import NIMModelConfig
    from nat.plugins.langchain.agent.react_agent.register import ReActAgentWorkflowConfig

    names = ["read_file", "grep_repo", "glob_files", "check_reference_exists", "tests_exist"]

    async def build():
        async with WorkflowBuilder() as b:
            await b.add_llm("m", NIMModelConfig(model_name="nvidia/nvidia/nemotron-3-ultra"))
            for name, cfg in reg.tool_configs(roots=[str(tmp_path)]).items():
                await b.add_function(name, cfg)
            tools = await b.get_tools(tool_names=names, wrapper_type=LLMFrameworkEnum.LANGCHAIN)
            await b.set_workflow(ReActAgentWorkflowConfig(
                llm_name="m", tool_names=names, use_native_tool_calling=False))
            return await b.build(), tools

    wf, tools = asyncio.run(build())
    assert type(wf).__name__ == "WorkflowImpl"
    # Tool descriptions drive the agent's tool-selection; assert each is present and
    # non-trivial (blanking any description must fail this — see review mutation #5).
    descs = [getattr(t, "description", "") for t in tools]
    assert len(descs) == len(names) and all(len(d.strip()) >= 10 for d in descs), descs
