# Self-Review

Review all changes before pushing.

## Usage
- (no args) — Review changes vs main branch

## Workflow

### 1. Get Changes
```bash
git log --oneline main..HEAD           # Commits
git diff main..HEAD --stat             # Changed files
git diff main..HEAD                    # Full diff
```

### 2. Review Summary
```
## Self-Review: {branch}

**Commits:** {N} commits
**Files:** {N} files changed
**Lines:** +{additions} / -{deletions}

### Commits
| Hash | Message |
|------|---------|
| {hash} | {message} |
```

### 3. Check Each File

For each changed file:

#### A. Correctness
- [ ] Logic is correct?
- [ ] Edge cases handled?
- [ ] No obvious bugs?

#### B. Style
- [ ] Follows codebase patterns?
- [ ] Good naming?
- [ ] No debug code left?

#### C. Security
- [ ] No hardcoded secrets?
- [ ] Input validated?
- [ ] Errors handled safely?

#### D. Tests
- [ ] New code has tests?
- [ ] Tests are meaningful?

### 4. Generate Report
```
## Review: {branch}

### ✅ Good
- {positive observations}

### ⚠️ Consider
- `{file}:{line}` — {suggestion}

### ❌ Fix Before Push
- `{file}:{line}` — {required fix}

### Summary
| Aspect | Status |
|--------|--------|
| Correctness | ✓/⚠/✗ |
| Style | ✓/⚠/✗ |
| Security | ✓/⚠/✗ |
| Tests | ✓/⚠/✗ |

**Verdict:** ✅ Ready to push / ⚠️ Minor fixes needed / ❌ Needs work
```

### 5. Update AGENTS.md
If "Self-review" task exists:
- Mark `[DONE]` after review complete

## If Issues Found
```
## Changes Needed

1. `{file}:{line}` — {issue}
   **Fix:** {suggested fix}

Run `/code` to fix, then `/self-review` again.
```

## Constraints
- **All changes**: Review entire diff, not just latest commit
- **Honest**: Flag real issues, don't rubber-stamp
- **Actionable**: Specific file:line for each issue
- **Update AGENTS.md**: Mark review task done
