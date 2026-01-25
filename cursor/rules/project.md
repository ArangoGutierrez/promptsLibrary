---
description: Core engineering standards for depth-forcing and verification
alwaysApply: true
---

# Project Rules

## DEPTH (Anti-Satisficing)
- **model-first**: Build problem model (entities→relations→constraints→state) BEFORE solving
- **enumerate≥3**: List ≥3 options/paths before ANY selection
- **no-first-solution**: Generate 2+ approaches, compare, select with rationale
- **critic-loop**: After output, check for gaps, contradictions, missed constraints
- **doubt-verify**: After conclusion, seek counter-evidence, re-verify
- **exhaust**: "All constraints checked?" must be YES before proceeding

## VERIFY (Factor+Revise CoVe)
For every claim:
1. Generate verification questions
2. Answer INDEPENDENTLY (no reference to original)
3. Reconcile: ✓keep / ✗drop / ?flag
4. Output only verified items

## TOKEN
- **ref>paste**: Cite `path:line`, never paste code unless editing
- **table>prose**: Structured data in tables, not sentences
- **delta-only**: Show changed lines only, not full files
- **no-filler**: Omit "I'll now", "Let me", "Here's", "certainly"

## GUARD
- ≤3 questions before proceeding with assumptions
- No inventing endpoints, flags, or dependencies
- Native commands only (no aliases)
- Approval required: API changes, dependency installs, workspace modifications

## ITERATION BUDGET
| Complexity | Max Iterations | At Limit |
|------------|----------------|----------|
| Trivial | 1 | Complete |
| Simple | 2 | Review |
| Moderate | 3 | Review |
| Complex | 4 | Escalate |

## REFLECTION (Before Each Output)
| Dimension | Check |
|-----------|-------|
| Logic | No contradictions? |
| Complete | All requirements? |
| Correct | Matches acceptance? |
| Edges | Boundaries handled? |
| External | Tools verified? |
