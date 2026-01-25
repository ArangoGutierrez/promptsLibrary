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

## Constraints
- **Auto-detect**: Use project's test toolchain
- **Report clearly**: Show pass/fail summary
- **On failure**: Suggest specific fixes
- **Update AGENTS.md**: Mark test task status
