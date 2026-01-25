# Research

Deep investigation without implementation.

## Usage
- `#{number}` — Research GitHub issue
- `{topic}` — Research codebase topic

## Workflow

### 1. Context
```bash
git remote get-url origin
git rev-parse --show-toplevel
```

### 2. Issue Fetch (if applicable)
- Title, body, labels, state
- Comments (chronological)
- Linked PRs, related issues

### 3. Classification
| Dimension | Assessment |
|-----------|------------|
| Type | bug/feature/refactor/docs/perf/security |
| Severity | critical/high/medium/low |
| Scope | localized/cross-cutting/architectural |
| Complexity | trivial/moderate/complex/unknown |

### 4. Codebase Investigation
- Files/packages mentioned
- Stack traces → source
- Existing tests
- Similar patterns
- Dependencies

### 5. Verify
| Claim | Question |
|-------|----------|
| C1 | "Do files exist?" |
| C2 | "Is behavior reproducible?" |
| C3 | "Understanding matches code?" |

Answer INDEPENDENTLY. Proceed only with ✓.

### 6. Solutions (2-3)
For each:
- **Approach**: One-line summary
- **Files affected**: With rationale
- **Complexity**: LOC estimate
- **Trade-offs**: Pros/cons
- **Risks**: What could go wrong

### 7. Comparison
| Criterion | Sol 1 | Sol 2 | Sol 3 |
|-----------|-------|-------|-------|
| Effort | L/M/H | | |
| Risk | L/M/H | | |
| Maintainability | L/M/H | | |

## Output
```markdown
# Research: #{number} - {title}

## Summary
- Type: {class} | Severity: {level}

## Problem
{2-3 sentences}

## Root Cause
{Technical explanation with file:line}

## Solutions
### 1. {Name} ⭐ Recommended
{details}

### 2. {Name}
{details}

## Recommendation
Solution 1 because {rationale}

## Open Questions
- {uncertainties}
```

## Constraints
- **Read-only**: No modifications
- **2-3 solutions**: Not 1, not >3
- **Evidence-based**: cite `file:line`
