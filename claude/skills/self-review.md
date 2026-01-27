---
name: self-review
description: Quick review of changes vs main branch before pushing. Reviews git diff for correctness, style, security, and test coverage. Provides verdict (Ready/Minor fixes/Needs work) and updates AGENTS.md. Fast pre-push quality check focusing on common issues.
disable-model-invocation: false
allowed-tools: Bash, Read, Edit
model: haiku
---

# Self-Review

Quick review of your changes before pushing.

## Usage

```bash
/self-review      # Review changes vs main branch
```

## Workflow

### Step 1: Get Changes Summary

```bash
# Show commit history since main
git log --oneline main..HEAD

# Show file statistics
git diff main..HEAD --stat

# Show full diff
git diff main..HEAD
```

Extract:

- Number of commits
- Files changed
- Lines added/removed

### Step 2: Review Summary

Present overview:

```
## Changes Since Main

**Commits**: 3
**Files**: 5 changed (+142, -38)
**Branch**: feat/user-auth
```

### Step 3: Review Each File

For each changed file, check 4 aspects:

#### A. Correctness

- **Logic**: Is the logic sound?
- **Edge cases**: Handled empty/nil/max values?
- **Bugs**: Any obvious bugs?
- **Compilation**: Will it compile/run?

#### B. Style

- **Patterns**: Follows project conventions?
- **Naming**: Clear, consistent names?
- **Debug code**: Left-over console.log, print statements?
- **Comments**: Outdated or redundant comments?

#### C. Security

- **Secrets**: No hardcoded tokens/keys?
- **Input validation**: User input validated?
- **Error safety**: No sensitive data in errors?
- **SQL injection**: Parameterized queries?

#### D. Tests

- **New code tested**: Changes have test coverage?
- **Tests meaningful**: Tests verify behavior?
- **Tests pass**: All tests passing?

### Step 4: Categorize Findings

Classify issues by severity:

**✅ Good**: No issues, approved

**⚠️ Consider** (Minor, optional fixes):

- File: `path/to/file.go:42`
- Issue: {description}
- Suggestion: {optional improvement}

**❌ Fix Required** (Must fix before merge):

- File: `path/to/file.go:88`
- Issue: {description}
- Fix: {required change}

### Step 5: Generate Verdict

Assess overall readiness:

| Aspect | Status | Notes |
|--------|--------|-------|
| **Correctness** | ✓ / ⚠️ / ✗ | Logic sound, edge cases handled |
| **Style** | ✓ / ⚠️ / ✗ | Follows conventions |
| **Security** | ✓ / ⚠️ / ✗ | No secrets, input validated |
| **Tests** | ✓ / ⚠️ / ✗ | Coverage adequate, tests pass |

**Overall Verdict**:

- ✅ **Ready**: Can push now
- ⚠️ **Minor Fixes**: Optional improvements
- ❌ **Needs Work**: Must fix issues before pushing

### Step 6: Update AGENTS.md

Mark self-review as complete:

```markdown
## Tasks
| # | Task | Status | Commit |
|---|------|--------|--------|
| ... | ... | [DONE] | abc1234 |
| N | Self-review | [DONE] | |
```

## Output Format

```markdown
## Self-Review: {branch}

### Changes Summary
- **Commits**: 3
- **Files**: 5 (+142, -38)
- **Branch**: feat/user-auth vs main

### Review by File

#### auth/handler.go ✓
**Correctness**: ✓ Logic sound
**Style**: ✓ Follows conventions
**Security**: ✓ Input validated
**Tests**: ✓ Covered in auth_test.go

#### models/user.go ⚠️
**Correctness**: ✓ Logic sound
**Style**: ⚠️ Consider shorter function
**Security**: ✓ No issues
**Tests**: ✓ Comprehensive tests

**Suggestions**:
- Line 42: Consider extracting validation logic to separate function
- Line 88: Variable name `tmp` could be more descriptive

#### api/routes.go ❌
**Correctness**: ✗ Missing nil check
**Style**: ✓ Follows conventions
**Security**: ✗ Missing auth check
**Tests**: ✗ No tests for new route

**Required Fixes**:
- Line 28: Add nil check on request.User
- Line 28: Add authentication middleware
- Add integration test for new /api/profile route

### Assessment

| Aspect | Status | Notes |
|--------|--------|-------|
| Correctness | ⚠️ | One nil check missing |
| Style | ✓ | Clean code, minor naming suggestion |
| Security | ✗ | Missing auth check (CRITICAL) |
| Tests | ⚠️ | New route needs tests |

### Verdict: ❌ **Needs Work**

**Blocking issues**:
1. api/routes.go:28 - Missing authentication middleware (Security)
2. api/routes.go:28 - Missing nil check (Correctness)
3. Missing tests for new /api/profile route (Tests)

### Recommendations
1. Fix security issue in api/routes.go (CRITICAL)
2. Add nil check for defensive programming
3. Add integration test for new route
4. Optional: Rename `tmp` variable in models/user.go

### Next Steps
- Run `/code` to fix blocking issues
- Run `/test` to verify after fixes
- Run `/self-review` again before pushing
```

## Issue Loop Integration

If issues found, integrate with code workflow:

```markdown
### Issues Found

List: file:line + issue + fix

**To fix**: Run `/code` to implement fixes, then `/self-review` again
```

## Constraints

- **Fast**: Should complete in < 1 minute
- **Focus on common issues**: Not exhaustive (use `/quality` for deep review)
- **Actionable**: Every issue has suggested fix
- **No false positives**: Only flag real issues
- **Update AGENTS.md**: Mark self-review as [DONE]

## When to Use

**Use /self-review when**:

- Before pushing to remote
- Before creating PR
- After completing task batch
- Quick quality check

**Use /quality instead when**:

- Need comprehensive review
- Before important merge
- Reviewing someone else's code
- Need security/performance deep-dive

## Related Skills

- `/quality` - Comprehensive multi-agent review
- `/test` - Run test suite
- `/git-polish` - Polish commit history
- `/code` - Fix issues found in review
