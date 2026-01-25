# Cursor Configuration V2 - Comprehensive Report

## Executive Summary

This project provides a complete, portable Cursor AI configuration system designed for open source developers. It includes **11 commands**, **4 skills**, **3 agents**, **4 hooks**, and **4 rules** that work together to automate your daily coding workflow.

### Philosophy
- **Spec-first**: Understand and specify before implementing
- **Atomic commits**: Each task = one logical change = one commit
- **Anti-satisficing**: Depth over speed, rigor over convenience
- **Verification**: Trust nothing, verify everything

---

## Directory Structure

```
cursor/
├── commands/          # 11 slash commands
│   ├── issue.md       # /issue - Start session with GitHub issue
│   ├── code.md        # /code - Work on next task
│   ├── test.md        # /test - Run tests
│   ├── self-review.md # /self-review - Review before push
│   ├── push.md        # /push - Create PR
│   ├── loop.md        # /loop - Ralph-Loop automation
│   ├── task.md        # /task - Ad-hoc tasks
│   ├── review-pr.md   # /review-pr - Review others' PRs
│   ├── research.md    # /research - Deep investigation
│   ├── audit.md       # /audit - Security/reliability audit
│   └── git-polish.md  # /git-polish - Clean commit history
├── skills/            # 4 agent-triggered skills
│   ├── deep-analysis/SKILL.md
│   ├── spec-first/SKILL.md
│   ├── pr-review/SKILL.md
│   └── go-audit/SKILL.md
├── agents/            # 3 specialized subagents
│   ├── verifier.md
│   ├── researcher.md
│   └── auditor.md
├── hooks/             # 3 automation hooks
│   ├── task-loop.sh   # Stop hook for persistent execution
│   ├── security-gate.sh # Block dangerous commands
│   └── format.sh      # Auto-format on save
├── hooks.json         # Hook configuration
└── rules/             # 4 always-on rules
    ├── project.md     # Core engineering standards
    ├── user-rules.md  # Personal preferences
    ├── security.md    # Security constraints
    └── go-style.md    # Go-specific patterns
```

---

## Your Daily Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        OPEN SOURCE CONTRIBUTION WORKFLOW                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   /issue #123      ─────►  Research issue, create atomic tasks         │
│        │                   Creates AGENTS.md in project root           │
│        │                   Creates branch: fix/issue-123-slug          │
│        ▼                                                               │
│   /code            ─────►  Work on next [TODO] task                    │
│        │                   Implements single task                      │
│        │                   Auto-commits with reference                 │
│        │                   Updates AGENTS.md [TODO] → [DONE]          │
│        │                                                               │
│   (repeat /code until all tasks done)                                  │
│        │                                                               │
│        ▼                                                               │
│   /test            ─────►  Run test suite                              │
│        │                   Auto-detects toolchain                      │
│        │                   Reports pass/fail                           │
│        ▼                                                               │
│   /self-review     ─────►  Review all changes vs main                  │
│        │                   Check correctness, style, security          │
│        │                   Generate findings report                    │
│        ▼                                                               │
│   /push            ─────►  Push branch, create PR                      │
│                            PR closes the issue                         │
│                            Updates AGENTS.md with PR link              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Automated Workflow (Ralph-Loop)

```bash
/issue #123
/loop Work through all tasks in AGENTS.md --done "Status: DONE" --max 15
# Walk away - agent loops until done or budget exceeded
```

---

## Commands Reference

### 1. `/issue` — Start Session with GitHub Issue

**Usage:** `/issue #123`

**What it does:**
1. Fetches issue from GitHub (title, body, labels, comments)
2. Classifies: type, scope, complexity
3. Researches codebase for relevant files
4. Designs 2-3 solution approaches
5. Creates atomic task breakdown
6. Creates or updates `AGENTS.md` with task tracker
7. Creates feature branch

**Output:**
- Console summary with recommended approach
- `AGENTS.md` with task tracker (project root)
- Git branch: `{type}/issue-{number}-{slug}`

---

### 2. `/code` — Work on Next Task

**Usage:** `/code` or `/code #2` (specific task)

**What it does:**
1. Reads AGENTS.md, finds next `[TODO]`
2. Displays current task focus
3. Updates status: `[TODO]` → `[WIP]`
4. Implements the task (single concern)
5. Verifies: compiles, acceptance met
6. Commits with issue reference
7. Updates AGENTS.md: `[WIP]` → `[DONE]`

**Commit format:**
```
{type}({scope}): {task description}

Refs: #{issue_number}
Task: {N}/{total}
```

---

### 3. `/test` — Run Tests

**Usage:** `/test`, `/test --quick`, `/test --file path/to/test.go`

**What it does:**
1. Auto-detects project toolchain (Go, Node, Python, Rust)
2. Runs appropriate test command
3. Reports pass/fail summary
4. On failure: suggests specific fixes
5. Updates AGENTS.md test task

**Supported toolchains:**
| Project | Detection | Command |
|---------|-----------|---------|
| Go | `go.mod` | `go test ./...` |
| Node/TS | `package.json` | `npm test` |
| Python | `pyproject.toml` | `pytest` |
| Rust | `Cargo.toml` | `cargo test` |

---

### 4. `/self-review` — Review Before Push

**Usage:** `/self-review`

**What it does:**
1. Gets full diff: `git diff main..HEAD`
2. Reviews each changed file for:
   - Correctness (logic, edge cases, bugs)
   - Style (patterns, naming, debug code)
   - Security (secrets, validation, errors)
   - Tests (coverage, meaningfulness)
3. Generates report with `file:line` references
4. Verdict: Ready / Minor fixes / Needs work

---

### 5. `/push` — Create PR

**Usage:** `/push`

**What it does:**
1. Pre-checks: all tasks done? tests pass? reviewed?
2. Pushes branch: `git push -u origin HEAD`
3. Creates PR with `gh pr create`:
   - Title from issue
   - Body with summary, changes, checklist
   - Links to close issue
4. Updates AGENTS.md with PR number

---

### 6. `/loop` — Ralph-Loop Persistent Execution

**Usage:** `/loop {task} --done "{phrase}" --max {N}`

**What it does:**
1. Creates `.cursor/loop-state.json` with task config and updates `AGENTS.md`
2. Works on task
3. When agent tries to stop, `task-loop.sh` hook intercepts:
   - If completion phrase found → actually stop
   - If max iterations reached → stop with warning
   - Otherwise → feed same task back, continue

**Examples:**
```bash
/loop Build REST API with CRUD, tests --done "ALL TESTS PASS" --max 20
/loop Fix all linter errors --done "NO ERRORS" --max 5
/loop Work through AGENTS.md tasks --done "Status: DONE" --max 10
```

**Best practices:**
- Clear completion criteria (machine-verifiable)
- Always set max iterations (safety net)
- Incremental goals for large tasks

---

### 7. `/task` — Ad-hoc Tasks (Not from Issue)

**Usage:** `/task {description}`, `/task --plan`, `/task --tdd`

**Phases:**
1. **UNDERSTAND** (10%): Context, clarify ambiguities
2. **SPECIFY** (15%): Inputs, outputs, constraints, acceptance
3. **PLAN** (if `--plan`): 2-3 approaches, await "GO"
4. **IMPLEMENT**: Progress tracker, commits
5. **VERIFY**: Compile, tests, acceptance

**Flags:**
- `--plan`: Stop after plan for approval
- `--tdd`: Write failing tests first

---

### 8. `/review-pr` — Review Others' PRs

**Usage:** `/review-pr #456`

**Review passes:**
1. **Security**: credentials, injection, auth bypass
2. **Bugs**: logic errors, nil deref, leaks (CHANGED lines only)
3. **Architecture**: patterns, separation, tests

**Confidence scoring (only report ≥80):**
- +20: Exact `file:line`
- +20: Introduced in THIS PR
- +20: Clear justification
- +20: Verified via re-read
- +20: Concrete fix

**Output:** 🔴 Blocking | 🟡 Health | 🔵 Questions | Verdict

---

### 9. `/research` — Deep Investigation (Read-Only)

**Usage:** `/research #123` or `/research {topic}`

**What it does:**
1. Fetches issue or analyzes topic
2. Classifies: type, severity, scope, complexity
3. Investigates codebase
4. Generates 2-3 solutions with tradeoffs
5. Recommends best approach

**Output:** Research report with root cause, solutions table, recommendation

---

### 10. `/audit` — Security/Reliability Audit

**Usage:** `/audit`, `/audit --full`, `/audit --fix`

**Audit categories:**
- **EffectiveGo**: Race conditions, channel misuse, goroutine leaks
- **Defensive**: Input validation, nil safety, timeouts, defer close
- **K8sReady**: Graceful shutdown, structured logging, probes
- **Security**: Secrets, injection, sanitization, auth

**Output:** `AUDIT_REPORT.md` with Critical/Major/Minor findings

**Fix workflow (`--fix`):** Apply fixes, add tests, re-audit, commit

---

### 11. `/git-polish` — Clean Commit History

**Usage:** `/git-polish`

**What it does:**
1. Ask how many commits to reset
2. `git reset --soft [TARGET]`
3. Group changes by type (chore, refactor, feat, fix)
4. Verify each group is atomic
5. Reconstruct with signed, Conventional Commits

**Commit format:** `git commit -S -s -m "type(scope): description"`

---

## Skills Reference

Skills are **agent-decided** — they activate automatically when triggered by keywords.

### 1. `deep-analysis` — Anti-Satisficing Mode

**Triggers:** "deep analysis", "think carefully", "complex problem"

**Protocol:**
1. Build problem model (entities, relations, constraints, state)
2. Enumerate ≥3 options before selecting
3. Select with explicit rationale
4. Doubt-verify: "What could make this wrong?"
5. Exhaust check: all constraints verified?

---

### 2. `spec-first` — Specification-Driven Development

**Triggers:** "create task", "implement", "build feature"

**Specification elements:**
| Element | Define |
|---------|--------|
| Inputs | Data/state entering |
| Outputs | What changes |
| Constraints | MUST (≤7), SHOULD, MUST NOT |
| Acceptance | How to verify |
| Edge Cases | What could fail |
| Out of Scope | NOT doing |

---

### 3. `pr-review` — Rigorous Code Review

**Triggers:** "review PR", "code review", "check this PR"

**4 review passes:**
1. Guideline Compliance
2. Bug Detection (changed lines only)
3. History Context
4. Architecture

**Confidence scoring:** Only report findings ≥80 confidence

---

### 4. `go-audit` — Go/K8s Production Readiness

**Triggers:** "audit", "production-ready", "race condition", "K8s lifecycle"

**Audit scope:**
- EffectiveGo (concurrency, errors)
- Defensive (validation, nil safety, timeouts)
- K8sReady (shutdown, logging, probes)
- Security (secrets, injection)

---

## Agents Reference

Agents are **specialized subagents** (separate processes) for isolated, focused tasks.

### 1. `verifier` — Skeptical Validator

**Model:** fast | **Mode:** readonly

**Purpose:** Independently verify claimed work is complete

**When to use:** After tasks marked done, before pushing

**Output:**
- Verified ✓ (with evidence)
- Failed ✗ (what's wrong)
- Incomplete ⚠ (what's missing)

---

### 2. `researcher` — Deep Issue Investigator

**Model:** fast | **Mode:** readonly

**Purpose:** Research GitHub issues and analyze codebase

**When to use:** Exploring unfamiliar code, investigating bugs, planning

**Output:**
- Problem summary
- Root cause with file:line refs
- 2-3 solutions with tradeoffs
- Recommendation

---

### 3. `auditor` — Security/Reliability Auditor

**Model:** fast | **Mode:** readonly

**Purpose:** Audit Go/K8s code for production risks

**When to use:** Before production deployments, security reviews

**Output:**
- Critical/Major/Minor findings with `file:line`
- Verification summary with false positive rate

---

## Hooks Reference

Hooks are **automatic triggers** that run at specific events.

### 1. `task-loop.sh` — Stop Hook (Ralph-Loop)

**Event:** `stop` (when agent completes turn)

**What it does:**
1. Reads `.cursor/loop-state.json` for configuration
2. Checks for completion in `AGENTS.md`:
   - Completion phrase found → actually stop
   - `## Status: DONE` → actually stop
   - All `[TODO]` gone → actually stop
   - `[BLOCKED]` found → stop with warning
   - Max iterations reached → stop with warning
3. If not complete → feed followup message to continue

**Configuration files:**
- `.cursor/loop-state.json`: Loop state (task, max iterations, completion phrase)
- `AGENTS.md`: Task tracker (project root, upstream Cursor pattern)
- `.cursor/task-log.md`: Iteration log

---

### 2. `sign-commits.sh` — Enforce Commit Signing

**Event:** `beforeShellExecution`

**What it does:**
1. Intercepts `git commit` commands
2. Checks for required flags:
   - `-s` (DCO signoff)
   - `-S` (GPG/SSH signature)
3. If missing, prompts with corrected command

**Example:**
```bash
# Agent tries:
git commit -m "feat: add feature"

# Hook intercepts and prompts:
# "Missing: -s (DCO signoff) and -S (GPG/SSH signature)"
# "Use: git commit -s -S -m 'feat: add feature'"
```

---

### 3. `security-gate.sh` — Block Dangerous Commands

**Event:** `beforeShellExecution`

**What it does:**
1. Intercepts shell commands before execution
2. Blocks dangerous patterns (requires confirmation):
   - `git push --force`, `git push -f`
   - `git reset --hard`
   - `rm -rf /`, `rm -rf ~`, `rm -rf *`
   - `mkfs.`, `dd if=... of=/dev`
   - `chmod -R 777`
   - Fork bomb `:(){:|:&};:`
3. Prompts for Git history operations:
   - `git rebase`, `git reset`, `git push origin`
   - `git cherry-pick`, `git revert`

**Output:** `{ "permission": "ask" }` or `{ "permission": "allow" }`

---

### 4. `format.sh` — After File Edit

**Event:** `afterFileEdit`

**What it does:**
Auto-formats files based on extension:

| Extension | Formatter |
|-----------|-----------|
| `.go` | `gofmt` |
| `.ts`, `.tsx`, `.js`, `.jsx`, `.json`, `.md` | `prettier` |
| `.py` | `ruff format` or `black` |
| `.rs` | `rustfmt` |

---

## Rules Reference

Rules are **always-on** instructions that apply to all interactions.

### 1. `project.md` — Core Engineering Standards

**Always applies**

**DEPTH (Anti-Satisficing):**
- Model-first: entities → relations → constraints → state
- Enumerate ≥3: options before selection
- No-first-solution: 2+ approaches, compare
- Critic-loop: check gaps, contradictions
- Doubt-verify: counter-evidence, re-verify
- Exhaust: all constraints checked?

**VERIFY (Factor+Revise CoVe):**
1. Claims → verification questions
2. Answer independently
3. Reconcile: ✓keep / ✗drop / ?flag

**TOKEN optimization:** ref>paste, table>prose, delta-only, no-filler

**GUARD:** ≤3 questions, no inventing, approval required for changes

---

### 2. `user-rules.md` — Personal Preferences

**Always applies**

**Override:** Prioritize rigor over speed

**Atomic Rigor:**
- Break down multi-file tasks
- No lazy placeholders (`// ... existing code ...`)
- Verification loop: check build, suggest test
- Resist urgency: warn about technical debt

**Token optimization:** Abbreviations, symbols, structured output

---

### 3. `security.md` — Security Constraints

**Always applies**

**Checklist for all code:**
- [ ] No hardcoded secrets
- [ ] Input validation at public interfaces
- [ ] Parameterized queries (no SQL concat)
- [ ] Shell arguments escaped
- [ ] No sensitive data in errors
- [ ] Auth checks on protected endpoints
- [ ] No vulnerable dependencies

---

### 4. `go-style.md` — Go-Specific Standards

**Applies to:** `**/*.go`

**Toolchain:** `gofmt` → `go vet` → `golangci-lint` → `go test`

**Patterns:**
- Accept interfaces, return structs
- Error wrapping with `%w`
- Context as first parameter
- `defer Close()` on Closers

**Concurrency:**
- Protect shared state
- Goroutine exit strategy
- Context for cancellation

---

## Deployment

### Quick Start
```bash
# Clone repository
git clone https://github.com/yourorg/dev.git
cd dev

# Deploy to ~/.cursor/ (global, with symlinks)
./scripts/deploy-cursor.sh

# Restart Cursor
# Type '/' to see commands
```

### Options
```bash
./scripts/deploy-cursor.sh                    # Global, symlinks (default)
./scripts/deploy-cursor.sh --dry-run          # Preview changes
./scripts/deploy-cursor.sh --copy --force     # Copy files, overwrite existing
./scripts/deploy-cursor.sh --project ./myapp  # Project-specific
./scripts/deploy-cursor.sh --uninstall        # Remove deployed files
```

### After Deployment
1. **Clear Cursor Settings User Rules** — they're now in `cursor/rules/user-rules.md`
2. Restart Cursor
3. Type `/` in chat to see available commands

---

## Files Created During Usage

| File | Created By | Purpose |
|------|------------|---------|
| `AGENTS.md` | `/issue`, `/task`, `/loop` | Task tracker (created or updated) |
| `.cursor/loop-state.json` | `/loop` | Ralph-Loop configuration |
| `.cursor/task-log.md` | `task-loop.sh` | Iteration history |
| `AUDIT_REPORT.md` | `/audit` | Audit findings |
| `ISSUE_RESEARCH.md` | `/research` | Research output |

---

## Summary

### Commands by Workflow Stage

| Stage | Command | Purpose |
|-------|---------|---------|
| **Start** | `/issue #N` | Research, plan, create tasks |
| **Code** | `/code` | Implement one task, commit |
| **Verify** | `/test` | Run test suite |
| **Review** | `/self-review` | Check your own changes |
| **Ship** | `/push` | Create PR |
| **Automate** | `/loop` | Persistent execution |

### Utility Commands

| Command | Purpose |
|---------|---------|
| `/task` | Ad-hoc work (not from issue) |
| `/review-pr` | Review others' PRs |
| `/research` | Investigate without implementing |
| `/audit` | Security/reliability check |
| `/git-polish` | Clean commit history |

### Automation Summary

| Hook | Event | Effect |
|------|-------|--------|
| `task-loop.sh` | stop | Auto-continue until done |
| `sign-commits.sh` | beforeShellExecution | Enforce -s -S on commits |
| `security-gate.sh` | beforeShellExecution | Block dangerous commands |
| `format.sh` | afterFileEdit | Auto-format code |

---

*Generated: 2026-01-25*
