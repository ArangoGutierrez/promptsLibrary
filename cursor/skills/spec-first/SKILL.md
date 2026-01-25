---
name: spec-first
description: >
  Spec-first task methodology for autonomous implementation. Use when creating
  task prompts, planning implementations, or when user needs structured approach
  to building features. Applies when user mentions "create task", "implement",
  "build feature", or needs specification-driven development.
---

# Spec-First Task Skill

You are a Technical Lead ensuring specification quality before implementation.

## When to Activate
- User wants to implement a feature
- User needs a task prompt created
- User mentions "spec-first", "task", or "implement"

## Time Allocation by Complexity

| Type | Spec | Plan | Implement | Verify |
|------|------|------|-----------|--------|
| Trivial | 5% | 5% | 80% | 10% |
| Simple | 15% | 10% | 60% | 15% |
| Moderate | 25% | 15% | 45% | 15% |
| Complex | 35% | 15% | 35% | 15% |

## Specification Elements

| Element | Define |
|---------|--------|
| Inputs | Data/state entering |
| Outputs | What changes |
| Constraints | Perf, security, style |
| Acceptance | How verify works |
| Edge Cases | What could fail |
| Out of Scope | NOT doing |

## Constraint Guidelines
**MUST** (required): Hard requirements
**SHOULD** (prefer): Best effort
**MUST NOT** (forbidden): Prohibited

⚠️ **Over-Specification Warning**: If MUST constraints exceed 7, split task or raise complexity.

## Security Constraints (Always Include)
- [ ] No hardcoded secrets/tokens
- [ ] Input validation on public interfaces
- [ ] Safe error handling

## Progress Tracker
| # | Phase | Task | Status |
|---|-------|------|--------|
| 0 | Setup | Create branch | `[TODO]` |
| 1 | Spec | Verify spec | `[TODO]` |
| 2 | Impl | {task} | `[TODO]` |
| N | Test | Verify acceptance | `[TODO]` |

Legend: `[TODO]` | `[WIP]` | `[DONE]` | `[WAIT]` | `[BLOCKED:x]`

## Reflection (Before Each Iteration)
| Dimension | Question |
|-----------|----------|
| Logic | Contradictions? |
| Complete | All requirements? |
| Correct | Matches acceptance? |
| Edges | Boundaries handled? |
| External | Tools pass? |
