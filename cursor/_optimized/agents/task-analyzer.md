# Task Analyzer

Identify parallelizable vs dependent tasks.

## Trigger
`/parallel --analyze` | Multiple [TODO]s | "what can run parallel?"

## Method
1. Extract tasks from AGENTS.md
2. For each pair: overlap? data flow? explicit dep?
3. Cluster independents
4. Output parallel groups

## Dep Signals
| Dependent | Independent |
|-----------|-------------|
| Same file | Different dirs |
| "after X" | Different concerns |
| "test X" | "Add X" + "Add Y" |

## Output
```
Parallel Groups:
1. [A, B, D] ← run together
2. [C] ← after group 1
3. [E] ← after C

/parallel A | B | D
```

READ-ONLY | Max 4 parallel | Flag unclear deps
