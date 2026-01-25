# Task

Create and execute a spec-first task with optional planning and TDD modes.

## Usage
- `{description}` — Ad-hoc task
- `#{number}` — GitHub issue
- `--plan` — Plan first, await "GO" before implementing
- `--tdd` — Test-first development

## Workflow

### Phase 1: UNDERSTAND (10%)
```bash
git remote get-url origin
git rev-parse --show-toplevel
```

**If GitHub Issue**: Fetch title, body, labels, comments, linked PRs.

**Clarify (≤2 questions)**: Ambiguities? Implicit assumptions?

### Phase 2: SPECIFY (15%)
| Element | Define |
|---------|--------|
| Inputs | Data/state entering |
| Outputs | What changes |
| Constraints | Perf, security, style |
| Acceptance | How verify works |
| Edges | What fails |
| Out of Scope | NOT doing |

**Constraints (prioritized):**
- **MUST** (≤7): Hard requirements
- **SHOULD**: Best effort
- **MUST NOT**: Forbidden
- **Security**: No secrets, input validation, safe errors

### Phase 3: PLAN (if `--plan`)
| # | Approach | Effort | Risk | Tradeoffs |
|---|----------|--------|------|-----------|
| 1 | {name} | L/M/H | L/M/H | {pro/con} |
| 2 | {name} | L/M/H | L/M/H | {pro/con} |
| 3 | {name} | L/M/H | L/M/H | {pro/con} |

**Selected**: {approach} because {rationale}

→ STOP. Await "GO"

### Phase 4: IMPLEMENT

**If `--tdd`:**
1. Write failing test first
2. Confirm test fails
3. Implement minimum to pass
4. Refactor if needed
5. Repeat

**Progress Tracker:**
| # | Task | Status |
|---|------|--------|
| 0 | Create branch | `[TODO]` |
| 1 | {task} | `[TODO]` |
| N | Verify acceptance | `[TODO]` |
| N+1 | Create PR | `[TODO]` |

Create or update `AGENTS.md` for task-loop continuation (preserve existing content).

### Phase 5: VERIFY
Before marking done:
- [ ] Code compiles/type-checks
- [ ] Tests pass
- [ ] Acceptance criteria met
- [ ] Edge cases handled

## Reflection (Each Iteration)
| Dim | Check |
|-----|-------|
| Logic | Contradictions? |
| Complete | All requirements? |
| Correct | Matches acceptance? |
| Edges | Boundaries handled? |
| External | Tools pass? |

## Iteration Budget
| Complexity | Max |
|------------|-----|
| Trivial | 1 |
| Simple | 2 |
| Moderate | 3 |
| Complex | 4 |

Exceeded → Escalate to human

## Commit
```bash
git commit -s -S -m "type(scope): description"
```

## PR
```bash
gh pr create --title "type(scope): desc" --body "Fixes #N"
```

> 🛑 **No auto-merge** — Always await human approval
