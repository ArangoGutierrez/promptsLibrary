---
name: task
description: Structured task execution workflow from understanding through verification. Use for implementing features, fixing bugs, or completing GitHub issues. Follows 5-phase approach - Understand, Specify, Plan, Implement, Verify. Maintains AGENTS.md for progress tracking and supports TDD workflow.
argument-hint: "[description | #N] [--plan] [--tdd]"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Task, AskUserQuestion
model: sonnet
---

# Task Execution Workflow

Structured approach to implementing tasks from understanding to verification.

## Usage

```bash
/task {description}        # Execute task with full workflow
/task #123                 # Execute GitHub issue #123
/task {desc} --plan        # Stop after planning phase for approval
/task {desc} --tdd         # Use test-driven development approach
```

## Phase 1: UNDERSTAND (10% of effort)

### Get Repository Context

```bash
git remote get-url origin
git rev-parse --show-toplevel
```

### Fetch Issue Data (if GitHub issue)

If task starts with `#`:

```bash
gh issue view 123 --json title,body,labels,state,comments,milestone
```

Extract:

- Title and body
- Labels
- Comments and discussion
- Linked PRs
- Related issues

### Clarify Requirements

Ask ≤ 2 clarifying questions using AskUserQuestion if:

- Requirements are ambiguous
- Multiple valid interpretations exist
- Scope is unclear
- Technology choices needed

## Phase 2: SPECIFY (15% of effort)

Define the contract for this task:

| Element | Definition |
|---------|------------|
| **Input** | What data/state enters this code? |
| **Output** | What changes occur (return value, side effects, state mutations)? |
| **Constraints** | Performance, security, style requirements |
| **Acceptance** | How to verify it's correct? |
| **Edge Cases** | How should it fail or handle boundaries? |
| **Out of Scope** | What are we explicitly NOT doing? |

### Constraints Template

Categorize requirements:

**MUST** (≤ 7 critical requirements):

- {Critical requirement 1}
- {Critical requirement 2}

**SHOULD** (nice to have):

- {Enhancement 1}

**MUST NOT**:

- {Forbidden action 1}

**Security** (always check):

- No secrets in code or logs
- Input validation for user data
- Safe error messages (no stack traces to users)

## Phase 3: PLAN (with --plan flag)

Generate 2-3 implementation approaches:

| # | Approach | Effort | Risk | Trade-offs |
|---|----------|--------|------|------------|
| 1 | {Name} | L/M/H | L/M/H | +{Pro}, -{Con} |
| 2 | {Name} | L/M/H | L/M/H | +{Pro}, -{Con} |

### Select Approach

**Selected**: {Approach N}

**Reasoning**: {Why this approach is best}

### Stop for Approval

If `--plan` flag is present:

- Output the plan
- Show selected approach
- Display: **⚠️ AWAITING USER APPROVAL - Please type "GO" to proceed**
- STOP and wait

If no `--plan` flag: Continue to Phase 4

## Phase 4: IMPLEMENT

### Test-Driven Development (with --tdd flag)

If `--tdd` is present, follow red-green-refactor cycle:

1. **Write failing test**: Create test that defines expected behavior
2. **Confirm failure**: Run test suite, verify it fails for right reason
3. **Minimal implementation**: Write just enough code to pass
4. **Verify success**: Run tests again, should pass
5. **Refactor**: Clean up implementation without changing behavior
6. **Repeat**: Next test case

### Regular Implementation (without --tdd)

Execute the plan:

1. Update AGENTS.md with task list
2. Implement changes
3. Write/update tests
4. Verify compilation
5. Run tests

### Progress Tracking

Maintain `AGENTS.md` in project root:

```markdown
# Current Task

**Issue**: #{N} - {title}
**Status**: IN_PROGRESS
**Branch**: `{type}/issue-{N}-{slug}`

## Tasks

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | {Task description} | [TODO] | |
| 2 | {Task description} | [WIP] | |
| 3 | {Task description} | [DONE] | abc1234 |

## Files Modified
- `path/to/file1.go`
- `path/to/file2.go`

## Acceptance Criteria
- [ ] {Criterion 1}
- [ ] {Criterion 2}

## Notes
{Any relevant context or decisions}
```

**Preserve existing content** when updating AGENTS.md.

## Phase 5: VERIFY

Run comprehensive verification:

### ✓ Compilation

```bash
# Go
go build ./...

# Node.js
npm run build

# Python
python -m py_compile **/*.py
```

### ✓ Tests

```bash
# Run full test suite
go test ./...        # Go
npm test             # Node.js
pytest               # Python
```

### ✓ Acceptance Criteria

For each criterion in spec:

- [ ] {Criterion}: ✓ Met / ✗ Not met / ⚠️ Partially

### ✓ Edge Cases

Test boundary conditions:

- Empty input
- Nil/null values
- Maximum values
- Error conditions
- Concurrent access (if applicable)

## Reflection

Before marking complete, verify:

| Check | Question |
|-------|----------|
| **Logic** | Does anything contradict itself? |
| **Complete** | Are all requirements met? |
| **Correct** | Does output match acceptance criteria? |
| **Edge** | Are boundary conditions handled? |
| **External** | Are external tools/dependencies working? |

## Commit

Create atomic commit with conventional format:

```bash
git add {files}
git commit -s -S -m "type(scope): description

Longer explanation if needed.

Refs: #{issue-number}
Task: {N}/{total}"
```

**Types**: feat, fix, refactor, docs, test, chore, perf, style

## Pull Request

Create PR only if task is complete:

```bash
gh pr create \
  --title "type(scope): description" \
  --body "Fixes #${issue_number}

## Summary
{Brief summary}

## Changes
- {Change 1}
- {Change 2}

## Testing
- {Test approach}

## Checklist
- [x] Tests pass
- [x] Acceptance criteria met
- [x] Code reviewed (self-review)
- [x] Documentation updated"
```

⚠️ **DO NOT auto-merge** - Always wait for review

## Budget Estimates

| Complexity | Max Turns | When to Escalate |
|------------|-----------|------------------|
| Trivial | 1 turn | If it takes > 1 turn |
| Simple | 2 turns | If it takes > 2 turns |
| Moderate | 3 turns | If it takes > 3 turns |
| Complex | 4 turns | If it takes > 4 turns |

If exceeding budget: Stop and ask user if should continue or break into subtasks.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| **No AGENTS.md** | Run `/issue #{N}` or `/task {desc}` first to initialize |
| **No TODO tasks** | Check for [BLOCKED] tasks; unblock or run `/test` or `/self-review` |
| **Dependency missing** | Work on prerequisite task first; update AGENTS.md with blocker |
| **Commit fails** | GPG: `git config --global user.signingkey {KEY}`<br>Hook: Fix lint errors<br>Conflict: `git pull --rebase` |
| **Build fails** | Check imports/interfaces<br>Revert if needed: `git reset --soft HEAD~1` |

## Constraints

- **1 task = 1 commit**: Atomic commits for easy revert
- **Update AGENTS.md**: Always keep progress tracker current
- **Reference issue**: Commit messages must reference issue number
- **Verify before commit**: Must compile and pass tests
- **TDD discipline**: If --tdd flag present, must write test first
- **Stop at plan**: If --plan flag present, must stop and await approval

## When to Use

**Use /task when**:

- Implementing well-defined features
- Fixing bugs with known scope
- Working on GitHub issues
- Need structured workflow
- Want progress tracking

**Don't use /task for**:

- Exploratory work (use `/research`)
- Architecture decisions (use `/architect`)
- Code review (use `/quality` or `/self-review`)

## Related Skills

- `/issue` - Research GitHub issue and create plan
- `/code` - Execute next TODO from AGENTS.md
- `/test` - Run test suite
- `/self-review` - Review changes before PR
- `/research` - Investigate issue before implementation
