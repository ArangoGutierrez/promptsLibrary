---
name: audit
description: Security and reliability auditing for Go/K8s codebases with automatic fix generation. Use before commits, for production readiness reviews, race condition detection, or resource leak identification. Focuses on EffectiveGo patterns, defensive programming, Kubernetes readiness, and security vulnerabilities.
argument-hint: "[--full] [--fix]"
disable-model-invocation: true
allowed-tools: Task, Bash, Read, Write, Edit
model: sonnet
---

# Security and Reliability Audit

Systematic code audit using the auditor agent for Go/Kubernetes codebases.

## Usage

```bash
/audit                # Audit git diff (changed files only)
/audit --full         # Audit entire codebase (handlers, db, auth + all)
/audit --fix          # Generate and apply fixes for critical/major issues
```

## Scope

**Default (P0)**: `git diff --name-only HEAD` (staged and unstaged changes)

**Always included (P1)**: High-risk files regardless of changes
- Handlers: `**/handlers/**/*.go`, `**/api/**/*.go`
- Database: `**/db/**/*.go`, `**/database/**/*.go`, `**/repo/**/*.go`
- Auth: `**/auth/**/*.go`, `**/authz/**/*.go`

**Full scan (P2)**: With `--full` flag
- All Go files in codebase
- Longer analysis time

## Categories

### A. EffectiveGo
- **Race conditions**: Unprotected shared state, missing mutex
- **Channel misuse**: Unbuffered blocking, closed channel writes
- **Goroutine leaks**: Missing context cancellation, infinite loops
- **Error swallowing**: `_ = f()` discarding errors
- **Panic misuse**: Panics in libraries, missing recovery
- **Error wrapping**: Missing context (`fmt.Errorf` vs `errors.Wrap`)

### B. Defensive Programming
- **Input validation**: Public functions lacking validation
- **Nil safety**: Missing nil checks on pointers, interfaces
- **Timeouts + context**: Missing deadlines on I/O, network calls
- **Defer close**: Resource leaks (files, connections not closed)

### C. Kubernetes Ready
- **Graceful shutdown**: Missing signal handling, abrupt termination
- **JSON logging**: Using `fmt.Print` instead of structured logging
- **Health probes**: Missing `/health` and `/ready` endpoints
- **Secrets in code**: Hardcoded credentials, tokens, API keys

### D. Security
- **No tokens in logs**: Credentials leaked in error messages
- **Injection prevention**: SQL injection, command injection risks
- **Input sanitization**: User input not validated/escaped
- **Safe errors**: Stack traces exposing internal paths
- **Authorization**: Missing access control checks

## Balance (What NOT to Flag)

- **Style as critical**: Don't escalate style issues to security concerns
- **Premature optimization**: Don't flag performance unless proven hot path
- **Architecture rewrites**: Don't suggest large refactorings
- **Already mitigated**: Don't flag issues with existing mitigations
- **Test code patterns**: Tests can use shortcuts (panics, no error handling)

## Workflow

### Step 1: Determine Scope

```bash
# Check what files will be audited
git diff --name-only HEAD | grep '\.go$'

# Or for full scan
find . -name '*.go' -not -path '*/vendor/*' -not -path '*_test.go'
```

### Step 2: Run Auditor Agent

Use the Task tool with a general-purpose subagent loaded with the auditor agent:

```
Use the auditor agent from ~/.claude/agents/auditor.md to audit the following scope:

Scope: [Default: git diff | Full: entire codebase]
Files: [list of .go files]

The agent should analyze for:
1. EffectiveGo issues (races, leaks, error handling)
2. Defensive programming gaps (validation, nil safety)
3. Kubernetes readiness (shutdown, logging, probes)
4. Security vulnerabilities (injection, secrets, authz)

For each finding:
1. Verify the issue exists by re-reading the file independently
2. Provide exact file:line reference
3. Classify severity: Critical, Major, Minor
4. Suggest specific fix with code example

Output format: AUDIT_REPORT.md with categorized findings.
```

### Step 3: Verify Each Finding

The auditor agent MUST independently verify each finding:

1. **Initial scan**: Identify potential issues
2. **Re-read file**: Read the specific file:line independently
3. **Confirm or drop**: ✓ Confirmed (issue exists) or ✗ Dropped (false positive)

This prevents hallucinated findings and ensures accuracy.

### Step 4: Generate Report

Agent outputs `AUDIT_REPORT.md`:

```markdown
## [Critical] {category}

### Issue 1
- **File**: `path/to/file.go:42`
- **Issue**: Race condition on shared map without mutex
- **Impact**: Data corruption under concurrent access
- **Fix**:
  ```go
  type SafeCache struct {
      mu sync.RWMutex
      data map[string]string
  }
  ```

## [Major] {category}

### Issue 2
- **File**: `path/to/handler.go:128`
- **Issue**: Missing input validation on user-provided ID
- **Impact**: Potential injection or crash
- **Fix**:
  ```go
  if id <= 0 {
      return fmt.Errorf("invalid id: %d", id)
  }
  ```

## [Minor] {category}

### Issue 3
- **File**: `path/to/util.go:88`
- **Issue**: Error not wrapped with context
- **Impact**: Harder debugging
- **Fix**:
  ```go
  return fmt.Errorf("failed to open file: %w", err)
  ```

## Summary

- **Generated**: 15 potential issues
- **Confirmed**: 8 issues (7 dropped as false positives)
- **Critical**: 1
- **Major**: 4
- **Minor**: 3

## Verification Process
- ✓ All findings independently verified by re-reading files
- ✓ Exact file:line references provided
- ✓ Code fixes tested for syntax
```

### Step 5: Apply Fixes (if --fix flag)

If `--fix` is present, automatically apply fixes for Critical and Major issues:

For each Critical/Major finding:
1. **Verify** the issue exists (re-read the file)
2. **Apply fix** using Edit tool
3. **Test** the fix (compile check)
4. **Re-audit** the changed code
5. **Commit** with message: `fix({scope}): {description} - Audit finding`

Example commit:
```bash
git add path/to/file.go
git commit -s -S -m "fix(cache): add mutex to prevent race condition - Audit finding

Found by security audit: shared map access without synchronization
could cause data corruption under concurrent load.

Refs: AUDIT_REPORT.md"
```

**Stop conditions**:
- If fix causes compile errors: Revert and document in report
- If fix introduces new audit issues: Revert and document
- If tests fail: Revert and mark as needs manual review

## Output Format

Present summary after audit completes:

```markdown
# Audit Complete: {scope}

## Risk Level: 🔴 Critical / 🟡 High / 🟢 Low

### Issues Found
| Category | Critical | Major | Minor |
|----------|----------|-------|-------|
| EffectiveGo | 1 | 2 | 0 |
| Defensive | 0 | 2 | 1 |
| K8s Ready | 0 | 0 | 2 |
| Security | 0 | 0 | 0 |

### Blocking Issues (--fix applied: {yes/no})
{List of critical and major issues}

### Report Location
Full details: `AUDIT_REPORT.md`

### Verdict
✅ Ready (no critical/major) / ⚠️ Fix Required / 🚫 Blocked
```

## When to Use

**Use /audit when**:
- Before committing sensitive changes
- Pre-production readiness review
- After adding concurrency (goroutines, channels)
- Working with auth/authz code
- Handling user input
- Opening network connections or files

**Don't audit**:
- Test files (unless testing auth/security)
- Generated code (protobuf, mocks)
- Vendor dependencies
- Obvious one-liners

## Examples

### Example 1: Audit staged changes
```
/audit
```
Audits only files in `git diff --name-only HEAD`

### Example 2: Full codebase scan
```
/audit --full
```
Audits all .go files including P1 high-risk areas

### Example 3: Audit and auto-fix
```
/audit --fix
```
Finds issues and automatically applies fixes for Critical/Major items

## Constraints

- **Evidence-based**: Every finding must cite exact `file:line`
- **Verification required**: Must re-read files to confirm issues
- **No false positives**: Drop suspicious findings during verification
- **Impact-focused**: Explain real-world impact, not theoretical
- **No paranoia**: Only flag issues that matter in practice
- **Test code exceptions**: Don't flag test code for panic/error handling
- **Fix atomicity**: Each fix is one commit, can be reverted independently

## Troubleshooting

### Too Many False Positives
**Problem**: Agent flags issues that don't exist
**Solution**: Verification step should catch these - agent must re-read file independently before confirming

### Audit Takes Too Long
**Problem**: Full scan on large codebase is slow
**Solution**: Use default scope (git diff) for rapid feedback, save --full for pre-release

### Fixes Break Compilation
**Problem**: Auto-applied fixes introduce syntax errors
**Solution**: Each fix should be tested for compilation before commit; revert on failure

### Missing Real Issues
**Problem**: Audit missed a known security issue
**Solution**: Verify P1 high-risk directories are included (handlers, db, auth); consider expanding P1 patterns

## Related Skills

- `/quality` - Multi-agent review including audit + perf + api
- `/self-review` - Quick review before pushing
- `/test` - Run test suite after fixes applied
