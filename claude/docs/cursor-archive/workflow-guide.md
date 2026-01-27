# Cursor Workflow Guide

This guide shows how all Cursor customizations work together as an integrated system.

## System Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         RULES (Always Active)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │project.md│  │user-rules│  │ security │  │    go-style      │ │
│  │ (depth)  │  │ (prefs)  │  │ (checks) │  │ (lang-specific)  │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                      COMMANDS (User-Triggered)                   │
│                                                                  │
│  Issue Workflow:     /issue → /code → /test → /self-review → /push │
│  Research:           /research → /architect                      │
│  Quality:            /audit → /quality → /review-pr              │
│  Automation:         /loop → /task                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                    AGENTS (Auto/Manual Invoked)                  │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │arch-explorer│───→│devil-advocate│───→│ prototyper  │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         ↓                  ↓                  ↓                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                     synthesizer                              ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │  auditor  │  │perf-critic│  │api-reviewer│  │ verifier  │    │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘    │
│                           ↓                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                     synthesizer                              ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                         HOOKS (Automatic)                        │
│                                                                  │
│  afterFileEdit:      format.sh (auto-format)                    │
│  beforeShell:        security-gate.sh, sign-commits.sh          │
│  stop:               task-loop.sh, context-monitor.sh           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Primary Workflows

### Workflow 1: Issue-to-PR (Standard Development)

The most common workflow for implementing GitHub issues:

```text
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────────┐     ┌─────────┐
│ /issue  │────→│  /code  │────→│  /test  │────→│/self-review │────→│  /push  │
│  #123   │     │         │     │         │     │             │     │         │
└─────────┘     └─────────┘     └─────────┘     └─────────────┘     └─────────┘
     │               │               │                 │                 │
     ↓               ↓               ↓                 ↓                 ↓
 AGENTS.md      Atomic          Tests run         Review           PR created
 created        commits         verified          changes
```

**Step-by-step:**

1. **`/issue #123`** - Analyzes issue, creates task breakdown in AGENTS.md
2. **`/code`** - Works on next [TODO] task, creates atomic commit
3. **`/test`** - Runs test suite, reports pass/fail
4. **`/self-review`** - Reviews all changes before push
5. **`/push`** - Pushes and creates PR

**When to use:** Any GitHub issue implementation

---

### Workflow 2: Parallel Execution (Independent Tasks)

When you have multiple independent tasks:

```text
┌─────────┐     ┌───────────────────────────────────────┐     ┌─────────┐
│ /issue  │────→│          /parallel --analyze          │────→│ /push   │
│  #123   │     │  Identifies independent tasks         │     │         │
└─────────┘     └───────────────────────────────────────┘     └─────────┘
                                  │
                                  ↓
                    ┌─────────────────────────────┐
                    │ /parallel A | B | C         │
                    │                             │
                    │  ┌───┐  ┌───┐  ┌───┐       │
                    │  │ A │  │ B │  │ C │       │
                    │  └───┘  └───┘  └───┘       │
                    │   (parallel subagents)     │
                    └─────────────────────────────┘
```

**Example:**

```bash
/issue #123                        # Creates AGENTS.md with tasks
/parallel --analyze                # Shows which can parallelize
/parallel "Add user model | Add handler | Update config"
/code                              # Sequential tasks (tests)
/push
```

**When to use:**

- Tasks touch different files/packages
- 3+ independent tasks identified
- Want to save time on multi-task issues

---

### Workflow 3: Autonomous Loop (Extended Tasks)

For complex tasks that need multiple iterations:

```text
┌─────────┐     ┌─────────────────────────────────────┐     ┌──────────┐
│ /issue  │────→│              /loop                   │────→│   /push  │
│  #123   │     │   (iterates until DONE or max)      │     │          │
└─────────┘     └─────────────────────────────────────┘     └──────────┘
                                  │
                                  ↓
                    ┌─────────────────────────┐
                    │ Automatic cycle:        │
                    │ /code → /test → check   │
                    │ Repeat until complete   │
                    └─────────────────────────┘
```

**Example:**

```bash
/issue #123
/loop Work through all tasks in AGENTS.md --done "Status: DONE" --max 15
/push
```

**When to use:**

- Tasks with 5+ subtasks
- Well-defined completion criteria
- Can run with minimal supervision

---

### Workflow 3: Architecture Decision

For exploring different approaches before committing:

```text
┌──────────┐     ┌─────────────┐     ┌────────────────┐     ┌────────────┐
│/research │────→│arch-explorer│────→│devil-advocate  │────→│ prototyper │
│ problem  │     │ 3-5 options │     │ challenge each │     │ validate   │
└──────────┘     └─────────────┘     └────────────────┘     └────────────┘
                                                                   │
                                                                   ↓
                                                            ┌────────────┐
                                                            │synthesizer │
                                                            │ recommend  │
                                                            └────────────┘
```

**Alternative (faster):**

```bash
/architect {problem} --quick
```

**When to use:**

- ADRs (Architecture Decision Records)
- Technical RFCs
- Migration planning
- "How should we..." questions

---

### Workflow 4: Code Quality Review

For thorough multi-perspective review:

```text
┌─────────────────────────────────────────────────────────────┐
│                      /quality (parallel)                     │
├──────────────┬──────────────┬──────────────┬────────────────┤
│   auditor    │  perf-critic │ api-reviewer │    verifier    │
│  (security)  │ (performance)│  (API design)│  (correctness) │
└──────────────┴──────────────┴──────────────┴────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ Unified Report  │
                    │ Risk: H/M/L     │
                    │ Blocking issues │
                    └─────────────────┘
```

**Focused variants:**

- `/quality --api` - API review only
- `/quality --perf` - Performance review only  
- `/quality --fast` - Auditor + verifier only

**When to use:**

- Before merging to main
- PR reviews
- After major refactoring

---

### Workflow 5: Research Deep-Dive

For understanding before implementing:

```text
┌────────────────────────────────────────────────────────────────┐
│                        /research                                │
├────────────────────┬──────────────────┬────────────────────────┤
│   /research #123   │  /research topic │  /research brainstorm: │
│   (GitHub issue)   │  (codebase)      │  (360 analysis)        │
└────────────────────┴──────────────────┴────────────────────────┘
```

**Example:**

```bash
/research #123                    # Analyze GitHub issue
/research "auth system"           # Explore codebase topic
/research brainstorm: new cache   # Full SWOT analysis with web research
```

**When to use:**

- Before `/issue` for complex issues
- Investigating root causes
- Evaluating new technologies

---

## Agent Relationships

### Collaborative Agents

| Agent | Works With | Relationship |
|-------|------------|--------------|
| arch-explorer | devil-advocate | Explorer proposes, advocate challenges |
| arch-explorer | prototyper | Explorer designs, prototyper validates |
| devil-advocate | synthesizer | Advocate challenges, synthesizer weighs |
| All reviewers | synthesizer | Reviewers analyze, synthesizer combines |
| verifier | All | Verifier validates any agent's claims |

### Agent Trigger Rules (from quality-gate.md)

| File Pattern | Agent Triggered |
|--------------|-----------------|
| `**/handlers/**`, `**/routes/**` | api-reviewer |
| `**/db/**`, `**/sql/**` | perf-critic |
| `**/auth/**`, `**/crypto/**` | auditor |
| Major feature complete | verifier |
| "How should we..." | arch-explorer |
| "Let's do X" | devil-advocate |

---

## Shared State: AGENTS.md

AGENTS.md is the central coordination file:

```markdown
# AGENTS.md

## Current Task
Issue #123: Add user authentication

## Status: IN_PROGRESS

## Tasks
| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Add User model | `[DONE]` | abc123 |
| 2 | Create auth middleware | `[WIP]` | |
| 3 | Add login endpoint | `[TODO]` | |
| 4 | Run tests | `[TODO]` | |

## Acceptance Criteria
- [ ] Users can register
- [ ] Users can login
- [x] Passwords are hashed
```

**Status markers:**

- `[TODO]` - Not started
- `[WIP]` - In progress
- `[DONE]` - Complete
- `[BLOCKED:{reason}]` - Cannot proceed

---

## Hook Automation

### format.sh (afterFileEdit)

- Auto-formats files on save
- Go → gofmt, TS → prettier, Python → ruff/black, Rust → rustfmt

### security-gate.sh (beforeShellExecution)

- Blocks dangerous commands (force push, rm -rf /, etc.)
- Requires confirmation for git history changes

### sign-commits.sh (beforeShellExecution)

- Auto-adds `-s -S` to git commit commands
- Enforces DCO signoff and GPG signing

### task-loop.sh (stop)

- Enables `/loop` autonomous execution
- Continues work until completion phrase detected

### context-monitor.sh (stop)

- Tracks context health
- Recommends `/summarize` when context filling
- Suggests new session when appropriate

---

## Decision Trees

### "I have a GitHub issue to implement"

```text
Is it complex (>5 tasks)?
  YES → /research #N → /issue #N → /loop
  NO  → /issue #N → /parallel --analyze
        ↓
        Has independent tasks?
          YES → /parallel A | B | C → /code (remaining)
          NO  → /code (manual cycle)
```

### "I need to design something"

```text
Is it an architecture decision?
  YES → /architect {problem}
  NO  → /research {topic}
```

### "I need to review code"

```text
Is it a PR from someone else?
  YES → /review-pr #N
  NO (my own code) → /self-review
```

### "Something isn't working"

```text
Is it a test failure?
  YES → /test --quick → fix → repeat
Is it a linting error?
  YES → format.sh should auto-fix
Is it a security concern?
  YES → /audit --fix
```

---

## Token Optimization

For large codebases or long sessions:

| Situation | Solution |
|-----------|----------|
| Rules too heavy | `--optimized` (~60% smaller) |
| Context filling | `--lazy` tiered loading |
| Long session | `/context-reset` after summarize |
| High token usage | Start new session between tasks |

### Deployment Modes

```bash
# Compare token impact
./scripts/deploy-cursor.sh --check

# Deploy options
./scripts/deploy-cursor.sh              # Full (~2,000 tok always-on)
./scripts/deploy-cursor.sh --optimized  # Optimized (~1,200 tok)
./scripts/deploy-cursor.sh --lazy       # Lazy (~200 tok always-on)
```

### Lazy Loading Details

When deployed with `--lazy`:

| Tier | Loaded When | Tokens | Examples |
|------|-------------|--------|----------|
| Core | Always | ~200 | Essential constraints |
| Language | File in context | ~100 | go.md, ts.md, python.md |
| Mode | `/command` invoked | ~150-200 | /deep, /security, /perf, /tdd |
| Full cmd | `/command` invoked | ~300-500 | /task, /audit, /issue |

**On-demand modes:**

```bash
/deep       # Activate deep analysis (anti-satisficing)
/security   # Activate security audit mode
/perf       # Activate performance review mode
/tdd        # Activate test-driven development mode
```

### When to Use Each Mode

| Scenario | Recommended |
|----------|-------------|
| Daily development | `--lazy` + modes on-demand |
| Complex audit/review | `--optimized` or full |
| Large codebase (>100k LOC) | `--lazy` |
| Learning the system | Full (no flags) |
| Quick fixes | `--lazy` |
| Long research sessions | `--lazy` + `/deep` when needed |

---

## Error Recovery

### Command Failed Mid-Workflow

| Problem | Recovery |
|---------|----------|
| `/issue` failed to parse | Check GitHub CLI: `gh issue view #N` |
| `/code` broke the build | `/test` to identify, then fix |
| `/loop` hit max iterations | Review AGENTS.md, continue manually |
| `/loop` stuck | `/context-reset`, then restart loop |
| `/push` rejected | Fix conflicts, `/self-review`, retry |

### Agent Conflicts

When agents disagree:

1. **synthesizer** weighs evidence from each
2. Higher severity wins (security > performance > style)
3. If still unclear, present options to user

### State Recovery

```bash
# Reset loop state (stuck loop)
rm -f .cursor/loop-state.json .cursor/loop-state.lock

# Reset context tracking
/context-reset

# View current state
/context-reset --status
```

### AGENTS.md Corruption

If AGENTS.md is malformed:

1. Check git: `git diff AGENTS.md`
2. Either fix manually or `git checkout AGENTS.md`
3. Re-run `/issue` to regenerate

---

## Conflict Resolution

When rules conflict, priority order:

1. **Security** > Correctness > Performance > Style
2. **User explicit request** > Default behavior
3. **project.md** > user-rules.md (unless safety concern)
4. **Blocking issues** > Suggestions

---

## Quick Reference

| Goal | Command |
|------|---------|
| Start issue work | `/issue #N` |
| Work on next task | `/code` |
| Run tests | `/test` |
| Review my changes | `/self-review` |
| Push and create PR | `/push` |
| Autonomous work | `/loop {task}` |
| **Run tasks in parallel** | `/parallel task1 \| task2` |
| **Analyze parallelization** | `/parallel --analyze` |
| Deep research | `/research {topic}` |
| Architecture options | `/architect {problem}` |
| Full quality review | `/quality` |
| Security audit | `/audit` |
| Review someone's PR | `/review-pr #N` |
| Reset context | `/context-reset` |
