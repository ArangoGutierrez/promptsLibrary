# Export Plan

Export current architectural discussion or task plan to a Claude CLI-ready execution file.

## Usage
- `/export-plan` — Export current discussion
- `/export-plan --output path/to/file.md` — Custom output path
- `/export-plan --type [task|arch|refactor]` — Specify plan type

## What It Does

Analyzes the current conversation and extracts:
1. **Context**: Problem statement, constraints, requirements
2. **Decisions**: Architectural choices, approach selected, trade-offs
3. **Specification**: Inputs, outputs, acceptance criteria
4. **Implementation Plan**: Step-by-step tasks with priorities
5. **Constraints**: Security, performance, style requirements

Generates a file in `.plans/` directory that can be executed with:
```bash
claude code .plans/plan-YYYYMMDD-HHMMSS.md
```

## Output Format

The generated file is a self-contained prompt that includes:

```markdown
# Execution Plan: {Title}

> **Generated**: {timestamp}
> **Source**: Cursor discussion with Claude 4.5 Opus
> **Execute with**: `claude code {this-file}`

## Context

### Problem Statement
{what we're solving}

### Current State
{git branch, relevant files, existing code}

### Decisions Made
| Decision | Rationale | Trade-offs |
|----------|-----------|------------|
| {choice} | {why}     | {accepted cons} |

## Specification

| Element | Definition |
|---------|------------|
| Inputs | {data/state} |
| Outputs | {changes} |
| Constraints | {MUST/SHOULD/MUST NOT} |
| Acceptance | {verification} |
| Security | {requirements} |

## Implementation Plan

| # | Task | Priority | Estimated Effort |
|---|------|----------|------------------|
| 1 | {task} | P0 | S/M/L |
| 2 | {task} | P1 | S/M/L |

## Constraints

### MUST (Hard Requirements)
- {requirement}

### SHOULD (Best Effort)
- {guideline}

### MUST NOT (Forbidden)
- {constraint}

## Verification Checklist

Before marking complete:
- [ ] All P0 tasks completed
- [ ] Tests pass
- [ ] Acceptance criteria met
- [ ] Security constraints satisfied
- [ ] Code compiles/type-checks

## Artifacts

Expected outputs:
- Files: {list}
- Tests: {list}
- Docs: {list}

## Context Files

Relevant files to read:
```
{file paths}
```

## Additional Notes

{any clarifications, edge cases, known issues}
```

## Integration with Existing Commands

### With `/architect`
After Phase 4 (Synthesize), optionally:
```
/export-plan --type arch
```
Exports the architectural decision with implementation steps.

### With `/task --plan`
After Phase 3 (PLAN), when user says "GO":
```
/export-plan --type task
```
Exports the spec + selected approach for CLI execution.

### With `/refactor`
After planning the refactor strategy:
```
/export-plan --type refactor
```
Exports the refactor plan with safety constraints.

## File Naming

Default pattern: `.plans/plan-{type}-{YYYYMMDD-HHMMSS}.md`

Examples:
- `.plans/plan-arch-20260127-143022.md`
- `.plans/plan-task-20260127-150534.md`
- `.plans/plan-refactor-20260127-152101.md`

## Workflow Integration

**Step 1: Discuss in Cursor (Opus)**
```
User: /architect "Add caching layer to API"
Agent: [Full architectural exploration]
User: "I like approach 2 with Redis"
```

**Step 2: Export Plan**
```
User: /export-plan
Agent: [Generates .plans/plan-arch-20260127-143022.md]
```

**Step 3: Execute in Terminal (Sonnet)**
```bash
cd /path/to/project
claude code .plans/plan-arch-20260127-143022.md
```

**Step 4: Review in Cursor**
```
User: /self-review
Agent: [Reviews what was implemented]
```

## Notes

- The `.plans/` directory is automatically created
- Files are gitignored by default (add to .gitignore if needed)
- Each export includes git context (branch, recent commits)
- Links back to original Cursor conversation if available
- Preserves all architectural decisions and trade-offs
- Self-contained: no external references needed for execution
