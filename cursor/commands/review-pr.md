# Review PR

Rigorous code review with confidence scoring.

## Usage
- `#{number}` — Review specific PR
- (no args) — Review current branch diff

## Workflow

1. Fetch PR details (files, diff, metadata)
2. Pre-flight check (skip if closed/draft/trivial)
3. Security pass on high-risk files
4. Bug detection pass on changed lines only
5. Architecture review pass
6. Apply confidence scoring (report only ≥80)
7. Generate review with verdict

## Pre-Flight Skip
| Condition | Action |
|-----------|--------|
| PR closed | Skip |
| PR draft | Skip |
| Trivial (docs only) | "LGTM" |

## Review Passes

### Pass 1: Security (ALWAYS for high-risk)
- [ ] Hardcoded credentials/tokens?
- [ ] Injection risks (SQL, command, path)?
- [ ] Input validation missing?
- [ ] Authorization bypass?
- [ ] Sensitive data in errors?

### Pass 2: Bugs (CHANGED lines only)
- Logic errors?
- Nil/undefined deref?
- Unhandled errors?
- Resource leaks?

### Pass 3: Architecture
- Follows existing patterns?
- Proper separation?
- Tests for new logic?

## Confidence Scoring

**Only report findings with confidence ≥80**

| Score | Action |
|-------|--------|
| 0-50 | DROP |
| 51-79 | Question for author |
| 80-100 | Report |

Scoring (+20 each):
- Exact `file:line`
- Introduced in THIS PR
- Clear justification
- Verified via re-read
- Concrete fix

## Verification
For each finding:
1. Generate question
2. Re-read INDEPENDENTLY
3. ✓confirmed / ✗drop / ?question

## Output
```markdown
## PR Review: #{number}

### Summary
- Files: {N} | Risk areas: {list}

### 🔴 Blocking (confidence ≥80)
`file:line` (conf: {N}/100)
- Issue: {desc}
- Fix: {code}

### 🟡 Health
{suggestions}

### 🔵 Questions
{unclear items}

### Verdict
✅ Approved / ⚠️ Changes Requested / 🚫 Blocked
```

## Constraints
- **Changes only**: Only flag issues introduced in PR
- **Evidence-based**: cite `file:line`
- **Threshold**: ≥80 confidence to report
