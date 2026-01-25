# Research

Deep investigation without implementation.

## Usage
- `#{number}` — Research GitHub issue
- `{topic}` — Research codebase topic
- `brainstorm: {idea}` — Deep-dive idea analysis with web research

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

---

## Brainstorm Workflow

### B1. Idea Extraction
- Core concept in one sentence
- Problem it solves
- Target audience/users
- Initial assumptions

### B2. Web Research
Search for:
- Existing solutions/competitors
- Market size and trends
- Technical feasibility references
- Failure cases in similar domains
- Expert opinions and critiques

### B3. Multi-Perspective Analysis

| Lens | Key Questions |
|------|---------------|
| **User** | Who benefits? Pain points solved? Adoption barriers? |
| **Technical** | Feasible? Stack choices? Scalability? Complexity? |
| **Business** | Revenue model? Market fit? Competitive moat? |
| **Market** | Timing right? Trends supporting? Market size? |
| **Risk** | What kills this? Dependencies? Single points of failure? |
| **Contrarian** | Why this fails? What's everyone missing? Devil's advocate? |

### B4. SWOT Synthesis
| | Positive | Negative |
|---|----------|----------|
| **Internal** | Strengths | Weaknesses |
| **External** | Opportunities | Threats |

### B5. Assumption Testing
| Assumption | Validity | Evidence | Risk if Wrong |
|------------|----------|----------|---------------|
| A1 | ✓/✗/? | Source | Impact |
| A2 | | | |
| A3 | | | |

### B6. Alternative Angles
- **Pivot options**: 2-3 variations of the idea
- **Simplification**: MVP version
- **Expansion**: Full vision version
- **Combination**: Synergies with other concepts

### B7. Action Matrix
| Priority | Action | Validates | Effort |
|----------|--------|-----------|--------|
| P0 | {immediate} | {assumption} | Low |
| P1 | {next} | | Med |
| P2 | {later} | | High |

## Brainstorm Output
```markdown
# Brainstorm: {idea}

## TL;DR
{One paragraph verdict}

## The Idea
{Refined statement after research}

## Research Findings
### Market Landscape
{What exists, trends, gaps}

### Technical Landscape  
{Feasibility, approaches, prior art}

## Analysis

### Strengths
- {with evidence}

### Weaknesses  
- {with evidence}

### Opportunities
- {with evidence}

### Threats
- {with evidence}

## Critical Assumptions
1. {assumption} — {validity assessment}

## Perspectives

### Bull Case 🐂
{Best realistic scenario}

### Bear Case 🐻
{Worst realistic scenario}

### Base Case 📊
{Most likely scenario}

## Recommendations
### Do This
- {actionable next steps}

### Avoid This
- {common pitfalls}

### Validate First
- {experiments to run}

## Open Questions
- {unknowns requiring more research}
```

---

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
- **Evidence-based**: cite `file:line` or web sources

## Brainstorm Constraints
- **Web research required**: Always search before analyzing
- **Multiple perspectives**: Minimum 4 lenses applied
- **Challenge assumptions**: Play devil's advocate
- **Actionable output**: End with concrete next steps
- **Honest assessment**: No cheerleading — include bear case
