# Review CLI Work

Review and validate implementation completed via Claude CLI in the terminal.

## Usage
- `/review-cli-work` — Review latest CLI implementation
- `/review-cli-work .plans/plan-*.md` — Review specific plan file
- `/review-cli-work --branch {name}` — Review work on specific branch

## What It Does

After implementation in terminal via `claude code`, this command:

1. **Loads Original Plan**: Reads the `.plans/plan-*.md` file used
2. **Analyzes Changes**: Reviews git diff since plan was created
3. **Validates Acceptance**: Checks if acceptance criteria met
4. **Runs Verification**: Tests, lints, type-checks
5. **Provides Feedback**: What's done, what's missing, suggestions

## Workflow

```
┌─────────────────────────┐
│ Cursor: /architect      │
│ [Discussion with Opus]  │
└────────────┬────────────┘
             │
             ▼
      /export-plan
             │
             ▼
┌─────────────────────────┐
│ Terminal: claude code   │
│ [Implementation]        │
└────────────┬────────────┘
             │
             ▼
      /review-cli-work  ← YOU ARE HERE
             │
             ▼
┌─────────────────────────┐
│ Cursor: Review & Polish │
│ [Final touches]         │
└─────────────────────────┘
```

## What Gets Checked

### 1. Acceptance Criteria
- [ ] All P0 tasks from plan completed
- [ ] Acceptance criteria from spec met
- [ ] Edge cases handled

### 2. Technical Quality
- [ ] Code compiles/type-checks
- [ ] Tests pass
- [ ] Lints clean
- [ ] No security issues

### 3. Alignment with Plan
- [ ] Follows selected approach
- [ ] Respects constraints (MUST/MUST NOT)
- [ ] Trade-offs as expected
- [ ] No scope creep

### 4. Completeness
- [ ] Expected files created
- [ ] Tests written (if --tdd)
- [ ] Documentation updated
- [ ] Commits follow convention

## Output Format

```markdown
## Review: {Plan Title}

### Plan Reference
- File: `.plans/plan-arch-20260127-143022.md`
- Created: 2026-01-27 14:30:22
- Branch: `feature/add-caching`

### Changes Detected
- Files modified: 12
- Files added: 3
- Tests added: 8
- Lines changed: +450 / -120

### Acceptance Status

| Criterion | Status | Notes |
|-----------|--------|-------|
| {criterion} | ✅ | Validated |
| {criterion} | ⚠️  | Partial |
| {criterion} | ❌ | Missing |

### Technical Checks

- ✅ Compiles
- ✅ Tests pass (24/24)
- ⚠️  Linter warnings (3)
- ✅ Security scan clean

### Alignment with Plan

**Selected Approach**: Redis-based caching
- ✅ Follows approach 2 from plan
- ✅ Respects MUST constraints
- ⚠️  Performance constraint untested

**Trade-offs Accepted**:
- ✅ Redis dependency added (expected)
- ✅ Increased complexity (expected)

### Issues Found

1. **Missing**: Cache invalidation strategy (mentioned in plan)
2. **Concern**: No error handling for Redis connection failures
3. **Style**: Some variable names don't match project conventions

### Recommendations

#### Must Fix (P0)
- [ ] Add cache invalidation logic
- [ ] Add Redis error handling

#### Should Fix (P1)
- [ ] Rename variables per style guide
- [ ] Add performance benchmarks

#### Nice to Have (P2)
- [ ] Add monitoring/metrics
- [ ] Document cache key patterns

### Next Steps

1. Fix P0 issues listed above
2. Run `/test` to validate fixes
3. Run `/self-review` for final check
4. Run `/git-polish` to clean up commits
5. Create PR with `/push`
```

## Integration with Other Commands

### After CLI work
```bash
# Back in Cursor
/review-cli-work
/test                    # If issues found
/refactor               # If code needs cleanup
/git-polish             # Clean up commits
/push                   # Create PR
```

### If major issues found
```bash
/review-cli-work
# Shows significant gaps
/task "Complete missing pieces from plan" --tdd
```

## Finding the Plan File

The command automatically:
1. Checks for recent `.plans/plan-*.md` files
2. Matches based on current git branch
3. Prompts if multiple candidates found
4. Falls back to asking user

## Notes

- Reviews only committed changes (commit first in terminal)
- Compares against plan's acceptance criteria
- Checks git metadata (branch, commits, PR links)
- Can detect if implementation diverged from plan
- Suggests next commands based on findings
