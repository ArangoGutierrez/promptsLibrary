# Test

Run tests and verify everything works.

## Usage
- (no args) — Run full test suite
- `--quick` — Run only tests for changed files
- `--file {path}` — Run specific test file

## Workflow

### 1. Detect Toolchain
```bash
# Go
[ -f go.mod ] && go test ./...

# Node/TS
[ -f package.json ] && npm test

# Python
[ -f pyproject.toml ] && pytest
[ -f requirements.txt ] && pytest

# Rust
[ -f Cargo.toml ] && cargo test
```

### 2. Run Tests
```bash
# Run detected test command
{test_command}
```

### 3. Report Results
```
## Test Results

**Status:** ✅ PASS / ❌ FAIL
**Tests:** {passed}/{total}
**Duration:** {time}

### Failures (if any)
| Test | Error |
|------|-------|
| {test_name} | {error_message} |

### Coverage (if available)
| Package | Coverage |
|---------|----------|
| {pkg} | {%} |
```

### 4. If Failures
```
## ❌ Test Failures

### Failing Tests
1. `{test_name}`: {error}

### Suggested Fixes
- {specific fix for each failure}

Run `/code` to fix, then `/test` again.
```

### 5. Update AGENTS.md
If "Run tests" task exists:
- `[TODO]` → `[DONE]` if passing
- `[TODO]` → `[BLOCKED:tests failing]` if failing

## Quick Mode (`--quick`)
Only test files related to recent changes:
```bash
# Get changed files
git diff --name-only HEAD~1

# Run targeted tests
{targeted_test_command}
```

## Output Format

### On Success
```markdown
## ✅ Tests Passed

**Status:** PASS
**Tests:** {passed}/{total}
**Duration:** {time}

### Coverage (if available)
| Package | Coverage |
|---------|----------|
| {pkg} | {%} |
```

### On Failure
```markdown
## ❌ Tests Failed

**Status:** FAIL
**Passed:** {N}/{total}
**Failed:** {M}

### Failures
| Test | Error |
|------|-------|
| {test_name} | {error_message} |

### Suggested Fixes
1. {specific fix for failure 1}
2. {specific fix for failure 2}

Run `/code` to fix, then `/test` again.
```

## Constraints
- **Auto-detect**: Use project's test toolchain
- **Report clearly**: Show pass/fail summary
- **On failure**: Suggest specific fixes
- **Update AGENTS.md**: Mark test task status

## Troubleshooting

### No Test Framework Detected
```
Error: Could not detect test framework
```
**Manual specification:**
```bash
# Go
go test ./...

# Node (check package.json scripts)
npm test
npm run test:unit

# Python
pytest
python -m pytest

# Rust
cargo test
```

### Tests Pass Locally But Fail Here
**Common causes:**
| Cause | Check | Fix |
|-------|-------|-----|
| Missing env vars | Compare with CI | Export required vars |
| Database not running | Check connection | Start test DB |
| Port conflicts | `lsof -i :8080` | Kill conflicting process |
| Cached state | Test isolation | Add cleanup/reset |

### Flaky Tests
```
Test passes sometimes, fails other times
```
**Actions:**
1. Run specific test multiple times: `go test -count=10 -run TestName`
2. Check for:
   - Race conditions: `go test -race`
   - Time-dependent logic
   - External dependencies
   - Shared state between tests

### Coverage Not Available
```bash
# Go
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Node (if Jest)
npm test -- --coverage

# Python
pytest --cov=.
```

### Tests Hanging
```
Test appears stuck
```
**Actions:**
1. Check for infinite loops or blocking I/O
2. Add timeout: `go test -timeout 30s`
3. Run with verbose: `go test -v` to see which test hangs
4. Check for missing mock/stub for external call

### Compilation Errors Before Tests Run
```
Build failed before tests
```
**Actions:**
1. Fix compile errors first (separate from test failures)
2. Run build only: `go build ./...`
3. Check for missing imports or type errors

### Test Database Issues
```bash
# Reset test database
docker-compose -f docker-compose.test.yml down -v
docker-compose -f docker-compose.test.yml up -d

# Or use in-memory for unit tests
# Example: SQLite instead of Postgres for tests
```

### Quick Mode Not Working
```
--quick still runs all tests
```
**Check:**
1. Git diff detection: `git diff --name-only HEAD~1`
2. File→test mapping may not exist
3. Fallback: manually specify test file with `--file`
