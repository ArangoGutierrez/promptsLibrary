# Claude Agents

Specialized sub-agents for Claude Code that provide focused analysis and automation capabilities.

## Overview

These agents are designed to work with Claude Code's Task tool for specialized analysis. Each agent has specific expertise and tools to perform thorough, independent work.

## Agent Versions

This directory contains both **regular** and **token-optimized** versions of agents:

| Version | Naming | Size | Use Case |
|---------|--------|------|----------|
| **Regular** | `{name}.md` | Full size | Complete documentation, examples, verbose |
| **Optimized** | `{name}-opt.md` | ~50% smaller | Compressed notation, production use |

**Token Savings**: Optimized versions provide ~40-50% reduction in token usage with identical functionality.

### When to Use Each Version

**Use Regular Versions (`{name}.md`)**:

- Learning and understanding agent capabilities
- Documentation and reference
- Onboarding team members
- When token usage isn't a concern

**Use Optimized Versions (`{name}-opt.md`)**:

- Production and routine operations
- Cost optimization
- Long sessions approaching token limits
- High-frequency agent invocations

### Available Optimized Agents

10 agents have optimized versions (with `-opt` suffix):

1. `api-reviewer-opt.md` - API consistency review
2. `arch-explorer-opt.md` - Architecture exploration
3. `auditor-opt.md` - Security/reliability audit
4. `devil-advocate-opt.md` - Critical analysis
5. `perf-critic-opt.md` - Performance review
6. `prototyper-opt.md` - Prototype creation
7. `researcher-opt.md` - Issue investigation
8. `synthesizer-opt.md` - Multi-agent synthesis
9. `task-analyzer-opt.md` - Dependency analysis
10. `verifier-opt.md` - Independent verification

**Note**: `documenter.md`, `test-generator.md`, and `code-simplifier.md` only have regular versions.

## Available Agents

### Phase 0: Research & Planning

#### 1. Researcher (`researcher.md`)

**Purpose**: Deep issue research and root cause analysis

**Use cases**:

- GitHub issue investigation
- Bug root cause analysis
- Solution alternatives generation
- Unfamiliar codebase exploration

**Specializes in**:

- Issue context gathering (via MCP)
- Stack trace analysis
- Pattern identification
- Dependency investigation

**Example**:

```
Use the Task tool with the researcher agent to investigate GitHub issue #456 and identify root causes.
```

#### 2. Task Analyzer (`task-analyzer.md`)

**Purpose**: Analyze task lists for parallelization opportunities

**Use cases**:

- Multi-task planning
- Dependency analysis
- Parallel execution planning
- AGENTS.md task review

**Specializes in**:

- Dependency matrix construction
- Independent task clustering
- Sequential workflow identification
- Parallelization recommendations

**Example**:

```
Use the Task tool with the task-analyzer agent to analyze AGENTS.md and identify which tasks can run in parallel.
```

### Phase 1: Critical Operations (Security & Performance)

#### 3. Auditor (`auditor.md`)

**Purpose**: Security and reliability auditing for Go/K8s codebases

**Use cases**:

- Pre-commit security checks
- Production readiness reviews
- Race condition detection
- Resource leak identification

**Specializes in**:

- Race conditions and goroutine leaks
- K8s lifecycle issues
- Security vulnerabilities (SQL injection, auth bypass)
- Defensive programming patterns

**Example**:

```
Use the Task tool with the auditor agent to review the authentication handlers for security issues.
```

#### 4. Performance Critic (`perf-critic.md`)

**Purpose**: Performance analysis and optimization recommendations

**Use cases**:

- API endpoint performance review
- Database query optimization
- Algorithmic complexity analysis
- Memory leak detection

**Specializes in**:

- N+1 query patterns
- Algorithmic complexity (O(n²) detection)
- Memory allocation issues
- I/O bottlenecks

**Example**:

```
Use the Task tool with the perf-critic agent to analyze the user listing endpoint for performance issues.
```

#### 5. API Reviewer (`api-reviewer.md`)

**Purpose**: API design consistency and best practices

**Use cases**:

- REST API design review
- API consistency audits
- Breaking change detection
- Developer experience improvements

**Specializes in**:

- REST/HTTP best practices
- Naming conventions
- Error response formats
- API versioning strategies

**Example**:

```
Use the Task tool with the api-reviewer agent to review all user-related endpoints for consistency.
```

### Phase 2: Design & Architecture

#### 6. Architecture Explorer (`arch-explorer.md`)

**Purpose**: Explore multiple architectural approaches for complex decisions

**Use cases**:

- ADR (Architecture Decision Record) creation
- Technical RFC authoring
- Solution comparison for new features
- Technology evaluation

**Specializes in**:

- Generating 3-5 genuinely different approaches
- Trade-off analysis
- Comparison matrices
- Decision frameworks

**Example**:

```
Use the Task tool with the arch-explorer agent to explore approaches for implementing user authentication.
```

#### 7. Devil's Advocate (`devil-advocate.md`)

**Purpose**: Critical review and challenge assumptions

**Use cases**:

- Pre-decision validation
- Proposal stress-testing
- Risk identification
- Failure mode analysis

**Specializes in**:

- Assumption challenging
- Edge case identification
- Scale analysis
- Hidden cost discovery

**Example**:

```
Use the Task tool with the devil-advocate agent to critique the microservices migration proposal.
```

#### 8. Prototyper (`prototyper.md`)

**Purpose**: Create working prototype implementations for architectural validation

**Use cases**:

- Proof-of-concept implementations
- Hands-on approach testing
- Parallel prototype comparison
- Architecture validation

**Specializes in**:

- Rapid prototyping
- Minimal viable implementations
- Isolated workspace setup
- Trade-off documentation

**Requires**: Write tool access

**Note**: Can run in background for parallel prototype creation

**Example**:

```
Use the Task tool with the prototyper agent to create a working prototype of the event-driven approach in .prototypes/event-driven/.
```

#### 9. Synthesizer (`synthesizer.md`)

**Purpose**: Combine outputs from multiple agents into unified recommendations

**Use cases**:

- Multi-agent analysis consolidation
- Architecture decision finalization
- Conflict resolution
- Consensus building

**Specializes in**:

- Pattern identification across inputs
- Consensus finding
- Conflict surfacing
- Final recommendation generation

**Example**:

```
Use the Task tool with the synthesizer agent to combine outputs from arch-explorer, devil-advocate, and both prototypers.
```

#### 10. Verifier (`verifier.md`)

**Purpose**: Independent verification that claimed work is complete

**Use cases**:

- PR verification
- Acceptance criteria validation
- Test coverage checks
- Implementation gap detection

**Specializes in**:

- Running tests and checks
- Verifying claims independently
- Finding missing implementations
- Gap analysis

**Example**:

```
Use the Task tool with the verifier agent to verify that PR #123 meets all acceptance criteria.
```

### Phase 3: Code Generation

#### 11. Test Generator (`test-generator.md`)

**Purpose**: Generate comprehensive test suites

**Use cases**:

- Creating unit tests
- Generating integration tests
- Edge case test coverage
- Test documentation

**Specializes in**:

- Behavior-focused testing
- Test case identification
- Test code generation (Go, JS, Python)
- Coverage analysis

**Requires**: Write tool access

**Example**:

```
Use the Task tool with the test-generator agent to create tests for the authentication module.
```

#### 12. Documenter (`documenter.md`)

**Purpose**: Generate and maintain code documentation

**Use cases**:

- API documentation
- README generation
- Inline documentation
- OpenAPI spec generation

**Specializes in**:

- GoDoc, JSDoc, Python docstrings
- README structure
- API reference generation
- Example extraction from code

**Requires**: Write tool access

**Example**:

```
Use the Task tool with the documenter agent to generate documentation for the API handlers.
```

## Usage Patterns

### Single Agent Analysis

```
Use the Task tool with the auditor agent to review src/auth/ for security issues.
```

### Parallel Agent Analysis

Run multiple agents concurrently for comprehensive review:

```
Run these in parallel:
1. Use auditor agent to check for security issues
2. Use perf-critic agent to check for performance issues
3. Use api-reviewer agent to check for API consistency
```

### Sequential Workflow

Chain agents for complex workflows:

```
1. Use arch-explorer to generate 3 approaches for caching
2. Use devil-advocate to critique each approach
3. After deciding, use test-generator to create tests
```

### Decision-Making Flow with Prototypes

For major architectural decisions:

```
1. researcher: Investigate current implementation and constraints
2. arch-explorer: Generate 3-5 distinct approaches
3. devil-advocate: Challenge each approach
4. prototyper: Create working prototypes in parallel (run 2-3 in parallel)
5. synthesizer: Combine all analyses into final recommendation
6. verifier: Validate the chosen approach meets requirements
```

### Issue Resolution Workflow

For bug investigation:

```
1. researcher: Investigate GitHub issue and gather context
2. task-analyzer: Break down fix into parallelizable tasks
3. Run fixes in parallel
4. verifier: Validate fix meets acceptance criteria
```

## Agent Capabilities

| Agent | Read | Write | Bash | WebSearch | Best For |
|-------|------|-------|------|-----------|----------|
| researcher | ✓ | - | ✓ | ✓ | Issue research |
| task-analyzer | ✓ | - | - | - | Task planning |
| auditor | ✓ | - | ✓ | - | Security analysis |
| perf-critic | ✓ | - | ✓ | - | Performance review |
| api-reviewer | ✓ | - | - | - | API consistency |
| arch-explorer | ✓ | - | - | ✓ | Design exploration |
| devil-advocate | ✓ | - | - | ✓ | Critical review |
| prototyper | ✓ | ✓ | ✓ | - | Prototype creation |
| synthesizer | ✓ | - | - | - | Multi-agent synthesis |
| verifier | ✓ | - | ✓ | - | Validation |
| test-generator | ✓ | ✓ | ✓ | - | Test creation |
| documenter | ✓ | ✓ | ✓ | - | Documentation |

## Best Practices

### When to Use Agents

**Use agents for**:

- Focused, specialized analysis
- Time-consuming analysis tasks
- Independent verification
- When you need expert perspective

**Don't use agents for**:

- Simple file reads (use Read tool directly)
- Quick questions (ask directly)
- Needle searches (use Grep/Glob directly)
- Tasks requiring conversation

### Agent Selection

**For research & planning**:

- Issue investigation → researcher
- Task parallelization → task-analyzer

**For code review**:

- Security → auditor
- Performance → perf-critic
- API design → api-reviewer

**For architecture & design**:

- Multiple options → arch-explorer
- Stress-test idea → devil-advocate
- Working prototypes → prototyper
- Combine analyses → synthesizer
- Validate decision → verifier

**For automation**:

- Tests → test-generator
- Docs → documenter

### Parallel Execution

When agents don't depend on each other, run in parallel:

```
# Good: Independent analyses
Run auditor and perf-critic in parallel on the same codebase

# Bad: Sequential dependency
Don't run arch-explorer and verifier in parallel (verifier needs a decision first)
```

## Integration with Workflow

### Pre-Commit Review

```bash
# Before committing
1. auditor: Check for security issues
2. perf-critic: Check for performance regressions
3. verifier: Run tests and verify changes
```

### Pull Request Review

```bash
# For PR review
1. api-reviewer: Check API consistency
2. auditor: Security audit
3. verifier: Validate acceptance criteria
```

### Architecture Decisions

```bash
# For ADRs (comprehensive)
1. researcher: Gather context and constraints
2. arch-explorer: Generate 3-5 approaches
3. devil-advocate: Critique each approach
4. prototyper: Create prototypes (run in parallel)
5. synthesizer: Consolidate all findings
6. Make decision
7. documenter: Document the decision
```

## Deployment

Agents are deployed to your Claude Code configuration directory:

```bash
# Local deployment
./scripts/deploy-claude.sh

# With symlinks (auto-update)
./scripts/deploy-claude.sh --symlink

# Remote installation
curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
```

After deployment, agents are available at: `~/.claude/agents/`

Both regular and optimized versions are deployed together, allowing you to choose based on your needs.

## Contributing

To add a new agent:

1. Create `{agent-name}.md` in `claude/agents/`
2. Follow the template structure (see existing agents)
3. Document tools used and capabilities
4. Add to this README
5. Update `deploy-claude.sh` to include in deployment

## Migration from Cursor

These agents were migrated from Cursor's agent format and adapted for Claude Code:

- Cursor agents used `---` frontmatter for metadata
- Claude agents use markdown with clear tool descriptions
- Added explicit workflow sections
- Adapted examples for Claude Code's Task tool

## License

Same as parent project.
