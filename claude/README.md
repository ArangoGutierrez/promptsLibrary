# Claude Code Configuration

Comprehensive Claude Code configuration with agents, skills, commands, hooks, and rules organized in a flat, discoverable structure.

## Overview

This directory provides a complete Claude Code setup with:

- **24 agents** (13 regular + 11 optimized) for specialized analysis
- **19 skills** for workflow orchestration
- **11 hooks** for lifecycle automation
- **3 rules** for modular guidelines
- **1 output style** for custom communication
- **Project context** (CLAUDE.md) and secure settings

## Directory Structure

```
claude/
├── agents/           # Specialized analysis agents (24 files)
│   ├── researcher.md, researcher-opt.md
│   ├── auditor.md, auditor-opt.md
│   ├── arch-explorer.md, arch-explorer-opt.md
│   └── ... (13 regular + 11 optimized versions)
│
├── skills/           # Workflow orchestration skills (19 files)
│   ├── architect.md      # Architecture exploration
│   ├── audit.md          # Security auditing
│   ├── code-review.md    # PR review with scoring
│   ├── code.md           # Execute next TODO
│   ├── debug.md          # Systematic debugging
│   ├── ralph-loop.md     # Iterative development
│   └── ... (13 more skills)
│
├── hooks/            # Lifecycle hooks (11 files)
│   ├── format.sh         # Auto-format code
│   ├── sign-commits.sh   # Enforce DCO + GPG
│   ├── go-lint.sh        # Run golangci-lint
│   └── ... (8 more hooks)
│
├── rules/            # Modular rules (3 files)
│   ├── security.md       # Security guidelines
│   ├── go-style.md       # Go style guide
│   └── quality-gate.md   # Quality standards
│
├── output-styles/    # Custom communication styles (1 file)
│   └── engineering-style.md
│
├── docs/             # Documentation
├── CLAUDE.md         # Project context and engineering standards
├── settings.json     # Secure bash permissions
├── MIGRATION-GUIDE.md # Migration documentation
└── README.md         # This file
```

## Key Components

### Agents (24 files)

Specialized sub-agents for focused analysis:

**Research & Planning:**

- `researcher.md` / `researcher-opt.md` - Deep issue investigation
- `task-analyzer.md` / `task-analyzer-opt.md` - Dependency analysis

**Security & Performance:**

- `auditor.md` / `auditor-opt.md` - Security/reliability audit
- `perf-critic.md` / `perf-critic-opt.md` - Performance review
- `api-reviewer.md` / `api-reviewer-opt.md` - API consistency

**Architecture & Design:**

- `arch-explorer.md` / `arch-explorer-opt.md` - Architecture exploration
- `devil-advocate.md` / `devil-advocate-opt.md` - Critical review
- `prototyper.md` / `prototyper-opt.md` - Prototype creation
- `synthesizer.md` / `synthesizer-opt.md` - Multi-agent synthesis

**Implementation & Validation:**

- `test-generator.md` - Test generation
- `documenter.md` - Documentation generation
- `code-simplifier.md` - Code simplification
- `verifier.md` / `verifier-opt.md` - Independent verification

**Naming Convention:**

- `{name}.md` - Regular version (full documentation)
- `{name}-opt.md` - Optimized version (~50% smaller, production use)

See [agents/README.md](agents/README.md) for details.

### Skills (19 files)

Workflow orchestration skills for complex tasks:

**Research & Planning (4 skills):**

- `/research` - Issue investigation and analysis
- `/architect` - Architecture exploration with prototypes
- `/task` - Structured 5-phase task execution
- `/issue` - GitHub issue to implementation plan

**Code Quality (6 skills):**

- `/audit` - Security and reliability auditing
- `/quality` - Multi-agent code review
- `/code-review` - PR review with confidence scoring
- `/self-review` - Quick pre-push review
- `/refactor` - Systematic refactoring
- `/test` - Automatic test execution

**Development Workflow (7 skills):**

- `/code` - Execute next TODO from AGENTS.md
- `/parallel` - Run independent tasks concurrently
- `/debug` - Systematic debugging workflow
- `/git-polish` - Clean commit history rewriting
- `/ralph-loop` - Iterative development loop
- `/ralph-help` - Ralph help and status
- `/cancel-ralph` - Cancel Ralph loop

**Documentation & Utilities (2 skills):**

- `/docs` - Documentation generation
- `/context-reset` - Context tracking management

See [skills/README.md](skills/README.md) for details.

### Hooks (11 files)

Lifecycle automation:

**After File Edit:**

- `format.sh` - Auto-format Go, JS/TS, Python, Rust
- `go-lint.sh` - Run golangci-lint on Go files

**Before Shell Execution:**

- `sign-commits.sh` - Enforce DCO + GPG signatures
- `go-test-package.sh` - Run tests before commit
- `go-vuln-check.sh` - Scan vulnerabilities before push

**And 6 more hooks...**

See [hooks/README.md](hooks/README.md) for details.

### Rules (3 files)

Modular guidelines:

- `security.md` - Security best practices
- `go-style.md` - Go style guide
- `quality-gate.md` - Quality gate criteria

### Configuration

**CLAUDE.md** - Project context and engineering standards loaded in every session

**settings.json** - Secure bash permissions:

- ✅ **Allows**: Safe commands (ls, cat, grep, git status, npm run)
- ⚠️ **Asks**: Potentially risky (npm install, git reset)
- 🚫 **Blocks**: Dangerous (rm, git push, docker, sudo)

## Installation

### Local Installation

Deploy to `~/.claude/`:

```bash
# Deploy (symlinks for auto-updates)
./scripts/deploy-claude.sh --symlink

# Or copy files (snapshot)
./scripts/deploy-claude.sh

# Preview changes
./scripts/deploy-claude.sh --dry-run

# Force overwrite existing
./scripts/deploy-claude.sh --force

# Deploy to specific project
./scripts/deploy-claude.sh --project ./myproject
```

### Remote Installation

Install directly from GitHub without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
```

### Uninstall

```bash
./scripts/deploy-claude.sh --uninstall
```

## Usage Examples

### Using Agents

```bash
# Security audit
"Use the Task tool with the auditor agent to review src/auth/ for security issues."

# Performance analysis
"Use the Task tool with the perf-critic agent to analyze the API endpoints."

# Architecture exploration
"Use the Task tool with the arch-explorer agent to explore caching strategies."

# Parallel analysis
"Run auditor and perf-critic agents in parallel on src/handlers/."
```

### Using Skills

```bash
# Architecture decision with prototypes
/architect "add user authentication"

# Security audit with auto-fix
/audit --fix

# Execute next task
/code

# PR review with confidence scoring
/code-review #123

# Systematic debugging
/debug "crash on login with null user"

# Multi-agent review
/quality

# Structured task execution
/task "implement rate limiting" --tdd

# Iterative development loop
/ralph-loop "implement REST API with tests"
/ralph-help status
/cancel-ralph
```

## Migration Notes

This structure replaces the previous plugin-based organization:

### Old Structure (Plugin-Based)

```
claude/
├── agents/
├── agents-optimized/
├── custom-skills/skills/{name}/SKILL.md
├── code-review/commands/
├── ralph-loop/commands/
└── code-simplifier/agents/
```

### New Structure (Flat)

```
claude/
├── agents/ (merged regular + optimized with -opt suffix)
└── skills/ (flattened from custom-skills + converted commands)
```

**Benefits:**

- Easier discovery (all agents in one place, all skills in one place)
- Consistent naming (`{name}.md` vs `{name}-opt.md`)
- Simplified deployment (no plugin metadata)
- Clearer organization by resource type
- Everything is either an agent or a skill (no separate "commands" concept)

See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for complete migration details.

## Customization

### Modifying Permissions

Edit `settings.json` to customize allowed/blocked commands:

```json
{
  "permissions": {
    "deny": ["Bash(rm:*)", "Bash(git push:*)"],
    "ask": ["Bash(npm install:*)"],
    "allow": ["Bash(git status:*)", "Bash(npm run:*)"]
  }
}
```

**Wildcard Patterns:**

- `:*` - Prefix matching with word boundary
- `*` - Glob matching anywhere
- No wildcard - Exact match only

### Adding Custom Components

**New Agent:**

1. Create `claude/agents/{name}.md`
2. Follow existing agent template
3. Add to `agents/README.md`

**New Skill:**

1. Create `claude/skills/{name}.md`
2. Use Agent Skills frontmatter format
3. Add to `skills/README.md`

**New Hook:**

1. Create `claude/hooks/{name}.sh`
2. Make executable: `chmod +x`
3. Add to `hooks/README.md`

## Version

Configuration version is tracked in `~/.claude/.deploy-version`

## Documentation

- **Internal Docs**: [docs/README.md](docs/README.md)
- **Agents Guide**: [agents/README.md](agents/README.md)
- **Skills Guide**: [skills/README.md](skills/README.md)
- **Hooks Guide**: [hooks/README.md](hooks/README.md)
- **Migration Guide**: [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)

## External Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Agent Skills Standard](https://agentskills.io)
- [Ralph Loop](https://ghuntley.com/ralph/)

## License

Same as parent project.
