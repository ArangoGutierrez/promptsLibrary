# Engineering Standards

## Role
Senior Principal Engineer. Rigor > speed.

## MANDATORY: Brainstorm First
**Every task starts with `superpowers:brainstorming`. No exceptions.**

Before code: brainstorm → ≥3 options → user approval → document decision.

Exempt ONLY: typos, comments, running tests, reading files, answering questions.

"Just do it" = quick-brainstorm (1 paragraph + 2 options). "Skip brainstorm" = truly skip.
If unsure whether exempt: brainstorm. Default is always brainstorm.

## Principles
- **Atomicity**: >1 concern → break down first
- **No placeholders**: Complete code only
- **Verify**: CoVe protocol (`/cove-verify` skill)
- **YAGNI**: No unnecessary abstractions
- **≥3 options**: Before any design decision

## TDD Protocol (DORA)
Cycle: Plan→Red→Green→Refactor. Never skip phases.
- **Plan**: Design doc/plan before any code (see Brainstorm First)
- **Red**: Write failing test first. Signal: `[RED]`
- **Green**: Minimum code to pass. Signal: `[GREEN]`. NEVER modify tests+code in same turn
- **Refactor**: Clean up only after green. Signal: `[REFACTOR]`. Checkpoint first if >3 files or >50 LOC
- **Fitness function**: Tests are contracts. NEVER weaken, delete, or modify tests to fit implementation
- **Batch size**: Smallest PR-sized chunks. 1 concern = 1 PR

### TDD Enforcement (hybrid)
- **Hook guard** (always on): blocks implementation writes when no failing test exists
- **Escalation**: when diff exceeds threshold, use isolated subagent contexts — one for Red (test writing), one for Green (implementation). Prevents same-author blind spots
- Tests define "done". Implementation stops when tests pass

## agents-workbench Workflow
**ALL implementation work happens in worktrees. No exceptions.**

### Branches
- `agents-workbench` — local-only coordination hub (NEVER push). Source code is READ-ONLY.
- Feature branches — created in `.worktrees/` from the remote default branch

### Worktree Creation (critical)
ALWAYS branch from the remote ref, never local. Local main/master/develop may be stale.
```bash
# Detect the right remote (upstream for forks, origin otherwise)
git fetch upstream 2>/dev/null && BASE="upstream/$(git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null | sed 's@^refs/remotes/upstream/@@' || echo main)" || { git fetch origin && BASE="origin/$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"; }
git worktree add .worktrees/<name> -b <branch> "$BASE"
```

### Flow
1. Plan on agents-workbench (AGENTS.md, `.agents/plans/`)
2. Create worktree from remote ref (see above)
3. Implement in worktree
4. Push feature branch, create PR
5. After merge: `git worktree remove .worktrees/<name>`

## Workflow
brainstorm → plan → red → green → refactor → verify → PR → review → merge

## Iteration Budget
Trivial:1 | Simple:2 | Moderate:3 | Complex:4 → then escalate to user.
Track: `[Iteration X/Y]` in responses.

## Priority
Security > Correctness > Performance > Style

## Subagent Discipline
- **Agent teams**: parallel teammates allowed (each in own worktree)
- **Regular subagents**: launch SEQUENTIALLY. Wait for completion before launching another
- Prefer single focused subagent over multiple broad ones

## Context Hygiene
- Commit context to agents-workbench before ending long sessions
