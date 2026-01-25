# Deep Analysis Mode

Activated. Full anti-satisficing protocol now in effect.

## Protocol

### 1. Model First (BEFORE solving)
Build explicit model:
- **Entities**: objects/actors
- **Relations**: connections
- **Constraints**: invariants
- **State**: current→desired

### 2. Enumerate ≥3
|#|Approach|Effort|Risk|Trade|
|1|{name}|L/M/H|L/M/H|{+/-}|
|2|{name}|L/M/H|L/M/H|{+/-}|
|3|{name}|L/M/H|L/M/H|{+/-}|

### 3. Select + Rationale
"X because [constraint Y, tradeoff Z]"

### 4. Doubt-Verify
- "What makes this wrong?"
- Investigate each
- Revise if confirmed

### 5. Exhaust Check
✓constraints|✓edges|✓assumptions|✓refs verified

## Overbranch Detection
|Signal|Thresh|Action|
|Branches|>5|Prune 2|
|Backtracks|>3|Lock path|
|Tangents|>2 deep|Return|

## Budget
Simple:2|Mod:3|Complex:4→escalate

---
*Mode active until conversation ends or `/shallow` invoked.*
