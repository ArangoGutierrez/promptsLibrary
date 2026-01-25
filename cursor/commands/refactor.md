# Refactor

Systematic refactoring workflow that preserves behavior while improving code quality.

## Usage
- `/refactor {target}` — Refactor specific code/module
- `/refactor {target} --safe` — Extra validation, smaller steps
- `/refactor {target} --aggressive` — Larger scope changes allowed
- `/refactor {target} --breaking` — Allow functional changes

## Workflow

### Phase 1: Analyze
Identify code smells, complexity metrics, and duplication patterns.

**Input**: Target code path or module identifier
**Output**: Analysis report with identified issues

**Actions**:
1. Read target code and related files
2. Identify code smells (long methods, large classes, duplication, etc.)
3. Calculate complexity metrics (cyclomatic complexity, coupling, cohesion)
4. Find duplication patterns (copy-paste code, similar logic)
5. Check test coverage for target code

### Phase 2: Plan
Create a refactoring plan with specific transformations and rationale.

**Input**: Analysis report
**Output**: Refactoring plan with ordered transformations

**Actions**:
1. List specific transformations needed (extract method, rename variable, etc.)
2. Provide rationale for each transformation
3. Order transformations by dependency and risk
4. Identify test gaps that need coverage before refactoring
5. Estimate impact scope for each transformation

### Phase 3: Verify Tests
Ensure adequate test coverage exists before making changes.

**Input**: Refactoring plan
**Output**: Test coverage assessment

**Actions**:
1. Run existing test suite
2. Identify gaps in test coverage
3. If `--safe` flag: Require tests before proceeding
4. Document test status for each transformation

### Phase 4: Execute
Make changes incrementally, testing after each transformation.

**Input**: Refactoring plan
**Output**: Refactored code with commits

**Actions**:
1. Apply one transformation at a time
2. Run tests after each transformation
3. Verify behavior is preserved
4. Commit each successful transformation
5. If tests fail: Revert and adjust approach

### Phase 5: Validate
Run full test suite and compare behavior.

**Input**: Refactored code
**Output**: Validation report

**Actions**:
1. Run full test suite
2. Compare test results before/after
3. Verify no performance regressions
4. Check linting/formatting compliance
5. Confirm behavior preservation

## Output Format

```markdown
# Refactoring Plan: {target}

## Analysis

### Code Smells Identified
| Issue | Location | Severity | Impact |
|-------|----------|----------|--------|
| {smell} | {file:line} | {high/medium/low} | {description} |

### Complexity Metrics
- Cyclomatic Complexity: {value}
- Coupling: {value}
- Cohesion: {value}

### Duplication
- {pattern}: {locations}

## Refactoring Plan

### Transformation 1: {name}
**Rationale**: {why this change}
**Risk**: {low/medium/high}
**Tests Required**: {yes/no}
**Dependencies**: {other transformations}

### Transformation 2: {name}
...

## Execution Log

### ✓ Transformation 1: {name}
**Commit**: {hash}
**Tests**: ✓ Pass
**Behavior**: ✓ Preserved

### ⚠️ Transformation 2: {name}
**Status**: Reverted
**Reason**: {why reverted}
```

## Constraints
- **Test-first**: Never refactor without tests
- **Incremental**: One transformation at a time
- **Behavior-preserving**: No functional changes unless `--breaking` flag
- **Commit-per-step**: Each transformation gets a commit
- **Verify-after-each**: Run tests after every transformation
- **Revert-on-failure**: If tests fail, revert and adjust

## Troubleshooting

### No Tests Found
**Problem**: Target code lacks test coverage
**Solution**:
1. If `--safe` flag: Stop and require tests first
2. Otherwise: Document risk and proceed with caution
3. Add basic tests for critical paths before refactoring

### Tests Fail After Transformation
**Problem**: Behavior changed unintentionally
**Actions**:
1. Revert the transformation: `git revert HEAD`
2. Analyze why behavior changed
3. Adjust transformation approach
4. Re-apply with corrected logic

### Circular Dependencies
**Problem**: Refactoring creates circular imports/dependencies
**Solution**:
1. Identify dependency cycle
2. Extract shared code to common module
3. Restructure imports to break cycle
4. Verify tests still pass

### Large Scope Overwhelming
**Problem**: Too many transformations identified
**Actions**:
1. Prioritize by impact/risk ratio
2. Break into smaller refactoring sessions
3. Use `--safe` flag for incremental approach
4. Focus on highest-value transformations first

### Performance Regression
**Problem**: Refactored code is slower
**Solution**:
1. Profile before/after performance
2. Identify bottleneck introduced
3. Optimize specific transformation
4. Consider reverting if optimization not feasible
