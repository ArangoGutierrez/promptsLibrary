# Prompt Template 360° Research Review

> **Generated:** 2026-01-18
> **Scope:** All 9 prompt templates in `/prompts/`
> **Research Basis:** Academic papers 2024-2026, META CoVe, Self-Planning, iterative refinement patterns
> **Status:** ✅ UPGRADES APPLIED

---

## Changes Applied (2026-01-18)

### Factor+Revise CoVe Upgraded (6 files)
- `audit-go.md` — Full 4-step Factor+Revise verification
- `pr_review.md` — Full 4-step Factor+Revise verification  
- `git-polish.md` — Full 4-step Factor+Revise verification
- `research-issue.md` — Full 4-step Factor+Revise verification
- `preflight.md` — Full 4-step Factor+Revise verification
- `workflow.md` — Full 4-step Factor+Revise verification

### Multi-Perspective Reflection Added (3 files)
- `task-prompt.md` — 5-dimension reflection + iteration budget
- `audit-to-prompt.md` — 5-dimension reflection + severity-based budget
- `issue-to-prompt.md` — 5-dimension reflection + complexity-based budget

### Security Constraints Added (2 files)
- `audit-go.md` — New SCOPE.D Security section
- `pr_review.md` — Enhanced SCOPE.B Security section

### Over-Specification Warning Added (1 file)
- `task-prompt.md` — MUST/SHOULD/MUST NOT hierarchy with ≤7 limit

### Reasoning Strategy Selection Added (1 file)
- `research-issue.md` — CoT/ToT/SGR/FoT topology selection

### Role Blocks Refined (All 9 files)
- Responsibilities/Boundaries/NOT Responsible For structure
- Domain-relevant expertise emphasized
- Irrelevant personality traits removed

---

## Executive Summary

Your current prompts already incorporate several research-backed techniques:
- ✅ **CoVe (Chain of Verification)** - Already in `audit-go.md`, `git-polish.md`, `research-issue.md`
- ✅ **Spec-First Workflow** - Strong foundation in `task-prompt.md`
- ✅ **Iterative Until-Done** - "Ralph Wiggum" pattern in `task-prompt.md`, `audit-to-prompt.md`
- ✅ **Role Assignment** - Used throughout
- ✅ **Structured Output Templates** - Consistent use of markdown schemas

**Key Upgrade Opportunities Based on 2025-2026 Research:**

| Technique | Research Support | Current Gap | Priority |
|-----------|-----------------|-------------|----------|
| **Multi-Perspective Reflection (PR-CoT)** | +15-20% on reasoning tasks | Verification uses single perspective | 🔴 High |
| **Adaptive Iteration (PASR)** | -41% tokens, +8% accuracy | Fixed iteration patterns | 🔴 High |
| **Self-Graph Reasoning (SGR)** | +17.7% on complex reasoning | Linear thought chains | 🟡 Medium |
| **Dynamic Topology Selection (SOLAR)** | +9-10% on math/logic | One-size-fits-all reasoning | 🟡 Medium |
| **Structured Spec Constraints (LongGuide)** | +5% format adherence | Informal constraint descriptions | 🟢 Low |
| **Security-Focused Prefixes** | -56% vulnerabilities | Missing in code prompts | 🟡 Medium |

---

## Part 1: Research Findings Deep Dive

### 1.1 Chain of Verification (CoVe) - META AI 2023

**What You Already Have:**
Your prompts use CoVe in `audit-go.md` (lines 33-44), `git-polish.md` (lines 32-44), `research-issue.md` (lines 58-68).

**Latest Improvements (2025-2026):**

| Variant | Description | Performance |
|---------|-------------|-------------|
| **Joint** | Questions + answers in same prompt | Baseline |
| **Two-Step** | Separate planning and verification | Better |
| **Factored** | Each question verified independently | +15% precision |
| **Factor+Revise** | Explicit cross-check phase | **Best** (+27% on biographies) |

**Upgrade Recommendation:**
Your current CoVe uses the "Joint" variant. Upgrade to **Factored** or **Factor+Revise**:

```markdown
## VERIFY (Factor+Revise Variant)

### Step 1: Generate Verification Questions
For each finding/claim, generate atomic fact-checking questions:
- "Does file X actually contain pattern Y at line Z?"
- "Is the described behavior X supported by code path Y?"

### Step 2: Execute Verifications INDEPENDENTLY
⚠️ Answer each question in isolation WITHOUT referencing:
- The original finding
- Other verification questions
- Previous verification answers

### Step 3: Cross-Check and Reconcile
Compare verification answers against original claims:
| Finding | Verification Answer | Match? | Action |
|---------|---------------------|--------|--------|
| {claim} | {independent answer} | ✓/✗/? | keep/drop/flag |

### Step 4: Generate Final Verified Response
Only include findings that passed Step 3 reconciliation.
```

---

### 1.2 Iterative Refinement & Self-Correction

**Your "Ralph Wiggum" Pattern:**
You use "KEEP WORKING UNTIL DONE" in `task-prompt.md` and `audit-to-prompt.md`.

**Latest Research (2025-2026):**

| Method | Innovation | Result |
|--------|------------|--------|
| **PASR (ProActive Self-Refinement)** | Refine *during* generation, not after | -41.6% tokens, +8.2% accuracy |
| **PR-CoT (Multi-Perspective Reflection)** | Reflect across dimensions before refining | Significant gains on nuanced tasks |
| **Probabilistic Theory** | Accuracy follows `Acc_t = Upp - α^t(Upp - Acc_0)` | Predictable diminishing returns |

**Critical Finding:**
> "Sole reliance on LLM's own feedback generation often leads to poor corrections—feedback sometimes wrong or misleading."
> — Kamoi et al., TACL 2024

**Upgrade: Multi-Perspective Reflection Loop**

```markdown
## Iterative Refinement Protocol (PR-CoT Enhanced)

> **🔁 KEEP WORKING UNTIL DONE**

### Before Each Iteration, Reflect Across Dimensions:

| Dimension | Question | Status |
|-----------|----------|--------|
| **Logical Consistency** | Are there contradictions in my reasoning? | ⬜ |
| **Completeness** | Did I miss any requirements from spec? | ⬜ |
| **Correctness** | Do my changes match acceptance criteria? | ⬜ |
| **Edge Cases** | Have I handled boundary conditions? | ⬜ |
| **External Verification** | Did I verify with tools (compiler, tests, lint)? | ⬜ |

### Adaptive Stopping Criteria:
- ✅ All reflection dimensions pass → STOP
- ⚠️ External tool failed → FIX and continue
- ❌ >3 iterations without progress → ESCALATE to human

### Iteration Budget:
| Task Complexity | Max Iterations | Rationale |
|-----------------|----------------|-----------|
| Trivial | 1 | Diminishing returns |
| Simple | 2 | |
| Moderate | 3 | |
| Complex | 4 | Beyond this, human review |
```

---

### 1.3 Spec-First / Self-Planning Code Generation

**Your Current Approach:**
`task-prompt.md` cites Self-Planning research (+25% improvement) and allocates time by complexity.

**Latest Research (2025-2026):**

| Study | Finding |
|-------|---------|
| **Self-Planning (PKU, ASE 2024)** | +25.4% Pass@1 over direct generation |
| **Spec2RTL-Agent** | -75% human interventions with spec-driven approach |
| **Type-Constrained Generation (PLDI 2025)** | -50% compilation errors with type specs |

**Key Insight: Over-Specification Paradox**
> "Over-specification (too much detail in ground truth prompts) may degrade performance."
> — UCL Framework, Dec 2025

**Upgrade: Balanced Specification with Constraints Hierarchy**

```markdown
## Specification (Balanced Depth)

### MUST (Required Constraints) — Strict
- [ ] {Hard requirement - failure breaks acceptance}
- [ ] {Security constraint}
- [ ] {API contract}

### SHOULD (Strong Preferences) — Flexible
- [ ] {Performance target - best effort}
- [ ] {Style preference}

### MAY (Optional Enhancements) — If Time Permits
- [ ] {Nice-to-have improvement}

### MUST NOT (Negative Constraints) — Forbidden
- [ ] {Explicitly prohibited behavior}
- [ ] {Out of scope items}

> ⚠️ Over-specification warning: If MUST list exceeds 7 items, 
> consider splitting task or raising complexity estimate.
```

---

### 1.4 Tree/Graph of Thought Reasoning

**Your Current Approach:**
Linear chain reasoning in most prompts.

**Latest Research (2025-2026):**

| Method | Innovation | Gains |
|--------|------------|-------|
| **Forest-of-Thought (FoT)** | Multiple parallel reasoning trees | More robust |
| **Self-Graph Reasoning (SGR)** | Graph structure, parallel premises | +17.7% on QA |
| **SSDP Pruning** | Prune redundant paths | -85% nodes, same accuracy |
| **SOLAR** | Dynamic topology selection | +9-10% accuracy |
| **LToT (Lateral)** | Mainlines + laterals with probes | Better depth exploration |

**When to Use Which:**

| Task Type | Recommended Topology |
|-----------|---------------------|
| Simple/linear | Chain-of-Thought (CoT) |
| Multiple approaches | Tree-of-Thought (ToT) |
| Interrelated evidence | Graph-of-Thought (SGR) |
| High-stakes verification | Forest-of-Thought (FoT) |

**Upgrade: Adaptive Reasoning Section**

```markdown
## Reasoning Strategy Selection

### Assess Task Characteristics:
| Characteristic | Assessment | Topology |
|----------------|------------|----------|
| Single clear path? | Yes → | CoT (chain) |
| Multiple valid approaches? | Yes → | ToT (tree) |
| Evidence from multiple sources? | Yes → | SGR (graph) |
| High-stakes, needs verification? | Yes → | FoT (forest) |

### For Complex Tasks (ToT/SGR):
1. **Generate** 2-3 distinct solution paths
2. **Evaluate** each path against constraints
3. **Prune** semantically similar paths (SSDP)
4. **Select** best path with rationale
5. **Verify** selected path passes CoVe check
```

---

### 1.5 Role/Persona Prompting

**Your Current Approach:**
Strong role assignments: "Senior Go Reliability Engineer", "Technical Lead", etc.

**Latest Research (2025-2026):**

| Finding | Source |
|---------|--------|
| Expert personas help reasoning, neutral/harmful for factual recall | Principled Personas, 2025 |
| Irrelevant persona details can hurt by up to 30 percentage points | Same study |
| Rule-based role prompting outperforms vague personas | CPGD Challenge, 2025 |
| "Act like an expert" less helpful with newer capable models | Multiple 2025 sources |

**Best Practice Guidelines:**
- ✅ **DO**: Specify domain-relevant expertise, task role, goals
- ❌ **DON'T**: Add irrelevant personality traits, vague "be an expert"
- ✅ **DO**: Pair persona with clear task structure
- ❌ **DON'T**: Rely on persona alone for factual accuracy

**Upgrade: Refined Role Blocks**

```markdown
## ROLE
{Title} — {Domain Expertise}

### Responsibilities:
- {Specific action 1}
- {Specific action 2}

### Constraints:
- {Ethical/safety boundary}
- {Scope limitation}

### NOT Responsible For:
- {Explicitly excluded activity}
```

---

### 1.6 Structured Output & Format Constraints

**Your Current Approach:**
Good use of markdown tables and templates throughout.

**Latest Research (2025-2026):**

| Method | Improvement |
|--------|-------------|
| **LongGuide (MGs + OCGs)** | +5% with metric + output constraint guidelines |
| **DICE** | +35% format accuracy, +29% content correctness |
| **Schema-First** | Explicit JSON/YAML schemas improve compliance |

**Upgrade: Enhanced Output Contracts**

```markdown
## OUTPUT CONTRACT

### Format Requirements (OCGs):
| Element | Constraint | Validation |
|---------|------------|------------|
| File paths | Must exist in codebase | `read_file` check |
| Line numbers | Must be current | Re-read to verify |
| Code snippets | Must compile | Syntax check |
| Severity labels | Enum: Critical/Major/Minor | String match |

### Quality Metrics (MGs):
| Metric | Target | Self-Check |
|--------|--------|------------|
| Findings accuracy | 100% verified | CoVe pass |
| False positive rate | <5% | Independent re-check |
| Completeness | All critical paths | Coverage trace |

### Output Template:
```{format}
{Exact structure with field descriptions}
```

### Validation:
Before finalizing, confirm:
- [ ] All OCG constraints met
- [ ] MG targets achieved or explained
```

---

### 1.7 Security-Aware Code Prompting

**Your Current Gap:**
No explicit security constraints in code-related prompts.

**Latest Research (2025):**

| Finding | Source |
|---------|--------|
| Security-focused prefixes reduce vulnerabilities by up to 56% | Benchmarking PE for Secure Code, 2025 |
| Iterative refinement can WORSEN security over rounds | Security Degradation study, 2025 |
| Adding "address security vulnerabilities" significantly improves warnings | Do LLMs consider security?, 2025 |

**Upgrade: Security Prefix for Code Prompts**

```markdown
## SECURITY CONSTRAINTS

### Code Generation Security Checklist:
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] Input validation on all public interfaces
- [ ] SQL/command injection prevention (parameterized queries)
- [ ] Buffer overflow prevention (bounds checking)
- [ ] Proper error handling (no sensitive info in errors)
- [ ] Resource cleanup (defer Close, context timeouts)

### Security Review Required For:
- Authentication/authorization logic
- Data encryption/decryption
- External API calls
- User input processing
- File system operations

### Iteration Security Gate:
⚠️ After each refinement iteration, re-check security:
- Did the fix introduce new attack vectors?
- Are error messages leaking sensitive information?
- Did complexity increase without security review?
```

---

## Part 2: Current Prompt Analysis

### Template Inventory

| File | Purpose | Strengths | Upgrade Priority |
|------|---------|-----------|------------------|
| `audit-go.md` | Go/K8s code audit | Good CoVe, structured output | 🟡 Medium |
| `audit-to-prompt.md` | Audit → task prompts | Strong workflow, until-done loop | 🟢 Low |
| `git-polish.md` | Git history cleanup | Good verification gate | 🟡 Medium |
| `issue-to-prompt.md` | Issue research → prompt | Comprehensive 2-phase | 🟢 Low |
| `pr_review.md` | Pull request review | Evidence-based findings | 🟡 Medium |
| `preflight.md` | Repo scan | Verification confidence ratings | 🟢 Low |
| `research-issue.md` | Deep issue analysis | CoVe, solution comparison | 🟡 Medium |
| `task-prompt.md` | General task prompts | Spec-first, Self-Planning refs | 🔴 High |
| `workflow.md` | Two-phase planning | Verification before GO | 🟡 Medium |

---

### Pattern Analysis Across Templates

**Patterns Already Present:**

| Pattern | Files Using | Research Backing |
|---------|-------------|------------------|
| Role Assignment | All 9 | Principled Personas (2025) |
| Verification Gates | 7/9 | CoVe (META 2023) |
| Structured Output | 8/9 | LongGuide (2025) |
| Until-Done Loops | 3/9 | PASR (2025) |
| Spec-First | 4/9 | Self-Planning (PKU 2024) |
| Time Allocation | 2/9 | Complexity-based planning |

**Missing Patterns:**

| Pattern | Research Source | Benefit |
|---------|-----------------|---------|
| Multi-Perspective Reflection | PR-CoT (2026) | Better self-correction |
| Adaptive Iteration Stopping | PASR (2025) | Token efficiency |
| Security Constraints | Secure Code PE (2025) | Vulnerability reduction |
| Dynamic Topology Selection | SOLAR (2025) | Better reasoning |
| Over-Specification Warning | UCL (2025) | Avoid perf degradation |
| Factored Verification | CoVe Factor+Revise | Higher precision |

---

## Part 3: Upgrade Plan

### Phase 1: High-Priority Upgrades (Core Patterns)

#### 1.1 Upgrade CoVe to Factor+Revise Variant

**Files to Update:**
- `audit-go.md` (lines 33-44)
- `git-polish.md` (lines 32-44)
- `research-issue.md` (lines 58-68)
- `pr_review.md` (lines 54-64)
- `preflight.md` (lines 23-35)
- `workflow.md` (lines 16-28)

**Template Block:**

```markdown
## VERIFY (Factor+Revise)

### Step 1: Generate Verification Questions
For each finding, create atomic fact-check questions:

| Finding ID | Verification Question |
|------------|----------------------|
| F1 | "Does `{file}:{line}` contain `{pattern}`?" |
| F2 | "Is `{behavior}` actually unhandled?" |

### Step 2: Execute Independently
⚠️ Answer each question WITHOUT referencing original findings.

### Step 3: Reconcile
| Finding | Independent Answer | Verdict |
|---------|-------------------|---------|
| F1 | {re-read result} | ✓ confirmed / ✗ drop / ? flag |

### Step 4: Final Output
Include ONLY findings with ✓ verdict.
```

#### 1.2 Add Multi-Perspective Reflection to Iteration Loops

**Files to Update:**
- `task-prompt.md` (lines 178-198)
- `audit-to-prompt.md` (lines 175-196)
- `issue-to-prompt.md` (lines 222-244)

**Template Block:**

```markdown
## Iteration Protocol (PR-CoT Enhanced)

> **🔁 KEEP WORKING UNTIL DONE**

### Pre-Iteration Reflection Checklist:
| Dimension | Question | Status |
|-----------|----------|--------|
| Logic | Contradictions in reasoning? | ⬜ |
| Completeness | All requirements addressed? | ⬜ |
| Correctness | Changes match acceptance criteria? | ⬜ |
| Edge Cases | Boundary conditions handled? | ⬜ |
| External | Tools verified (compile/test/lint)? | ⬜ |

### Iteration Budget:
| Complexity | Max Iterations |
|------------|----------------|
| Trivial | 1 |
| Simple | 2 |
| Moderate | 3 |
| Complex | 4 (then escalate) |

### Stopping Criteria:
- ✅ All reflection dimensions pass
- ⚠️ External failure → fix and continue
- ❌ Budget exceeded → human review
```

#### 1.3 Add Security Constraints Block

**Files to Update:**
- `audit-go.md` (add to SCOPE)
- `pr_review.md` (add to SCOPE)
- `task-prompt.md` (add to Specification template)

**Template Block:**

```markdown
## SECURITY CONSTRAINTS

### Mandatory Checks:
- [ ] No hardcoded secrets/tokens/credentials
- [ ] Input validation on public interfaces
- [ ] Injection prevention (SQL, command, path)
- [ ] Proper error handling (no sensitive data leaks)
- [ ] Resource cleanup (Close, context cancellation)

### High-Risk Areas (require extra scrutiny):
- Authentication/authorization
- Encryption/decryption
- External API calls
- User input processing
- File system operations

### Iteration Security Gate:
After each refinement:
- [ ] No new attack vectors introduced
- [ ] Error messages don't leak sensitive info
- [ ] Complexity increase has security review
```

---

### Phase 2: Medium-Priority Upgrades (Enhancements)

#### 2.1 Add Reasoning Strategy Selection

**Files to Update:**
- `research-issue.md` (Solution Design section)
- `task-prompt.md` (Solution Design section)
- `issue-to-prompt.md` (Solution Design section)

**Template Block:**

```markdown
## Reasoning Strategy

### Task Assessment:
| Characteristic | Answer | Recommended |
|----------------|--------|-------------|
| Single clear path? | {Y/N} | CoT |
| Multiple valid approaches? | {Y/N} | ToT |
| Evidence from multiple sources? | {Y/N} | SGR |
| High-stakes verification? | {Y/N} | FoT |

### Selected Strategy: {CoT|ToT|SGR|FoT}

### If ToT/SGR Selected:
1. **Generate** 2-3 solution paths
2. **Evaluate** against constraints
3. **Prune** semantically similar paths
4. **Select** with rationale
5. **Verify** via CoVe
```

#### 2.2 Add Over-Specification Warning

**Files to Update:**
- `task-prompt.md` (Specification section)
- `issue-to-prompt.md` (Specification section)

**Template Block:**

```markdown
### Specification Complexity Check

> ⚠️ **Over-Specification Warning**
> If MUST constraints exceed 7 items, consider:
> - Splitting into multiple tasks
> - Raising complexity estimate
> - Removing redundant constraints

| Constraint Type | Count | Threshold |
|-----------------|-------|-----------|
| MUST (required) | {N} | ≤7 |
| SHOULD (preferred) | {N} | ≤5 |
| MUST NOT (forbidden) | {N} | ≤5 |
```

#### 2.3 Refine Role Blocks

**Files to Update:** All 9 prompts

**Current Pattern:**
```markdown
## ROLE
Senior Go Reliability Engineer + K8s Architect
```

**Upgraded Pattern:**
```markdown
## ROLE
**Senior Go Reliability Engineer** — Production Systems

### Responsibilities:
- Identify race conditions, resource leaks, panic risks
- Verify K8s lifecycle compliance
- Recommend idiomatic Go patterns

### Boundaries:
- Evidence-based findings only (cite file:line)
- No architectural rewrites without explicit request
- Flag uncertainty rather than assume

### NOT Responsible For:
- Business logic correctness
- UI/UX decisions
- Deployment strategy
```

---

### Phase 3: Low-Priority Upgrades (Polish)

#### 3.1 Standardize Output Contracts

Add explicit format validation to all templates:

```markdown
## OUTPUT CONTRACT

### Format Requirements:
| Element | Constraint | Validation Method |
|---------|------------|-------------------|
| File paths | Must exist | `read_file` |
| Line numbers | Must be current | Re-read |
| Code snippets | Must compile | Syntax check |

### Before Finalizing:
- [ ] All format constraints met
- [ ] Quality metrics achieved
- [ ] Self-check passed
```

#### 3.2 Add Adaptive Stopping Metrics

For iteration loops, add explicit stopping criteria with metrics:

```markdown
### Adaptive Stopping

| Metric | Stop Threshold |
|--------|----------------|
| All tasks [DONE] | Yes |
| Reflection all ✅ | Yes |
| External tools pass | Yes |
| Iteration count | ≤ budget |
| Progress stalled | 2 iterations without change → escalate |
```

---

## Part 4: Implementation Checklist

### Quick Wins (< 30 min each)

- [ ] Add Security Constraints block to `audit-go.md`
- [ ] Add Security Constraints block to `pr_review.md`
- [ ] Refine Role blocks in all 9 prompts (more specific)
- [ ] Add Over-Specification Warning to `task-prompt.md`

### Medium Effort (1-2 hours each)

- [ ] Upgrade CoVe to Factor+Revise in 6 files
- [ ] Add Multi-Perspective Reflection to 3 iteration-based prompts
- [ ] Add Reasoning Strategy Selection to research prompts

### Larger Refactors (half day)

- [ ] Create shared `_blocks/` directory for reusable prompt components
- [ ] Add Output Contract validation to all prompts
- [ ] Create prompt testing framework (input/expected patterns)

---

## Part 5: Research References

### Core Papers

| Paper | Year | Key Contribution |
|-------|------|------------------|
| Chain-of-Verification (CoVe) | META 2023 | Verification loop reduces hallucinations |
| Self-Planning Code Generation | PKU 2024 | +25% with plan-before-code |
| Principled Personas | 2025 | Role prompting effectiveness study |
| PASR (ProActive Self-Refinement) | 2025 | -41% tokens, +8% accuracy |
| PR-CoT (Multi-Perspective Reflection) | 2026 | Better self-correction |
| SOLAR (Dynamic Topology) | 2025 | +9-10% with adaptive reasoning |
| LongGuide | 2025 | +5% with structured constraints |
| Secure Code Prompting | 2025 | -56% vulnerabilities |

### Key Insights Summary

1. **Verification should be factored** - Independent verification catches more errors
2. **Iteration has diminishing returns** - Use adaptive stopping, budget iterations
3. **Multi-perspective reflection > single critique** - Check logic, completeness, correctness, edges
4. **Over-specification hurts** - Keep MUST constraints ≤7
5. **Roles help reasoning, not recall** - Use for analysis, not factual lookup
6. **Security must be explicit** - Models don't consider security by default
7. **Topology matters** - Match reasoning structure to task complexity

---

## Appendix: Reusable Prompt Blocks

### Block: Factor+Revise Verification

```markdown
## VERIFY (Factor+Revise)

### 1. Generate Verification Questions
| ID | Question |
|----|----------|
| V1 | "Does {file}:{line} contain {pattern}?" |

### 2. Execute Independently (no reference to original)

### 3. Reconcile
| ID | Independent Answer | Verdict |
|----|-------------------|---------|
| V1 | {result} | ✓/✗/? |

### 4. Output Only Confirmed (✓) Items
```

### Block: Multi-Perspective Reflection

```markdown
## Pre-Iteration Reflection

| Dimension | Question | ✓/✗ |
|-----------|----------|-----|
| Logic | Any contradictions? | |
| Complete | All requirements? | |
| Correct | Matches acceptance? | |
| Edges | Boundaries handled? | |
| External | Tools verified? | |
```

### Block: Security Constraints

```markdown
## Security Checklist

- [ ] No hardcoded secrets
- [ ] Input validation on public APIs
- [ ] Injection prevention
- [ ] Safe error handling
- [ ] Resource cleanup
```

### Block: Iteration Budget

```markdown
## Iteration Budget

| Complexity | Max | Action at Limit |
|------------|-----|-----------------|
| Trivial | 1 | Complete |
| Simple | 2 | Review |
| Moderate | 3 | Review |
| Complex | 4 | Escalate |
```

---

*End of Research Review*
