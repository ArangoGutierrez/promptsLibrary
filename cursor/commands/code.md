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

## Output Format

### On Task Start
```markdown
## Current Task: #{N}

**Task:** {description}
**Files:** {files to modify}
**Status:** [TODO] → [WIP]
```

### On Task Complete
```markdown
## ✓ Task #{N} Complete

**Commit:** {hash}
**Changed:** {files}

### Progress
| Done | Total | Next |
|------|-------|------|
| {X} | {Y} | Task #{N+1}: {desc} |

Run `/code` to continue, or `/test` to verify.
```

### On Blocked
```markdown
## ⚠️ Task #{N} Blocked

**Reason:** {why blocked}
**Need:** {what's required to unblock}

AGENTS.md updated: `[BLOCKED:{reason}]`
```

## Constraints
- **One task at a time**: Don't scope creep
- **Atomic commits**: Each task = 1 commit
- **Update AGENTS.md**: Keep progress current
- **Refs issue**: All commits reference issue number

## Troubleshooting

### AGENTS.md Not Found
```
Error: No AGENTS.md in project root
```
**Fix:** Run `/issue #{number}` or `/task {description}` first to create AGENTS.md

### No TODO Tasks Found
```
All tasks marked [DONE] or [BLOCKED]
```
**Actions:**
1. Check for `[BLOCKED]` tasks that can be unblocked
2. Run `/test` and `/self-review` if implementation complete
3. Run `/push` if ready for PR

### Task Dependencies Missing
```
Task requires output from incomplete task
```
**Actions:**
1. Check dependency chain in AGENTS.md
2. Work on prerequisite task first
3. If circular dependency, restructure task breakdown

### Commit Failed
| Error | Cause | Fix |
|-------|-------|-----|
| GPG sign failed | Key not configured | `git config --global user.signingkey {KEY}` |
| Pre-commit hook failed | Linting errors | Fix lint issues, re-commit |
| Merge conflict | Branch out of date | `git pull --rebase origin main` |

### Build/Compile Fails After Change
```
Task implementation breaks build
```
**Actions:**
1. Review the specific error message
2. Check if imports are correct
3. Verify interface implementations match
4. Revert with `git checkout -- {file}` if needed to restart

### AGENTS.md Status Mismatch
If AGENTS.md shows wrong status:
```bash
# Manually fix status markers
# [TODO] → [WIP] → [DONE] → [BLOCKED:{reason}]
```
Then continue with `/code`
