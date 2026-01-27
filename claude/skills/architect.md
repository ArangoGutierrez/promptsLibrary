---
name: architect
description: Comprehensive architecture exploration with parallel prototyping and synthesis. Use when designing new features, evaluating architectural approaches, making major technical decisions, or choosing between implementation strategies. Generates 3-5 distinct approaches, critiques them, optionally creates working prototypes, and synthesizes a final recommendation.
argument-hint: "[problem] [--quick] [--proto N]"
disable-model-invocation: true
allowed-tools: Task, AskUserQuestion
model: sonnet
---

# Architecture Decision Pipeline

Full architecture exploration with parallel prototyping for major technical decisions.

## Usage

```bash
/architect {problem}              # Full pipeline with 2 prototypes
/architect {problem} --quick      # Skip prototypes (fast exploration)
/architect {problem} --proto N    # Create N prototypes (default: 2)
```

## Pipeline Overview

```
arch-explorer → devil-advocate → [prototyper×N] → synthesizer
     ↓               ↓                 ↓              ↓
  3-5 options    challenge top    parallel impl    recommend
```

## Workflow

### Phase 1: Explore Approaches (arch-explorer)

Use the Task tool with a general-purpose subagent loaded with the arch-explorer agent prompt to generate 3-5 genuinely different architectural approaches.

**Prompt for Task tool**:

```
Use the arch-explorer agent from ~/.claude/agents/arch-explorer.md to explore architectural approaches for: $ARGUMENTS

The agent should:
1. Generate 3-5 distinct approaches (not minor variations)
2. Create a comparison matrix (effort, risk, maintainability, scalability)
3. Analyze trade-offs for each approach
4. Provide decision criteria

Output should include the comparison matrix and detailed analysis of each approach.
```

**What arch-explorer produces**:

- 3-5 genuinely different approaches (not trivial variations)
- Comparison matrix with effort/risk/maintainability/scalability
- Trade-off analysis for each approach
- Decision criteria framework

### Phase 2: Challenge Top Recommendation (devil-advocate)

Use the Task tool with a general-purpose subagent loaded with the devil-advocate agent prompt to critically review the top recommendation from arch-explorer.

**Prompt for Task tool**:

```
Use the devil-advocate agent from ~/.claude/agents/devil-advocate.md to critique the top architectural approach from the previous analysis.

The agent should challenge:
1. Assumptions made in the approach
2. Failure modes and edge cases
3. Scale considerations
4. Hidden complexity and costs
5. Alternative perspectives

Focus on the approach: [insert top recommendation from Phase 1]

Output should include severity-ranked concerns (Blocker, Major, Minor, Question).
```

**What devil-advocate produces**:

- Severity-ranked concerns (Blocker, Major, Minor, Question)
- Challenged assumptions
- Identified failure modes
- Scale issues
- Hidden costs

### Phase 3: Prototype (parallel, optional)

**Skip if**: `--quick` flag is present

**Default**: Prototype top 2 approaches
**Custom**: Use `--proto N` to specify number of prototypes

Launch N prototyper agents in parallel using the Task tool with `run_in_background: true`.

**Prompt for each prototyper** (run in parallel):

```
Use the prototyper agent from ~/.claude/agents/prototyper.md to create a working prototype for approach: [approach name]

Requirements:
1. Create prototype in .prototypes/[approach-slug]/
2. Implement core functionality only (no polish)
3. Focus on validating technical feasibility
4. Document trade-offs discovered during implementation
5. Include README with setup and usage

Approach details:
[Insert approach description from Phase 1]

Output should include prototype location, setup instructions, and key findings.
```

**Monitor background tasks** using TaskOutput to check progress.

**What prototyper produces** (per approach):

- Working code in `.prototypes/{approach-slug}/`
- README with setup and run instructions
- Key findings about feasibility
- Discovered trade-offs

### Phase 4: Synthesize Recommendation (synthesizer)

Use the Task tool with a general-purpose subagent loaded with the synthesizer agent prompt to combine all outputs into a final recommendation.

**Prompt for Task tool**:

```
Use the synthesizer agent from ~/.claude/agents/synthesizer.md to create a final architecture recommendation.

Inputs to synthesize:
1. arch-explorer output: [insert or reference file]
2. devil-advocate critique: [insert or reference file]
3. Prototype findings (if available): [insert or reference files]

The agent should:
1. Identify consensus patterns across all inputs
2. Surface unresolved conflicts
3. Weigh evidence from prototypes
4. Generate final recommendation with confidence level
5. Provide clear next steps

Output should be a definitive recommendation with supporting evidence.
```

**What synthesizer produces**:

- Final recommendation with confidence level
- Evidence from all phases
- Consensus patterns identified
- Unresolved conflicts surfaced
- Clear next steps

## Output Format

After all phases complete, present:

```markdown
# Architecture Decision: {Problem}

## Summary
[2-3 sentence summary of recommendation]

## Approaches Evaluated
| # | Approach | Effort | Risk | Validated | Notes |
|---|----------|--------|------|-----------|-------|
| 1 | {name} ⭐ | M | L | ✓ | Recommended |
| 2 | {name} | H | M | ✓ | Good alternative |
| 3 | {name} | L | H | - | Too risky |

## Recommendation: {Approach Name}

**Why**: [Evidence-based reasoning]
**Trade-offs**: [Accepted cons with mitigation]
**Risks**: [Identified risks with mitigations]
**Confidence**: [High/Medium/Low based on prototype evidence]

## Key Concerns (from devil-advocate)
- {Blocker or Major concern}: {mitigation}

## Prototype Findings (if applicable)
- **Approach 1**: {key finding}
- **Approach 2**: {key finding}

## Next Steps
1. {Concrete action with owner}
2. {Concrete action with owner}
3. {Concrete action with owner}
```

## Execution Tips

1. **Use --quick for reversible decisions**: Skip prototypes when decision can be easily changed later
2. **Prototype for high-risk choices**: Always prototype for:
   - Major architectural changes
   - Unfamiliar technologies
   - Performance-critical paths
   - Security-sensitive components
3. **Run prototypers in parallel**: Use `run_in_background: true` to save time
4. **Monitor progress**: Check prototype progress with TaskOutput while other agents run
5. **Ask for clarification**: Use AskUserQuestion if problem statement is ambiguous

## Examples

### Example 1: Quick exploration (no prototypes)

```
/architect "Add real-time notifications" --quick
```

Result: arch-explorer → devil-advocate → synthesizer (fast, ~5 min)

### Example 2: Full pipeline (2 prototypes)

```
/architect "Add real-time notifications"
```

Result: arch-explorer → devil-advocate → 2× prototyper (parallel) → synthesizer (~15-20 min)

### Example 3: Extensive prototyping

```
/architect "Choose database for new service" --proto 3
```

Result: Prototypes 3 different database options in parallel

## When to Use This Skill

**Use /architect when**:

- Adding major new features
- Choosing between technologies
- Making irreversible architectural decisions
- High-risk or high-cost changes
- Unfamiliar problem domains

**Don't use /architect for**:

- Minor feature additions
- Well-understood patterns
- Time-sensitive hot fixes
- Reversible implementation details

## Constraints

- **Sequential phases**: Must complete arch-explorer before devil-advocate
- **Parallel prototypes**: Prototypers run simultaneously (not sequential)
- **Evidence-based**: Final recommendation must reference specific evidence
- **Document trade-offs**: Every recommendation must acknowledge cons
- **Clear next steps**: Must end with concrete, actionable steps
