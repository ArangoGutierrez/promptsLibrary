---
name: research
description: Deep issue research and root cause analysis. Use for GitHub issue investigation, bug analysis, solution generation, or brainstorming new ideas. READ-ONLY analysis that investigates issues, classifies complexity, and generates multiple solution approaches with comparison matrix.
argument-hint: "[#N | topic | brainstorm: idea]"
disable-model-invocation: false
allowed-tools: Task, Bash(git:*), Bash(gh:*), WebSearch
model: sonnet
---

# Research

Deep investigation and root cause analysis for issues, topics, or brainstorming.

## Usage

```bash
/research #123                    # Research GitHub issue #123
/research {topic}                 # Research codebase topic
/research brainstorm: {idea}      # Deep dive brainstorming on idea
```

## Mode 1: GitHub Issue Research

When argument starts with `#` (e.g., `#123`).

### Step 1: Get Repository Context

```bash
git remote get-url origin
git rev-parse --show-toplevel
```

### Step 2: Fetch Issue Data

Use `gh` CLI to fetch comprehensive issue information:

```bash
gh issue view 123 --json title,body,labels,state,comments,milestone
gh issue view 123 --comments
```

Extract:

- Title and body text
- Labels and milestone
- State (open/closed)
- All comments and discussion
- Linked pull requests

### Step 3: Classify Issue

Analyze and classify the issue:

**Type**:

- `bug` - Broken functionality
- `feat` - New feature request
- `refactor` - Code improvement without behavior change
- `docs` - Documentation update
- `perf` - Performance improvement
- `sec` - Security vulnerability

**Severity**:

- `critical` - System down, data loss, security breach
- `high` - Major feature broken, significant impact
- `medium` - Feature partially broken, workaround exists
- `low` - Minor issue, cosmetic problem

**Scope**:

- `local` - Single file or function
- `cross` - Multiple files/modules
- `arch` - Architectural change needed

**Complexity**:

- `trivial` - < 10 lines, obvious fix
- `moderate` - 10-100 lines, straightforward
- `complex` - > 100 lines or unclear solution
- `unknown` - Need more investigation

### Step 4: Investigate Root Cause

Use the Task tool with researcher agent:

```
Use the researcher agent from ~/.claude/agents/researcher.md to investigate:

Issue #$ARGUMENTS
Title: [title]
Description: [body]
Classification: [from step 3]

Tasks:
1. Find mentioned files/packages in issue and comments
2. Trace stack traces to source code
3. Read relevant test files
4. Identify patterns (similar bugs, common code paths)
5. Check dependencies and external factors
6. Verify claims in issue description

Output should include:
- Confirmed root cause with file:line references
- Relevant code context
- Why this happens (technical explanation)
```

### Step 5: Verify Understanding

Before proceeding, verify:

- ✓ **C1**: Do all mentioned files exist?
- ✓ **C2**: Can the behavior be reproduced or understood from code?
- ✓ **C3**: Does our understanding match what the code actually does?

If any check fails, document questions and proceed with caveats.

### Step 6: Generate Solutions

Generate 2-3 solution approaches:

For each solution:

| Element | Description |
|---------|-------------|
| **Approach** | High-level strategy name |
| **Files** | Which files change and why |
| **Complexity** | Estimated LOC or effort |
| **Trade-offs** | Pros (+) and cons (-) |
| **Risk** | Low/Medium/High - what could go wrong |

### Step 7: Compare Solutions

Create comparison matrix:

| Criterion | Solution 1 | Solution 2 | Solution 3 |
|-----------|------------|------------|------------|
| Effort | L/M/H | L/M/H | L/M/H |
| Risk | L/M/H | L/M/H | L/M/H |
| Maintainability | L/M/H | L/M/H | L/M/H |
| Performance Impact | None/Minor/Major | None/Minor/Major | None/Minor/Major |

### Output Format (Issue Research)

```markdown
# Research: #123 - {title}

## Summary
- **Type**: bug | feat | refactor | docs | perf | sec
- **Severity**: critical | high | medium | low
- **Scope**: local | cross | arch
- **Complexity**: trivial | moderate | complex | unknown

## Problem
[2-3 sentence description of the actual problem]

## Root Cause
[Technical explanation with file:line references]

**Location**: `path/to/file.go:142`
**Why**: [Explanation of why this causes the issue]

## Solutions

### 1. {Approach Name} ⭐ (Recommended)
**Strategy**: [High-level approach]
**Files**: [List of files and why they change]
**Complexity**: ~{N} LOC
**Trade-offs**:
  + Pro 1
  + Pro 2
  - Con 1
**Risk**: Low - [why low risk]

### 2. {Alternative Approach}
**Strategy**: [High-level approach]
**Files**: [List of files and why they change]
**Complexity**: ~{N} LOC
**Trade-offs**:
  + Pro 1
  - Con 1
  - Con 2
**Risk**: Medium - [specific risk]

### 3. {Another Alternative}
[Same structure]

## Comparison Matrix

| Criterion | Solution 1 ⭐ | Solution 2 | Solution 3 |
|-----------|-------------|------------|------------|
| Effort | Low | High | Medium |
| Risk | Low | Medium | Low |
| Maintainability | High | Low | Medium |
| Performance | No impact | Minor | No impact |

## Recommendation

**Choose Solution 1** because: [Evidence-based reasoning]

## Open Questions
- {Question 1}?
- {Question 2}?
```

## Mode 2: Codebase Topic Research

When argument doesn't start with `#` or `brainstorm:`.

Same workflow as Issue Research but:

- Skip Step 2 (no GitHub issue to fetch)
- Start at Step 3 with topic classification
- Focus investigation on codebase patterns and architecture
- Solutions may be "understanding" rather than "fixes"

## Mode 3: Brainstorming

When argument starts with `brainstorm:` (e.g., `brainstorm: add GraphQL API`).

### B1: Extract Core Idea

From the idea statement, extract:

- **Concept**: What is being proposed?
- **Problem**: What problem does it solve?
- **Audience**: Who benefits?
- **Assumptions**: What assumptions are embedded?

### B2: Web Research

Use WebSearch to gather external context:

- Competitors offering similar solutions
- Market research and demand signals
- Technical feasibility and best practices
- Known failures and cautionary tales
- Expert opinions and blog posts

### B3: Multiple Lenses Analysis

Analyze through different perspectives:

**User Lens**:

- Benefit: What do users gain?
- Pain: What friction or cost?
- Barriers: What prevents adoption?

**Technical Lens**:

- Feasible: Can we build it with our stack?
- Stack: What technologies needed?
- Scale: How does it handle growth?

**Business Lens**:

- Revenue: Does it make/save money?
- Fit: Does it align with product vision?
- Moat: Does it create competitive advantage?

**Risk Lens**:

- Killers: What could make this fail completely?
- Dependencies: What external factors matter?
- Single points of failure: Where are we vulnerable?

### B4: SWOT Analysis

| | Internal | External |
|---|---|---|
| **Positive** | **Strengths**: What advantages do we have? | **Opportunities**: What external factors help? |
| **Negative** | **Weaknesses**: What disadvantages or gaps? | **Threats**: What external factors hurt? |

### B5: Test Assumptions

For each key assumption:

- **Assumption**: [Statement]
- **Valid?**: Is this actually true?
- **Evidence**: What supports/contradicts it?
- **Risk if wrong**: What happens if assumption is false?

### B6: Explore Angles

Generate variations:

- **Pivots**: How could we adjust the idea?
- **MVP**: What's the minimal version?
- **Full vision**: What's the ultimate version?
- **Combos**: What if we combine with other ideas?

### B7: Prioritized Actions

| Priority | Actions |
|----------|---------|
| **P0** (immediate) | {What to do now} |
| **P1** (next) | {What to do after P0} |
| **P2** (later) | {What to do eventually} |

### Output Format (Brainstorming)

```markdown
# Brainstorm: {idea}

## TL;DR
[3 sentence summary: What is it? Why might it work/fail? Recommendation]

## Research Findings

### Concept
{Core idea extracted}

### Market Research
- **Competitors**: {Who else does this}
- **Demand**: {Evidence of need}
- **Best practices**: {Industry standards}
- **Failures**: {Cautionary examples}

## Analysis

### User Perspective
- **Benefit**: {What users gain}
- **Pain**: {What friction exists}
- **Barriers**: {What prevents adoption}

### Technical Perspective
- **Feasibility**: {Can we build it?}
- **Stack**: {What tech needed}
- **Scale**: {How it grows}

### Business Perspective
- **Revenue**: {Financial impact}
- **Fit**: {Strategic alignment}
- **Moat**: {Competitive advantage}

### Risk Perspective
- **Killers**: {What could make this fail}
- **Dependencies**: {External factors}
- **SPOF**: {Single points of failure}

## SWOT

| | Helpful | Harmful |
|---|---|---|
| **Internal** | **Strengths**<br>- {Advantage 1}<br>- {Advantage 2} | **Weaknesses**<br>- {Gap 1}<br>- {Gap 2} |
| **External** | **Opportunities**<br>- {External factor 1} | **Threats**<br>- {External risk 1} |

## Scenarios

### Bull Case (Best outcome)
{What happens if everything goes right}

### Bear Case (Worst outcome)
{What happens if key assumptions fail}

### Base Case (Most likely)
{What probably happens}

## Assumptions Testing

| Assumption | Valid? | Evidence | Risk if Wrong |
|------------|--------|----------|---------------|
| {Assumption 1} | ✓/✗/?  | {Evidence} | {Impact} |
| {Assumption 2} | ✓/✗/?  | {Evidence} | {Impact} |

## Recommendations

### Do (Green light)
- {Thing we should definitely do}

### Avoid (Red light)
- {Thing we should NOT do}

### Validate (Yellow light - need more info)
- {Thing we need to test/research before deciding}

## Next Steps

| Priority | Action | Owner | Timeline |
|----------|--------|-------|----------|
| P0 | {Immediate action} | TBD | This week |
| P1 | {Next action} | TBD | Next sprint |
| P2 | {Future action} | TBD | Later |
```

## Constraints

- **READ-ONLY**: Do not modify files during research
- **Evidence-based**: Every claim needs supporting evidence (code, docs, web research)
- **Multiple solutions**: Always provide 2-3 alternatives, not just one
- **Trade-offs explicit**: Every solution must acknowledge cons
- **Independent verification**: Verify claims by reading actual code
- **Time-boxed**: Research should complete in reasonable time (< 30 min for issues, < 45 min for brainstorming)

## When to Use

**Use /research when**:

- Investigating GitHub issues before coding
- Understanding unfamiliar codebase areas
- Analyzing bug reports
- Exploring new feature ideas
- Evaluating architecture changes
- Brainstorming product ideas

**Don't use /research for**:

- Simple code questions (use direct questions)
- Already well-understood issues
- Urgent hot fixes (start coding immediately)

## Related Skills

- `/issue` - Research GitHub issue and create implementation plan
- `/architect` - Deep architectural exploration (after research)
- `/debug` - Systematic debugging workflow
