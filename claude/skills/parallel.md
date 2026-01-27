---
name: parallel
description: Run independent tasks concurrently via subagents. Analyzes task dependencies, groups independent tasks for parallel execution, and launches Task subagents with fast model. Can analyze AGENTS.md for parallelization opportunities or execute pipe-separated tasks directly.
argument-hint: "[task1 | task2 | task3] [--analyze] [--from-agents]"
disable-model-invocation: true
allowed-tools: Task, Read, Edit
model: haiku
---

# Parallel Task Execution

Run independent tasks concurrently to maximize throughput.

## Usage

```bash
/parallel task1 | task2 | task3    # Execute tasks in parallel
/parallel --analyze                # Check AGENTS.md for parallel opportunities
/parallel --from-agents            # Auto-run parallel [TODO]s from AGENTS.md
```

## Workflow

### Step 1: Parse Tasks

Split input by `|` delimiter:

```
Input: "add logging | update docs | run tests"
Tasks: ["add logging", "update docs", "run tests"]
```

### Step 2: Analyze Dependencies

Check for dependencies between tasks:

**Dependency signals** (tasks CANNOT run in parallel):

- **Same file**: Both tasks modify same file
- **Explicit dependency**: "after X", "needs X", "depends on X"
- **Test dependency**: "test X" requires "implement X" to complete first
- **Data flow**: Task B uses output from Task A

**Independence signals** (tasks CAN run in parallel):

- **Different directories**: No file overlap
- **Different concerns**: Separate functional areas (docs vs code vs tests)
- **No explicit deps**: No "after" or "needs" language

**Dependency matrix**:

| Task | Depends On | Blocks |
|------|------------|--------|
| Task 1 | - | Task 2 |
| Task 2 | Task 1 | - |
| Task 3 | - | - |

### Step 3: Group Tasks

Organize into parallel and sequential groups:

**Parallel group**: Independent tasks that can run simultaneously

- Max 4 tasks in parallel (to avoid overwhelming)
- Use fast model (haiku) for efficiency

**Sequential group**: Dependent tasks that must run in order

- Execute one after another
- Wait for each to complete before starting next

**Example**:

```
Input: "impl auth | test auth | add docs | update readme"

Groups:
  Parallel A: ["impl auth", "add docs", "update readme"]
  Sequential: ["test auth"] (waits for "impl auth")
```

### Step 4: Execute Parallel Tasks

Launch independent tasks using Task tool:

```typescript
// Launch in parallel (all in single message)
Task({
  prompt: "Complete task 1: {description}",
  description: "task 1",
  model: "haiku",
  run_in_background: true
})

Task({
  prompt: "Complete task 2: {description}",
  description: "task 2",
  model: "haiku",
  run_in_background: true
})

Task({
  prompt: "Complete task 3: {description}",
  description: "task 3",
  model: "haiku",
  run_in_background: true
})
```

Use `run_in_background: true` for parallel execution.

### Step 5: Monitor Progress

Check background task status with TaskOutput:

```bash
# Check task progress
TaskOutput(task_id="task_1", block=false)
```

### Step 6: Merge Results

After all tasks complete:

1. Collect results from each task
2. Identify files changed
3. Check for conflicts
4. Update AGENTS.md with results

**Conflict detection**:

- Same file modified by multiple tasks: ⚠️ Manual merge needed
- No file overlap: ✓ Clean merge

## Output Format

```markdown
## /parallel Results

**Executed**: 4 tasks (3 parallel, 1 sequential)

### Completed Tasks
| Task | Status | Files Changed | Duration |
|------|--------|---------------|----------|
| Impl auth | ✓ | auth.go, middleware.go | 2.3s |
| Add docs | ✓ | README.md | 1.1s |
| Update readme | ✓ | README.md | 0.8s |
| Test auth | ✓ | auth_test.go | 1.5s |

### Changes Summary
- `auth.go`: Authentication implementation
- `middleware.go`: Auth middleware added
- `README.md`: Documentation updated (CONFLICT - manual merge needed)
- `auth_test.go`: Tests added

### Conflicts
⚠️ **README.md**: Modified by both "Add docs" and "Update readme"
  - Manual merge required
  - Review both changes before committing

### Next Steps
- Resolve README.md conflict
- Run `/test` to verify all changes
- Commit merged changes
```

## Dependency Rules Reference

| Signal | Example | Parallel? | Reason |
|--------|---------|-----------|--------|
| Same file | "fix auth.go", "refactor auth.go" | ❌ No | File conflict |
| "after X" | "test auth after impl" | ❌ No | Explicit dependency |
| "needs X" | "needs database migration" | ❌ No | Prerequisite required |
| "test X" | "test login", "impl login" | ❌ No | Tests need implementation |
| Different dirs | "api/", "docs/" | ✅ Yes | No file overlap |
| Different concerns | "code", "docs", "tests" | ✅ Yes | Independent work |
| No dependencies | "add logging", "update UI" | ✅ Yes | Unrelated tasks |

## Mode: --analyze (Analyze AGENTS.md)

Check AGENTS.md for tasks that can run in parallel:

1. Read AGENTS.md
2. Extract all [TODO] tasks
3. Analyze dependencies using rules above
4. Group into parallel and sequential
5. Report opportunities

**Output**:

```markdown
## Parallelization Analysis

### Current AGENTS.md Tasks
- [ ] Task 1: Implement auth
- [ ] Task 2: Add logging
- [ ] Task 3: Update docs
- [ ] Task 4: Test auth

### Parallelization Opportunities
**Parallel group A** (can run simultaneously):
- Task 1: Implement auth
- Task 2: Add logging
- Task 3: Update docs

**Sequential** (must wait):
- Task 4: Test auth (depends on Task 1)

### Recommendation
Run tasks 1, 2, 3 in parallel using:
```bash
/parallel impl auth | add logging | update docs
```

Then run task 4 after completion.

```

## Mode: --from-agents (Auto-run from AGENTS.md)

Automatically execute parallel tasks from AGENTS.md:

1. Read AGENTS.md
2. Extract [TODO] tasks
3. Analyze dependencies
4. Launch independent tasks in parallel
5. Update AGENTS.md with [WIP] status
6. Wait for completion
7. Update AGENTS.md with [DONE] status

**Note**: This mode is experimental. Use with caution.

## Constraints

- **Max 4 parallel**: Don't launch more than 4 tasks simultaneously
- **Fast model**: Use haiku for parallel tasks (cost and speed)
- **Conflict detection**: Check for file overlaps before merging
- **Background execution**: All parallel tasks must use `run_in_background: true`
- **No silent failures**: Report any task that fails

## When to Use

**Use /parallel when**:
- Multiple independent tasks identified
- Want to save time on unrelated work
- Tasks have no dependencies
- Working on different parts of codebase

**Don't use /parallel for**:
- Dependent tasks (use sequential)
- Tasks modifying same file
- Complex tasks needing human judgment
- When sequential is clearer

## Related Skills

- `/task` - Execute single task
- `/code` - Execute next TODO from AGENTS.md
- `/issue` - Break down issue into parallelizable tasks
