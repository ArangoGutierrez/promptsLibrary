# Code

Work on the next TODO task from AGENTS.md.

## Usage
- (no args) — Work on next `[TODO]` task
- `#{N}` — Work on specific task number

## Workflow

### 1. Read AGENTS.md
```bash
cat AGENTS.md
```

Find next `[TODO]` task (or specified task).

### 2. Focus on Single Task
Display:
```
## Current Task: #{N}

**Task:** {description}
**Files:** {files to modify}
**Status:** [TODO] → [WIP]
```

Update AGENTS.md: `[TODO]` → `[WIP]`

### 3. Implement
- Focus ONLY on this task
- Don't touch unrelated code
- Keep changes minimal

### 4. Verify Before Done
- [ ] Code compiles/type-checks
- [ ] Task-specific acceptance met
- [ ] No unrelated changes

### 5. Commit
When task complete:
```bash
git add {files}
git commit -s -S -m "{type}({scope}): {task description}

Refs: #{issue_number}
Task: {N}/{total}"
```

### 6. Update AGENTS.md
- Change `[WIP]` → `[DONE]`
- Add commit hash to task

### 7. Report
```
## ✓ Task #{N} Complete

**Commit:** {hash}
**Changed:** {files}

### Progress
- Done: {X}/{total}
- Next: Task #{N+1} — {description}

Run `/code` to continue, or `/test` to verify.
```

## If Blocked
```
## ⚠️ Task #{N} Blocked

**Reason:** {why blocked}
**Need:** {what's required}

Update AGENTS.md: `[BLOCKED:{reason}]`
```

## Reflection (Each Task)
| Check | Status |
|-------|--------|
| Single concern? | ✓/✗ |
| Minimal changes? | ✓/✗ |
| Compiles? | ✓/✗ |
| Tests pass? | ✓/✗ |

## Constraints
- **One task at a time**: Don't scope creep
- **Atomic commits**: Each task = 1 commit
- **Update AGENTS.md**: Keep progress current
- **Refs issue**: All commits reference issue number
