# Agents Reference

Complete reference guide for all Cursor agents in this project.

## Table of Contents

- [api-reviewer](#api-reviewer)
- [arch-explorer](#arch-explorer)
- [auditor](#auditor)
- [devil-advocate](#devil-advocate)
- [perf-critic](#perf-critic)
- [prototyper](#prototyper)
- [researcher](#researcher)
- [synthesizer](#synthesizer)
- [task-analyzer](#task-analyzer)
- [verifier](#verifier)

---

## api-reviewer

**API design specialist for HTTP handlers, REST endpoints, gRPC services, and public interfaces.**

### Purpose
Reviews API design for consistency, best practices, versioning, security, and developer experience. Focuses on creating APIs that developers love to use.

### When It's Used
- **Proactively** when creating or modifying HTTP handlers
- **Proactively** for REST endpoints, gRPC services, GraphQL schemas
- **Proactively** for public package interfaces and SDKs
- Always use for: new routes, API changes, breaking changes

### Model
- **Model**: `fast`
- **Read-only**: `true`

### Review Categories

1. **Naming & Consistency**: Resource names, pluralization, casing, patterns
2. **HTTP/REST Best Practices**: Methods, status codes, error formats, pagination
3. **Request/Response Design**: Minimal fields, defaults, no internal leaks, consistent formats
4. **Versioning & Evolution**: Version strategy, backward compatibility, deprecation
5. **Security**: Authentication, authorization, rate limiting, input validation
6. **Documentation**: Endpoints, examples, error cases, auth requirements

### Output Format
- Summary with endpoint count and issue counts
- Critical/Major/Minor issues by endpoint
- Consistency report
- Recommended standards

### Related Agents
- `auditor` - Security-focused review
- `perf-critic` - Performance of API endpoints
- `verifier` - Verify API functionality

### Triggered By
- `/quality` command (when API changes detected)
- `/architect` command (for API architecture decisions)
- Manual invocation for API design reviews

---

## arch-explorer

**Explores 3-5 genuinely different architectural approaches for a given problem.**

### Purpose
Generates diverse architectural solutions with comparison matrices and trade-offs. Great for ADRs and technical RFCs. Focuses on exploring before recommending.

### When It's Used
- Facing design decisions with multiple valid solutions
- Need for ADRs (Architecture Decision Records)
- Technical RFCs requiring approach comparison
- Before committing to a single architectural pattern

### Model
- **Model**: `inherit`
- **Read-only**: `true`

### Approach Types
- Monolith, Microservices, Serverless, Event-driven, Hybrid patterns

### Output Format
- Context and problem statement
- 3-5 distinct approaches with:
  - Core idea
  - Key components
  - Implementation sketch
  - Pros/cons
  - When it shines/struggles
- Comparison matrix (complexity, scalability, cost, etc.)
- Decision guide (when to choose each)
- Optional recommendation with rationale

### Related Agents
- `devil-advocate` - Challenges top recommendation
- `prototyper` - Validates approaches with code
- `synthesizer` - Combines exploration results

### Triggered By
- `/architect` command (Phase 1: Exploration)
- `/research` command (for architectural research)
- Manual invocation for architecture decisions

---

## auditor

**Go/K8s security and reliability auditor for production risks.**

### Purpose
Checks code for production risks, race conditions, resource leaks, security vulnerabilities, and K8s lifecycle issues. Focuses on production safety.

### When It's Used
- Reviewing code for production readiness
- Security compliance checks
- Before deploying to Kubernetes
- Code review for reliability issues

### Model
- **Model**: `fast`
- **Read-only**: `true`

### Audit Categories

1. **EffectiveGo**: Race conditions, channel misuse, goroutine leaks, error handling
2. **Defensive**: Input validation, nil safety, timeouts, resource cleanup
3. **K8sReady**: Graceful shutdown, structured logging, probes, no hardcoded secrets
4. **Security**: No credentials, injection prevention, input sanitization, safe errors, auth checks

### Output Format
- Audit report with findings by severity:
  - Critical issues
  - Major issues
  - Minor issues
- Each finding includes: file:line, description, fix suggestion
- Verification summary (generated vs confirmed vs dropped)

### Related Agents
- `perf-critic` - Performance issues
- `api-reviewer` - API security
- `verifier` - Verify fixes work

### Triggered By
- `/audit` command
- `/quality` command (security pass)
- `/review-pr` command (security pass)
- Manual invocation for security audits

---

## devil-advocate

**Contrarian reviewer that challenges proposals and finds holes.**

### Purpose
Finds weaknesses, challenges assumptions, identifies failure modes, and questions necessity. Not negative—thorough. Ensures proposals are well-vetted before proceeding.

### When It's Used
- **Proactively** before major architectural decisions
- **Proactively** for migration plans
- **Proactively** when a recommendation is made
- Always use for: ADRs, technical RFCs, "we should" statements, migration proposals

### Model
- **Model**: `inherit`
- **Read-only**: `true`

### Challenge Categories

1. **Assumptions**: Questions stated or implied assumptions
2. **Failure Modes**: Identifies how components could fail
3. **Scale & Performance**: What happens at 10x, 100x load
4. **Complexity & Maintenance**: Moving parts, expertise required, debugging difficulty
5. **Alternative Perspectives**: Simpler/robust solutions, industry practices
6. **Hidden Costs**: Migration, operations, learning curve, vendor lock-in

### Output Format
- Understanding summary
- Overall assessment
- Challenges by severity:
  - 🔴 Blockers
  - 🟠 Major concerns
  - 🟡 Minor concerns
  - 🔵 Clarifying questions
- What I like (acknowledges strengths)
- Recommendations
- "If I had to kill this proposal" (strongest argument)

### Related Agents
- `arch-explorer` - Provides proposals to challenge
- `synthesizer` - Incorporates challenges into final recommendation
- `researcher` - Provides evidence for challenges

### Triggered By
- `/architect` command (Phase 2: Challenge)
- `/research` command (brainstorm mode - contrarian perspective)
- Manual invocation before major decisions

---

## perf-critic

**Performance specialist for handlers, database operations, and hot paths.**

### Purpose
Finds real performance issues without premature optimization paranoia. Focuses on algorithmic complexity, I/O patterns, memory allocations, and concurrency.

### When It's Used
- **Proactively** when reviewing handlers
- **Proactively** for database operations
- **Proactively** for loops over collections
- **Proactively** for any code touching hot paths
- Always use for: API endpoints, batch operations, data transformations

### Model
- **Model**: `fast`
- **Read-only**: `true`

### Analysis Categories

1. **Algorithmic Complexity**: Nested loops, repeated searches, sorting, recursion
2. **I/O Patterns**: N+1 queries, unbatched API calls, sequential I/O, missing pooling
3. **Memory & Allocations**: Slice/map growth, string concatenation, unnecessary copies
4. **Concurrency**: Lock contention, unnecessary serialization, blocking operations

### Severity Levels
- **Critical**: O(n²)+ in hot path, N+1 queries (must fix)
- **High**: Unbatched I/O, missing indexes (should fix)
- **Medium**: Suboptimal allocations, lock contention (fix if easy)
- **Low**: Micro-optimizations (document only)

### Output Format
- Critical issues with impact estimates
- High priority issues
- Observations and patterns
- Recommendations prioritized by impact

### Related Agents
- `auditor` - Reliability issues that affect performance
- `api-reviewer` - API performance considerations
- `verifier` - Verify performance improvements

### Triggered By
- `/quality` command (performance pass)
- `/audit` command (performance aspects)
- Manual invocation for performance reviews

---

## prototyper

**Creates working prototype implementations for architectural exploration.**

### Purpose
Creates minimal but functional implementations to validate architectural approaches. Proves concepts work before committing to full implementation.

### When It's Used
- Testing an approach hands-on before committing
- Comparing multiple approaches side-by-side
- Validating architectural decisions
- Rapid proof-of-concept development

### Model
- **Model**: `inherit`
- **Is Background**: `true` (runs in background, can run multiple in parallel)

### Prototype Structure
Creates `.prototypes/{prototype-id}/` with:
- `README.md` - What prototype demonstrates
- `DECISIONS.md` - Key decisions and rationale
- `TRADE_OFFS.md` - Discovered pros/cons
- `src/` - Implementation
- `examples/` - Usage examples

### Implementation Strategy
- **Core** (60%): Minimum to prove concept
- **Happy Path** (25%): One working example
- **Documentation** (15%): Decisions & trade-offs

### Output Format
- Prototype location
- What was built (components)
- Key findings (pros validated, cons discovered, surprises)
- Recommendation (pursue / abandon / needs more exploration)
- Files created list

### Related Agents
- `arch-explorer` - Provides approaches to prototype
- `synthesizer` - Combines prototype results
- `verifier` - Verifies prototype functionality

### Triggered By
- `/architect` command (Phase 3: Prototype - parallel execution)
- Manual invocation for rapid prototyping

---

## researcher

**Deep issue research specialist for investigating GitHub issues and codebase analysis.**

### Purpose
Investigates GitHub issues, analyzes codebase for root causes, and generates solution alternatives. Specializes in exploring unfamiliar code and planning implementations.

### When It's Used
- Exploring unfamiliar code
- Investigating bugs
- Planning implementations
- Root cause analysis
- Solution research

### Model
- **Model**: `fast`
- **Read-only**: `true`

### Research Process

1. **Understand Question**: Issue investigation, root cause, solutions, exploration
2. **Gather Context**: Repo info, project root
3. **Issue Research**: Fetch title, body, comments, linked PRs, related issues
4. **Codebase Investigation**: Files, stack traces, tests, patterns, dependencies
5. **Problem Classification**: Type, severity, scope, complexity
6. **Generate Solutions**: 2-3 approaches with trade-offs
7. **Verify Findings**: Confirm files exist, behavior reproducible, understanding current

### Output Format
- Research summary
- Problem distillation
- Root cause with file:line references
- 2-3 solutions with comparison table
- Recommendation with rationale
- Open questions

### Related Agents
- `arch-explorer` - Architectural research
- `task-analyzer` - Task breakdown from research
- `verifier` - Verify research findings

### Triggered By
- `/research` command
- `/issue` command (research phase)
- `/task` command (research phase)
- Manual invocation for investigation

---

## synthesizer

**Combines outputs from multiple parallel agents into unified recommendation.**

### Purpose
Facilitates technical decisions by combining multiple perspectives into actionable recommendations. Finds patterns, surfaces conflicts, and provides clear guidance.

### When It's Used
- After running multiple explorers, reviewers, or prototypers
- Need for consolidated view and final recommendation
- Multiple agents have provided input
- Decision time after exploration

### Model
- **Model**: `inherit`
- **Read-only**: `true`

### Synthesis Process

1. **Catalog Inputs**: Lists all sources and key findings
2. **Find Consensus**: Identifies what multiple sources agree on
3. **Surface Conflicts**: Highlights disagreements and analyzes them
4. **Weight Evidence**: Prioritizes working prototypes, performance data, theoretical concerns
5. **Synthesize Recommendation**: Provides clear decision with supporting evidence

### Output Format
- Inputs analyzed (table of sources)
- Consensus points
- Contentious points with analysis
- Recommendation:
  - Decision statement
  - Supporting evidence
  - Risks & mitigations
  - Confidence level
- Dissenting views
- Next steps

### Related Agents
- `arch-explorer` - Provides approaches to synthesize
- `devil-advocate` - Provides challenges to incorporate
- `prototyper` - Provides validation data
- `auditor`, `perf-critic`, `api-reviewer` - Provide review perspectives

### Triggered By
- `/architect` command (Phase 4: Synthesize)
- `/quality` command (synthesizes multiple agent outputs)
- Manual invocation after parallel agent execution

---

## task-analyzer

**Analyzes task lists for parallelization opportunities and dependencies.**

### Purpose
Identifies which tasks are independent (parallelizable) vs dependent (sequential). Optimizes task execution order for efficiency.

### When It's Used
- `/parallel --analyze` command
- Reviewing AGENTS.md with multiple `[TODO]` items
- "Which tasks can run in parallel?" questions
- Before starting multi-task work

### Model
- **Model**: Not specified (uses default/inherit)
- **Read-only**: `true`

### Analysis Method

1. **Extract Tasks**: From AGENTS.md or user input
2. **Build Dependency Matrix**: For each task pair, determines relationship
3. **Identify Clusters**: Groups independent tasks, sequences dependent ones
4. **Output Recommendation**: Parallel groups and execution order

### Dependency Detection

**Likely Dependent:**
- "Add tests for X" → depends on X implementation
- "Update docs for X" → depends on X being done
- Same file in both tasks
- "after", "once", "when X is done"

**Likely Independent:**
- Different directories/packages
- Different concerns (auth vs logging)
- "Add X" and "Add Y" (new features)
- Documentation for different areas

### Output Format
- Dependency graph (ASCII)
- Parallel groups table
- Recommendation with command
- Time estimate (sequential vs parallel)

### Related Agents
- `researcher` - Provides task context
- `verifier` - Verifies task completion

### Triggered By
- `/parallel --analyze` command
- `/parallel --from-agents` command
- Manual invocation for task analysis

---

## verifier

**Skeptical validator that independently verifies claimed work is complete.**

### Purpose
Verifies that work claimed as complete actually works. Trusts nothing, requires evidence, finds gaps. Ensures implementations meet acceptance criteria.

### When It's Used
- After tasks are marked done
- Need to confirm implementations are functional
- Verify tests pass
- Confirm acceptance criteria are met
- Before marking work complete

### Model
- **Model**: `fast`
- **Read-only**: `true`

### Verification Process

1. **Identify Claims**: What was claimed to be completed?
2. **Verify Each Claim**: Runs features, executes tests, checks edge cases
3. **Run Tests**: Executes test suite, checks exit code
4. **Check Acceptance Criteria**: Verifies each criterion from spec
5. **Look for Gaps**: Edge cases, error conditions, untested assumptions

### Output Format
- **Verified ✓**: Claims with evidence
- **Failed ✗**: Claims with what's wrong
- **Incomplete ⚠**: Claims with what's missing
- Recommendations for fixes

### Related Agents
- `auditor` - Verifies security/reliability fixes
- `perf-critic` - Verifies performance improvements
- `api-reviewer` - Verifies API implementations

### Triggered By
- `/quality` command (verification pass)
- `/test` command (verification aspect)
- `/self-review` command (verification check)
- Manual invocation to verify completion

---

## Agent Model Types

### `fast` Model
Used for: `api-reviewer`, `auditor`, `perf-critic`, `researcher`, `verifier`
- Faster, more cost-effective
- Good for focused, specific tasks
- Suitable for read-only analysis

### `inherit` Model
Used for: `arch-explorer`, `devil-advocate`, `prototyper`, `synthesizer`
- Uses conversation's current model
- Better for complex reasoning
- Suitable for exploration and synthesis

## Agent Read-Only Status

All agents are **read-only** (`readonly: true`) except:
- `prototyper` - Creates prototype files in `.prototypes/` directory

This ensures agents provide analysis and recommendations without modifying production code.

## Agent Relationships

### Architecture Flow
```
arch-explorer → devil-advocate → prototyper (parallel) → synthesizer
```

### Quality Review Flow
```
auditor + perf-critic + api-reviewer + verifier → synthesizer
```

### Research Flow
```
researcher → arch-explorer → task-analyzer
```

### Verification Flow
```
verifier → (any agent providing implementation)
```

## Agent Invocation Patterns

### Parallel Execution
- `/quality` - Runs `auditor`, `perf-critic`, `api-reviewer`, `verifier` in parallel
- `/architect` - Runs `prototyper` agents in parallel (background)
- `/parallel` - Uses subagents (not these specialized agents)

### Sequential Execution
- `/architect` - Sequential phases: explorer → advocate → prototypes → synthesizer
- `/research` → `/issue` - Research informs task creation

### Conditional Execution
- `api-reviewer` - Only if API changes detected
- `perf-critic` - Skips for docs-only changes
- `verifier` - Only if tests exist
