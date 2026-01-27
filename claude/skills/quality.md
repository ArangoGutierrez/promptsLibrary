---
name: quality
description: Multi-perspective code review with parallel agents (auditor, perf-critic, api-reviewer, verifier). Reviews git diff, specific files, or pull requests. Runs specialized agents simultaneously, synthesizes results into unified report with risk assessment and verdict. Supports fast mode and focused reviews.
argument-hint: "[path | #PR] [--fast] [--api] [--perf]"
disable-model-invocation: true
allowed-tools: Task, Bash
model: sonnet
---

# Quality Review

Multi-agent code review for comprehensive quality assessment.

## Usage

```bash
/quality                # Review git diff (changed files)
/quality {path}         # Review specific file or directory
/quality #123           # Review pull request #123
/quality --fast         # Quick review (auditor + verifier only)
/quality --api          # Focus on API design review
/quality --perf         # Focus on performance review
```

## Pipeline

```
/quality
    ├──→ auditor      (security, races, leaks)
    ├──→ perf-critic  (N+1 queries, algorithmic complexity)
    ├──→ api-reviewer (API consistency, REST best practices)
    └──→ verifier     (tests pass, acceptance criteria)
           ↓
       Synthesis
```

All agents run **in parallel** for speed.

## Workflow

### Step 1: Determine Scope

**Default (no args)**: Review changed files
```bash
git diff --name-only HEAD
```

**File/directory**: Review specified path
```bash
# Example: /quality src/api/
```

**Pull request**: Review PR diff
```bash
gh pr diff 123
gh pr view 123
```

### Step 2: Select Agents

**Default (full review)**:
- auditor: Security and reliability
- perf-critic: Performance issues
- api-reviewer: API design (if handlers/API files present)
- verifier: Tests pass

**--fast mode**:
- auditor: Security only
- verifier: Tests only
(Skip perf-critic and api-reviewer)

**--api mode**:
- api-reviewer: API design focus
- auditor: Security for API handlers
(Skip perf-critic and general verifier)

**--perf mode**:
- perf-critic: Performance focus
- auditor: Check for races/leaks
(Skip api-reviewer and verifier)

### Step 3: Launch Parallel Agents

Launch all selected agents simultaneously using Task tool:

**Auditor**:
```
Use the auditor agent from ~/.claude/agents/auditor.md to review:

Scope: {files to review}

Check for:
- Security vulnerabilities
- Race conditions
- Resource leaks
- Defensive programming issues

Output: AUDIT_REPORT.md with severity-ranked findings
```

**Perf-critic**:
```
Use the perf-critic agent from ~/.claude/agents/perf-critic.md to review:

Scope: {files to review}

Check for:
- N+1 query patterns
- Algorithmic complexity (O(n²)+)
- Memory allocation issues
- I/O bottlenecks

Output: PERF_REPORT.md with impact assessment
```

**API-reviewer** (only if API files present):
```
Use the api-reviewer agent from ~/.claude/agents/api-reviewer.md to review:

Scope: {API handler files}

Check for:
- REST/HTTP best practices
- Naming consistency
- Error response formats
- API versioning

Output: API_REPORT.md with consistency findings
```

**Verifier**:
```
Use the verifier agent from ~/.claude/agents/verifier.md to verify:

Scope: {test suite}

Tasks:
- Run test suite
- Verify tests pass
- Check acceptance criteria
- Identify test gaps

Output: VERIFICATION_REPORT.md with test status
```

**All agents run in parallel** - use multiple Task tool calls in a single message.

### Step 4: Synthesize Results

After all agents complete, combine findings into unified report:

1. Collect all agent outputs
2. Categorize by severity: Critical, High, Medium, Low
3. Calculate risk score
4. Determine verdict
5. Generate actionable recommendations

## Output Format

```markdown
## Quality Report: {scope}

### Risk Assessment: 🔴 High / 🟡 Medium / 🟢 Low

### Summary
| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Security | 1 | 2 | 0 | 1 |
| Performance | 0 | 1 | 2 | 0 |
| API Design | 0 | 0 | 1 | 2 |
| Tests | - | - | - | ✓ Pass |

### Blocking Issues (Must Fix)

#### 🔴 [Critical] Race condition in auth handler
**Source**: auditor
**Location**: `auth/handler.go:142`
**Issue**: Shared map access without mutex
**Impact**: Data corruption under concurrent load
**Fix**:
```go
type SafeCache struct {
    mu sync.RWMutex
    data map[string]string
}
```

#### 🟠 [High] N+1 query in user listing
**Source**: perf-critic
**Location**: `api/users.go:88`
**Issue**: Separate query per user for roles
**Impact**: ~100ms per user, scales poorly
**Fix**: Use JOIN or preload with `INNER JOIN roles`

### Non-blocking Issues

#### 🟡 [Medium] Inconsistent error response format
**Source**: api-reviewer
**Location**: `api/errors.go:24`
**Issue**: Some endpoints return `{"error": "..."}`, others `{"message": "..."}`
**Impact**: Client confusion, harder integration
**Recommendation**: Standardize on `{"error": {...}}` format

### Test Status
✅ **All tests passing** (42/42)
- Unit tests: 38/38
- Integration tests: 4/4

### Verdict
⚠️ **Fix Required** - Address 1 critical and 2 high-priority issues before merging

#### Recommended Actions
1. Fix race condition in auth handler (Critical)
2. Optimize user listing query (High)
3. Add mutex to shared cache access (High)
4. Consider standardizing error format (Medium - can defer)

### Agent Reports
- Full audit: AUDIT_REPORT.md
- Performance analysis: PERF_REPORT.md
- API review: API_REPORT.md
- Verification: VERIFICATION_REPORT.md
```

## Risk Calculation

Risk level determined by highest severity finding:

| Findings | Risk Level | Symbol |
|----------|------------|--------|
| 1+ Critical | High | 🔴 |
| 1+ High (no Critical) | Medium | 🟡 |
| Only Medium/Low | Low | 🟢 |
| No issues | Pass | ✅ |

## Verdict Rules

| Verdict | Criteria |
|---------|----------|
| ✅ **Ready** | No Critical or High issues, all tests pass |
| ⚠️ **Fix Required** | 1+ High issues OR tests failing |
| 🚫 **Blocked** | 1+ Critical issues |

## Mode Details

### Default Mode (Full Review)
- All 4 agents
- Comprehensive analysis
- Slowest but most thorough
- Use before: major PRs, releases, production deploys

### --fast Mode
- auditor + verifier only
- Security and test check
- Fastest review
- Use before: routine commits, small PRs

### --api Mode
- api-reviewer + auditor (API focus)
- API design and security
- Use when: adding/changing API endpoints

### --perf Mode
- perf-critic + auditor (race focus)
- Performance and concurrency
- Use when: optimizing hot paths, scaling concerns

## Constraints

- **Parallel execution required**: All agents must run simultaneously
- **Synthesis required**: No raw agent dumps, must synthesize
- **Critical/High = blocked**: Cannot merge with unresolved severe issues
- **Test verification**: Must run tests, not just review test code
- **Evidence-based**: Every finding needs `file:line` reference

## When to Use

**Use /quality when**:
- Before creating pull request
- Reviewing PRs before merge
- Pre-production readiness check
- After major refactoring
- Before release deployment

**Use /quality --fast when**:
- Quick pre-commit check
- Small bug fixes
- Documentation updates

**Use /quality --api when**:
- Adding new API endpoints
- Changing existing APIs
- API consistency audit

**Use /quality --perf when**:
- Performance-critical changes
- Scaling concerns
- Database query changes

## Related Skills

- `/audit` - Security-focused review
- `/self-review` - Quick self-check before pushing
- `/test` - Run test suite only
- `/architect` - Architecture-level review
