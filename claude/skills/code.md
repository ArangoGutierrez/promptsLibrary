---
name: code
description: Execute next TODO task from AGENTS.md with automatic progress tracking. Reads AGENTS.md, finds next [TODO], implements minimal changes for that task only, verifies compilation and acceptance, commits with references, and updates AGENTS.md. Atomic 1task=1commit workflow.
argument-hint: "[ | #N]"
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit
model: sonnet
---

# Code Execution from AGENTS.md

Execute next TODO task with automatic progress tracking.

## Usage

```bash
/code          # Execute next [TODO] task
/code #N       # Execute specific task #N
```

## Workflow

### Step 1: Read AGENTS.md

Load current task tracking file:

```bash
cat AGENTS.md
```

Extract:
- Current issue number
- Task list with statuses
- Acceptance criteria
- Files to modify

### Step 2: Find Next Task

**Mode: Automatic (no argument)**:
- Find first task with status `[TODO]`
- If no `[TODO]` found, check for `[BLOCKED]` and report

**Mode: Specific (#N)**:
- Find task with number N
- Verify it's not blocked by prerequisites

### Step 3: Display Task

Show what will be implemented:

```markdown
## Executing Task #N

**Task**: {description}
**Files**: {affected files}
**Status**: [TODO] → [WIP]

Updating AGENTS.md...
```

Update AGENTS.md task status to `[WIP]`.

### Step 4: Implement Task

Execute the task with these constraints:

**ONLY this task**: Don't implement related or future tasks
**Minimal changes**: Only what's needed for this specific task
**No over-engineering**: Don't add features not in task description

Implementation approach:
1. Read affected files
2. Make necessary changes
3. Add/update tests if specified
4. Keep changes focused

### Step 5: Verify

Run verification checks:

#### ✓ Compilation Check

```bash
# Go
go build ./...

# Node.js
npm run build

# Python
python -m py_compile {files}

# Rust
cargo check
```

**Requirement**: Must compile without errors

#### ✓ Task Acceptance

Check against task-specific acceptance criteria:
- Does implementation match task description?
- Are requirements met?
- No unrelated changes?

#### ✓ No Unrelated Changes

Verify only task-related files modified:
```bash
git status --short
```

### Step 6: Commit

Create atomic commit with standard format:

```bash
# Stage task-related files
git add {files}

# Create signed commit
git commit -s -S -m "{type}({scope}): {description}

{Optional longer explanation}

Refs: #{issue-number}
Task: {N}/{total}"
```

**Commit message parts**:
- **Type**: feat, fix, refactor, docs, test, chore
- **Scope**: Functional area (auth, api, db, etc.)
- **Description**: Concise summary
- **Refs**: GitHub issue number
- **Task**: Task number out of total

**Example**:
```bash
git commit -s -S -m "feat(auth): add user validation method

Validates email format and password strength before persistence.

Refs: #123
Task: 1/4"
```

### Step 7: Update AGENTS.md

Update task status and commit hash:

```markdown
## Tasks
| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Add User.Validate() method | [DONE] | abc1234 |
| 2 | Update handler | [TODO] | |
```

Mark task as `[DONE]` with commit hash.

### Step 8: Report Progress

Show completion status:

```markdown
## Task #N Complete ✓

**Commit**: abc1234
**Files Modified**:
- models/user.go
- models/user_test.go

**Progress**: 1/4 tasks complete (25%)

**Next Task**: #2 - Update handler to use validation
Run `/code` to continue
```

## BLOCKED Tasks

If task is marked `[BLOCKED: {reason}]`:

```markdown
## Task #N is BLOCKED

**Reason**: {blocking reason}

**To unblock**:
- {Action needed to unblock}

**Other available tasks**:
- Task #X: {description} [TODO]

Run `/code #X` to work on available task
```

## Reflection Checks

Before marking task complete, verify:

| Check | Question |
|-------|----------|
| **Single-concern** | Does commit change only one thing? |
| **Minimal** | Is this the smallest change that works? |
| **Compiles** | Does code build without errors? |
| **Tests** | If task requires tests, are they added? |
| **No extras** | No unrelated improvements or fixes? |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| **No AGENTS.md** | Run `/issue #N` or `/task {desc}` first to initialize |
| **No TODO tasks** | Check for [BLOCKED] tasks to unblock, or run `/test`, `/self-review` |
| **Dependency missing** | Work on prerequisite task first (check `blockedBy` field) |
| **Commit fails** | **GPG**: `git config --global user.signingkey {KEY}`<br>**Hook**: Fix lint errors<br>**Conflict**: `git pull --rebase` |
| **Build fails** | Check imports/interfaces, revert if needed: `git reset --soft HEAD~1` |

## Constraints

- **1 task = 1 commit**: Atomic commits for easy revert
- **Update AGENTS.md**: Always keep progress tracker current
- **Reference issue**: Commit messages must reference issue number
- **Verify before commit**: Must compile and meet task acceptance
- **Signed commits**: Always use `-S -s` flags
- **No feature creep**: Implement only what task describes

## When to Use

**Use /code when**:
- Executing tasks from AGENTS.md
- Need automatic progress tracking
- Want atomic commit workflow
- Working on planned issue

**Use /task instead when**:
- No AGENTS.md exists
- Ad-hoc task without planning
- Need full workflow (understand → specify → plan → implement)

## Related Skills

- `/issue` - Initialize AGENTS.md from GitHub issue
- `/task` - General task execution with full workflow
- `/test` - Run test suite after implementation
- `/self-review` - Review changes before pushing
