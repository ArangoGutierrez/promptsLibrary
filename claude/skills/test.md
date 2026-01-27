---
name: test
description: Run test suites with automatic detection and targeted testing. Detects test framework (Go, Node.js, Python, Rust) and runs appropriate commands. Supports full suite, quick mode (changed files), and specific file testing. Updates AGENTS.md with results.
argument-hint: "[--quick] [--file path]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit
model: haiku
---

# Test Runner

Automatic test suite detection and execution with smart targeting.

## Usage

```bash
/test                  # Run full test suite
/test --quick          # Run tests for changed files only
/test --file {path}    # Run tests for specific file
```

## Test Framework Detection

Automatically detect test framework based on project files:

| File Present | Framework | Command |
|--------------|-----------|---------|
| `go.mod` | Go | `go test ./...` |
| `package.json` | Node.js/npm | `npm test` |
| `pyproject.toml` or `requirements.txt` | Python/pytest | `pytest` |
| `Cargo.toml` | Rust | `cargo test` |

## Execution Modes

### Mode 1: Full Suite (default)

Run all tests in the project:

```bash
# Example for Go
go test ./... -v

# Capture: Status (PASS/FAIL), Count (pass/total), Duration
```

**Output variables**:
- Status: PASS | FAIL
- Tests passed: N
- Tests total: M
- Duration: X.XXs

### Mode 2: Quick Mode (--quick)

Run tests only for files changed since last commit:

```bash
# Get changed files
git diff --name-only HEAD~1

# Map to test files and run targeted tests
# Go: go test ./path/to/changed/...
# Node: npm test -- --findRelatedTests file.js
# Python: pytest path/to/test_file.py
# Rust: cargo test --package {package}
```

**Benefits**:
- Faster feedback loop
- Relevant test results
- Useful for TDD workflow

### Mode 3: Specific File (--file {path})

Run tests for a specific file or package:

```bash
# Go
go test ./path/to/package

# Node.js
npm test -- path/to/test.js

# Python
pytest path/to/test_file.py

# Rust
cargo test --package {package-name}
```

## Output Format

### Success (All tests pass)

```markdown
## ✅ Tests Passed

**Framework**: Go
**Command**: `go test ./...`
**Status**: PASS
**Tests**: 42/42 passed
**Duration**: 2.34s

### AGENTS.md Update
- Run tests → [DONE]
```

### Failure (Some tests fail)

```markdown
## ❌ Tests Failed

**Framework**: Go
**Command**: `go test ./...`
**Status**: FAIL
**Tests**: 38/42 passed (4 failed)
**Duration**: 2.87s

### Failed Tests

| Test | Error | Suggested Fix |
|------|-------|---------------|
| `TestUserLogin` | panic: runtime error: invalid memory address | Check nil pointer in handler.go:142 |
| `TestGetProfile` | expected 200, got 500 | API call failing, check auth middleware |

### Next Steps
1. Fix test failures
2. Re-run with `/test`
3. Use `/code` to implement fixes

### AGENTS.md Update
- Run tests → [BLOCKED: tests failing]
```

## AGENTS.md Integration

After test run, update AGENTS.md:

**If tests pass**:
```markdown
- [ ] Run tests → [DONE]
```

**If tests fail**:
```markdown
- [ ] Run tests → [BLOCKED: tests failing]
- [ ] Fix test failures → [TODO]
```

Preserve all existing AGENTS.md content.

## Troubleshooting Guide

| Issue | Diagnosis | Fix |
|-------|-----------|-----|
| **No test framework detected** | Missing `go.mod`, `package.json`, etc. | Run manually: `go test`, `npm test`, `pytest`, `cargo test` |
| **Tests pass locally but fail in skill** | Environment differences | Check: env vars, DB running, port conflicts, clear cache |
| **Flaky tests** | Intermittent failures | Run with: `-count=10` (Go), check for: races, time dependencies, shared state |
| **Tests hanging** | Infinite loop or waiting | Check: loops/I/O, add timeouts, verbose mode, missing mocks |
| **Compilation errors** | Build fails before tests run | Fix build first: check imports, type errors, missing dependencies |

### Detailed Troubleshooting

#### No test framework found
**Problem**: Can't detect how to run tests
**Actions**:
1. Look for test files manually
2. Check project documentation
3. Run test command manually and report
4. Ask user for test command

#### Tests pass locally, fail here
**Problem**: Environment-specific failure
**Check**:
1. Environment variables set correctly?
2. Database/services running?
3. Port conflicts (another process using port)?
4. Stale cache files?

**Fix**: Document environment differences, ask user to clarify

#### Flaky tests
**Problem**: Tests sometimes pass, sometimes fail
**Actions**:
1. Run multiple times: `go test -count=10 ./...`
2. Check for race conditions: `go test -race ./...`
3. Look for time dependencies (sleep, timeout)
4. Check for shared state between tests
5. Report pattern to user

#### Tests hanging
**Problem**: Test suite doesn't complete
**Check**:
1. Infinite loops in test setup/teardown
2. Waiting for I/O that never completes
3. Missing context timeouts
4. Blocking on channels

**Fix**:
1. Add timeouts to test execution
2. Run with verbose mode to see where it stops
3. Check for missing mocks on network calls

#### Compilation errors before tests
**Problem**: Code doesn't compile
**Actions**:
1. Fix compilation errors first
2. Check imports are correct
3. Verify type errors resolved
4. Run build command separately
5. Don't run tests until build succeeds

## When to Use

**Use /test when**:
- After implementing code changes
- Before committing
- During TDD workflow (test → code → test)
- Verifying acceptance criteria
- After fixing bugs

**Use /test --quick when**:
- In TDD red-green-refactor loop
- Want fast feedback
- Only changed specific area

**Use /test --file when**:
- Debugging specific test
- Working on isolated feature
- Want fastest possible feedback

## Automatic Invocation

Claude may automatically invoke `/test`:
- After code changes in TDD mode
- When verifying acceptance criteria
- Before marking task complete
- After applying fixes

To prevent auto-invocation: Set `disable-model-invocation: true` in frontmatter

## Related Skills

- `/task --tdd` - Test-driven development workflow
- `/code` - Implement next TODO (automatically runs tests)
- `/self-review` - Review code (includes test check)
- `/quality` - Multi-agent review (includes test verification)
