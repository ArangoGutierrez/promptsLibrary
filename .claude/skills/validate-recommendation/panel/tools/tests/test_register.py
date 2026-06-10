import asyncio


def test_tools_register_and_build_into_react_agent(tmp_path):
    import panel.tools.register as reg
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
                tool_names=["read_file", "grep_repo", "glob_files",
                            "check_reference_exists", "tests_exist"],
                use_native_tool_calling=False))
            return await b.build()

    wf = asyncio.run(build())
    assert type(wf).__name__ == "WorkflowImpl"
