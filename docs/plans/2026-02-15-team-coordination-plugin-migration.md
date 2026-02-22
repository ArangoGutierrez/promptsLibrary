# Team Coordination Plugin Migration Design

**Date:** 2026-02-15
**Author:** Eduardo A
**Status:** Approved

## Overview

Migrate the team-coordination skill from `~/.claude/skills/` to `~/.claude/plugins/` to enable command auto-discovery and slash command visibility in Claude Code's autocomplete menu.

## Problem Statement

The team-coordination skill has command files (`team-plan.md`, `team-execute.md`, `team-shutdown.md`) in a `commands/` subdirectory, but these commands don't appear in Claude Code's autocomplete menu when typing `/`.

**Root cause:** Skills cannot have `commands/` subdirectories. Command auto-discovery only works for plugins (which have `.claude-plugin/plugin.json` manifests).

## Solution

Convert team-coordination from a skill to a plugin using **Approach A: In-Place Plugin Conversion**.

## Architecture

### Core Concept

Add plugin infrastructure while preserving all existing functionality. This is a structural change, not a functional change.

### What Changes

- **Location:** `~/.claude/skills/team-coordination/` → `~/.claude/plugins/team-coordination/`
- **Registration:** Skill registration → Plugin registration with auto-discovered commands
- **Interface:** Commands become first-class slash commands in autocomplete menu

### What Stays the Same

- All content in SKILL.md, lib/, docs/, examples/ remains unchanged
- Command files remain unchanged
- Logic, workflows, and documentation stay identical
- Library references work the same

### User Experience

**Before:**
- Type `/team-coordination` → invoke skill → skill reads command files manually
- Commands not visible in autocomplete

**After:**
- Type `/` → see `/team-plan`, `/team-execute`, `/team-shutdown` in autocomplete
- Select command → command invokes main skill logic

## Directory Structure

### Target Structure

```
~/.claude/plugins/team-coordination/
├── .claude-plugin/
│   └── plugin.json              # NEW: Plugin manifest (minimal config)
├── SKILL.md                     # KEEP: Main skill documentation
├── commands/                    # KEEP: Auto-discovered as slash commands
│   ├── .gitkeep
│   ├── team-plan.md            # → /team-plan
│   ├── team-execute.md         # → /team-execute
│   └── team-shutdown.md        # → /team-shutdown
├── lib/                         # KEEP: Supporting libraries
│   ├── architect-decisions.md
│   ├── architect-patterns.md
│   ├── architect-security.md
│   ├── architect-validation.md
│   ├── branch-validator.md
│   └── qa-validator.md
├── docs/                        # KEEP: Documentation
│   └── decisions/
├── examples/                    # KEEP: Usage examples
├── README.md                    # NEW: Plugin overview
└── TESTING.md                   # KEEP: Testing documentation
```

### New Files

1. `.claude-plugin/plugin.json` - Plugin manifest (required)
2. `README.md` - Plugin overview and installation instructions

### Command Auto-Discovery

- Claude Code scans `commands/*.md` automatically
- Each `.md` file in `commands/` becomes a slash command
- Command name derived from filename: `team-plan.md` → `/team-plan`
- Frontmatter in command files already correct (name, description fields)

## Manifest Configuration

### File: `.claude-plugin/plugin.json`

```json
{
  "name": "team-coordination",
  "version": "1.0.0",
  "description": "Structured team workflow for parallel implementation with architectural oversight and quality gates",
  "author": {
    "name": "Eduardo A",
    "email": "eduardoa@example.com"
  },
  "license": "MIT"
}
```

### Field Explanations

- **name** (required): `"team-coordination"` - Must match directory name, kebab-case
- **version**: `"1.0.0"` - Starting version, follows semver
- **description**: Copied from SKILL.md frontmatter
- **author**: Plugin author information
- **license**: MIT (or choose preferred license)

### Optional Fields Omitted

For private use, we're omitting:
- `homepage` - Documentation URL
- `repository` - Git repo URL
- `keywords` - Search tags
- `commands` - Default `./commands` auto-discovered

### Component Discovery

- Plugin manifest tells Claude Code this is a plugin
- Commands auto-discovered from `commands/` directory (default location)
- No additional configuration needed

### Validation

- Name format: ✅ `team-coordination` (kebab-case, starts/ends with letter)
- Version format: ✅ `1.0.0` (semantic versioning)
- All required fields present: ✅

## Migration Steps

### 1. Backup Current Skill

```bash
cp -r ~/.claude/skills/team-coordination ~/.claude/skills/team-coordination.backup
```

### 2. Create Plugin Directory Structure

```bash
mkdir -p ~/.claude/plugins/team-coordination/.claude-plugin
```

### 3. Create Plugin Manifest

Create `~/.claude/plugins/team-coordination/.claude-plugin/plugin.json` with the manifest configuration above.

### 4. Move Skill Contents to Plugin

```bash
# Move all existing files/directories
mv ~/.claude/skills/team-coordination/* ~/.claude/plugins/team-coordination/

# Clean up old skill directory
rmdir ~/.claude/skills/team-coordination
```

### 5. Create README.md

Add `~/.claude/plugins/team-coordination/README.md` with:
- Plugin overview
- Installation instructions
- Command usage examples
- Link to SKILL.md for detailed documentation

### 6. Verify Structure

```bash
ls -la ~/.claude/plugins/team-coordination/
# Should see: .claude-plugin/, commands/, lib/, docs/, examples/, SKILL.md, README.md, TESTING.md
```

### 7. Restart Claude Code

- Close all Claude Code sessions
- Restart to trigger plugin discovery
- Claude Code will scan `~/.claude/plugins/` and register the plugin

### 8. Verify Registration

- Type `/` in chat
- Look for `/team-plan`, `/team-execute`, `/team-shutdown` in autocomplete
- Test one command to confirm it works

### Rollback Plan

```bash
# Restore from backup
mv ~/.claude/plugins/team-coordination ~/.claude/plugins/team-coordination.failed
mv ~/.claude/skills/team-coordination.backup ~/.claude/skills/team-coordination
# Restart Claude Code
```

### Expected Outcome

- Plugin registered as "team-coordination"
- Three commands visible in autocomplete: `/team-plan`, `/team-execute`, `/team-shutdown`
- All existing functionality preserved
- Command files work identically to before

## Testing and Validation

### 1. Plugin Discovery

```bash
# Check if plugin directory exists
test -d ~/.claude/plugins/team-coordination && echo "✓ Plugin directory exists"

# Check if manifest exists and is valid JSON
test -f ~/.claude/plugins/team-coordination/.claude-plugin/plugin.json && \
  python3 -m json.tool ~/.claude/plugins/team-coordination/.claude-plugin/plugin.json > /dev/null && \
  echo "✓ Valid plugin.json"
```

### 2. Command Discovery

- After restart, type `/` in Claude Code
- Verify `/team-plan`, `/team-execute`, `/team-shutdown` appear
- Commands should show descriptions from frontmatter

### 3. Functional Testing

Test each command to ensure it works:

**Test /team-plan:**
- Run `/team-plan test planning workflow`
- Should invoke planning phase logic
- Verify it reads from lib/branch-validator.md
- Check AGENTS.md gets updated correctly

**Test /team-execute:**
- Run `/team-execute` after planning
- Should spawn team (Architect, QA, Workers)
- Verify worktree creation works
- Check agent coordination functions

**Test /team-shutdown:**
- Run `/team-shutdown` after execution
- Should clean up team infrastructure
- Verify worktrees removed
- Check AGENTS.md updated

### 4. Library References

Verify library references still work:
- Commands should access library files correctly
- May need to update from `@skills/team-coordination/lib/` to `${CLAUDE_PLUGIN_ROOT}/lib/` if references break

### 5. Documentation Consistency

- README.md accurately describes plugin
- SKILL.md content still relevant
- TESTING.md procedures still valid
- All examples in examples/ directory work

### Success Criteria

- ✅ Plugin appears in Claude Code plugin list
- ✅ All three commands visible in autocomplete
- ✅ Commands execute without errors
- ✅ Team coordination workflow functions identically
- ✅ Library references resolve correctly
- ✅ No functionality lost in migration

### Known Issues to Watch For

- **Commands don't appear:** Check manifest JSON syntax, verify restart happened
- **Library references break:** May need to update from `@skills/` to `${CLAUDE_PLUGIN_ROOT}/`
- **Commands error:** Check frontmatter format, verify file permissions

## Alternative Approaches Considered

### Approach B: Hybrid - Plugin with Embedded Skill

Create plugin with embedded skill inside `skills/` subdirectory. Commands invoke the embedded skill with phase context.

**Rejected because:** More complex structure with unnecessary indirection layer. Approach A achieves the same goal with simpler architecture.

### Approach C: Clean Break - Pure Plugin

Convert SKILL.md content into command logic directly. No skill component.

**Rejected because:** Most migration work required, risk of logic duplication, breaking change to skill interface. Approach A preserves all existing functionality.

## Trade-offs

### Chosen Approach (A) Trade-offs

**Benefits:**
- Minimal migration effort
- Commands work as expected in autocomplete
- Low risk, no logic changes
- Easy to reverse if needed
- Matches private use requirements

**Costs:**
- Directory location changes (old references need updating)
- Mental model shift from skill to plugin
- Small learning curve on plugin concepts

## Distribution

**Scope:** Private use only (personal ~/.claude/plugins/)

**No marketplace publishing:** Minimal manifest metadata, no comprehensive documentation requirements, simple local installation.

## References

- Plugin manifest reference: `/Users/eduardoa/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/plugin-structure/references/manifest-reference.md`
- Command development: `/Users/eduardoa/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/command-development/SKILL.md`
- Research findings: Agent ace516d (2026-02-15)

## Decisions

1. **Plugin location:** `~/.claude/plugins/team-coordination/` (user-level, not project-level)
2. **Manifest metadata:** Minimal for private use (name, version, description, author, license)
3. **Migration approach:** In-place conversion (Approach A)
4. **Distribution:** Private only, no marketplace publishing
5. **Backward compatibility:** Preserve all existing functionality, no breaking changes

## Next Steps

1. ✅ Design approved
2. → Create implementation plan (invoke writing-plans skill)
3. → Execute migration
4. → Test and validate
5. → Document lessons learned
