# Parallel

Execute independent tasks concurrently using subagents.

## Usage

```
/parallel task1 | task2 | task3
/parallel --analyze          # Analyze AGENTS.md for parallelizable tasks
/parallel --from-agents      # Auto-run parallel tasks from AGENTS.md
```

## Workflow

### 1. Parse Tasks

Split input by `|` delimiter:
```
Input: "Fix auth | Update docs | Add tests"
→ ["Fix auth", "Update docs", "Add tests"]
```

### 2. Dependency Analysis

For each task pair, check:

| Dependency Type | Example | Parallel? |
|-----------------|---------|-----------|
| File overlap | Both edit `auth.go` | No |
| Data flow | Task B needs Task A output | No |
| Independent | Different files/concerns | **Yes** |

Build dependency graph:
```
Task A ──→ Task C (A must complete first)
Task B ────────→ (independent)
```

### 3. Group by Independence

```
Group 1 (parallel): [Task A, Task B]
Group 2 (after G1):  [Task C]
```

### 4. Execute

For each parallel group, launch subagents:

```
Launch Task subagents with model: fast
- Each gets: task description + relevant file context
- Each returns: summary of changes made
```

### 5. Merge Results

```markdown
## Parallel Execution Report

### Completed in Parallel
| Task | Status | Files Changed |
|------|--------|---------------|
| Fix auth | ✓ | auth.go |
| Update docs | ✓ | README.md |

### Sequential (had dependencies)
| Task | Waited For | Status |
|------|------------|--------|

### Summary
3 tasks, 2 parallel + 1 sequential
Time saved: ~40% vs sequential
```

## `--analyze` Mode

Read AGENTS.md and identify parallelization opportunities:

```markdown
## Parallelization Analysis

### Current Tasks
| # | Task | Dependencies | Can Parallel With |
|---|------|--------------|-------------------|
| 1 | Add model | None | 2, 3 |
| 2 | Add handler | None | 1, 3 |
| 3 | Add tests | 1, 2 | None (needs impl) |

### Recommended Groups
- **Group 1** (parallel): Tasks 1, 2
- **Group 2** (sequential): Task 3

### Command
`/parallel Add model | Add handler`
Then: `/code` for Task 3
```

## `--from-agents` Mode

Auto-extract and run parallel tasks from AGENTS.md:

1. Parse `[TODO]` tasks
2. Analyze dependencies
3. Execute independent tasks in parallel
4. Update AGENTS.md with results

## Dependency Detection Rules

| Signal | Means |
|--------|-------|
| Same file mentioned | Potential conflict |
| "after X", "needs X" | Explicit dependency |
| "test" task | Usually depends on impl |
| Different packages/dirs | Likely independent |
| "refactor" | Check scope overlap |

## Constraints

- Max 4 parallel subagents (resource limit)
- Each subagent uses `fast` model
- Timeout: 2 min per subagent
- If dependency unclear → ask user

## Output

```markdown
## /parallel Results

Executed: {N} tasks ({P} parallel, {S} sequential)

### Changes
{task}: {files changed}
...

### Next
{remaining tasks or "All complete"}
```
