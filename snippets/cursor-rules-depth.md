# CURSOR RULES: DEPTH-FORCING + TOKEN-OPTIMIZED

## Problem 1: Claude Prioritizes Speed Over Depth

Research shows LLMs "satisfice" (good-enough shortcuts) due to:
- Autoregressive optimization for immediate token probability
- No explicit direction to explore multiple paths
- Implicit pressure to respond quickly

### Solution: Anti-Satisficing Rules

The key insight from 2025 research (SCoT, Plan-and-Solve, MFR):
> **Model the problem BEFORE solving it**

Add these to your Cursor User Rules:

```
# DEPTH (anti-satisficing)
- model-first: build problem model (entities|constraints|state) BEFORE solving
- enumerate-before-conclude: list ≥3 options/paths before selecting
- no-first-solution: generate 2+ approaches, compare, select with rationale
- mandatory-doubt: after answer, list "what could be wrong" then re-check
- unlimited-time-framing: "thorough > fast; exhaust analysis before output"
- critic-loop: review own output for: gaps|contradictions|missed-constraints
```

### Why Each Rule Works

| Rule | Cognitive Effect | Research Backing |
|------|------------------|------------------|
| `model-first` | Forces global constraint awareness | Model-First Reasoning (MFR) 2025 |
| `enumerate≥3` | Prevents premature convergence | Tree-of-Thought, Self-Consistency |
| `no-first-solution` | Avoids satisficing | Plan-and-Solve Prompting |
| `critic-loop` | Catches errors post-generation | Validation/Critic Loops |
| `doubt-verify` | Forces counter-evidence search | Strategic CoT (SCoT) |
| `slow>fast` | Reframes time pressure | "Unlimited time" framing |

### Depth-Forcing Prompt Patterns

Use these patterns in custom prompts to force deep analysis:

**Pattern 1: Problem Model First**
```
BEFORE solving, build explicit model:
1. Entities: list all objects/actors
2. Relations: how entities connect
3. Constraints: rules that must hold
4. State: current vs desired
5. THEN solve using model
```

**Pattern 2: Enumerate Before Select**
```
HALT. Before proceeding:
1. Generate ≥3 distinct approaches
2. For each: pros|cons|risks|effort
3. Compare in table
4. Select with explicit rationale
5. THEN implement selected approach
```

**Pattern 3: Mandatory Doubt**
```
After generating answer:
1. List 3 ways this could be wrong
2. For each: investigate if actually wrong
3. If any confirmed wrong: revise
4. If uncertain: flag explicitly
```

**Pattern 4: Exhaustive Constraint Check**
```
Before finalizing:
□ All inputs validated?
□ All edge cases handled?
□ All constraints satisfied?
□ All assumptions documented?
□ All cited refs verified?
If ANY unchecked: address before proceed
```

---

## Problem 2: Token Optimization for Large Projects

Research (2025): Token compression up to 20× possible with minor perf loss on many tasks.
Key finding: Reasoning tasks (math, logic, code) are MORE sensitive to compression.

### Token-Saving Principles

| Technique | Savings | Example | Risk |
|-----------|---------|---------|------|
| Abbrev syntax | ~30% | `fn` not `function` | Low |
| Path:line refs | ~80% | `auth.go:45-60` vs paste | Low |
| Tables > prose | ~40% | Structured vs sentences | Low |
| Symbols > words | ~25% | `→` vs "leads to" | Low |
| No filler | ~15% | Omit "I'll now" | None |
| Enum > sentences | ~30% | `1.X 2.Y` vs prose | Low |
| Delta-only | ~70% | Changed lines only | Medium |

### Abbreviation Dictionary

Use consistently across prompts and rules:

```
fn=function|impl=implementation|cfg=config|ctx=context
err=error|req=request|res=response|auth=authentication
val=validation|init=initialize|exec=execute|spec=specification
dep=dependency|pkg=package|mod=module|ver=version
src=source|dst=destination|tmp=temporary|ref=reference
```

### Symbol Dictionary

```
→ = leads to, then, implies
← = from, derived from
↔ = bidirectional, mutual
∴ = therefore, so
⚠ = warning, caution
✓ = pass, confirmed, done
✗ = fail, rejected, drop
? = uncertain, investigate
≥ = minimum, at least
≤ = maximum, at most
@ = at, reference to
# = number, issue
| = or, alternative
& = and, also
```

### Token-Optimized Output Contract

Add to prompts that generate reports:

```
# OUTPUT-TOKEN
- ref>paste: cite `path:line` never paste unless editing
- table>prose: data→table; narrative→enum
- abbrev: use standard abbrevs (fn|impl|cfg|ctx|err)
- symbols: →∴⚠✓✗ replace words
- no-filler: omit politeness, hedging, transitions
- delta: show changes only, not full context
```

---

## Combined Rules Block

The full token-optimized, depth-forcing rules (in cursor-rules.md):

```
# DEPTH (anti-satisficing, System-2)
model-first:entities→relations→constraints→state BEFORE solve
enumerate≥3:list ≥3 paths before ANY selection
no-first-solution:2+ approaches→compare→select-with-rationale
critic-loop:after-output check:gaps|contradictions|missed-constraints
doubt-verify:conclusion→counter-evidence→re-verify
exhaust:"all constraints checked?" must=YES before proceed
slow>fast:thorough-analysis > quick-response

# TOKEN (optimize for large codebases)
ref>paste:`path:line` refs, never paste unless editing
table>prose:structured data in tables
abbrev:fn|impl|cfg|ctx|err|req|res|auth|val|init|exec
symbols:→∴⚠✓✗≥≤@#|&
no-filler:omit "I'll now", "Let me", "Here's"
delta-only:changed lines only
```

---

## Measuring Effectiveness

### Depth Metrics
- Problem model present before solution? Y/N
- Options enumerated ≥3 before selection? Y/N
- Counter-evidence considered? Y/N
- All constraints explicitly checked? Y/N

### Token Metrics
- Code pasted vs referenced? Count
- Tables vs prose paragraphs? Ratio
- Filler phrases used? Count
- Symbols vs word equivalents? Ratio

---

## When NOT to Apply

**Depth-forcing overhead not worth it for:**
- Trivial tasks (rename variable, fix typo)
- Time-critical debugging
- Simple factual questions

**Token optimization risks for:**
- Complex reasoning chains (math, logic)
- First-time explanations to humans
- Documentation meant for human readers
