# Debug

Systematic debugging workflow to identify and fix issues efficiently.

## Usage
- `/debug {symptom}` — Debug an issue described by symptom
- `/debug --trace {error}` — Analyze stack trace or error message
- `/debug --bisect` — Binary search for regression point
- `/debug {symptom} --verbose` — Include detailed diagnostic output

## Workflow

### Phase 1: Reproduce
Define exact reproduction steps and conditions.

**Input**: Symptom description or error message
**Output**: Reproducible test case

**Actions**:
1. Understand the reported symptom
2. Identify exact steps to reproduce
3. Determine environment conditions (OS, versions, config)
4. Create minimal reproduction case if possible
5. Document reproduction steps

### Phase 2: Isolate
Narrow down scope to specific file, function, or line.

**Input**: Reproduction case
**Output**: Isolated scope of issue

**Actions**:
1. Use binary search to narrow scope
2. Add logging/breakpoints to trace execution
3. Eliminate unrelated code paths
4. Identify specific function/method involved
5. Pinpoint approximate line range

### Phase 3: Hypothesize
Form 2-3 theories about root cause.

**Input**: Isolated scope and symptoms
**Output**: List of hypotheses with test plans

**Actions**:
1. Analyze code in isolated scope
2. Review recent changes (git log, blame)
3. Form 2-3 specific hypotheses
4. Design experiments to test each hypothesis
5. Rank hypotheses by likelihood

### Phase 4: Test
Design and run experiments to test each theory.

**Input**: Hypotheses with test plans
**Output**: Evidence for/against each hypothesis

**Actions**:
1. Create test cases for each hypothesis
2. Run experiments (unit tests, manual tests, logging)
3. Collect evidence (logs, stack traces, state dumps)
4. Eliminate disproven hypotheses
5. Identify root cause

### Phase 5: Fix
Implement minimal fix that addresses root cause.

**Input**: Confirmed root cause
**Output**: Fix implementation

**Actions**:
1. Design minimal fix (smallest change that solves issue)
2. Implement fix
3. Ensure fix doesn't break existing functionality
4. Add regression test if missing
5. Document fix rationale

### Phase 6: Verify
Confirm fix resolves issue without side effects.

**Input**: Fix implementation
**Output**: Verification report

**Actions**:
1. Run reproduction case - should now pass
2. Run full test suite - ensure no regressions
3. Test edge cases related to fix
4. Verify fix in different environments if applicable
5. Document findings for future reference

## Output Format

```markdown
# Debug Report: {symptom}

## Reproduction

### Steps to Reproduce
1. {step 1}
2. {step 2}
3. {step 3}

### Environment
- OS: {version}
- Runtime: {version}
- Config: {relevant settings}

### Expected vs Actual
- **Expected**: {expected behavior}
- **Actual**: {actual behavior}

## Isolation

### Scope Narrowed To
- **File**: {file path}
- **Function**: {function name}
- **Lines**: {line range}

### Eliminated Areas
- {area}: {why eliminated}

## Hypotheses

### Hypothesis 1: {theory}
**Likelihood**: {high/medium/low}
**Test Plan**: {how to test}
**Evidence**: {results}
**Status**: {confirmed/rejected/pending}

### Hypothesis 2: {theory}
...

## Root Cause

**Identified**: {root cause}
**Location**: {file:line}
**Why**: {explanation}

## Fix

### Implementation
```{language}
{code changes}
```

### Rationale
{why this fix works}

### Testing
- [x] Reproduction case passes
- [x] Full test suite passes
- [x] Edge cases verified
- [x] No regressions introduced

## Documentation

### Key Learnings
- {learning point 1}
- {learning point 2}

### Prevention
- {how to prevent similar issues}
```

## Constraints
- **Evidence-based**: Every hypothesis needs a test
- **Minimal fix**: Don't fix unrelated issues
- **Document**: Record findings for future reference
- **Reproduce first**: Always reproduce before fixing
- **Isolate scope**: Narrow down before deep analysis
- **Test hypotheses**: Don't assume, verify

## Troubleshooting

### Cannot Reproduce Issue
**Problem**: Symptom doesn't occur in current environment
**Actions**:
1. Ask for more details about environment
2. Check for environment-specific conditions
3. Review recent changes that might have "fixed" it
4. Look for intermittent/timing-related issues
5. Check logs for error patterns

### Too Many Hypotheses
**Problem**: Many possible causes identified
**Solution**:
1. Rank by likelihood and ease of testing
2. Test most likely first
3. Use `--bisect` flag to find regression point
4. Focus on recent changes if regression suspected

### Fix Breaks Other Things
**Problem**: Fix resolves issue but introduces new problems
**Actions**:
1. Revert fix: `git revert HEAD`
2. Analyze why fix caused side effects
3. Redesign fix with broader context
4. Add integration tests to catch side effects
5. Consider alternative fix approach

### Intermittent Issue
**Problem**: Issue doesn't always reproduce
**Solution**:
1. Look for race conditions or timing issues
2. Check for resource leaks or state accumulation
3. Add extensive logging to catch when it occurs
4. Use stress testing to increase reproduction rate
5. Consider if it's a concurrency issue

### Root Cause Unclear
**Problem**: Tests don't clearly identify cause
**Actions**:
1. Add more detailed logging
2. Use debugger to step through execution
3. Review git history for recent changes
4. Check for external dependencies (APIs, files, env vars)
5. Consider if it's a configuration issue

### Bisect Finds No Regression
**Problem**: `--bisect` doesn't find a commit that introduced issue
**Solution**:
1. Issue may have always existed but recently discovered
2. Check if it's an environment or dependency change
3. Review if it's a data-specific issue
4. Consider if it's a cumulative effect (memory leak, etc.)
