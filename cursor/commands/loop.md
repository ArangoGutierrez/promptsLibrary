# Loop

Ralph-Loop style persistent task execution until completion.

## Usage
```
{task description}

--done "{completion phrase}"  # What signals completion (default: "DONE")
--max {N}                     # Max iterations (default: 10)
```

## Examples
```
/loop Build a REST API with CRUD, validation, and tests --done "ALL TESTS PASS" --max 20

/loop Fix all linter errors in src/ --done "NO ERRORS" --max 5

/loop Implement feature from AGENTS.md --done "DONE" --max 10
```

## How It Works

### 1. Initialize Loop
Create `.cursor/loop-state.json`:
```json
{
  "task": "{task description}",
  "completion_promise": "{done phrase}",
  "max_iterations": {N},
  "current_iteration": 0,
  "started_at": "{timestamp}",
  "status": "running"
}
```

### 2. Display Start
```
## 🔁 Loop Started

**Task:** {task}
**Done when:** "{completion phrase}"
**Max iterations:** {N}

Beginning iteration 1/{N}...
```

### 3. Work On Task
Execute the task. After each iteration:
- Check for completion phrase in recent output
- Check for `## Status: DONE` in AGENTS.md
- Check iteration count

### 4. Loop Logic (handled by stop hook)
The `task-loop.sh` hook intercepts stops and:
- If completion phrase found → actually stop
- If max iterations reached → stop with warning
- Otherwise → continue with: "Continuing task. Iteration {N}/{max}"

### 5. Completion Report
```
## ✅ Loop Complete

**Task:** {task}
**Iterations:** {N}/{max}
**Duration:** {time}
**Result:** {completion phrase found / max reached / cancelled}

### Work Done
{summary of changes}
```

## Best Practices (from Ralph-Loop)

### 1. Clear Completion Criteria
❌ Bad: "Make the code better"
✅ Good: "Fix all test failures. Output TESTS PASS when done."

### 2. Automatic Verification
❌ Bad: "Make it look good" (needs human judgment)
✅ Good: "All linter errors fixed" (machine-verifiable)

### 3. Incremental Goals
❌ Bad: "Build complete e-commerce platform"
✅ Good: "Phase 1: Auth. Phase 2: Products. Phase 3: Cart. Output COMPLETE when all phases done."

### 4. Always Set Max Iterations
```
/loop "Try to fix flaky test" --max 5
```

If stuck after max iterations, loop reports what was attempted.

## Cancelling

Say "cancel loop" or "stop loop" to abort.

Updates `AGENTS.md` status and `.cursor/loop-state.json`:
```json
{
  "status": "cancelled",
  "cancelled_at": "{timestamp}",
  "iterations_completed": {N}
}
```

## Integration with /issue Workflow

After `/issue #123` creates AGENTS.md with tasks:
```
/loop Work through all tasks in AGENTS.md --done "Status: DONE" --max 15
```

The loop will:
1. Read AGENTS.md, find next `[TODO]`
2. Implement task, commit
3. Update AGENTS.md `[TODO]` → `[DONE]`
4. Check if all tasks done
5. Repeat until `Status: DONE` or max reached

## Constraints
- **Max iterations**: Always enforced as safety
- **Completion phrase**: Exact match required
- **State file**: `.cursor/loop-state.json` tracks progress
- **Interruptible**: User can cancel anytime
