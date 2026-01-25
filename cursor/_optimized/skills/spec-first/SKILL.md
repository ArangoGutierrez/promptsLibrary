---
name: spec-first
description: Spec-first task methodology
---

# Spec-First

## Activate

impl feature|create task prompt|"spec-first"|"implement"

## Time

| Type | Spec | Plan | Impl | Verify |
|------|------|------|------|--------|
| Trivial | 5% | 5% | 80% | 10% |
| Simple | 15% | 10% | 60% | 15% |
| Mod | 25% | 15% | 45% | 15% |
| Complex | 35% | 15% | 35% | 15% |

## Spec Elements

| El | Def |
|----|-----|
| In | data/state entering |
| Out | changes |
| Constraints | perf,sec,style |
| Accept | verify-how |
| Edge | fail-how |
| OOS | NOT doing |

## Constraints

MUST(req)≤7|SHOULD(prefer)|MUST-NOT(forbidden)
⚠>7 MUST→split or raise complexity

## Security(always)

No secrets|input-val@public|safe err

## Progress

| # | Phase | Task | Status |
|---|-------|------|--------|
| 0 | Setup | branch | [TODO] |
| 1 | Spec | verify | [TODO] |
| 2 | Impl | {task} | [TODO] |
| N | Test | verify accept | [TODO] |

[TODO]|[WIP]|[DONE]|[WAIT]|[BLOCKED:x]

## Reflect(before iter)

Logic:contradict?|Complete:all req?|Correct:match accept?|Edge:bounds?|Ext:tools?
