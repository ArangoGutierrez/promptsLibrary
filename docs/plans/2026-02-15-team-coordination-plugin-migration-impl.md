# Team Coordination Plugin Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate team-coordination from skill to plugin to enable command auto-discovery in Claude Code's autocomplete menu.

**Architecture:** In-place conversion that moves the skill directory to plugins location and adds minimal plugin infrastructure (manifest + README) while preserving all existing functionality.

**Tech Stack:** Claude Code plugin system, JSON manifests, Markdown documentation

---

## Task 1: Backup and Prepare

**Files:**
- Backup: `~/.claude/skills/team-coordination/` → `~/.claude/skills/team-coordination.backup`
- Check: `~/.claude/plugins/` directory exists

**Step 1: Create backup of current skill**

```bash
cp -r ~/.claude/skills/team-coordination ~/.claude/skills/team-coordination.backup
```

**Step 2: Verify backup created**

```bash
test -d ~/.claude/skills/team-coordination.backup && echo "✓ Backup exists"
ls -la ~/.claude/skills/team-coordination.backup/
```

Expected: Backup directory exists with all files (SKILL.md, commands/, lib/, docs/, examples/, TESTING.md)

**Step 3: Check plugins directory exists**

```bash
test -d ~/.claude/plugins && echo "✓ Plugins directory exists" || mkdir -p ~/.claude/plugins
```

Expected: `✓ Plugins directory exists`

---

## Task 2: Create Plugin Directory Structure

**Files:**
- Create: `~/.claude/plugins/team-coordination/`
- Create: `~/.claude/plugins/team-coordination/.claude-plugin/`

**Step 1: Create plugin root directory**

```bash
mkdir -p ~/.claude/plugins/team-coordination
```

**Step 2: Create .claude-plugin directory for manifest**

```bash
mkdir -p ~/.claude/plugins/team-coordination/.claude-plugin
```

**Step 3: Verify directory structure**

```bash
test -d ~/.claude/plugins/team-coordination/.claude-plugin && echo "✓ Plugin structure created"
ls -la ~/.claude/plugins/team-coordination/
```

Expected: Directory exists with `.claude-plugin/` subdirectory

---

## Task 3: Create Plugin Manifest

**Files:**
- Create: `~/.claude/plugins/team-coordination/.claude-plugin/plugin.json`

**Step 1: Write plugin manifest**

Create file with this exact content:

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

**Step 2: Validate JSON syntax**

```bash
python3 -m json.tool ~/.claude/plugins/team-coordination/.claude-plugin/plugin.json > /dev/null && echo "✓ Valid JSON"
```

Expected: `✓ Valid JSON` (no errors)

**Step 3: Verify manifest content**

```bash
cat ~/.claude/plugins/team-coordination/.claude-plugin/plugin.json
```

Expected: Manifest displays correctly with all required fields (name, version, description, author, license)

---

## Task 4: Move Skill Contents to Plugin

**Files:**
- Move: `~/.claude/skills/team-coordination/*` → `~/.claude/plugins/team-coordination/`
- Remove: `~/.claude/skills/team-coordination/` (empty directory)

**Step 1: Move all skill files to plugin directory**

```bash
mv ~/.claude/skills/team-coordination/* ~/.claude/plugins/team-coordination/
```

**Step 2: Verify files moved**

```bash
ls -la ~/.claude/plugins/team-coordination/
```

Expected: See SKILL.md, commands/, lib/, docs/, examples/, TESTING.md, .claude-plugin/

**Step 3: Remove old skill directory**

```bash
rmdir ~/.claude/skills/team-coordination && echo "✓ Old skill directory removed"
```

Expected: `✓ Old skill directory removed` (directory was empty after move)

**Step 4: Verify skill backup still exists (safety check)**

```bash
test -d ~/.claude/skills/team-coordination.backup && echo "✓ Backup still safe"
```

Expected: `✓ Backup still safe`

---

## Task 5: Create Plugin README

**Files:**
- Create: `~/.claude/plugins/team-coordination/README.md`

**Step 1: Write README.md**

Create file with this content:

```markdown
# Team Coordination Plugin

Structured team workflow for parallel implementation with architectural oversight and quality gates.

## Overview

The team-coordination plugin provides a comprehensive workflow for coordinating multiple agents working on independent implementation tasks. It enforces architectural consistency, quality review gates, and clear role separation between Systems Architect, QA, and Worker agents.

## Installation

This plugin is installed locally in `~/.claude/plugins/team-coordination/`.

After installation, restart Claude Code to register the plugin and discover commands.

## Commands

### /team-plan

Plan team structure, branch strategy, and task assignments for parallel work.

**Usage:**
```
/team-plan
/team-plan [optional context or task description]
```

**What it does:**
- Validates branch source (prevents outdated branch errors)
- Asks mandatory branching strategy question
- Creates plan document in `.agents/plans/`
- Updates AGENTS.md with task assignments
- Plans worktrees for workers

### /team-execute

Spawn team agents (Architect, QA, Workers) and execute implementation.

**Usage:**
```
/team-execute
/team-execute [optional execution context]
```

**What it does:**
- Verifies on agents-workbench branch
- Confirms plan exists
- Re-validates branch source
- Creates worktrees for workers
- Spawns team in order: Architect → QA → Workers
- Coordinates implementation

### /team-shutdown

Clean shutdown of team agents, worktrees, and context.

**Usage:**
```
/team-shutdown
```

**What it does:**
- Verifies completion status
- Shuts down agents with TeamDelete
- Removes all worktrees
- Updates AGENTS.md
- Runs /compact for context hygiene

## Documentation

For detailed documentation on team structure, workflows, and protocols, see:

- **SKILL.md** - Complete skill documentation with team structure, workflows, examples
- **TESTING.md** - Testing procedures and validation
- **docs/** - Additional decision documents
- **examples/** - Usage examples
- **lib/** - Supporting libraries (architect decisions, QA validation, etc.)

## Architecture

The plugin uses a structured team approach:

1. **Lead (you)** - Stays on agents-workbench, coordinates process
2. **Systems Architect** - Maintains architectural consistency (mandatory)
3. **QA Agent** - Tests changes, preserves stability (mandatory)
4. **Workers (1-3)** - Implement features in dedicated worktrees

For teams with >3 tasks, use waves (sequential batches of 3 tasks).

## Requirements

- agents-workbench workflow (see CLAUDE.md)
- Git worktrees
- Task tracking in AGENTS.md

## License

MIT

## Author

Eduardo A <eduardoa@example.com>
```

**Step 2: Verify README created**

```bash
test -f ~/.claude/plugins/team-coordination/README.md && echo "✓ README.md exists"
wc -l ~/.claude/plugins/team-coordination/README.md
```

Expected: `✓ README.md exists` and line count shown

---

## Task 6: Verify Complete Plugin Structure

**Files:**
- Verify: All required files exist in `~/.claude/plugins/team-coordination/`

**Step 1: Check directory structure**

```bash
ls -la ~/.claude/plugins/team-coordination/
```

Expected output should include:
- `.claude-plugin/` (directory)
- `SKILL.md` (file)
- `README.md` (file)
- `TESTING.md` (file)
- `commands/` (directory)
- `lib/` (directory)
- `docs/` (directory)
- `examples/` (directory)

**Step 2: Verify command files exist**

```bash
ls -la ~/.claude/plugins/team-coordination/commands/
```

Expected: `team-plan.md`, `team-execute.md`, `team-shutdown.md`, `.gitkeep`

**Step 3: Verify library files exist**

```bash
ls -la ~/.claude/plugins/team-coordination/lib/
```

Expected: `architect-decisions.md`, `architect-patterns.md`, `architect-security.md`, `architect-validation.md`, `branch-validator.md`, `qa-validator.md`

**Step 4: Run comprehensive structure check**

```bash
cd ~/.claude/plugins/team-coordination && \
test -f .claude-plugin/plugin.json && \
test -f SKILL.md && \
test -f README.md && \
test -f TESTING.md && \
test -d commands && \
test -d lib && \
test -d docs && \
test -d examples && \
echo "✓ Complete structure verified"
```

Expected: `✓ Complete structure verified`

---

## Task 7: Validate Plugin Configuration

**Files:**
- Validate: `~/.claude/plugins/team-coordination/.claude-plugin/plugin.json`
- Validate: Command frontmatter in `commands/*.md`

**Step 1: Validate manifest JSON**

```bash
python3 -m json.tool ~/.claude/plugins/team-coordination/.claude-plugin/plugin.json && echo "✓ Valid JSON"
```

Expected: JSON formatted output + `✓ Valid JSON`

**Step 2: Check manifest required fields**

```bash
cd ~/.claude/plugins/team-coordination && \
python3 -c "
import json
with open('.claude-plugin/plugin.json') as f:
    data = json.load(f)
    assert 'name' in data and data['name'] == 'team-coordination', 'Invalid name'
    assert 'version' in data, 'Missing version'
    assert 'description' in data, 'Missing description'
    assert 'author' in data, 'Missing author'
    assert 'license' in data, 'Missing license'
    print('✓ All required fields present')
"
```

Expected: `✓ All required fields present`

**Step 3: Verify command file frontmatter**

```bash
head -n 5 ~/.claude/plugins/team-coordination/commands/team-plan.md
```

Expected: Should show YAML frontmatter with `name:` and `description:` fields

---

## Task 8: Commit Migration Changes

**Files:**
- Commit: All new plugin files
- Commit: Document migration completion

**Step 1: Stage plugin files**

```bash
cd ~/.claude && git add plugins/team-coordination/
```

**Step 2: Verify staged changes**

```bash
git status
```

Expected: Shows `plugins/team-coordination/` with all files staged (new files)

**Step 3: Commit migration**

```bash
cd ~/.claude && git commit -m "feat: migrate team-coordination from skill to plugin

Convert team-coordination from skill to plugin to enable command
auto-discovery and autocomplete visibility.

Changes:
- Move from ~/.claude/skills/ to ~/.claude/plugins/
- Add .claude-plugin/plugin.json manifest
- Add README.md with plugin overview and command documentation
- Preserve all existing functionality (SKILL.md, commands/, lib/, etc.)

Commands now auto-discovered:
- /team-plan
- /team-execute
- /team-shutdown

Related: docs/plans/2026-02-15-team-coordination-plugin-migration.md"
```

**Step 4: Verify commit**

```bash
git log -1 --oneline
```

Expected: Shows commit with "feat: migrate team-coordination from skill to plugin"

---

## Task 9: Manual Testing - Claude Code Restart

**Files:**
- None (manual testing)

**Step 1: Save current work and close Claude Code**

Manual action:
1. Save any open files
2. Exit Claude Code completely (Cmd+Q on Mac, close all windows)

**Step 2: Restart Claude Code**

Manual action:
1. Launch Claude Code
2. Wait for initialization to complete
3. Open a chat session

**Step 3: Test command autocomplete**

Manual action:
1. In chat, type `/`
2. Look for commands in autocomplete menu
3. Verify presence of: `/team-plan`, `/team-execute`, `/team-shutdown`

Expected: All three commands visible with descriptions

---

## Task 10: Functional Testing - Command Execution

**Files:**
- Test: `/team-plan` command
- Test: Command invokes skill logic correctly

**Step 1: Test /team-plan command**

Manual action in Claude Code:
1. Type `/team-plan test migration verification`
2. Execute command
3. Observe behavior

Expected:
- Command executes without errors
- Planning phase logic runs
- Prompts for branch validation
- References lib/branch-validator.md correctly

**Step 2: Verify library references work**

Check in command output:
- Does it access `@skills/team-coordination/lib/` files?
- OR does it need `${CLAUDE_PLUGIN_ROOT}/lib/` updates?

Expected: Library files referenced and loaded correctly (may need path updates)

**Step 3: Document any path reference issues**

If library references fail:
- Note the error messages
- Identify files needing path updates
- Document for future fix (separate task if needed)

---

## Task 11: Cleanup and Documentation

**Files:**
- Update: This implementation plan with results
- Optional: Remove backup after verification

**Step 1: Document test results**

Add to end of this file:
```markdown
## Test Results

- Plugin discovery: [PASS/FAIL]
- Command autocomplete: [PASS/FAIL]
- /team-plan execution: [PASS/FAIL]
- /team-execute execution: [PASS/FAIL]
- /team-shutdown execution: [PASS/FAIL]
- Library references: [PASS/FAIL/NEEDS UPDATE]

## Known Issues

[List any issues discovered during testing]

## Next Steps

[List any follow-up work needed]
```

**Step 2: Optional - Remove backup after successful verification**

Only after confirming everything works:

```bash
# ONLY RUN AFTER CONFIRMING SUCCESS
# rm -rf ~/.claude/skills/team-coordination.backup
echo "Keep backup for now - run manual removal after extended testing"
```

Expected: Keep backup for now, remove later after extended use

**Step 3: Commit test documentation**

```bash
cd ~/.claude && git add docs/plans/2026-02-15-team-coordination-plugin-migration-impl.md && \
git commit -m "docs: add team-coordination plugin migration test results"
```

---

## Success Criteria

After completing all tasks:

- ✅ Plugin exists at `~/.claude/plugins/team-coordination/`
- ✅ Manifest valid JSON with all required fields
- ✅ Commands visible in Claude Code autocomplete
- ✅ `/team-plan`, `/team-execute`, `/team-shutdown` execute without errors
- ✅ All existing functionality preserved
- ✅ Library references work correctly
- ✅ Documentation complete (README.md created)
- ✅ Migration committed to git

## Rollback Procedure

If migration fails:

```bash
# 1. Move failed plugin aside
mv ~/.claude/plugins/team-coordination ~/.claude/plugins/team-coordination.failed

# 2. Restore from backup
mv ~/.claude/skills/team-coordination.backup ~/.claude/skills/team-coordination

# 3. Restart Claude Code
echo "Restart Claude Code to re-register skill"

# 4. Investigate issues
cd ~/.claude/plugins/team-coordination.failed
# Review manifest, check logs, identify problems
```

## References

- Design document: `docs/plans/2026-02-15-team-coordination-plugin-migration.md`
- Plugin manifest reference: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/plugin-structure/references/manifest-reference.md`
- Command development guide: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/command-development/SKILL.md`
