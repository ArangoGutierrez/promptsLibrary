---
name: issue
description: Fetch and analyze GitHub issue, create implementation plan with atomic tasks in AGENTS.md. Fetches issue details, classifies complexity/scope, researches codebase, designs approaches, breaks down into 1task=1change=1test=1commit, creates branch, and initializes AGENTS.md for tracking.
argument-hint: "[#N]"
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Task
model: sonnet
---

# GitHub Issue to Implementation Plan

Convert GitHub issue into actionable implementation plan with atomic tasks.

## Usage

```bash
/issue #123      # Analyze issue and create plan
```

## Workflow

### Step 1: Fetch Issue Data

Get repository and issue information:

```bash
# Get repository URL
git remote get-url origin
# Result: https://github.com/owner/repo

# Fetch issue details
gh issue view $ARGUMENTS --json title,body,labels,state,comments,milestone
```

Extract:
- Title and body
- Labels
- State (open/closed)
- All comments
- Linked PRs
- Related issues

### Step 2: Classify Issue

Analyze and categorize:

**Type**:
- `bug` - Broken functionality
- `feat` - New feature
- `refactor` - Code improvement
- `docs` - Documentation
- `perf` - Performance
- `sec` - Security

**Scope**:
- `local` - Single file/function
- `cross` - Multiple files/modules
- `arch` - Architectural change

**Complexity**:
- `trivial` - < 1 hour, obvious
- `simple` - 1-4 hours, straightforward
- `moderate` - 4-8 hours, some unknowns
- `complex` - > 8 hours, many unknowns

### Step 3: Research Codebase

Investigate mentioned code:

- Files/packages mentioned in issue
- Stack traces → source files
- Related test files
- Similar patterns in codebase

Use Task tool with researcher agent if needed for deep investigation.

### Step 4: Design Approaches

Generate 2-3 implementation approaches:

| # | Approach | Effort | Risk | Trade-offs |
|---|----------|--------|------|------------|
| 1 | {Name} | L/M/H | L/M/H | +{Pro}, -{Con} |
| 2 | {Name} | L/M/H | L/M/H | +{Pro}, -{Con} |

**Select best**: Choose based on effort/impact ratio

### Step 5: Break Into Atomic Tasks

Create task list where:
- **1 task = 1 change = 1 test = 1 commit**
- Each task is independently verifiable
- Tasks ordered by dependency

**Good task examples**:
- ✓ "Add User.Validate() method with tests"
- ✓ "Update handler to call User.Validate()"
- ✓ "Add integration test for validation"

**Bad task examples**:
- ✗ "Fix authentication" (too vague)
- ✗ "Update multiple files" (not atomic)
- ✗ "Add feature" (too large)

### Step 6: Verify Prerequisites

Check before proceeding:
- ✓ **Files exist**: Mentioned files are present?
- ✓ **Behavior understood**: Can read and understand the code?
- ✓ **Current**: Issue reflects latest codebase state?

### Step 7: Create Branch

Create feature branch following naming convention:

```bash
# Checkout and update main
git checkout main
git pull

# Create feature branch
git checkout -b {type}/issue-{N}-{slug}
```

**Branch naming**:
- `feat/issue-123-add-user-auth`
- `fix/issue-456-null-pointer`
- `refactor/issue-789-extract-validation`

### Step 8: Initialize AGENTS.md

Create or update `AGENTS.md` in project root:

```markdown
# Current Task

**Issue**: #$ARGUMENTS - {title}
**Status**: IN_PROGRESS
**Branch**: `{type}/issue-{N}-{slug}`
**Type**: {bug|feat|refactor|docs|perf|sec}
**Complexity**: {trivial|simple|moderate|complex}

## Tasks

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Add User.Validate() method | [TODO] | |
| 2 | Update handler to use validation | [TODO] | |
| 3 | Add unit tests for validation | [TODO] | |
| 4 | Add integration tests | [TODO] | |

## Files to Modify
- `models/user.go` - Add Validate() method
- `handlers/auth.go` - Call validation
- `models/user_test.go` - Unit tests
- `handlers/auth_test.go` - Integration tests

## Acceptance Criteria
- [ ] Invalid email returns error
- [ ] Empty password rejected
- [ ] Valid input passes validation
- [ ] All tests pass

## Approach
Using approach #1: Add validation layer before persistence
- Lower risk than changing database schema
- Easier to test
- Can be done incrementally

## Notes
- Consider adding validation middleware for future endpoints
- Email regex from RFC 5322
- Password min length: 8 chars
```

**IMPORTANT**: Preserve existing AGENTS.md content if file exists.

## Output Format

```markdown
## Issue #$ARGUMENTS: {title}

**Type**: {type} | **Scope**: {scope} | **Complexity**: {complexity}

### Summary
{2-3 sentence description}

### Branch Created
```bash
git checkout -b {type}/issue-{N}-{slug}
```

### Task Breakdown
{N} atomic tasks created in AGENTS.md

| # | Task | Estimated |
|---|------|-----------|
| 1 | Add User.Validate() method | 15 min |
| 2 | Update handler | 10 min |
| 3 | Add unit tests | 20 min |
| 4 | Add integration tests | 15 min |

**Total estimated effort**: ~1 hour

### Next Steps
1. Review AGENTS.md task list
2. Run `/code` to implement first task
3. Continue with `/code` for subsequent tasks

### Files
AGENTS.md initialized with full plan
```

## Constraints

- **1 task = 1 commit**: Each task must be independently committable
- **Atomic tasks**: Tasks must be self-contained
- **Ordered by dependency**: Prerequisites listed first
- **Verifiable**: Each task has clear acceptance criteria
- **Preserve AGENTS.md**: Don't overwrite existing content

## When to Use

**Use /issue when**:
- Starting work on GitHub issue
- Need structured plan
- Want task tracking
- Working on unfamiliar code

**Don't use /issue for**:
- Already have clear plan
- Trivial one-line fixes
- Non-GitHub work

## Related Skills

- `/research` - Deep issue investigation (called internally if needed)
- `/code` - Execute next TODO from AGENTS.md
- `/task` - General task execution (without GitHub issue)
