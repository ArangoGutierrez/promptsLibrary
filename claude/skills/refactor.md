---
name: refactor
description: Systematic refactoring workflow that preserves behavior while improving code quality. Analyzes code smells, creates refactoring plan, verifies tests exist, executes transformations incrementally, and validates after each step. Supports safe mode (extra validation) and fix-on-failure revert.
argument-hint: "[target] [--safe] [--aggressive] [--breaking]"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Task
model: sonnet
---

# Systematic Refactoring

Behavior-preserving code improvements with test-driven safety.

## Usage

```bash
/refactor {target}              # Refactor specific code/module
/refactor {target} --safe       # Extra validation, smaller steps
/refactor {target} --aggressive # Allow larger scope changes
/refactor {target} --breaking   # Allow functional changes (use carefully)
```

## Workflow

### Phase 1: Analyze

Identify code smells, complexity metrics, and duplication patterns.

**Actions**:
1. Read target code and related files
2. Identify code smells:
   - Long methods (> 50 lines)
   - Large classes (> 500 lines)
   - Duplicated code (copy-paste patterns)
   - Deep nesting (> 4 levels)
   - Many parameters (> 5)
3. Calculate complexity metrics:
   - Cyclomatic complexity
   - Coupling (dependencies)
   - Cohesion (related functionality)
4. Find duplication patterns
5. Check test coverage for target code

**Output**: Analysis report with identified issues

### Phase 2: Plan

Create a refactoring plan with specific transformations and rationale.

**Transformation catalog**:
- Extract method/function
- Rename variable/function
- Inline temporary
- Replace magic number with constant
- Extract interface
- Split class/module
- Move method
- Simplify conditional

**For each transformation**:
- **Name**: e.g., "Extract validation logic to ValidateUser()"
- **Rationale**: Why this improves code
- **Risk**: Low (safe) / Medium (needs care) / High (risky)
- **Tests required**: Yes/No
- **Dependencies**: Other transformations that must happen first
- **Impact**: Files affected

**Ordering rules**:
1. Safe transformations first (rename, extract constant)
2. Then structural changes (extract method)
3. Finally risky changes (move between modules)
4. Resolve dependencies (if B needs A, do A first)

**Output**: Ordered list of transformations with rationale

### Phase 3: Verify Tests

Ensure adequate test coverage exists before making changes.

**Actions**:
1. Run existing test suite: `/test`
2. Check if target code has tests
3. Measure coverage (if tool available)
4. Identify test gaps

**Coverage assessment**:
- ✅ **Good**: > 80% coverage, tests pass
- ⚠️ **Partial**: 50-80% coverage or some areas untested
- ❌ **Insufficient**: < 50% coverage or no tests

**If `--safe` flag**:
- Require ✅ Good coverage before proceeding
- Stop if coverage insufficient

**Otherwise**:
- Proceed with caution
- Document risk
- Add tests if transformations are risky

**Output**: Test coverage assessment

### Phase 4: Execute

Make changes incrementally, testing after each transformation.

**For each transformation**:

1. **Apply transformation**:
   - Use Edit tool for code changes
   - One transformation at a time
   - Keep changes minimal

2. **Compile check**:
   ```bash
   go build ./...          # Go
   npm run build           # Node.js
   python -m py_compile    # Python
   cargo check             # Rust
   ```

3. **Run tests**:
   ```bash
   /test
   ```

4. **Verify behavior preserved**:
   - All tests still pass?
   - No new compilation errors?
   - Functionality unchanged?

5. **Commit**:
   ```bash
   git add {files}
   git commit -s -S -m "refactor({scope}): {transformation name}

   {Brief explanation of refactoring}

   Behavior preserved - all tests pass."
   ```

6. **If tests fail**:
   ```bash
   git revert HEAD
   ```
   - Document why transformation failed
   - Adjust approach
   - Try again with modified transformation

**Progress tracking**: Update after each successful transformation

**Output**: Execution log with commits or reverts

### Phase 5: Validate

Run full test suite and compare behavior.

**Actions**:
1. Run full test suite: `/test`
2. Compare test results before/after refactoring
3. Check for performance regressions (if applicable)
4. Verify linting/formatting compliance
5. Confirm behavior preservation

**Validation checklist**:
- [x] All tests pass
- [x] No new warnings or errors
- [x] Performance not degraded
- [x] Code style compliant
- [x] Behavior unchanged

**Output**: Validation report

## Output Format

```markdown
# Refactoring Plan: {target}

## Analysis

### Code Smells Identified
| Issue | Location | Severity | Impact |
|-------|----------|----------|--------|
| Long method | `user.go:42` | Medium | Hard to test and understand |
| Duplication | `auth.go:15, admin.go:28` | High | DRY violation, maintenance burden |

### Complexity Metrics
- Cyclomatic Complexity: 15 (target: < 10)
- Coupling: High (8 dependencies)
- Cohesion: Medium

### Duplication
- Validation logic repeated in 3 places: `user.go:42`, `admin.go:28`, `api.go:88`

## Refactoring Plan

### Transformation 1: Extract validateEmail() function
**Rationale**: Reduce duplication, improve testability
**Risk**: Low - pure function, easy to extract
**Tests Required**: Yes - add unit test for validation
**Dependencies**: None
**Files**: `user.go`, `admin.go`, `api.go`

### Transformation 2: Split UserService into UserReader and UserWriter
**Rationale**: Improve cohesion, follow SRP
**Risk**: Medium - affects multiple call sites
**Tests Required**: Yes - verify all call sites still work
**Dependencies**: Transformation 1 (validation must be extracted first)
**Files**: `service.go`, `handler.go`

## Test Coverage
- **Current**: 75% (Partial)
- **Tests exist**: Yes
- **Gaps**: Validation logic not tested
- **Recommendation**: Add tests for validation before refactoring

## Execution Log

### ✓ Transformation 1: Extract validateEmail()
**Commit**: abc1234
**Tests**: ✓ Pass (42/42)
**Behavior**: ✓ Preserved
**Notes**: Created util/validation.go with extracted function

### ⚠️ Transformation 2: Split UserService (REVERTED)
**Status**: Reverted
**Reason**: Breaking change to public API, requires `--breaking` flag
**Tests**: ✗ Compilation failed
**Action**: Skipped this transformation

## Summary
- **Planned**: 2 transformations
- **Completed**: 1
- **Reverted**: 1
- **Skipped**: 0
- **Net result**: Code improved, duplication reduced, behavior preserved
```

## Flags Behavior

### --safe (Extra Validation)
- Require good test coverage (> 80%)
- Smaller transformation steps
- More frequent test runs
- Stop on any test failure

### --aggressive (Larger Changes)
- Allow larger scope transformations
- Can modify multiple files at once
- Still require tests to pass

### --breaking (Functional Changes)
- Allow changes that modify behavior
- Use for intentional API changes
- Still requires tests, but tests may change too
- Document behavior changes explicitly

## Constraints

- **Test-first**: Never refactor without tests
- **Incremental**: One transformation at a time
- **Behavior-preserving**: No functional changes (unless `--breaking`)
- **Commit-per-step**: Each transformation gets a commit
- **Verify-after-each**: Run tests after every transformation
- **Revert-on-failure**: If tests fail, revert immediately

## When to Use

**Use /refactor when**:
- Code smells identified
- Preparing for new features
- Improving maintainability
- Reducing technical debt
- Code review suggests improvements

**Don't refactor when**:
- No tests exist (write tests first)
- Under time pressure (defer to later)
- For style only (use formatter)
- "Because we can" (need clear benefit)

## Related Skills

- `/test` - Run tests after refactoring
- `/quality` - Code quality review
- `/self-review` - Review refactored code
