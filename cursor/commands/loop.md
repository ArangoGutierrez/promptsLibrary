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

## Output Format

### On Start
```markdown
## 🔁 Loop Started

**Task:** {task description}
**Done when:** "{completion phrase}"
**Budget:** {N} iterations

Beginning iteration 1/{N}...
```

### Per Iteration
```markdown
📍 Iteration {N}/{max} | {remaining} tasks remaining

Continue working on TODO items in AGENTS.md
```

### On Complete
```markdown
## ✅ Loop Complete

**Task:** {task}
**Iterations:** {N}/{max}
**Duration:** {time}
**Result:** {completion phrase found | max reached | cancelled}

### Summary
- Tasks completed: {N}
- Files changed: {list}
- Commits: {count}
```

## Constraints
- **Max iterations**: Always enforced as safety
- **Completion phrase**: Exact match required
- **State file**: `.cursor/loop-state.json` tracks progress
- **Interruptible**: User can cancel anytime

## Troubleshooting

### Loop Not Continuing
```
Loop stops after first iteration
```
**Causes & Fixes:**
| Cause | Check | Fix |
|-------|-------|-----|
| Completion phrase matched | Review last output | Use more specific phrase |
| Hook not installed | `cat cursor/hooks.json` | Ensure `task-loop.sh` in `stop` array |
| State file missing | `ls .cursor/` | Re-run `/loop` to initialize |

### Loop State Corrupted
```bash
# Reset loop state
rm .cursor/loop-state.json

# Or fix manually
cat > .cursor/loop-state.json << 'EOF'
{
  "task": "your task",
  "completion_promise": "DONE",
  "max_iterations": 10,
  "current_iteration": 0,
  "status": "running"
}
EOF
```

### Loop Stuck on Same Step
```
Iteration 5: Same error as iteration 4
```
**Actions:**
1. Say "cancel loop" to stop
2. Analyze what's blocking progress
3. Fix blocking issue manually
4. Restart loop with adjusted task description

### Max Iterations Reached Without Completion
```
Loop stopped: Max iterations (10) reached
```
**Actions:**
1. Review progress in `.cursor/task-log.md`
2. Analyze what's left incomplete
3. Either:
   - Restart with higher `--max`
   - Break into smaller sub-tasks
   - Complete remaining work manually

### AGENTS.md Not Updating
```
Loop runs but AGENTS.md tasks stay [TODO]
```
**Causes:**
- Task completion not detected
- AGENTS.md syntax error
- Status markers malformed

**Fix:**
```bash
# Verify AGENTS.md syntax
grep -E '\[(TODO|WIP|DONE|BLOCKED)\]' AGENTS.md
```

### Hook Errors
```bash
# Check hook execution
bash -x cursor/hooks/task-loop.sh << 'EOF'
{"status":"completed","loop_count":1}
EOF

# Common issues:
# - Missing jq: brew install jq
# - Permission denied: chmod +x cursor/hooks/task-loop.sh
# - JSON parse error: validate hooks.json syntax
```

### Recovery From Failed Loop
```bash
# 1. Check state
cat .cursor/loop-state.json

# 2. Check progress log
cat .cursor/task-log.md

# 3. Reset if needed
rm .cursor/loop-state.json

# 4. Continue manually with /code
```
