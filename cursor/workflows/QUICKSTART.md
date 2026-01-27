# Quick Start: Cursor to CLI Workflow

Get started with the hybrid Cursor + Terminal workflow in 5 minutes.

## 30-Second Overview

1. **Plan in Cursor** with Claude 4.5 Opus → `/export-plan`
2. **Implement in Terminal** with Claude 4.5 Sonnet → `claude code {plan-file}`
3. **Review in Cursor** with Opus → `/review-cli-work`

## Your First Hybrid Workflow

### Example: Add a New Feature

#### Step 1: Architecture in Cursor (2-3 minutes)

Open Cursor and start a chat:

```
/architect "Add user authentication with JWT"
```

Claude Opus will:
- Explore 3-5 approaches (JWT, sessions, OAuth, etc.)
- Challenge the top recommendation
- Prototype top 2 approaches
- Synthesize a final recommendation

When you see the recommendation, say:

```
/export-plan
```

Output: `.plans/plan-arch-20260127-143022.md` ✅

#### Step 2: Implementation in Terminal (10-15 minutes)

Open your terminal:

```bash
cd /path/to/your/project

# Start Claude CLI session with the plan
claude code .plans/plan-arch-20260127-143022.md
```

Claude Sonnet will:
- Read the full architectural plan
- Implement according to the specification
- Write tests
- Follow the constraints
- Commit incrementally

Just chat naturally:
```
> Start with the JWT token generation
> Add the middleware next
> Write tests for the auth flow
```

When done, type `exit` or press Ctrl+D.

#### Step 3: Review in Cursor (2-3 minutes)

Back in Cursor:

```
/review-cli-work
```

Claude Opus will:
- Load the original plan
- Compare against what was implemented
- Check acceptance criteria
- Validate tests and lints
- Provide feedback

If issues found:
```
/test              # Fix and run tests
/self-review       # Final check
```

When satisfied:
```
/git-polish        # Clean up commits
/push             # Create PR
```

Done! 🎉

## Common Scenarios

### Scenario 1: GitHub Issue

```bash
# In Cursor
/task #456 --plan --export

[Discuss specification and approaches]

You: "GO"

# Generated: .plans/plan-task-20260127-150534.md

# In Terminal
claude code .plans/plan-task-20260127-150534.md

# Back in Cursor
/review-cli-work
/push
```

### Scenario 2: Quick Bug Fix

```bash
# Just stay in Cursor, no need for hybrid
/debug "Users can't login"
[Fix it]
/push
```

### Scenario 3: Large Refactor

```bash
# In Cursor
/refactor "Extract payment processing into service" --export

# In Terminal (for the heavy lifting)
claude code .plans/plan-refactor-20260127-152101.md

# Back in Cursor (for safety checks)
/review-cli-work
/test
/audit
/push
```

## Tips for Success

### ✅ Do This

- **Use Opus for thinking**: Architecture, trade-offs, exploration
- **Use Sonnet for doing**: Implementation, tests, iteration
- **Commit frequently** in terminal: Small, focused commits
- **Review thoroughly** in Cursor: Opus catches what Sonnet might miss

### ❌ Avoid This

- Don't use hybrid for simple tasks (overhead not worth it)
- Don't skip the review phase (defeats the purpose)
- Don't make plan files vague (be specific!)
- Don't forget to commit in terminal before reviewing

## Keyboard Shortcuts

### In Cursor
- `Cmd+Shift+K` (Mac) / `Ctrl+Shift+K` (Win): Open chat
- Type `/` to see command list
- Type `/export-plan` and hit Enter

### In Terminal
```bash
# Quick aliases (add to your .zshrc or .bashrc)
alias cplan='claude code .plans/plan-*.md'
alias lsplans='ls -lht .plans/'
```

## Cost Comparison

**Traditional (all Opus)**:
```
Planning: $1.50
Implementation: $7.50
Total: $9.00
```

**Hybrid (Opus + Sonnet)**:
```
Planning: $1.50
Implementation: $1.50
Review: $0.75
Total: $3.75
```

**Save ~60%** on implementation-heavy work! 💰

## Troubleshooting

### "Plan file not found"
```bash
# List plan files
ls -lht .plans/

# Use specific file
/review-cli-work .plans/plan-arch-20260127-143022.md
```

### "Implementation doesn't match plan"
```
/review-cli-work
# Will show exactly what diverged
# Either: fix in Cursor, or continue in terminal
```

### "Terminal session got interrupted"
```bash
# Just restart with same plan file
claude code .plans/plan-arch-20260127-143022.md
# Sonnet sees git state and continues from where you left off
```

### "Need to change the plan mid-implementation"
Option 1: Update in Cursor, re-export, use new plan file
Option 2: Just tell Sonnet in terminal: "Change of plans: ..."

## Next Steps

1. **Read the full workflow**: [`cursor-to-cli.md`](cursor-to-cli.md)
2. **Explore commands**: [`../commands/README.md`](../commands/README.md)
3. **Try it yourself**: Pick a task and use the hybrid workflow
4. **Customize**: Create plan templates in `.plans/templates/`

## Questions?

- **When to use hybrid vs Cursor-only?** Use hybrid for architectural + implementation work. Stay in Cursor for quick fixes.
- **Can I mix models?** Yes! Use any model in Cursor, any in CLI.
- **What about other editors?** This works with any editor + Claude CLI.
- **Do I need to commit plan files?** No, they're gitignored by default.

---

**Ready?** Try it now:

```
/architect "Your idea here" --export
```

Then open your terminal:

```bash
claude code .plans/plan-*.md
```

Happy coding! 🚀
