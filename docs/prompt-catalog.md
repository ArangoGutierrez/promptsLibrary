# Prompt Catalog

Complete reference of all prompts in the library, organized by category.

## Quick Reference

| Trigger | Prompt | Purpose |
|---------|--------|---------|
| "Run Audit [scope]" | `audit-go.md` | Deep Go/K8s code audit |
| "Create prompts from audit" | `audit-to-prompt.md` | Convert audit findings to tasks |
| "Fix audit issues" | `audit-to-prompt.md` | Generate and fix Critical issues |
| "Git Polish" | `git-polish.md` | Clean up git history |
| "Plan Mode" | `workflow.md` | Two-phase planning workflow |
| "Pre-Flight" | `preflight.md` | Scan repo before changes |
| "Research Issue #N" | `research-issue.md` | Deep issue analysis |
| "Review PR [#N]" | `pr_review.md` | Code review workflow |
| "Create prompt for Issue #N" | `issue-to-prompt.md` | Research + task prompt |
| "Create prompt for: {desc}" | `task-prompt.md` | Ad-hoc task prompt |
| "Deep Mode" | `master-agent.md` | Depth-forcing agent |
| "Meta-Enhance" | `meta-enhance.md` | Recursive self-improvement |

---

## Core Prompts

### master-agent.md

**Purpose:** Depth-forcing, token-optimized master prompt for complex analysis.

**When to Use:**
- Large codebase navigation
- Complex multi-step reasoning
- High-stakes recommendations

**Key Features:**
- Anti-satisficing protocol (enumerate ≥3 options)
- Chain-of-Draft for token efficiency
- Solver-Critic-Reviser loop
- Overbranching detection

**Trigger:** "Deep Mode" or direct `@prompts/master-agent.md`

---

### task-prompt.md

**Purpose:** Generate spec-first autonomous task prompts.

**When to Use:**
- Creating structured tasks for AI execution
- Converting requirements into actionable prompts
- Any feature/fix that needs systematic approach

**Key Features:**
- Spec-first workflow (understand → specify → plan → implement)
- Time allocation by complexity
- Multi-perspective reflection (PR-CoT)
- Iteration budgets

**Triggers:**
- "Create prompt for Issue #NNN"
- "Create prompt for: {description}"
- "Create prompt for recommended solution"

**Output:** `prompts/{type}-{slug}.md`

---

### workflow.md

**Purpose:** Two-phase planning before implementation.

**When to Use:**
- Before making significant changes
- When you need approval checkpoints
- Complex refactoring

**Key Features:**
- Plan-only mode until explicit "GO"
- Blast radius tracking
- ≤80 LOC per step, ≤3 files per diff

**Trigger:** "Plan Mode"

---

## Code Review Prompts

### audit-go.md

**Purpose:** Deep defensive audit for Go and Kubernetes code.

**When to Use:**
- Before shipping to production
- When inheriting a codebase
- Security-sensitive changes

**Scope:**
- **EffectiveGo:** race conditions, error handling, interface pollution
- **Defensive:** input validation, nil safety, timeouts, resource cleanup
- **K8sReady:** graceful shutdown, observability, probes, config
- **Security:** secrets, injection, sanitization, error leaks, authz

**Output:** `AUDIT_REPORT.md` with severity levels (Critical/Major/Minor)

**Trigger:** "Run Audit [scope]" where scope is `@Codebase`, `@folder/`, or "last N commits"

---

### pr_review.md

**Purpose:** Rigorous pull request code review.

**When to Use:**
- Before approving PRs
- Final gatekeeper review
- When you need evidence-based feedback

**Scope:**
- Architecture & patterns
- Security (hardcoded secrets, injection, authz)
- Safety & error handling
- Performance
- Testability

**Output:** In-chat review with Blocking Issues, Code Health suggestions, and Verdict

**Trigger:** "Review PR #NNN" or "Review PR" (uses current branch)

---

### preflight.md

**Purpose:** Reconnaissance scan before proposing changes.

**When to Use:**
- Starting work on unfamiliar codebase
- Before running audits or making changes
- To understand toolchain and health gates

**Checks:**
- Workspace status (git state)
- Toolchain detection (go.mod, package.json, etc.)
- Health gates (format, lint, typecheck)
- Topology (packages/modules)

**Output:** Pre-Flight Report with confidence ratings

**Trigger:** "Pre-Flight"

---

## Git Prompts

### git-polish.md

**Purpose:** Rewrite local git history into clean, atomic, signed commits.

**When to Use:**
- Before pushing messy local commits
- When you need atomic commits for CI
- Preparing commits for PR

**Features:**
- Non-interactive (no UI editors)
- DCO sign-off (-s) + SSH signing (-S)
- Conventional Commits format
- Verification that each commit compiles

**Trigger:** "Git Polish"

---

## Research Prompts

### research-issue.md

**Purpose:** Deep analysis of GitHub issues.

**When to Use:**
- Before starting work on an issue
- When issue is complex or unclear
- To generate solution options

**Output:** `ISSUE_RESEARCH.md` with:
- Problem classification
- Root cause analysis
- 2-3 solution approaches with trade-offs
- Comparison matrix

**Trigger:** "Research Issue #NNN"

---

### issue-to-prompt.md

**Purpose:** Research issue AND generate task prompt.

**When to Use:**
- Complete workflow: research → task prompt
- When you want to go from issue to actionable prompt

**Phases:**
1. Research (40%): Fetch issue, analyze, design solutions
2. Generate (60%): Create spec-first task prompt

**Trigger:** "Create prompt for Issue #NNN"

---

## Generator Prompts

### audit-to-prompt.md

**Purpose:** Convert audit findings into task prompts.

**When to Use:**
- After running an audit
- Mid-PR workflow (fixes go to current branch)
- Batch processing audit findings

**Features:**
- Groups findings by severity
- Generates prompts for Critical/Major/Minor
- No branch creation (uses current branch)

**Triggers:**
- "Create prompts from audit"
- "Fix audit issues"

---

### meta-enhance.md

**Purpose:** Recursive self-improvement of the prompt library.

**When to Use:**
- Updating prompts with latest research
- Finding gaps and inconsistencies
- Evolving the library

**Protocol:**
1. Audit current state
2. Research latest findings
3. Identify gaps
4. Apply improvements
5. Verify and log

**Trigger:** "Meta-Enhance"

---

## Compressed Variants

### _compressed/task-prompt-min.md

**Purpose:** Token-optimized version of task-prompt.md.

**When to Use:**
- Large context windows
- Token-constrained environments
- When full prompt is too verbose

**Stats:**
- Original: ~430 lines, ~12K chars
- Compressed: ~220 lines, ~5K chars
- Reduction: ~58% tokens saved

---

## Snippets (Non-Prompt Files)

### snippets/cursor-rules.md

Copy-paste ready rules for Cursor User Settings.

### snippets/cursor-rules-depth.md

Extended documentation explaining the rules and their research basis.

---

## Research & Documentation

### PROMPT_RESEARCH_360.md

Complete research review covering:
- Chain of Verification (CoVe)
- Self-Planning code generation
- Multi-perspective reflection
- Token optimization
- Security-aware prompting

### EVOLUTION_LOG.md

Tracks changes across meta-enhance iterations:
- Research integrated
- Patterns added
- Metrics and coverage

---

## Choosing the Right Prompt

```text
┌─────────────────────────────────────────────────────────────┐
│ What are you trying to do?                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Understand codebase? ──────────────────► Pre-Flight         │
│                                                             │
│ Review code quality? ──────────────────► Run Audit          │
│                                                             │
│ Review a PR? ──────────────────────────► Review PR          │
│                                                             │
│ Fix audit findings? ───────────────────► Fix audit issues   │
│                                                             │
│ Research an issue? ────────────────────► Research Issue #N  │
│                                                             │
│ Create a task? ────────────────────────► Create prompt for  │
│                                                             │
│ Plan before coding? ───────────────────► Plan Mode          │
│                                                             │
│ Clean git history? ────────────────────► Git Polish         │
│                                                             │
│ Complex analysis? ─────────────────────► Deep Mode          │
│                                                             │
│ Improve prompts? ──────────────────────► Meta-Enhance       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
