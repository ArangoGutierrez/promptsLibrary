# Cursor to Claude Code Migration Guide

This document explains how your Cursor rules have been migrated to Claude Code format.

## What Changed

### File Structure Mapping

| Cursor Location | Claude Code Location | Purpose |
|-----------------|---------------------|----------|
| `cursor/rules/project.md` | `claude/CLAUDE.md` | Core engineering standards merged into main context file |
| `cursor/rules/user-rules.md` | `claude/output-styles/engineering-style.md` | Personal communication preferences as an output style |
| `cursor/rules/security.md` | `claude/rules/security.md` | Security rules (copied as-is) |
| `cursor/rules/go-style.md` | `claude/rules/go-style.md` | Go-specific guidelines (copied as-is) |
| `cursor/rules/quality-gate.md` | `claude/rules/quality-gate.md` | Quality thresholds (copied as-is) |

## How to Use

### 1. CLAUDE.md (Always Loaded)

The `CLAUDE.md` file is automatically loaded in every Claude Code session. It contains:

- Core engineering standards (DEPTH, VERIFY, ATOMIC RIGOR)
- Security rules summary
- Token optimization guidelines
- Conflict resolution priorities

**No action needed** - it's automatically active.

### 2. Output Style (Must Be Activated)

The engineering communication style needs to be explicitly selected:

```bash
# Activate the output style
/output-style
# Then select "Engineering Style" from the menu
```

Or configure it in `.claude/settings.json`:

```json
{
  "outputStyle": "engineering-style"
}
```

### 3. Modular Rules (Path-Specific)

Rules in `claude/rules/` are loaded based on context:

- `security.md` - Security-specific guidelines
- `go-style.md` - Go language conventions
- `quality-gate.md` - Quality thresholds

These are automatically referenced by Claude Code when working with relevant files.

## Key Differences from Cursor

### Always Active vs. On-Demand

| Feature | Cursor | Claude Code |
|---------|--------|-------------|
| Project rules | Always active via `alwaysApply: true` | Always active via `CLAUDE.md` |
| Personal style | Always active | Must select output style |
| Modular rules | Always active | Context-aware loading |

### CLAUDE.md Best Practices

1. **Keep it focused**: CLAUDE.md should contain codebase context and standards, not detailed implementation guides
2. **Use references**: Instead of copying all security rules, CLAUDE.md references `claude/rules/security.md`
3. **Team sharing**: CLAUDE.md is meant to be committed to git for team consistency
4. **Personal overrides**: Use `.claude/CLAUDE.local.md` for personal project-specific additions

### Output Styles vs. Rules

**Output Styles** change HOW Claude responds:

- Communication tone (direct vs. friendly)
- Formatting preferences (tables vs. prose)
- Depth of explanations (senior engineer vs. beginner)

**CLAUDE.md** changes WHAT Claude knows:

- Project architecture
- Engineering standards
- Security requirements
- Codebase conventions

## Testing Your Migration

### 1. Verify CLAUDE.md is loaded

Start a new Claude Code session and ask:

```
What are the core engineering principles you should follow?
```

Expected response should mention: DEPTH, VERIFY, ATOMIC RIGOR

### 2. Verify output style

Activate the engineering style and ask:

```
What communication style should you use with me?
```

Expected response should mention: direct, no hedging, senior engineer audience

### 3. Verify modular rules

Ask about security:

```
What are the security rules for handling secrets?
```

Expected response should reference the security.md guidelines

## Next Steps

### Option 1: Activate Everything (Recommended)

```bash
# 1. Deploy to ~/.claude (if not already done)
./scripts/deploy-claude.sh

# 2. Select the engineering output style
/output-style
# Select "Engineering Style"

# 3. Verify CLAUDE.md is working
# (automatic - just start a new session)
```

### Option 2: Selective Activation

If you prefer not to use the output style globally:

```bash
# Just deploy the CLAUDE.md and rules
./scripts/deploy-claude.sh

# Use output style only when needed
claude --append-system-prompt "Use direct, technical communication"
```

### Option 3: Per-Project Setup

Keep configuration in this project only:

```bash
# Add to .claude/settings.json
{
  "outputStyle": "engineering-style"
}
```

## Comparison with Cursor

### What Works the Same

✅ Project-wide rules automatically applied
✅ Security guidelines always enforced
✅ Language-specific conventions available
✅ Modular rule organization

### What's Different

⚠️ Personal style requires explicit activation (output style)
⚠️ CLAUDE.md is a single file, not multiple rule files
⚠️ Rules are context-aware rather than always-applied
⚠️ No YAML frontmatter (`alwaysApply: true`)

### What's Better in Claude Code

✨ Stronger separation between project context (CLAUDE.md) and behavior (output styles)
✨ Path-specific rules can be organized by directory
✨ Output styles are shareable and reusable across projects
✨ Settings are more granular (permissions, sandbox, etc.)

## Rollback Plan

If you need to revert:

```bash
# Uninstall Claude Code configuration
./scripts/deploy-claude.sh --uninstall

# Your original Cursor rules remain unchanged in cursor/rules/
```

## Support

- [Claude Code Documentation](https://code.claude.com/docs)
- [Output Styles Guide](https://code.claude.com/docs/output-styles)
- [CLAUDE.md Specification](https://code.claude.com/docs/claude-md)

## Directory Structure Migration

### Old Plugin-Based Structure

The previous structure organized components by plugin:

```
claude/
├── agents/                      # 13 regular agents
├── agents-optimized/            # 11 optimized agents
├── custom-skills/
│   └── skills/
│       ├── architect/SKILL.md
│       ├── audit/SKILL.md
│       └── ... (15 skills)
├── code-review/
│   └── commands/code-review.md
├── ralph-loop/
│   └── commands/*.md (3 files)
├── code-simplifier/
│   └── agents/code-simplifier.md
├── hooks/                       # 11 hooks
├── rules/                       # 3 rules
└── output-styles/               # 1 style
```

### New Flat Structure

The new structure organizes by resource type for easier discovery:

```
claude/
├── agents/          # 24 files (13 regular + 11 optimized)
│   ├── researcher.md
│   ├── researcher-opt.md
│   ├── auditor.md
│   ├── auditor-opt.md
│   └── ... (all agents in one place)
├── skills/          # 19 skills (includes converted commands)
│   ├── architect.md
│   ├── audit.md
│   ├── code-review.md
│   ├── ralph-loop.md
│   └── ... (all skills in one place)
├── hooks/           # 11 hooks (unchanged)
├── rules/           # 3 rules (unchanged)
└── output-styles/   # 1 style (unchanged)
```

### Path Mapping Table

| Old Path | New Path | Change |
|----------|----------|--------|
| `agents/{name}.md` | `agents/{name}.md` | Unchanged |
| `agents-optimized/{name}.md` | `agents/{name}-opt.md` | Suffix added |
| `custom-skills/skills/{name}/SKILL.md` | `skills/{name}.md` | Flattened |
| `code-review/commands/code-review.md` | `skills/code-review.md` | Converted to skill |
| `ralph-loop/commands/ralph-loop.md` | `skills/ralph-loop.md` | Converted to skill |
| `ralph-loop/commands/help.md` | `skills/ralph-help.md` | Converted to skill |
| `ralph-loop/commands/cancel-ralph.md` | `skills/cancel-ralph.md` | Converted to skill |
| `code-simplifier/agents/code-simplifier.md` | `agents/code-simplifier.md` | Moved |
| `hooks/`, `rules/`, `output-styles/` | (unchanged) | Same paths |

### Migration Benefits

**Easier Discovery:**

- All agents in one directory instead of split across `agents/` and `agents-optimized/`
- All skills in one place instead of buried in `custom-skills/skills/{name}/`
- Everything is either an agent or a skill - no separate "commands" concept

**Consistent Naming:**

- Regular agents: `{name}.md`
- Optimized agents: `{name}-opt.md`
- All skills: `{name}.md`
- Clear suffix pattern instead of separate directories

**Simplified Deployment:**

- No plugin metadata (`.claude-plugin/` directories)
- Direct deployment of resource directories
- Cleaner deployment script
- No confusion about commands vs skills

**Better Organization:**

- Organized by resource type (agents, skills)
- Easier to find and navigate
- Less nesting and complexity
- Claude Code's native model: agents for Task tool, skills for / invocation

### Backward Compatibility

**Functionality unchanged:**

- All agents, skills, and commands work identically
- No changes to file contents (only paths)
- Deploy script updated to handle flat structure

### What You Need to Do

**If you haven't deployed yet:**

- Nothing! The new structure is automatically deployed

**If you have existing deployments:**

1. Redeploy with `./scripts/deploy-claude.sh --force`
2. New flat structure deployed to `~/.claude/agents/`, `~/.claude/skills/`, etc.

**Accessing resources:**

- Agents: `~/.claude/agents/{name}.md` or `~/.claude/agents/{name}-opt.md`
- Skills: `~/.claude/skills/{name}.md` (includes former commands)

### Example Usage After Migration

**Using agents (no change):**

```bash
# Regular version
Use the Task tool with the auditor agent to review src/auth/

# Optimized version (explicit)
Use the Task tool with the auditor-opt agent to review src/auth/
```

**Using skills:**

```bash
# Original skills
/architect "add caching"
/audit --fix
/code

# Converted from commands - now skills
/code-review #123
/ralph-loop "implement feature"
/ralph-help status
/cancel-ralph
```

All usage patterns remain the same - former "commands" are now skills with `/` invocation.

## Future Enhancements

Consider adding:

1. Project-specific `.claude/CLAUDE.local.md` for personal overrides
2. Directory-specific rules (e.g., `backend/CLAUDE.md`, `frontend/CLAUDE.md`)
3. Additional output styles for different contexts (debugging, documentation, etc.)
