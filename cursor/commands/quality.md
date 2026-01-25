# Quality

Multi-perspective code quality review using parallel subagents.

## Usage
- (no args) — Review current git diff
- `{path}` — Review specific file/directory
- `#{PR}` — Review PR changes

## What Happens

**One command triggers 4 parallel agents:**

```
┌─────────────┐
│  /quality   │
└──────┬──────┘
       │ parallel
       ├──→ auditor      → Security + Reliability
       ├──→ perf-critic  → Performance Issues
       ├──→ api-reviewer → API Design (if endpoints)
       └──→ verifier     → Actual Functionality
              │
       ┌──────┴──────┐
       │  Synthesis  │
       └─────────────┘
```

## Workflow

### 1. Determine Scope
```bash
# Default: staged + unstaged changes
git diff --name-only HEAD

# Or use provided path/PR
```

### 2. Launch Parallel Agents

Launch these subagents **simultaneously**:

| Agent | Focus | Skip If |
|-------|-------|---------|
| `auditor` | Security, races, leaks | Never |
| `perf-critic` | N+1, complexity, allocs | Docs-only |
| `api-reviewer` | HTTP/API changes | No handlers |
| `verifier` | Tests pass, works | No tests |

### 3. Synthesize Results

Combine all agent outputs:

```markdown
## Quality Report: {scope}

### Risk Level: 🔴 High / 🟡 Medium / 🟢 Low

### By Category

#### Security (auditor)
{findings or ✓ clear}

#### Performance (perf-critic)
{findings or ✓ clear}

#### API Design (api-reviewer)
{findings or ✓ clear / ⊘ not applicable}

#### Functionality (verifier)
{findings or ✓ verified}

### Summary
| Category | Issues | Severity |
|----------|--------|----------|
| Security | N | crit/high/med |
| Performance | N | high/med/low |
| API | N | major/minor |
| Tests | pass/fail | — |

### Blocking Issues
{must fix before merge}

### Recommendations
1. {priority fix}
2. {next fix}

### Verdict
✅ Ready / ⚠️ Fix Required / 🚫 Blocked
```

## Quick Variants

| Command | Shortcut For |
|---------|--------------|
| `/quality` | Full review (all 4 agents) |
| `/quality --fast` | auditor + verifier only |
| `/quality --api` | api-reviewer focus |
| `/quality --perf` | perf-critic focus |

## Output Format

```markdown
## Quality Report: {scope}

### Risk Level: 🔴 High / 🟡 Medium / 🟢 Low

### Summary
| Category | Issues | Severity |
|----------|--------|----------|
| Security | {N} | {crit/high/med} |
| Performance | {N} | {high/med/low} |
| API | {N} | {major/minor} |
| Tests | {pass/fail} | — |

### Findings

#### 🔴 Blocking (must fix)
- `file:line` — {issue} → {fix}

#### 🟡 Should Fix
- `file:line` — {issue} → {fix}

#### 🟢 Suggestions
- {recommendation}

### Verdict
✅ Ready / ⚠️ Fix Required / 🚫 Blocked
```

## Constraints
- **Parallel execution**: All agents run simultaneously
- **Synthesis required**: Don't dump raw outputs
- **Actionable**: Every finding needs a fix suggestion
- **Blocking gate**: Critical/High issues = blocked
