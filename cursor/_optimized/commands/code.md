# Code
(no args)→next[TODO]|`#{N}`→specific task

## Flow
1.Read AGENTS.md→find[TODO]
2.Display:Task#{N}+desc+files,update[TODO]→[WIP]
3.Impl:ONLY this task,minimal changes
4.Verify:✓compile|✓task-accept|✓no-unrelated
5.Commit:`git add {f} && git commit -s -S -m "{type}({scope}): {desc}\n\nRefs: #{issue}\nTask: {N}/{total}"`
6.Update AGENTS.md:[WIP]→[DONE]+hash
7.Report:commit,files,progress,next

## Blocked
Update:[BLOCKED:{reason}]

## Reflect
Single-concern?|Minimal?|Compiles?|Tests?

## Rules
1task=1commit|atomic|update AGENTS.md|refs issue
