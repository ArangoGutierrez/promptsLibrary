# Cursor Setup Guide

This guide covers how to configure Cursor IDE to work with the prompts library.

## User Rules Configuration

### Basic Setup

1. Open Cursor
2. Go to **Settings** (Cmd/Ctrl + ,)
3. Navigate to **Rules** → **User Rules**
4. Paste the contents from `snippets/cursor-rules.md`

### Customizing the Library Path

Update the `# LIB` section with your installation path:

```text
# LIB /your/path/to/promptsLibrary/prompts/
DeepMode→master-agent.md (depth-first,token-optimized,all-protocols)
MetaEnhance→meta-enhance.md (recursive self-improvement loop)
Audit[scope]→audit-go.md|Audit2Prompt→audit-to-prompt.md
...
```

### Understanding the Rules

The user rules are organized into sections:

#### DEPTH (Anti-Satisficing)

Forces Claude to think deeply rather than give quick answers:

```text
model-first: entities→relations→constraints→state BEFORE solve
enumerate≥3: list ≥3 paths/options before ANY selection
no-first-solution: 2+ approaches→compare→select-with-rationale
```

#### TOKEN (Optimization)

Reduces token usage for large codebases:

```text
ref>paste: use `path:line` refs, never paste code unless editing
table>prose: structured data in tables, not sentences
abbrev: fn|impl|cfg|ctx|err|req|res|auth|val|init|exec
```

#### VERIFY (CoVe Pattern)

Enables Chain of Verification:

```text
1.claims→questions 2.answer-independently(no-ref-original) 3.reconcile:✓keep|✗drop|?flag
```

#### GUARD (Safety Rails)

Prevents destructive operations:

```text
approval-required:API-change|dep-install|workspace-modify
```

## Project-Level Rules

You can also add project-specific rules. Create a `.cursorrules` file in your project root:

```markdown
# Project: MyApp

## Context
- Framework: React + TypeScript
- Testing: Jest + React Testing Library
- State: Redux Toolkit

## Conventions
- Components in PascalCase
- Hooks start with `use`
- Tests co-located with source files

## Prompts
When running audits, focus on:
- React hook dependencies
- TypeScript strict mode compliance
- Performance (memo, useMemo, useCallback usage)
```

## Using Prompts in Cursor

### Method 1: @-mention

Reference a prompt file directly:

```bash
@prompts/audit-go.md Run Audit on the authentication module
```

### Method 2: Trigger Commands

If your rules are set up, use trigger commands:

```bash
Run Audit on @src/auth/
```

### Method 3: Paste Prompt

For one-off use, paste the prompt content directly into the chat.

## Recommended Workflow

### Starting a New Task

1. **Pre-Flight Scan** - Understand the codebase state

   ```bash
   Pre-Flight
   ```

2. **Plan Mode** - Design before implementing

   ```bash
   Plan Mode for: implement user authentication
   ```

3. **Execute** - Implement with verification

   ```bash
   GO step 1
   ```

### Code Review Flow

1. **Run Audit** - Deep analysis

   ```bash
   Run Audit on @src/handlers/
   ```

2. **Create Fix Prompts** - Generate task prompts from findings

   ```bash
   Create prompts from audit
   ```

3. **Fix Issues** - Execute fixes

   ```bash
   Fix audit issues
   ```

### PR Review Flow

1. **Review PR** - Comprehensive review

   ```bash
   Review PR #123
   ```

## Advanced Configuration

### Context Awareness

The hooks system includes context monitoring to recommend when to `/summarize` or start a new session.

**How it works:**

- `context-monitor.sh` hook tracks iterations, files touched, and tasks completed
- Estimates context usage using heuristics (no direct token count access)
- Recommends actions based on context health + task status from AGENTS.md

**Global config** (`~/.cursor/context-config.json`):

```json
{
  "thresholds": {
    "healthy_max": 50,
    "filling_max": 75,
    "critical_max": 90
  },
  "weights": {
    "iteration": 8,
    "file": 2,
    "task": 15,
    "summarize_recovery": 25
  },
  "tasks_before_new_session": 3
}
```

**Commands:**

- `/context-reset` — Reset tracking after manual `/summarize`
- `/context-reset --status` — Check current context health

**Decision guide:**

| Context State | Mid-Task | Task Done |
|---------------|----------|-----------|
| Healthy | Continue | New session (recommended) |
| Filling | `/summarize` | New session |
| Critical | `/summarize` + finish | New session (required) |

### Multiple Prompt Libraries

If you maintain multiple prompt libraries:

```text
# LIB-MAIN /path/to/promptsLibrary/prompts/
# LIB-WORK /path/to/work-prompts/

# Switch context by loading different prompts:
# @LIB-MAIN/audit-go.md for general Go audits
# @LIB-WORK/company-audit.md for company-specific patterns
```

### Token Optimization Settings

For very large codebases, enable aggressive token optimization:

```text
# TOKEN-AGGRESSIVE
no-explanation: skip intermediate reasoning unless asked
compress-output: use abbrevs in all output
batch-refs: group file refs by directory
```

### Debug Mode

When prompts aren't working as expected:

```text
# DEBUG
verbose-reasoning: show full thought process
cite-prompt-line: reference which prompt instruction is being followed
verification-trace: show CoVe question/answer pairs
```

## Validation and Error Prevention

### Configuration Validation

The repository includes validation tooling:

**CI Workflow** (`.github/workflows/validate-cursor.yml`):

- Validates `hooks.json` structure and referenced scripts
- Checks agent/skill/rule frontmatter
- Validates command structure (required sections)
- Detects sync drift between main and optimized

**Local Validation:**

```bash
# Check hooks.json
jq empty cursor/hooks.json

# Validate all hook scripts
for f in cursor/hooks/*.sh; do bash -n "$f"; done

# Check sync status
./scripts/sync-optimized.sh --report
```

### JSON Schemas

Schemas in `cursor/schemas/` provide validation for:

| File | Schema |
|------|--------|
| `hooks.json` | `hooks.schema.json` |
| Hook outputs | `hook-output.schema.json` |
| State files | `state-file.schema.json` |

### Hook Security Model

Hooks follow a **fail-closed** security model:

- If `jq` is missing, security-sensitive hooks **block** rather than allow
- `sign-commits.sh` validates GPG configuration before adding `-S` flag
- `preflight.sh` escapes error messages to prevent JSON injection

### Sync Tooling

Keep main and optimized versions in sync:

```bash
# Check for drift
./scripts/sync-optimized.sh --check

# Full report with token analysis
./scripts/sync-optimized.sh --report

# Create stubs for missing optimized files
./scripts/sync-optimized.sh --create
```

## Troubleshooting

### "Prompt not found"

- Check the path in your rules matches your installation
- Ensure the file exists: `ls /your/path/to/promptsLibrary/prompts/`

### "Claude ignoring my rules"

- Rules have a character limit; keep them concise
- Use the compressed versions (`_compressed/`) for token-heavy workflows
- Load prompts explicitly with `@` when rules aren't working

### "Verification taking too long"

- For simple tasks, skip CoVe: "Skip verification, quick fix for typo"
- Use iteration budgets: "Max 2 iterations"

### "Output too verbose"

- Enable token optimization rules
- Request specific format: "Output as table only"
- Use compressed prompts: `@prompts/_compressed/task-prompt-min.md`
