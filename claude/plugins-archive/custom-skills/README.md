# Custom Skills Plugin

Workflow orchestration skills for Claude Code - comprehensive task execution from research to deployment.

## Overview

This plugin provides 16 custom skills that orchestrate complex development workflows using Claude Code's agent system. Each skill coordinates multiple specialized agents, tools, and workflows to accomplish high-level tasks.

## Skills

### Research & Planning (4 skills)

#### /research
Deep issue investigation and root cause analysis.
- GitHub issue research
- Codebase topic exploration
- Brainstorming with SWOT analysis
- Multiple solution generation

#### /architect
Full architecture exploration with parallel prototyping.
- Generate 3-5 distinct approaches
- Devil's advocate critique
- Optional working prototypes
- Synthesized recommendation

#### /task
Structured task execution from understanding to verification.
- 5-phase workflow (Understand → Specify → Plan → Implement → Verify)
- TDD support with `--tdd`
- AGENTS.md progress tracking
- Optional plan approval with `--plan`

#### /issue
Convert GitHub issue to implementation plan.
- Fetch and classify issue
- Research codebase context
- Break into atomic tasks
- Initialize AGENTS.md
- Create feature branch

### Code Quality (5 skills)

#### /audit
Security and reliability auditing for Go/K8s codebases.
- Race conditions and goroutine leaks
- Defensive programming checks
- Kubernetes readiness
- Security vulnerabilities
- Optional auto-fix with `--fix`

#### /quality
Multi-agent code review (auditor + perf-critic + api-reviewer + verifier).
- Parallel agent execution
- Risk assessment
- Verdict (Ready/Fix Required/Blocked)
- Modes: `--fast`, `--api`, `--perf`

#### /self-review
Quick pre-push review.
- Review changes vs main
- Check correctness, style, security, tests
- Fast feedback (< 1 min)
- Updates AGENTS.md

#### /refactor
Systematic refactoring with behavior preservation.
- Analyze code smells
- Create refactoring plan
- Incremental execution with tests
- Commit per transformation
- Revert on failure

#### /test
Automatic test suite detection and execution.
- Detects framework (Go, Node.js, Python, Rust)
- Modes: full suite, `--quick` (changed files), `--file` (specific)
- Updates AGENTS.md
- Troubleshooting guidance

### Development Workflow (4 skills)

#### /code
Execute next TODO from AGENTS.md.
- Read and find next [TODO]
- Implement minimal changes
- Verify and commit
- Update progress
- Atomic 1task=1commit

#### /parallel
Run independent tasks concurrently.
- Analyze dependencies
- Group parallel/sequential tasks
- Launch Task subagents
- Merge results
- Modes: `--analyze`, `--from-agents`

#### /debug
Systematic debugging workflow.
- Reproduce → Isolate → Hypothesize → Test → Fix → Verify
- Evidence-based hypothesis testing
- Minimal fix approach
- Regression test addition
- Modes: `--trace`, `--bisect`

#### /git-polish
Rewrite messy commits into clean, atomic, signed commits.
- Soft reset history
- Group changes logically
- Conventional Commits format
- GPG + DCO signatures
- Verify each commit

### Documentation & Utilities (3 skills)

#### /docs
Generate and maintain documentation.
- Analyze undocumented APIs
- Generate language-appropriate docs (GoDoc, JSDoc, docstrings)
- Modes: `--api`, `--readme`, `--inline`, `--verify`
- Accuracy verification

#### /context-reset
Reset or inspect context tracking state.
- Check context health (Healthy/Filling/Critical)
- Reset after `/summarize`
- Clear false "stuck" warnings
- Mode: `--status`

## Skill Categories

```
custom-skills/
├── Research & Planning
│   ├── /research      # Issue investigation, brainstorming
│   ├── /architect     # Architecture exploration
│   ├── /task          # Structured task execution
│   └── /issue         # GitHub issue to plan
│
├── Code Quality
│   ├── /audit         # Security & reliability audit
│   ├── /quality       # Multi-agent review
│   ├── /self-review   # Quick pre-push review
│   ├── /refactor      # Systematic refactoring
│   └── /test          # Test suite execution
│
├── Development Workflow
│   ├── /code          # Execute next TODO
│   ├── /parallel      # Concurrent tasks
│   ├── /debug         # Systematic debugging
│   └── /git-polish    # Clean commit history
│
└── Documentation & Utilities
    ├── /docs          # Documentation generation
    └── /context-reset # Context tracking
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
/audit --fix             # Security audit with auto-fix
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

## Installation

### Via deploy script

```bash
./scripts/deploy-claude.sh
```

### Manual installation

```bash
cp -r claude/custom-skills ~/.claude/plugins/custom-skills
```

## Configuration

All skills follow [Agent Skills](https://agentskills.io) open standard and support:

- **Frontmatter fields**: name, description, allowed-tools, model, context, etc.
- **String substitution**: $ARGUMENTS, $N, ${CLAUDE_SESSION_ID}
- **Automatic invocation**: Claude can invoke when relevant (unless `disable-model-invocation: true`)
- **Manual invocation**: Always available via `/skill-name`

## Development

### Adding a New Skill

1. Create skill directory:
   ```bash
   mkdir -p claude/custom-skills/skills/my-skill
   ```

2. Create `SKILL.md`:
   ```yaml
   ---
   name: my-skill
   description: What this skill does and when to use it
   argument-hint: "[arg]"
   disable-model-invocation: true/false
   allowed-tools: Read, Write, Edit, Bash, Task
   model: sonnet/haiku
   ---

   # Skill instructions here
   ```

3. Update `config.json`:
   ```json
   {
     "skills": [
       "my-skill"
     ]
   }
   ```

4. Redeploy:
   ```bash
   ./scripts/deploy-claude.sh --force
   ```

## Comparison with Cursor Commands

These skills were migrated from Cursor's token-optimized command format:

| Aspect | Cursor Commands | Claude Skills |
|--------|----------------|---------------|
| Format | Ultra-compressed notation | Clear, expanded instructions |
| Location | `.cursor/commands/*.md` | `.claude/skills/*/SKILL.md` |
| Frontmatter | Minimal | Comprehensive (Agent Skills standard) |
| Invocation | Manual only | Manual + automatic |
| Tool grants | Not supported | `allowed-tools` field |
| Subagents | Not supported | `context: fork` + agent specification |
| String substitution | Basic | Full support ($ARGUMENTS, $N, etc.) |

## Related Documentation

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Agent Skills Open Standard](https://agentskills.io)
- [Claude Code Agents](../agents/README.md)
- [Claude Code Hooks](../hooks/README.md)

## License

Same as parent project.
