# AUDIT TO PROMPT

## ROLE
**Technical Lead** — Audit-to-Task Conversion

### Responsibilities:
- Convert audit findings into spec-first task prompts
- Group findings by severity and logical batches
- Generate prompts for mid-PR workflow (current branch)

### Boundaries:
- Spec-from-audit: specification derives from audit findings
- No branch creation (use current branch)
- Trace every prompt to original audit finding

### NOT Responsible For:
- Running the audit (that's audit-go.md)
- Architectural decisions beyond the fix
- Timeline estimation

## GOAL
Read `AUDIT_REPORT.md` → generate task prompts for fixes on **current branch**

## CONTEXT
Audits typically run **mid-PR** — you're already on a feature branch with an open PR.
Fixes should be committed to the current branch, not create new branches/PRs.

## TRIGGERS
- "Create prompts from audit" → generates prompts for all Critical/Major findings
- "Create prompt for audit finding: {description}" → single finding
- "Fix audit issues" → generates and starts working on Critical issues

## DEPENDENCY
This prompt generates output following the **task-prompt.md** template structure, adapted for mid-PR workflow:
- Full Specification section
- Solution Design section
- **No branch creation** (use current)
- **No PR creation** (add to current PR)
- Commit directly to current branch

---

## EXEC

### 1. Detect Current Context
```bash
# Confirm we're on a feature branch (not main)
git branch --show-current
# Check for existing PR
gh pr view --json number,title 2>/dev/null || echo "No PR yet"
```

### 2. Read Audit Report
```bash
cat AUDIT_REPORT.md
```

Parse sections:
- `## [Critical]` → immediate action required
- `## [Major]` → production risk
- `## [Minor]` → hygiene (optional prompts)

### 3. Extract Findings
For each finding, extract:
| Field | From Audit |
|-------|------------|
| Severity | Section header ([Critical]/[Major]/[Minor]) |
| File | `File: path/file.go:line` |
| Issue | Issue description |
| Suggested Fix | Fix code snippet |

### 4. Map to Complexity
| Audit Severity | Default Complexity | Spec Time |
|----------------|-------------------|-----------|
| Critical | Moderate | 25% |
| Major | Simple-Moderate | 15-25% |
| Minor | Trivial-Simple | 5-15% |

### 5. Group by Strategy (Mid-PR)
| Strategy | When |
|----------|------|
| **Single prompt per Critical** | Each critical = separate commit |
| **Batch Major by file** | Multiple majors in same file = one commit |
| **Batch Minor** | All minors = one hygiene commit |

### 6. VERIFY (before generating)
| Question | Check |
|----------|-------|
| "Does AUDIT_REPORT.md exist?" | Read file |
| "Are file:line references still valid?" | Verify files exist |
| "Are we on a feature branch?" | Not main/master |
| "Are suggested fixes still applicable?" | Re-read context |

### 7. Generate Prompts
Output: `prompts/fix-audit-{severity}-{slug}.md`

---

## OUTPUT TEMPLATE (Critical Fix — Mid-PR)

For each `[Critical]` finding, generate:

```markdown
# Fix: {Issue Title}

## Audit Reference
- **Source:** AUDIT_REPORT.md
- **Audit Severity:** 🔴 Critical
- **Current Branch:** `{current_branch}` (use as-is)
- **Current PR:** #{pr_number} (if exists)
- **Priority:** P0
- **Complexity:** {Moderate|Complex}

## Background
This issue was identified during code audit on the current PR.
{Context about why this is critical - panic/data-loss/security risk}

## Objective
Fix the critical issue at `{file:line}` and commit to current branch.

---

## Specification (Complete Before Implementation)

### Problem Statement
{Restate the audit finding in context - what is actually happening}

### Assumptions
- We are on feature branch `{current_branch}`
- Audit finding is still valid (code unchanged since audit)
- Suggested fix approach is correct
- {Any other assumptions from audit context}

### Inputs & Outputs
| Input | Type | Description |
|-------|------|-------------|
| {affected input} | {type} | {what triggers the issue} |

| Output | Type | Description |
|--------|------|-------------|
| {expected behavior} | {type} | {what should happen after fix} |

### Constraints
- **Must not break:** existing functionality, API compatibility
- **Security:** {if security-related finding}
- **Performance:** {if performance-related}
- **Style:** match existing codebase patterns

> ⚠️ **Over-Specification Warning** (UCL 2025)
> If MUST constraints exceed 7 items, consider:
> - Splitting into multiple tasks
> - Raising complexity estimate
> Over-specification degrades LLM performance.

### Acceptance Criteria
- [ ] Issue at `{file:line}` is resolved
- [ ] Audit re-run on file shows finding resolved
- [ ] No new issues introduced
- [ ] All existing tests pass
- [ ] New test covers the fixed case

### Edge Cases
| Case | Expected Behavior |
|------|-------------------|
| {edge case from audit} | {safe behavior} |
| {nil/empty input} | {handled gracefully} |

### Out of Scope
- Other audit findings (separate prompts)
- Refactoring beyond the fix
- Performance optimization (unless directly related)

---

## Solution Design

### Approach Selected: {Name from audit suggestion}

{Brief description based on audit's suggested fix}

### Suggested Fix (from audit)
```{lang}
{Fix code snippet from audit}
```

### Alternatives Considered
| Approach | Pros | Cons | Why Not Selected |
|----------|------|------|------------------|
| {Alternative} | {pros} | {cons} | {reason or "Selected"} |

### Root Cause Analysis
{Why this issue exists - from audit analysis}

---

## Autonomous Mode (Mid-PR)

> **🔁 KEEP WORKING UNTIL DONE**
>
> Continue until ALL tasks reach `[DONE]`. If tasks remain, re-invoke: `@prompts/{filename}.md`

### Multi-Perspective Reflection (PR-CoT 2026: +15-20% accuracy)

Before each iteration, reflect across dimensions:

| Dimension | Question | ✓/✗ |
|-----------|----------|-----|
| **Logic** | Any contradictions in my fix approach? | |
| **Completeness** | All aspects of audit finding addressed? | |
| **Correctness** | Fix matches suggested approach? | |
| **Edge Cases** | Boundary conditions from audit handled? | |
| **External** | Tools verified (compile/test/lint/audit)? | |

### Iteration Budget (PASR 2025: -41% tokens with adaptive stopping)

| Severity | Max Iterations | Action at Limit |
|----------|----------------|-----------------|
| Critical | 2 | Escalate |
| Major | 3 | Review |
| Minor | 2 | Complete |

**Stopping Criteria:**
- ✅ All reflection dimensions pass → STOP
- ⚠️ Audit re-run still shows finding → FIX and continue
- ❌ Budget exceeded → ESCALATE to human

### Progress Tracker

| # | Phase | Task | Status | Notes |
|---|-------|------|--------|-------|
| 1 | Spec | Verify specification matches current code | `[TODO]` | |
| 2 | Impl | Apply fix at `{file:line}` | `[TODO]` | |
| 3 | Test | Add/update test for fixed case | `[TODO]` | |
| 4 | Verify | Run audit on file to confirm fix | `[TODO]` | |
| 5 | Commit | Commit fix to current branch | `[TODO]` | |
| 6 | Push | Push to update PR | `[TODO]` | ⚠️ Human may push |

**Legend:** `[TODO]` | `[WIP]` | `[DONE]` | `[WAIT]` | `[BLOCKED:reason]`

> ℹ️ **No branch/PR creation** — fixes go to current branch `{current_branch}`

---

## Step 1: Verify Specification `[TODO]`

Before applying fix, confirm:
- [ ] We are on branch `{current_branch}` (not main)
- [ ] Code at `{file:line}` still matches audit finding
- [ ] No recent changes have altered the context
- [ ] Suggested fix approach is still valid

> ⚠️ If code has changed significantly, re-run audit first

---

## Implementation Tasks

### Task 2: Apply Fix `[TODO]`

Apply the fix from audit at `{file:line}`.

**Files:**
- `{path/to/file}` — {apply suggested fix}

**Acceptance:**
- [ ] Fix matches audit suggestion (or improved version)
- [ ] Code compiles/type-checks
- [ ] No unintended side effects

**Verify before marking done:**
- [ ] Read surrounding context
- [ ] Ensure fix handles edge cases from spec

> 💡 After completing: Update tracker → `[DONE]`

---

### Task 3: Add Test `[TODO]`

Add or update test to cover the fixed case.

**Files:**
- `{path/to/file_test}` — add test case

**Acceptance:**
- [ ] Test would have caught the original issue
- [ ] Test passes with fix applied
- [ ] Test fails if fix is reverted

---

### Task 4: Verify Fix via Audit `[TODO]`

Re-run audit on the affected file to confirm fix.

```bash
# Run audit scoped to fixed file
# The finding should no longer appear
```

**Acceptance:**
- [ ] Original finding no longer appears
- [ ] No new findings introduced

---

## Testing Requirements

### Pre-Commit Checks
```bash
# Run project's standard checks
make all  # or equivalent for toolchain
```

### Verification Against Spec
| Acceptance Criterion | Test Method | Status |
|---------------------|-------------|--------|
| Issue resolved | Code review at `{file:line}` | ⬜ |
| Audit passes | Re-run audit on file | ⬜ |
| Tests pass | Run test suite | ⬜ |
| No regressions | Full test suite | ⬜ |

---

## Commit to Current Branch

```bash
git add {files}
git commit -s -S -m "fix({scope}): {description from audit}

Audit: {severity} finding resolved"
```

### Push (Optional — Human May Prefer)
```bash
git push origin {current_branch}
```

> ℹ️ Human may prefer to batch multiple audit fixes before pushing

---

## Self-Check (Before Ending Turn)

```
┌─────────────────────────────────────────────────────────────┐
│ AUDIT-FIX SELF-CHECK (Mid-PR)                               │
├─────────────────────────────────────────────────────────────┤
│ □ On correct branch (not main)?                             │
│ □ Is the audit finding still valid in current code?         │
│ □ Does the fix match the specification?                     │
│ □ Did audit re-run confirm the fix?                         │
│ □ Are tests added for the fixed case?                       │
│ □ Updated Progress Tracker?                                 │
│ □ Committed to current branch?                              │
├─────────────────────────────────────────────────────────────┤
│ Tasks remain → "Re-invoke @prompts/{file}.md"               │
│ All [DONE] → 🎉 Archive prompt, continue PR review          │
└─────────────────────────────────────────────────────────────┘
```
```

---

## OUTPUT TEMPLATE (Batched Major — Mid-PR)

For related `[Major]` findings, generate:

```markdown
# Fix: Major Audit Findings - {Component/File}

## Audit Reference
- **Source:** AUDIT_REPORT.md
- **Audit Severity:** 🟡 Major (batched)
- **Current Branch:** `{current_branch}` (use as-is)
- **Priority:** P1
- **Complexity:** Moderate

## Findings Addressed
| # | File | Issue | Suggested Fix |
|---|------|-------|---------------|
| 1 | `{file1:line}` | {issue} | {fix summary} |
| 2 | `{file2:line}` | {issue} | {fix summary} |

{... full Specification section for combined fixes ...}

### Progress Tracker
| # | Phase | Task | Status |
|---|-------|------|--------|
| 1 | Spec | Verify all findings still valid | `[TODO]` |
| 2 | Impl | Fix finding #1 | `[TODO]` |
| 3 | Impl | Fix finding #2 | `[TODO]` |
| N | Verify | Re-run audit on affected files | `[TODO]` |
| N+1 | Commit | Commit all fixes | `[TODO]` |
```

---

## OUTPUT TEMPLATE (Hygiene Sweep — Mid-PR)

For all `[Minor]` findings:

```markdown
# Chore: Audit Hygiene Sweep

## Audit Reference
- **Source:** AUDIT_REPORT.md
- **Audit Severity:** 🔵 Minor (batched)
- **Current Branch:** `{current_branch}` (use as-is)
- **Priority:** P3
- **Complexity:** Simple

## Findings Addressed
| # | File | Issue |
|---|------|-------|
{list all minors}

{... simplified spec - hygiene doesn't need full alternatives analysis ...}
```

---

## INTERACTIVE OPTIONS

When invoked, present:

```
## Audit Report Summary

**Current Branch:** `{branch_name}`
**Current PR:** #{pr_number} - {pr_title} (or "No PR yet")

Found in AUDIT_REPORT.md:
- 🔴 Critical: {N} findings
- 🟡 Major: {N} findings  
- 🔵 Minor: {N} findings

**Options:**
1. Generate prompts for all Critical issues (recommended)
2. Generate prompts for all Critical + Major
3. Generate single prompt for specific finding
4. Generate hygiene prompt for all Minor
5. Generate all prompts

**All fixes will be committed to current branch `{branch_name}`**

**Reply with option number.**
```

---

## TOKEN PROTOCOL
| Rule | Implementation |
|------|----------------|
| `ref>paste` | Cite `path:line-range`, avoid full code paste |
| `table>prose` | Findings, progress → table format |
| `delta-only` | Show fix locations, not full file context |

## CONSTRAINTS
- **mid-pr-workflow:** fixes commit to current branch, no new branches
- **no-pr-creation:** PR already exists (or will be created separately)
- **follows-task-prompt:** all generated prompts use task-prompt.md structure
- **spec-first:** include full specification before implementation
- **trace-to-audit:** every prompt references original AUDIT_REPORT.md finding
- **verify-before-generate:** confirm files/lines still valid
- **atomic-commits:** each severity group = one commit
- **no-scope-creep:** fix only what audit identified
- **re-audit:** include audit re-run as verification step
