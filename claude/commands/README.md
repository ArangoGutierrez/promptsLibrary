# Claude Commands

Custom commands for Claude Code that provide specialized functionality.

## Overview

This directory contains 4 commands extracted from plugin directories. Commands are invoked using the `/command-name` syntax in Claude Code.

## Available Commands

### Code Review Commands

#### /code-review (`code-review.md`)
**Origin**: `code-review` plugin

Comprehensive code review workflow for pull requests or changes.
- Multi-dimensional analysis (correctness, security, performance, maintainability)
- Risk assessment and verdict
- Actionable recommendations
- Integration with GitHub PRs

**Usage**:
```bash
/code-review              # Review current changes
/code-review #123         # Review PR #123
/code-review src/         # Review specific directory
```

### Ralph Loop Commands

Ralph is an AI coding assistant loop that maintains state and context across multiple iterations.

#### /ralph-loop (`ralph-loop.md`)
**Origin**: `ralph-loop` plugin

Start a Ralph coding loop for iterative development.
- Maintains context across iterations
- Task tracking in RALPH.md
- Automatic checkpoint saving
- Error recovery

**Usage**:
```bash
/ralph-loop "implement user authentication"
/ralph-loop --resume      # Resume previous session
```

#### /help (`help.md`)
**Origin**: `ralph-loop` plugin

Display Ralph loop help and current status.
- Show available commands
- Display current loop state
- List active tasks
- Context information

**Usage**:
```bash
/help                    # Show help
/help status             # Show detailed status
```

#### /cancel-ralph (`cancel-ralph.md`)
**Origin**: `ralph-loop` plugin

Cancel the current Ralph loop and cleanup state.
- Stop running loop
- Save checkpoint
- Clear context
- Cleanup temporary files

**Usage**:
```bash
/cancel-ralph            # Cancel current loop
/cancel-ralph --force    # Force cancel without saving
```

## Command Categories

```
commands/
├── Code Review
│   └── code-review.md       # Comprehensive PR/code review
│
└── Ralph Loop (Task Orchestration)
    ├── ralph-loop.md        # Start coding loop
    ├── help.md              # Display help/status
    └── cancel-ralph.md      # Cancel loop
```

## Command Origins

These commands were extracted from plugin directories to create a flatter, more discoverable structure:

| Command | Original Location | Category |
|---------|------------------|----------|
| `code-review.md` | `code-review/commands/` | Code Review |
| `ralph-loop.md` | `ralph-loop/commands/` | Task Orchestration |
| `help.md` | `ralph-loop/commands/` | Task Orchestration |
| `cancel-ralph.md` | `ralph-loop/commands/` | Task Orchestration |

## Usage Patterns

### Code Review Workflow

```bash
# Before committing
/code-review src/auth/

# Before merging PR
/code-review #456

# Quick review of changes
git diff | /code-review
```

### Ralph Loop Workflow

```bash
# Start new loop
/ralph-loop "add user authentication"

# Check status during loop
/help status

# Cancel if needed
/cancel-ralph

# Resume previous loop
/ralph-loop --resume
```

## Integration with Other Components

### With Agents
Commands can invoke agents for specialized analysis:
- `/code-review` may use: auditor, perf-critic, api-reviewer
- `/ralph-loop` may use: task-analyzer, verifier

### With Skills
Commands are distinct from skills:
- **Commands** (`/command`): Explicit user invocation only
- **Skills** (`/skill`): Can be automatically invoked by Claude

## Deployment

Commands are deployed alongside other Claude Code components:

```bash
# Local deployment
./scripts/deploy-claude.sh

# With symlinks (auto-update)
./scripts/deploy-claude.sh --symlink

# Remote installation
curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
```

After deployment, commands are available at: `~/.claude/commands/`

## Migration Notes

These commands were extracted from plugin directories to flatten the structure:
- Old: `{plugin-name}/commands/{command}.md`
- New: `commands/{command}.md`

All functionality remains the same. Plugin metadata has been archived in `plugins-archive/`.

## Contributing

To add a new command:

1. Create `{command-name}.md` in `claude/commands/`
2. Follow the Agent Skills standard for frontmatter
3. Document usage and examples
4. Add to this README
5. Update `deploy-claude.sh` to include in deployment

## Related Documentation

- [Claude Code Commands Documentation](https://code.claude.com/docs/en/commands)
- [Claude Code Skills](../skills/README.md)
- [Claude Code Agents](../agents/README.md)

## License

Same as parent project.
