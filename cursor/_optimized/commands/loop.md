# Loop
`{task} --done "{phrase}" --max {N}`
Default:done="DONE",max=10

## Init
`.cursor/loop-state.json`:task,completion_promise,max,current:0,status:running

## Work
Execute→check:phrase in output|"## Status: DONE" in AGENTS.md|iteration count
Hook `task-loop.sh`:phrase→stop|max→stop+warn|else→continue

## Complete
Report:task,iterations,duration,result,changes

## Cancel
"cancel loop"→status:cancelled,update AGENTS.md

## +/issue
`/loop Work through AGENTS.md --done "Status: DONE" --max 15`
Read AGENTS.md→next[TODO]→impl→commit→[TODO]→[DONE]→repeat
