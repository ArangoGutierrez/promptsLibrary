# Claude Skills

Workflow orchestration skills for Claude Code - comprehensive task execution from research to deployment.

## Overview

This directory contains 19 custom skills that orchestrate complex development workflows using Claude Code's agent system. Each skill coordinates multiple specialized agents, tools, and workflows to accomplish high-level tasks.

These skills follow the [Agent Skills](https://agentskills.io) open standard and support automatic invocation, tool grants, and string substitution.

## Available Skills

### Research & Planning (4 skills)

#### /research (`research.md`)
Deep issue investigation and root cause analysis.
- GitHub issue research
- Codebase topic exploration
- Brainstorming with SWOT analysis
- Multiple solution generation

#### /architect (`architect.md`)
Full architecture exploration with parallel prototyping.
- Generate 3-5 distinct approaches
- Devil's advocate critique
- Optional working prototypes
- Synthesized recommendation

#### /task (`task.md`)
Structured task execution from understanding to verification.
- 5-phase workflow (Understand → Specify → Plan → Implement → Verify)
- TDD support with `--tdd`
- AGENTS.md progress tracking
- Optional plan approval with `--plan`

#### /issue (`issue.md`)
Convert GitHub issue to implementation plan.
- Fetch and classify issue
- Research codebase context
- Break into atomic tasks
- Initialize AGENTS.md
- Create feature branch

### Code Quality (6 skills)

#### /audit (`audit.md`)
Security and reliability auditing for Go/K8s codebases.
- Race conditions and goroutine leaks
- Defensive programming checks
- Kubernetes readiness
- Security vulnerabilities
- Optional auto-fix with `--fix`

#### /quality (`quality.md`)
Multi-agent code review (auditor + perf-critic + api-reviewer + verifier).
- Parallel agent execution
- Risk assessment
- Verdict (Ready/Fix Required/Blocked)
- Modes: `--fast`, `--api`, `--perf`

#### /code-review (`code-review.md`)
Comprehensive PR review with confidence-based scoring.
- 8-step systematic process
- Parallel agent reviews
- Confidence scoring (0-100)
- GitHub integration

#### /self-review (`self-review.md`)
Quick pre-push review.
- Review changes vs main
- Check correctness, style, security, tests
- Fast feedback (< 1 min)
- Updates AGENTS.md

#### /refactor (`refactor.md`)
Systematic refactoring with behavior preservation.
- Analyze code smells
- Create refactoring plan
- Incremental execution with tests
- Commit per transformation
- Revert on failure

#### /test (`test.md`)
Automatic test suite detection and execution.
- Detects framework (Go, Node.js, Python, Rust)
- Modes: full suite, `--quick` (changed files), `--file` (specific)
- Updates AGENTS.md
- Troubleshooting guidance

### Development Workflow (7 skills)

#### /code (`code.md`)
Execute next TODO from AGENTS.md.
- Read and find next [TODO]
- Implement minimal changes
- Verify and commit
- Update progress
- Atomic 1task=1commit

#### /parallel (`parallel.md`)
Run independent tasks concurrently.
- Analyze dependencies
- Group parallel/sequential tasks
- Launch Task subagents
- Merge results
- Modes: `--analyze`, `--from-agents`

#### /debug (`debug.md`)
Systematic debugging workflow.
- Reproduce → Isolate → Hypothesize → Test → Fix → Verify
- Evidence-based hypothesis testing
- Minimal fix approach
- Regression test addition
- Modes: `--trace`, `--bisect`

#### /git-polish (`git-polish.md`)
Rewrite messy commits into clean, atomic, signed commits.
- Soft reset history
- Group changes logically
- Conventional Commits format
- GPG + DCO signatures
- Verify each commit

#### /ralph-loop (`ralph-loop.md`)
Iterative development loop using the Ralph technique.
- Self-referential feedback loops
- Autonomous iteration
- Completion promises
- State persistence across iterations

#### /ralph-help (`ralph-help.md`)
Display Ralph loop help and status.
- Show available commands
- Display current loop state
- List active tasks
- Context information

#### /cancel-ralph (`cancel-ralph.md`)
Cancel current Ralph loop and cleanup state.
- Stop running loop
- Save checkpoint
- Clear context
- Cleanup temporary files

### Documentation & Utilities (2 skills)

#### /docs (`docs.md`)
Generate and maintain documentation.
- Analyze undocumented APIs
- Generate language-appropriate docs (GoDoc, JSDoc, docstrings)
- Modes: `--api`, `--readme`, `--inline`, `--verify`
- Accuracy verification

#### /context-reset (`context-reset.md`)
Reset or inspect context tracking state.
- Check context health (Healthy/Filling/Critical)
- Reset after `/summarize`
- Clear false "stuck" warnings
- Mode: `--status`

## Skill Categories

```
skills/
├── Research & Planning (4 skills)
│   ├── research.md       # Issue investigation, brainstorming
│   ├── architect.md      # Architecture exploration
│   ├── task.md           # Structured task execution
│   └── issue.md          # GitHub issue to plan
│
├── Code Quality (6 skills)
│   ├── audit.md          # Security & reliability audit
│   ├── quality.md        # Multi-agent review
│   ├── code-review.md    # PR review with scoring
│   ├── self-review.md    # Quick pre-push review
│   ├── refactor.md       # Systematic refactoring
│   └── test.md           # Test suite execution
│
├── Development Workflow (7 skills)
│   ├── code.md           # Execute next TODO
│   ├── parallel.md       # Concurrent tasks
│   ├── debug.md          # Systematic debugging
│   ├── git-polish.md     # Clean commit history
│   ├── ralph-loop.md     # Iterative development loop
│   ├── ralph-help.md     # Ralph help/status
│   └── cancel-ralph.md   # Cancel Ralph loop
│
└── Documentation & Utilities (2 skills)
    ├── docs.md           # Documentation generation
    └── context-reset.md  # Context tracking
```

## Common Workflows

### New Feature Development

```bash
/issue #123              # Research and plan
/code                    # Implement first task
/code                    # Implement next task
/test                    # Run tests
/self-review             # Quick review
/git-polish              # Clean commits
# Create PR
```

### Bug Investigation & Fix

```bash
/research #456           # Investigate bug
/debug "crash on login"  # Systematic debugging
/test                    # Verify fix
/self-review             # Review changes
```

### Architecture Decision

```bash
/architect "add caching"  # Full exploration with prototypes
# Or
/architect "add caching" --quick  # Skip prototypes
```

### Code Quality Check

```bash
/quality                 # Full review (all agents)
/quality --fast          # Quick check (audit + verify)
/code-review #123        # Review PR with scoring
/audit --fix             # Security audit with auto-fix
```

### Iterative Development

```bash
/ralph-loop "implement feature X"  # Start Ralph loop
/ralph-help status                 # Check loop status
/cancel-ralph                      # Cancel loop
```

### Refactoring Session

```bash
/refactor src/auth       # Analyze and plan
/refactor src/auth --safe  # Extra validation
/test                    # Verify behavior preserved
```

## Skill Interactions

Skills work together through shared state:

### AGENTS.md (Task Tracking)
- Created by: `/issue`, `/task`
- Updated by: `/code`, `/test`, `/self-review`
- Read by: `/code`, `/parallel`

### Git Workflow
- Branch created by: `/issue`
- Commits created by: `/code`, `/refactor`
- History cleaned by: `/git-polish`

### Agent Coordination
- `/architect` uses: arch-explorer, devil-advocate, prototyper, synthesizer
- `/quality` uses: auditor, perf-critic, api-reviewer, verifier
- `/research` uses: researcher agent
- `/audit` uses: auditor agent

## Deployment

Skills are deployed alongside agents and other Claude Code components:

```bash
# Local deployment
./scripts/deploy-claude.sh

# With symlinks (auto-update)
./scripts/deploy-claude.sh --symlink

# Remote installation
curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
```

After deployment, skills are available at: `~/.claude/skills/`

## Migration Notes

These skills were migrated from the custom-skills plugin structure:
- Old: `custom-skills/skills/{name}/SKILL.md`
- New: `skills/{name}.md`

All functionality remains the same - only the directory structure changed for easier discovery and maintenance.

## Related Documentation

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Agent Skills Open Standard](https://agentskills.io)
- [Claude Code Agents](../agents/README.md)
- [Claude Code Hooks](../hooks/README.md)

## License

Same as parent project.
