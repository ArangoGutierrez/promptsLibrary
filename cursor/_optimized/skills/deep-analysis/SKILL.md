---
name: deep-analysis
description: Anti-satisficing deep analysis for complex problems
---

# Deep Analysis

## Activate

Complex reasoning|arch decisions|root cause|high-stakes|user:"think carefully"

## Protocol

1.Model(BEFORE solve):Entities|Relations|Constraints|State(current→desired)
2.Enumerate≥3:|#|Approach|Eff|Risk|Trade|
3.Select+rationale:"X∵[constraint Y,tradeoff Z]"
4.Doubt-verify:"What makes this wrong?"→investigate→revise if confirmed
5.Exhaust:✓all constraints|✓all edges|✓all assumptions|✓all refs verified

## Verify(CoVe)

claim→Q→answer INDEPENDENTLY→✓keep/✗drop/?flag

## Overbranch

| Signal | Thresh | Action |
|--------|--------|--------|
| Branches | >5 | Prune weakest 2 |
| Backtracks | >3 | Lock best path |
| Tangents | >2 deep | Return main |

## Budget

Simple:2|Mod:3|Complex:4→escalate
