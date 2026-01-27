# Architect

Full architectural exploration pipeline with parallel prototyping.

## Usage
- `{problem}` — Explore approaches for a problem
- `--quick` — Skip prototyping, just compare approaches
- `--prototype N` — Prototype top N approaches (default: 2)
- `--export` — Generate CLI execution file after synthesis

## What Happens

**One command triggers the full pipeline:**

```
┌──────────────────┐
│    /architect    │
│   {problem}      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  arch-explorer   │ → 3-5 approaches with comparison
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  devil-advocate  │ → Challenge top recommendation
└────────┬─────────┘
         │
    ┌────┴────┐ parallel
    ▼         ▼
┌────────┐ ┌────────┐
│proto-A │ │proto-B │ → Working prototypes (background)
└────┬───┘ └───┬────┘
     │         │
     └────┬────┘
          ▼
   ┌─────────────┐
   │ synthesizer │ → Final recommendation
   └─────────────┘
```

## Workflow

### Phase 1: Exploration
Launch `arch-explorer` with the problem statement.

**Input**: Problem description, constraints, scale requirements
**Output**: 3-5 genuinely different approaches with comparison matrix

### Phase 2: Challenge
Launch `devil-advocate` on the top recommended approach.

**Input**: The recommended approach from Phase 1
**Output**: Blockers, concerns, questions, risks

### Phase 3: Prototype (Parallel)
Launch 2+ `prototyper` agents in **background** simultaneously.

**Input**: Top 2 approaches (adjusted for devil's advocate feedback)
**Output**: Working code in `.prototypes/{approach}/`

### Phase 4: Synthesize
Launch `synthesizer` to combine all findings.

**Input**: All outputs from phases 1-3
**Output**: Final recommendation with evidence

## Output Format

```markdown
# Architecture Decision: {Problem}

## Executive Summary
{2-3 sentences: what we decided and why}

## Approaches Considered
| # | Approach | Effort | Risk | Prototype |
|---|----------|--------|------|-----------|
| 1 | {name} ⭐ | M | L | ✓ validated |
| 2 | {name} | H | M | ✓ validated |
| 3 | {name} | L | H | — |

## Recommendation: {Approach Name}

### Why This Approach
1. {evidence from explorer}
2. {evidence from prototype}
3. {addressed concern from devil's advocate}

### Trade-offs Accepted
- {con we're accepting}
- {con we're accepting}

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| {from devil-advocate} | {how addressed} |

### Prototype Validation
- Location: `.prototypes/{name}/`
- Key finding: {what we learned}

## Alternative: {Second Choice}
If {condition}, pivot to this approach because {reason}.

## Next Steps
1. {immediate action}
2. {follow-up}
3. {validation}

## Appendix
- Full exploration: {link or expand}
- Devil's advocate: {link or expand}
- Prototype A: `.prototypes/a/`
- Prototype B: `.prototypes/b/`
```

## Quick Mode (--quick)

Skip prototyping for faster decisions:
```
arch-explorer → devil-advocate → synthesizer
```

Use for: Early-stage discussions, reversible decisions, time pressure

## Export Mode (--export)

After Phase 4 completes, automatically generate a CLI execution file:
```bash
.plans/plan-arch-YYYYMMDD-HHMMSS.md
```

This file contains:
- All architectural decisions and trade-offs
- Selected approach with rationale
- Implementation steps extracted from "Next Steps"
- Constraints and acceptance criteria
- Links to prototypes

**Execute with**: `claude code .plans/plan-arch-*.md`

**Use for**: Handing off implementation to Claude CLI after architectural planning in Cursor.

## Constraints
- **Full pipeline**: Don't skip phases without `--quick`
- **Parallel prototypes**: Run simultaneously, not sequentially
- **Evidence-based**: Recommendation must cite prototype findings
- **Document trade-offs**: No approach is perfect—be explicit
