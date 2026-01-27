---
name: debug
description: Systematic debugging workflow from reproduction to fix verification. Follows 6-phase approach - Reproduce, Isolate, Hypothesize, Test, Fix, Verify. Supports stack trace analysis and binary search for regressions. Evidence-based hypothesis testing with minimal fixes.
argument-hint: "[symptom] [--trace error] [--bisect] [--verbose]"
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit
model: sonnet
---

# Systematic Debugging

Evidence-based debugging from symptom to verified fix.

## Usage

```bash
/debug {symptom}              # Debug issue described by symptom
/debug --trace {error}        # Analyze stack trace or error message
/debug --bisect               # Binary search for regression point
/debug {symptom} --verbose    # Include detailed diagnostic output
```

## Workflow

### Phase 1: Reproduce

Define exact reproduction steps and conditions.

**Actions**:
1. Understand the reported symptom
2. Identify exact steps to reproduce
3. Determine environment conditions (OS, runtime version, config)
4. Create minimal reproduction case if possible
5. Document reproduction steps

**Output**: Reproducible test case

### Phase 2: Isolate

Narrow down scope to specific file, function, or line.

**Techniques**:
- Binary search: Comment out half the code, test, repeat
- Add logging at key points to trace execution
- Eliminate unrelated code paths
- Use git blame to find recent changes
- Check which tests fail

**Actions**:
1. Use binary search to narrow scope
2. Add logging/print statements to trace execution
3. Eliminate unrelated code paths
4. Identify specific function/method involved
5. Pinpoint approximate line range

**Output**: Isolated scope (file, function, line range)

### Phase 3: Hypothesize

Form 2-3 theories about root cause.

**For each hypothesis**:
- **Theory**: What do you think is wrong?
- **Likelihood**: High / Medium / Low
- **Test plan**: How to verify this theory?
- **Expected evidence**: What would confirm it?

**Actions**:
1. Analyze code in isolated scope
2. Review recent changes (`git log --oneline -n 10 {file}`)
3. Form 2-3 specific hypotheses
4. Design experiments to test each hypothesis
5. Rank hypotheses by likelihood

**Output**: List of hypotheses with test plans

### Phase 4: Test

Design and run experiments to test each theory.

**Experiment types**:
- Add assertions to verify assumptions
- Create unit test for suspected behavior
- Add logging to capture state
- Temporarily modify code to isolate cause
- Use debugger to inspect runtime state

**Actions**:
1. Create test cases for each hypothesis
2. Run experiments (unit tests, manual tests, logging)
3. Collect evidence (logs, stack traces, state dumps)
4. Eliminate disproven hypotheses
5. Identify root cause

**Output**: Evidence for/against each hypothesis, confirmed root cause

### Phase 5: Fix

Implement minimal fix that addresses root cause.

**Principles**:
- **Minimal**: Smallest change that solves the issue
- **Targeted**: Fix only the identified problem
- **No extras**: Don't fix unrelated issues
- **Tested**: Add regression test if missing

**Actions**:
1. Design minimal fix (smallest change that solves issue)
2. Implement fix
3. Ensure fix doesn't break existing functionality
4. Add regression test to prevent recurrence
5. Document fix rationale in commit message

**Output**: Fix implementation with test

### Phase 6: Verify

Confirm fix resolves issue without side effects.

**Actions**:
1. Run reproduction case - should now pass
2. Run full test suite - ensure no regressions
3. Test edge cases related to fix
4. Verify fix in different environments if applicable
5. Document findings for future reference

**Verification checklist**:
- [x] Reproduction case passes
- [x] Full test suite passes
- [x] Edge cases verified
- [x] No regressions introduced

**Output**: Verification report

## Output Format

```markdown
# Debug Report: {symptom}

## Reproduction

### Steps to Reproduce
1. Start server with `go run main.go`
2. Send POST request to `/api/login` with invalid JSON
3. Observe server panic and crash

### Environment
- OS: macOS 13.2
- Runtime: Go 1.21
- Config: Development mode

### Expected vs Actual
- **Expected**: Return 400 Bad Request with error message
- **Actual**: Server panics with "runtime error: invalid memory address"

## Isolation

### Scope Narrowed To
- **File**: `api/handler.go`
- **Function**: `HandleLogin`
- **Lines**: 42-58

### Binary Search Process
1. Commented out authentication logic → still panics
2. Commented out request parsing → no panic
3. Issue is in request parsing section

### Eliminated Areas
- Database layer: Not reached before panic
- Middleware: Panic occurs in handler
- Validation: Happens after panic point

## Hypotheses

### Hypothesis 1: Missing nil check on request body ⭐
**Likelihood**: High
**Test Plan**: Add logging before request parsing, check if body is nil
**Expected Evidence**: Log shows nil body when JSON is invalid
**Status**: ✓ **Confirmed**

**Evidence**: Added log statement at line 44:
```go
log.Printf("Request body: %v", r.Body)
```
Output shows: `Request body: <nil>`

### Hypothesis 2: JSON parser doesn't handle malformed input
**Likelihood**: Medium
**Test Plan**: Test json.Unmarshal with various invalid inputs
**Expected Evidence**: Unmarshal returns error but doesn't panic
**Status**: ✗ **Rejected**

**Evidence**: json.Unmarshal handles invalid JSON gracefully, returns error

### Hypothesis 3: Missing error handling
**Likelihood**: Medium
**Test Plan**: Check if error from parsing is handled
**Expected Evidence**: Error is ignored or unchecked
**Status**: ⚠️ **Partial**

**Evidence**: Error is checked, but body is accessed before check

## Root Cause

**Identified**: Request body is accessed without nil check before JSON parsing

**Location**: `api/handler.go:45`

**Why**: Code reads `r.Body` directly before checking if request parsing succeeded. When JSON is invalid, body might be nil, causing panic on access.

**Code**:
```go
func HandleLogin(w http.ResponseWriter, r *http.Request) {
    var req LoginRequest
    body := r.Body  // ← Bug: No nil check
    json.NewDecoder(body).Decode(&req)  // ← Panic here if body is nil
    // ...
}
```

## Fix

### Implementation
```go
func HandleLogin(w http.ResponseWriter, r *http.Request) {
    if r.Body == nil {
        http.Error(w, "request body required", http.StatusBadRequest)
        return
    }

    var req LoginRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid JSON", http.StatusBadRequest)
        return
    }
    // ...
}
```

### Rationale
- Check `r.Body != nil` before accessing it
- Return 400 Bad Request instead of panicking
- Add proper error handling for JSON decoding
- Minimal change - only adds necessary checks

### Regression Test
```go
func TestHandleLogin_InvalidJSON(t *testing.T) {
    req := httptest.NewRequest("POST", "/api/login", nil)
    rec := httptest.NewRecorder()

    HandleLogin(rec, req)

    if rec.Code != http.StatusBadRequest {
        t.Errorf("expected 400, got %d", rec.Code)
    }
}
```

## Verification

### Testing
- [x] Reproduction case passes - server returns 400 instead of panicking
- [x] Full test suite passes - all 42 tests pass
- [x] Edge cases verified:
  - [x] nil body
  - [x] empty body
  - [x] malformed JSON
  - [x] valid JSON
- [x] No regressions introduced

### Key Learnings
- Always check for nil before dereferencing
- Handle errors immediately after operations
- Add nil checks at API boundaries

### Prevention
- Add linter rule for nil dereference
- Review all API handlers for similar pattern
- Add integration tests for malformed requests

## Commit
```bash
git add api/handler.go api/handler_test.go
git commit -s -S -m "fix(api): handle nil request body in login handler

Fixes panic when invalid JSON is sent to /api/login endpoint.
Added nil check and proper error handling.

Root cause: Request body was accessed without checking if it was nil,
causing panic when JSON parsing failed.

Refs: #debug-session-2024-01-27"
```
```

## Special Modes

### --trace (Stack Trace Analysis)

When invoked with `--trace {error}`:
1. Parse stack trace
2. Identify entry point and failure point
3. Trace execution path
4. Focus isolation on specific functions in trace
5. Skip reproduction phase (already have error)

### --bisect (Binary Search for Regression)

When invoked with `--bisect`:
1. Find last known good commit
2. Use `git bisect` to find regression point
3. Test each commit between good and bad
4. Identify exact commit that introduced bug
5. Review that commit's changes

```bash
git bisect start
git bisect bad HEAD
git bisect good {last-known-good-commit}
# Test each revision
git bisect good/bad
```

### --verbose (Detailed Output)

Include detailed diagnostic information:
- Full stack traces
- Complete log output
- Environment details
- All hypothesis test results

## Constraints

- **Evidence-based**: Every hypothesis needs a test
- **Minimal fix**: Don't fix unrelated issues
- **Document**: Record findings for future reference
- **Reproduce first**: Always reproduce before fixing
- **Isolate scope**: Narrow down before deep analysis
- **Test hypotheses**: Don't assume, verify

## When to Use

**Use /debug when**:
- Systematic issue investigation needed
- Bug is difficult to reproduce
- Root cause is unclear
- Multiple possible causes
- Need to document debugging process

**Don't use /debug for**:
- Obvious bugs (fix directly)
- Compilation errors (use compiler output)
- Known issues with clear fixes
- Urgent production incidents (fix first, debug later)

## Related Skills

- `/research` - Investigate issues in codebase
- `/test` - Run test suite
- `/quality` - Multi-agent code review
