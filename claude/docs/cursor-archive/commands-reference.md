# Commands Reference

Complete reference guide for all Cursor commands in this project.

## Table of Contents

- [architect](#architect)
- [audit](#audit)
- [code](#code)
- [context-reset](#context-reset)
- [git-polish](#git-polish)
- [issue](#issue)
- [loop](#loop)
- [parallel](#parallel)
- [push](#push)
- [quality](#quality)
- [research](#research)
- [review-pr](#review-pr)
- [self-review](#self-review)
- [task](#task)
- [test](#test)

---

## architect

**Full architectural exploration pipeline with parallel prototyping.**

### Description

Explores multiple architectural approaches for a problem, challenges the top recommendation, creates parallel prototypes, and synthesizes a final recommendation.

### Usage

```text
/architect {problem}
/architect {problem} --quick
/architect {problem} --prototype N
```

**Arguments:**

- `{problem}` - Problem statement to explore
- `--quick` - Skip prototyping, just compare approaches
- `--prototype N` - Prototype top N approaches (default: 2)

### Workflow Steps

1. **Exploration Phase**: Launches `arch-explorer` to generate 3-5 different approaches
2. **Challenge Phase**: Launches `devil-advocate` on the top recommendation
3. **Prototype Phase**: Launches 2+ `prototyper` agents in parallel (background)
4. **Synthesis Phase**: Launches `synthesizer` to combine all findings

### Output

Generates an architecture decision document with:

- Executive summary
- Comparison matrix of approaches
- Final recommendation with evidence
- Trade-offs and risks
- Prototype validation results

### Related Commands

- `/research` - Deep investigation without implementation
- `/quality` - Multi-perspective code review
- `/parallel` - Execute independent tasks concurrently

---

## audit

**Deep defensive audit with integrated fix workflow.**

### Description

Performs comprehensive security and reliability audits on Go code, checking for race conditions, resource leaks, security vulnerabilities, and K8s readiness issues.

### Usage

```text
/audit
/audit --full
/audit --fix
```

**Options:**

- (no args) - Audit recent changes (`git diff`)
- `--full` - Full codebase audit
- `--fix` - Generate fixes for findings

### Workflow Steps

1. **Determine Scope**: Prioritizes changed files, handlers/db/auth, or full codebase
2. **Audit Categories**: Checks EffectiveGo, defensive programming, K8s readiness, security
3. **Verification**: Independently verifies each finding
4. **Fix Workflow** (if `--fix`): Applies fixes, adds tests, re-runs audit

### Output

Creates `AUDIT_REPORT.md` with findings categorized by severity:

- Critical issues
- Major issues
- Minor issues
- Summary with verification counts

### Related Commands

- `/quality` - Multi-perspective quality review
- `/code` - Implement fixes for audit findings
- `/test` - Verify fixes don't break tests

---

## code

**Work on the next TODO task from AGENTS.md.**

### Description

Processes tasks from AGENTS.md one at a time, updating status and committing changes atomically.

### Usage

```text
/code
/code #{N}
```

**Options:**

- (no args) - Work on next `[TODO]` task
- `#{N}` - Work on specific task number

### Workflow Steps

1. **Read AGENTS.md**: Finds next `[TODO]` task
2. **Update Status**: Changes `[TODO]` → `[WIP]`
3. **Implement**: Focuses only on the current task
4. **Verify**: Checks compilation, acceptance criteria, no unrelated changes
5. **Commit**: Creates signed commit with task reference
6. **Update AGENTS.md**: Changes `[WIP]` → `[DONE]` with commit hash
7. **Report**: Shows progress and next task

### Output

Reports task completion with:

- Commit hash
- Changed files
- Progress (X/total tasks)
- Next task preview

### Related Commands

- `/issue` - Create AGENTS.md from GitHub issue
- `/task` - Create AGENTS.md for ad-hoc task
- `/loop` - Automatically work through all tasks
- `/test` - Verify task implementation

---

## context-reset

**Reset or inspect context tracking state.**

### Description

Manages context tracking state used by `context-monitor.sh` hook to estimate token usage and recommend session management.

### Usage

```text
/context-reset
/context-reset --status
```

**Options:**

- (no args) - Reset metrics to zero
- `--status` - Show current health without resetting

### Workflow Steps

1. **Status Check** (`--status`): Reads `.cursor/context-state.json` and displays health metrics
2. **Reset** (default): Removes state files to reset tracking

### Output

- **Status mode**: Shows health state, score percentage, tasks completed, recommendations
- **Reset mode**: Confirms reset completion

### When to Use

- After manual `/summarize` to recalibrate score
- When "stuck" detection is a false positive
- Starting fresh work on the same branch
- Checking health without resetting

### Related Commands

- `/summarize` - Reduces context usage (recovered by context-monitor)
- `/task` - Start new task (may trigger context recommendations)

---

## git-polish

**Rewrite local history into atomic, signed commits.**

### Description

Refactors local git history into clean, atomic commits with proper signing and conventional commit messages.

### Usage

```text
/git-polish
```

### Workflow Steps

1. **Reset**: Shows recent commits, asks how many to reset
2. **Analyze**: Groups changes by type (chore, refactor, feat/fix)
3. **Verify**: Checks each group independently for validity
4. **Reconstruct**: Creates atomic commits with `-s -S` flags
5. **Verify**: Confirms all commits are signed and compile

### Output

Creates a clean commit history with:

- Atomic commits (each compiles independently)
- Conventional commit format: `type(scope): description`
- All commits signed with SSH/GPG
- DCO signoff on all commits

### Related Commands

- `/push` - Push polished commits and create PR
- `/code` - Creates properly formatted commits automatically

---

## issue

**Read a GitHub issue and create atomic task breakdown.**

### Description

Analyzes a GitHub issue, researches the codebase, designs solutions, and creates an atomic task breakdown in AGENTS.md.

### Usage

```text
/issue #{number}
```

**Arguments:**

- `#{number}` - GitHub issue number to analyze

### Workflow Steps

1. **Fetch Issue**: Retrieves issue details, comments, linked PRs
2. **Classify**: Determines type, scope, complexity
3. **Research Codebase**: Investigates mentioned files, patterns, tests
4. **Design Solution**: Generates 2-3 approaches with comparison
5. **Create Atomic Tasks**: Breaks into smallest possible commits
6. **Verify**: Confirms files exist and understanding is current
7. **Create Branch**: Checks out new branch `{type}/issue-{number}-{slug}`

### Output

Creates or updates `AGENTS.md` with:

- Issue context and classification
- Recommended solution approach
- Atomic task breakdown table
- Files to modify
- Acceptance criteria

### Related Commands

- `/code` - Work through tasks from AGENTS.md
- `/loop` - Automatically complete all tasks
- `/research` - Deep investigation without creating tasks
- `/push` - Push changes and create PR

---

## loop

**Ralph-Loop style persistent task execution until completion.**

### Description

Continuously works on a task until a completion phrase is detected or max iterations reached. Implements autonomous task continuation.

### Usage

```text
/loop {task description}
/loop {task description} --done "{completion phrase}"
/loop {task description} --max {N}
```

**Arguments:**

- `{task description}` - Task to work on
- `--done "{phrase}"` - Completion signal (default: "DONE")
- `--max {N}` - Max iterations (default: 10)

### Workflow Steps

1. **Initialize**: Creates `.cursor/loop-state.json` with task config
2. **Work**: Executes task each iteration
3. **Check Completion**: Looks for completion phrase or AGENTS.md status
4. **Loop Logic**: Hook intercepts stops and continues if not done
5. **Complete**: Reports when done or max iterations reached

### Output

- **Start**: Shows task, completion criteria, max iterations
- **Each Iteration**: Progress updates
- **Complete**: Summary of work done, iterations used, result

### Best Practices

- Use clear, machine-verifiable completion criteria
- Set appropriate max iterations
- Break large tasks into phases
- Use with AGENTS.md for structured tasks

### Related Commands

- `/code` - Single task execution
- `/issue` - Create task breakdown for loop
- `/task` - Create task plan for loop
- `/context-reset` - Reset if loop state corrupted

---

## parallel

**Execute independent tasks concurrently using subagents.**

### Description

Identifies and executes independent tasks in parallel to speed up work, with dependency analysis to ensure correct ordering.

### Usage

```text
/parallel task1 | task2 | task3
/parallel --analyze
/parallel --from-agents
```

**Options:**

- `task1 | task2 | task3` - Execute tasks in parallel
- `--analyze` - Analyze AGENTS.md for parallelization opportunities
- `--from-agents` - Auto-run parallel tasks from AGENTS.md

### Workflow Steps

1. **Parse Tasks**: Splits input by `|` delimiter
2. **Dependency Analysis**: Checks for file overlap, data flow, independence
3. **Group by Independence**: Creates parallel groups and sequential order
4. **Execute**: Launches subagents simultaneously (max 4 parallel)
5. **Merge Results**: Combines outputs and reports time saved

### Output

Shows:

- Tasks completed in parallel
- Sequential tasks (with dependencies)
- Summary with time savings estimate
- Next steps

### Related Commands

- `/code` - Sequential task execution
- `/loop` - Can use parallel for batch processing
- `/task` - Create tasks that can be parallelized

---

## push

**Push changes and create PR.**

### Description

Verifies all tasks are complete, pushes branch, and creates a pull request with proper linking to the issue.

### Usage

```text
/push
```

### Workflow Steps

1. **Pre-Push Checklist**: Verifies all tasks `[DONE]`, tests pass, self-review done
2. **Check Status**: Confirms clean git state and tests passing
3. **Read AGENTS.md**: Gets issue number and context
4. **Push Branch**: Pushes with upstream tracking
5. **Create PR**: Uses GitHub CLI to create PR with proper title/body
6. **Update AGENTS.md**: Records PR number and status

### Output

Reports:

- PR number and link
- Branch name
- Issue closure reference
- Next steps (CI, reviews, merge)

### Pre-Checks

Warns if:

- Tasks still `[TODO]`
- Tests not run
- Self-review not done

### Related Commands

- `/test` - Run tests before pushing
- `/self-review` - Review changes before pushing
- `/code` - Complete remaining tasks
- `/git-polish` - Clean up commits before push

---

## quality

**Multi-perspective code quality review using parallel subagents.**

### Description

Launches 4 parallel agents (auditor, perf-critic, api-reviewer, verifier) to comprehensively review code quality from multiple angles.

### Usage

```text
/quality
/quality {path}
/quality #{PR}
/quality --fast
/quality --api
/quality --perf
```

**Options:**

- (no args) - Review current git diff
- `{path}` - Review specific file/directory
- `#{PR}` - Review PR changes
- `--fast` - auditor + verifier only
- `--api` - api-reviewer focus
- `--perf` - perf-critic focus

### Workflow Steps

1. **Determine Scope**: Gets changed files or specified path/PR
2. **Launch Parallel Agents**: Runs 4 agents simultaneously
3. **Synthesize Results**: Combines all outputs into unified report
4. **Generate Verdict**: Ready / Fix Required / Blocked

### Output

Quality report with:

- Risk level (High/Medium/Low)
- Findings by category (Security, Performance, API, Functionality)
- Summary table with issue counts
- Blocking issues
- Recommendations
- Final verdict

### Related Commands

- `/audit` - Deep security/reliability audit
- `/review-pr` - PR review with confidence scoring
- `/self-review` - Review before pushing

---

## research

**Deep investigation without implementation.**

### Description

Conducts thorough research on GitHub issues or codebase topics, generating solution alternatives without implementing them.

### Usage

```text
/research #{number}
/research {topic}
/research brainstorm: {idea}
```

**Arguments:**

- `#{number}` - Research GitHub issue
- `{topic}` - Research codebase topic
- `brainstorm: {idea}` - Deep-dive idea analysis with web research

### Workflow Steps

1. **Context**: Gets repo and project root
2. **Issue Fetch** (if applicable): Retrieves issue details
3. **Classification**: Determines type, severity, scope, complexity
4. **Codebase Investigation**: Traces files, tests, patterns, dependencies
5. **Verify**: Confirms files exist and understanding is current
6. **Solutions**: Generates 2-3 approaches with trade-offs
7. **Comparison**: Creates comparison matrix

### Brainstorm Mode

For `brainstorm:` prefix:

- Extracts core idea
- Performs web research
- Multi-perspective analysis (User, Technical, Business, Market, Risk, Contrarian)
- SWOT synthesis
- Assumption testing
- Action matrix

### Output

Research report with:

- Problem summary
- Root cause analysis
- 2-3 solution alternatives
- Recommendation with rationale
- Open questions

### Related Commands

- `/issue` - Research + create task breakdown
- `/architect` - Architectural exploration
- `/task` - Research + implement

---

## review-pr

**Rigorous code review with confidence scoring.**

### Description

Reviews pull requests with multiple passes (security, bugs, architecture) and only reports findings with ≥80 confidence.

### Usage

```text
/review-pr #{number}
/review-pr
```

**Options:**

- `#{number}` - Review specific PR
- (no args) - Review current branch diff

### Workflow Steps

1. **Pre-Flight Skip**: Skips closed/draft PRs, LGTM for trivial changes
2. **Pass 1 - Security**: Checks credentials, injection, validation, auth, error messages
3. **Pass 2 - Bugs**: Reviews CHANGED lines for logic errors, nil derefs, leaks
4. **Pass 3 - Architecture**: Checks patterns, separation, tests
5. **Confidence Scoring**: Only reports findings ≥80 confidence
6. **Verification**: Re-reads independently to confirm

### Output

PR review with:

- Summary (files, risk areas)
- Blocking issues (confidence ≥80)
- Health suggestions
- Questions for author
- Verdict (Approved / Changes Requested / Blocked)

### Related Commands

- `/quality` - Multi-perspective quality review
- `/audit` - Deep security audit
- `/self-review` - Review your own changes

---

## self-review

**Review all changes before pushing.**

### Description

Reviews all changes in current branch compared to main, checking correctness, style, security, and tests.

### Usage

```text
/self-review
```

### Workflow Steps

1. **Get Changes**: Lists commits and full diff vs main
2. **Review Summary**: Shows commit count, files changed, line counts
3. **Check Each File**: Reviews correctness, style, security, tests
4. **Generate Report**: Creates review with good/bad/consider items
5. **Update AGENTS.md**: Marks review task as `[DONE]`

### Output

Review report with:

- Summary of changes
- ✅ Good observations
- ⚠️ Consider (suggestions)
- ❌ Fix Before Push (required fixes)
- Summary table by aspect
- Verdict (Ready / Minor fixes / Needs work)

### Related Commands

- `/push` - Push after self-review
- `/quality` - Multi-perspective review
- `/test` - Verify tests pass

---

## task

**Create and execute a spec-first task with optional planning and TDD modes.**

### Description

Creates structured tasks with specification-first approach, optional planning phase, and TDD support.

### Usage

```text
/task {description}
/task #{number}
/task {description} --plan
/task {description} --tdd
```

**Arguments:**

- `{description}` - Ad-hoc task description
- `#{number}` - GitHub issue number
- `--plan` - Plan first, await "GO" before implementing
- `--tdd` - Test-first development

### Workflow Steps

1. **UNDERSTAND** (10%): Gets context, fetches issue if applicable, clarifies ambiguities
2. **SPECIFY** (15%): Defines inputs, outputs, constraints, acceptance, edges, out of scope
3. **PLAN** (if `--plan`): Generates 2-3 approaches, selects best, awaits "GO"
4. **IMPLEMENT**: Creates/updates AGENTS.md, implements with TDD if `--tdd`
5. **VERIFY**: Checks compilation, tests, acceptance criteria, edge cases

### Output

Creates or updates `AGENTS.md` with:

- Task specification
- Approach comparison (if `--plan`)
- Progress tracker
- Acceptance criteria

### Related Commands

- `/code` - Work through task from AGENTS.md
- `/loop` - Automatically complete task
- `/issue` - Create task from GitHub issue
- `/test` - Run tests (especially with `--tdd`)

---

## test

**Run tests and verify everything works.**

### Description

Auto-detects test framework and runs appropriate test suite, reporting results and suggesting fixes for failures.

### Usage

```text
/test
/test --quick
/test --file {path}
```

**Options:**

- (no args) - Run full test suite
- `--quick` - Run only tests for changed files
- `--file {path}` - Run specific test file

### Workflow Steps

1. **Detect Toolchain**: Identifies Go, Node/TS, Python, Rust
2. **Run Tests**: Executes appropriate test command
3. **Report Results**: Shows pass/fail summary, failures, coverage
4. **Update AGENTS.md**: Marks test task status

### Output

Test report with:

- Status (PASS/FAIL)
- Test counts (passed/total)
- Duration
- Failures with error messages
- Coverage (if available)
- Suggested fixes for failures

### Related Commands

- `/code` - Fix test failures
- `/quality` - Includes test verification
- `/push` - Requires tests to pass
- `/self-review` - Includes test check

---

## Command Relationships

### Task Management Flow

```text
/issue or /task → /code or /loop → /test → /self-review → /push
```

### Quality Assurance Flow

```text
/audit or /quality → /code (fixes) → /test → /self-review
```

### Architecture Flow

```text
/research → /architect → /parallel (prototypes) → /quality → /code
```

### Parallel Execution

```text
/parallel --analyze → /parallel task1 | task2 → /code (sequential)
```

### Context Management

```text
/code (many iterations) → /context-reset --status → /summarize → /context-reset
```
