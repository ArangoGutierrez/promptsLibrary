# Cursor to CLI Workflow

Hybrid workflow: **Plan in Cursor with Claude 4.5 Opus**, **Implement in Terminal with Claude 4.5 Sonnet**.

## Philosophy

**Cursor (Opus)**: Best for architectural thinking, exploration, trade-off discussions
**Terminal (Sonnet)**: Best for focused implementation, faster iteration, cost-effective

## Full Workflow

```
┌────────────────────────────────────────────────────────┐
│ PHASE 1: ARCHITECT IN CURSOR (Opus)                   │
│ - Explore approaches                                    │
│ - Prototype in parallel                                 │
│ - Make architectural decisions                          │
│ - Define constraints                                    │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
               /export-plan
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│ .plans/plan-{type}-{timestamp}.md                      │
│ - Complete specification                                │
│ - Architectural decisions                               │
│ - Implementation roadmap                                │
│ - Acceptance criteria                                   │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
          claude code {plan-file}
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│ PHASE 2: IMPLEMENT IN TERMINAL (Sonnet)               │
│ - Write code                                            │
│ - Write tests                                           │
│ - Iterate quickly                                       │
│ - Commit frequently                                     │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
              Back to Cursor
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│ PHASE 3: REVIEW IN CURSOR (Opus)                      │
│ /review-cli-work                                        │
│ - Validate against plan                                 │
│ - Check quality                                         │
│ - Suggest improvements                                  │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│ PHASE 4: POLISH & SHIP                                 │
│ /git-polish → /push                                     │
└────────────────────────────────────────────────────────┘
```

## Scenarios

### Scenario 1: New Feature with Architecture

**In Cursor**:
```
/architect "Add real-time notifications system"

[Opus explores 3-5 approaches]
[Prototypes top 2 in parallel]
[Devil's advocate challenges]
[Synthesizer recommends: WebSocket + Redis pub/sub]

You: "Export this for terminal implementation"

/export-plan
```

**Generated**: `.plans/plan-arch-20260127-143022.md`

**In Terminal**:
```bash
cd /path/to/project
claude code .plans/plan-arch-20260127-143022.md
```

**Back in Cursor**:
```
/review-cli-work
[Reviews implementation]
[Suggests polish items]

/git-polish
/push
```

### Scenario 2: GitHub Issue with Planning

**In Cursor**:
```
/task #456 --plan --export

[Opus reads issue]
[Creates specification]
[Proposes 3 approaches]
[You discuss and select approach 2]

You: "GO"

[Generates .plans/plan-task-20260127-150534.md]
```

**In Terminal**:
```bash
claude code .plans/plan-task-20260127-150534.md
```

**Back in Cursor**:
```
/review-cli-work .plans/plan-task-20260127-150534.md
/self-review
/push
```

### Scenario 3: Complex Refactor

**In Cursor**:
```
/refactor "Extract payment processing into separate service"

[Opus analyzes dependencies]
[Plans migration strategy]
[Defines safety constraints]

/export-plan --type refactor
```

**In Terminal**:
```bash
claude code .plans/plan-refactor-20260127-152101.md
```

**Back in Cursor**:
```
/review-cli-work
/test                    # Run full test suite
/audit                   # Security check
/push
```

## Best Practices

### When to Use This Workflow

✅ **Use for**:
- Features requiring architectural decisions
- Complex refactors with multiple approaches
- Tasks where planning and implementation are separate concerns
- Work requiring deep exploration but fast implementation
- Cost-sensitive projects (Opus for planning, Sonnet for coding)

❌ **Don't use for**:
- Simple bug fixes (just do in Cursor)
- Urgent hotfixes (stay in one environment)
- Exploratory prototyping (Cursor only)
- Trivial changes (overhead not worth it)

### Plan File Guidelines

**Good plan files are**:
- ✅ Self-contained (no external references)
- ✅ Specific (clear acceptance criteria)
- ✅ Constrained (explicit MUST/MUST NOT)
- ✅ Testable (how to verify)
- ✅ Context-rich (git state, relevant files)

**Bad plan files are**:
- ❌ Vague ("make it better")
- ❌ Open-ended ("fix all bugs")
- ❌ Missing context ("update the API")
- ❌ No acceptance criteria

### Terminal Tips

```bash
# Start session
claude code .plans/plan-arch-20260127-143022.md

# During implementation
# - Sonnet sees the full plan
# - Follows architectural decisions
# - Respects constraints
# - Works toward acceptance criteria

# Commit frequently
git commit -m "feat: add WebSocket server"
git commit -m "feat: integrate Redis pub/sub"
git commit -m "test: add notification tests"

# When done, return to Cursor for review
```

### Review Checklist

Before running `/review-cli-work`:
- [ ] All work committed (not staged)
- [ ] Tests passing locally
- [ ] No obvious issues
- [ ] Ready for review

After `/review-cli-work`:
- [ ] Address P0 issues (must fix)
- [ ] Consider P1 issues (should fix)
- [ ] Run suggested commands
- [ ] Re-review if major changes

## Cost Analysis

**Traditional (all in Cursor Opus)**:
- Planning: 100K tokens × $15/M = $1.50
- Implementation: 500K tokens × $15/M = $7.50
- **Total**: ~$9.00

**Hybrid (Cursor Opus + Terminal Sonnet)**:
- Planning in Cursor: 100K tokens × $15/M = $1.50
- Implementation in Terminal: 500K tokens × $3/M = $1.50
- Review in Cursor: 50K tokens × $15/M = $0.75
- **Total**: ~$3.75

**Savings**: ~60% reduction for implementation-heavy tasks

## Troubleshooting

### Plan file not found
```bash
ls .plans/
# Find the right file, then:
/review-cli-work .plans/plan-arch-20260127-143022.md
```

### Implementation diverged from plan
```
/review-cli-work
# Shows divergence
# Decide: rollback or update plan
```

### Need to resume in Cursor
```
# Read the plan file manually
# Continue implementation in Cursor
# Don't use /review-cli-work (not from terminal)
```

### Terminal session interrupted
```bash
# Just restart with same plan file
claude code .plans/plan-arch-20260127-143022.md
# Sonnet sees git state and continues
```

## Files Structure

```
.plans/
  ├── plan-arch-20260127-143022.md      # Architecture decision
  ├── plan-task-20260127-150534.md      # Task with spec
  └── plan-refactor-20260127-152101.md  # Refactor plan

.gitignore
  .plans/                               # (optional) Gitignore plans
```

## Integration with Existing Commands

### Commands that generate plans
- `/architect --export`
- `/task --plan --export`
- `/refactor --export`
- `/export-plan` (standalone)

### Commands that consume plans
- `claude code {plan-file}` (in terminal)
- `/review-cli-work` (in Cursor)

### Commands for polish
- `/self-review`
- `/git-polish`
- `/test`
- `/audit`
- `/push`

## Advanced: Custom Plan Templates

Create `.plans/templates/` for your own plan formats:

```markdown
.plans/templates/feature.md
.plans/templates/bugfix.md
.plans/templates/refactor.md
```

Reference with:
```
/export-plan --template .plans/templates/feature.md
```
