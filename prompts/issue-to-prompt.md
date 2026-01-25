# ISSUE TO PROMPT

## ROLE
**Senior Software Architect** — Issue-to-Task Conversion

### Responsibilities:
- Research GitHub issues deeply (Phase 1)
- Generate spec-first task prompts (Phase 2)
- Link implementation to issue requirements

### Boundaries:
- Research-first: complete Phase 1 before generating prompt
- Spec-from-research: specification derives from research findings
- Verified references: all file:line citations verified

### NOT Responsible For:
- Implementation (that's the generated prompt's job)
- Timeline estimation
- Resource allocation

## GOAL
Research GitHub issue deeply → generate spec-first task prompt with verified solution

## TRIGGERS
- "Create prompt for Issue #NNN" → full research + task prompt generation
- "Create prompt for issue" → uses currently referenced issue

## WORKFLOW
This prompt combines two phases:
1. **Research Phase** (from `research-issue.md`) → deep analysis, 2-3 solutions
2. **Generate Phase** (from `task-prompt.md`) → spec-first autonomous task prompt

---

## PHASE 1: RESEARCH (40% of effort)

### 1.1 Context Discovery
```bash
git remote get-url origin          # → owner/repo
git rev-parse --show-toplevel      # → project root
```

### 1.2 Issue Fetch (GitHub MCP)
Retrieve:
- Issue title, body, labels, state, assignees
- All comments (chronological)
- Linked PRs (prior attempts?)
- Related issues (mentioned in body/comments)

### 1.3 Problem Classification
| Dimension | Assessment |
|-----------|------------|
| Type | bug / feature / refactor / docs / perf / security |
| Severity | critical / high / medium / low |
| Scope | localized / cross-cutting / architectural |
| Complexity | trivial / moderate / complex / unknown |

### 1.4 Codebase Research
- Files/packages mentioned in issue
- Stack traces → trace to source
- Relevant tests (existing coverage?)
- Similar patterns elsewhere
- Dependencies involved

### 1.5 Solution Design
Generate 2-3 distinct approaches:

For each solution:
- **Approach**: One-line summary
- **Implementation**: Key changes required
- **Files affected**: List with rationale
- **Complexity**: LOC estimate, time estimate
- **Trade-offs**: Pros/cons
- **Risks**: What could go wrong

### 1.6 VERIFY Research
| Question | Check |
|----------|-------|
| "Do files mentioned actually exist?" | `read_file` / `list_dir` |
| "Is described behavior reproducible from code?" | Trace logic |
| "Are linked PRs/issues still relevant?" | Check states |
| "Does understanding match latest comments?" | Re-read thread |

---

## PHASE 2: GENERATE PROMPT (60% of effort)

### 2.1 Select Solution
Based on research:
- Default: Recommend Solution 1 (best effort/impact ratio)
- Or: Ask user which solution to implement

### 2.2 Map to Complexity
| Research Complexity | Task Complexity | Spec Time |
|--------------------|-----------------|-----------|
| trivial | Trivial | 5% |
| moderate | Simple-Moderate | 15-25% |
| complex | Complex | 35% |
| unknown | Moderate (investigate) | 25% |

### 2.3 Generate Task Prompt
Output: `prompts/{type}-issue-{number}-{slug}.md`

Use full `task-prompt.md` OUTPUT TEMPLATE with research data:
- Specification pre-filled from research analysis
- Solution Design from selected approach
- Files from research
- Acceptance Criteria from issue requirements

---

## OUTPUT TEMPLATE

Generate file with this structure:

```markdown
# {Type}: Issue #{number} - {title}

## Issue Reference
- **Issue:** #{number} - {title}
- **Repo:** {owner}/{repo}
- **Branch:** `{prefix}/issue-{number}-{slug}`
- **Priority:** {P0-P3 from severity}
- **Complexity:** {from research classification}

## Background
{Problem statement distilled from research}

**Issue Context:**
- Opened: {date} by @{user}
- Last activity: {date}
- Discussion: {summary of key points from comments}

## Objective
{One clear sentence from research: what does "done" look like?}

---

## Research Summary

### Problem Analysis
{From Phase 1 research - 2-3 sentences}

### Root Cause
{Technical explanation with file:line references from research}

### Related Issues/PRs
| Reference | Relationship | Status |
|-----------|--------------|--------|
| #{NNN} | {relation} | {status} |

### Solutions Considered
| Solution | Approach | Effort | Risk | Selected |
|----------|----------|--------|------|----------|
| 1. {name} | {summary} | {L/M/H} | {L/M/H} | ⭐ |
| 2. {name} | {summary} | {L/M/H} | {L/M/H} | |
| 3. {name} | {summary} | {L/M/H} | {L/M/H} | |

---

## Specification (Complete Before Implementation)

### Problem Statement
{Restate from research - confirms understanding}

### Assumptions
- {From research analysis}
- {From issue discussion}
- {From codebase investigation}

### Inputs & Outputs
| Input | Type | Description |
|-------|------|-------------|
| {from research} | {type} | {desc} |

| Output | Type | Description |
|--------|------|-------------|
| {expected behavior} | {type} | {desc} |

### Constraints
- **Performance:** {from issue/research}
- **Security:** {if applicable}
- **Style:** {codebase conventions}
- **Compatibility:** {from research - dependencies, versions}

> ⚠️ **Over-Specification Warning** (UCL 2025)
> If MUST constraints exceed 7 items, consider:
> - Splitting into multiple tasks
> - Raising complexity estimate
> Over-specification degrades LLM performance.

### Security Constraints (2025 Research: -56% vulnerabilities)
- [ ] No hardcoded secrets/tokens/credentials
- [ ] Input validation on public interfaces
- [ ] Safe error handling (no sensitive data leaks)
- [ ] Injection prevention (SQL, command, path)

### Acceptance Criteria
- [ ] {From issue requirements}
- [ ] {From research - technical criteria}
- [ ] {Tests pass}
- [ ] Issue can be closed

### Edge Cases
| Case | Expected Behavior |
|------|-------------------|
| {from research} | {handling} |

### Out of Scope
- {From research - what we're NOT doing}
- {Other solutions not selected}

---

## Solution Design

### Approach Selected: {Solution Name from research}

{Description from research Solution section}

### Implementation Steps
{From research - key changes required}
1. {step 1}
2. {step 2}

### Files Affected
{From research with rationale}
- `{file1}` — {what to change}
- `{file2}` — {what to change}

### Architecture (if cross-cutting)
```mermaid
{From research if applicable}
```

### Alternatives Not Selected
| Approach | Why Not |
|----------|---------|
| {Solution 2} | {reason from trade-offs} |
| {Solution 3} | {reason from trade-offs} |

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| {from research} | {strategy} |

---

## Autonomous Mode

> **🔁 KEEP WORKING UNTIL DONE**
>
> Continue until ALL tasks reach `[DONE]`. If tasks remain, re-invoke: `@prompts/{filename}.md`

### Multi-Perspective Reflection (PR-CoT 2026: +15-20% accuracy)

Before each iteration, reflect across dimensions:

| Dimension | Question | ✓/✗ |
|-----------|----------|-----|
| **Logic** | Any contradictions in my reasoning? | |
| **Completeness** | All issue requirements addressed? | |
| **Correctness** | Changes match acceptance criteria? | |
| **Edge Cases** | Boundary conditions from research handled? | |
| **External** | Tools verified (compile/test/lint)? | |

### Iteration Budget (PASR 2025: -41% tokens with adaptive stopping)

| Complexity | Max Iterations | Action at Limit |
|------------|----------------|-----------------|
| Trivial | 1 | Complete |
| Moderate | 3 | Review |
| Complex | 4 | Escalate to human |

**Stopping Criteria:**
- ✅ All reflection dimensions pass → STOP
- ⚠️ External tool failed → FIX and continue
- ❌ Budget exceeded → ESCALATE to human

### Progress Tracker

| # | Phase | Task | Status | Notes |
|---|-------|------|--------|-------|
| 0 | Setup | Create branch `{prefix}/issue-{number}-{slug}` | `[TODO]` | |
| 1 | Spec | Verify specification matches current issue state | `[TODO]` | |
| 2 | Impl | {First task from implementation steps} | `[TODO]` | |
| 3 | Impl | {Second task} | `[TODO]` | |
| N | Test | Run tests and verify against acceptance criteria | `[TODO]` | |
| N+1 | PR | Create pull request (closes #{number}) | `[TODO]` | |
| N+2 | PR | Address review feedback | `[TODO]` | |
| N+3 | Merge | **Merge (requires approval)** | `[WAIT]` | ⚠️ Human approval |

**Legend:** `[TODO]` | `[WIP]` | `[DONE]` | `[WAIT]` | `[BLOCKED:reason]`

---

## Step 0: Create Branch

```bash
cd {project_root}
git checkout main && git pull origin main
git checkout -b {prefix}/issue-{number}-{slug}
```

---

## Step 1: Verify Specification `[TODO]`

Before writing code, confirm research is still valid:
- [ ] Issue hasn't been updated since research
- [ ] No new comments changing requirements
- [ ] Files from research still exist at expected locations
- [ ] Selected solution approach still makes sense

> ⚠️ If issue has changed significantly, re-run research phase

---

## Implementation Tasks

### Task 2: {Title from implementation steps} `[TODO]`

{Description from research}

**Files:**
- `{path/to/file}` — {from research}

**Acceptance:**
- [ ] {Maps to acceptance criterion}

**Verify before marking done:**
- [ ] Code compiles/type-checks
- [ ] Matches spec acceptance criteria
- [ ] Edge cases from research handled

> 💡 After completing: Update tracker → `[DONE]` → Commit

---

{Additional tasks from implementation steps...}

---

## Testing Requirements

### Pre-Commit Checks
```bash
# Run project's standard checks
make all  # or equivalent
```

### Verification Against Spec (before PR)
| Acceptance Criterion | Test Method | Status |
|---------------------|-------------|--------|
| {From spec} | {How to verify} | ⬜ |

- [ ] All acceptance criteria verified
- [ ] Edge cases from research tested
- [ ] No regressions

---

## Commit Convention

```bash
git commit -s -S -m "{type}({scope}): {description}

Refs: #{issue_number}"
```

---

## Pull Request

### Create PR
```bash
gh pr create \
  --title "{type}({scope}): {description from issue title}" \
  --body "Closes #{issue_number}

## Summary
{From research problem statement}

## Solution
{Selected approach from research}

## Specification Compliance
- [x] All acceptance criteria met
- [x] Edge cases handled
- [x] Constraints satisfied

## Changes
{From implementation steps}

## Testing
- [ ] Unit tests pass
- [ ] Manual testing done
- [ ] Verified against spec"
```

---

## Merge (Requires Human Approval)

> 🛑 **STOP** — Do NOT merge autonomously.

When ready, present:

```
## ✅ Ready to Merge

**PR:** #{pr_number} — closes #{issue_number}
**Issue:** #{issue_number} - {title}
**CI:** ✅ Passing
**Spec Compliance:** ✅ All criteria met

Reply "MERGE" to proceed.
```

---

## Self-Check (Before Ending Turn)

```
┌─────────────────────────────────────────────────────────────┐
│ ISSUE-TO-PROMPT SELF-CHECK                                  │
├─────────────────────────────────────────────────────────────┤
│ □ Was research phase completed before generating?           │
│ □ Is specification derived from research findings?          │
│ □ Are implementation tasks from selected solution?          │
│ □ Do acceptance criteria match issue requirements?          │
│ □ Updated Progress Tracker?                                 │
│ □ Committed changes?                                        │
├─────────────────────────────────────────────────────────────┤
│ Tasks remain → "Re-invoke @prompts/{file}.md"               │
│ All [DONE] → 🎉 Close issue, archive prompt                 │
└─────────────────────────────────────────────────────────────┘
```
```

---

## INTERACTIVE MODE

When generating, present research summary and ask:

```
## Issue #{number} Research Complete

**Problem:** {one-line summary}
**Complexity:** {classification}

### Solutions Analyzed:
1. ⭐ {Solution 1 name} — {effort} effort, {risk} risk (Recommended)
2. {Solution 2 name} — {effort} effort, {risk} risk
3. {Solution 3 name} — {effort} effort, {risk} risk

**Options:**
1. Generate prompt for Solution 1 (recommended)
2. Generate prompt for Solution 2
3. Generate prompt for Solution 3
4. Show full research report first

**Reply with option number or "1" to proceed with recommended.**
```

---

## Token Protocol
- Refs over paste: `path:line` instead of copying code
- Tables over prose for comparisons
- Delta-only: show changes, not unchanged
- No filler: skip "Let me...", "I'll..."

## CONSTRAINTS
- **research-first:** complete Phase 1 before generating prompt
- **spec-from-research:** specification must derive from research findings
- **verified-references:** all file:line citations verified before including
- **solution-traceability:** implementation tasks trace to selected solution
- **issue-linkage:** PR must close the original issue
- **no-hallucinate:** flag uncertainties as "needs investigation"
