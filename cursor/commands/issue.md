# Issue

Read a GitHub issue and create atomic task breakdown.

## Usage
`#{number}` — Analyze issue and create task plan

## Workflow

### 1. Fetch Issue
```bash
git remote get-url origin  # → owner/repo
```

Retrieve via GitHub:
- Title, body, labels, state
- All comments (chronological)
- Linked PRs (prior attempts?)
- Related issues

### 2. Classify
| Dimension | Assessment |
|-----------|------------|
| Type | bug / feature / refactor / docs / perf / security |
| Scope | localized / cross-cutting / architectural |
| Complexity | trivial / simple / moderate / complex |

### 3. Research Codebase
- Files/packages mentioned in issue
- Stack traces → trace to source
- Existing tests (coverage?)
- Similar patterns elsewhere

### 4. Design Solution
Generate 2-3 approaches:

| # | Approach | Effort | Risk | Tradeoffs |
|---|----------|--------|------|-----------|
| 1 | {name} | L/M/H | L/M/H | {pro/con} |
| 2 | {name} | L/M/H | L/M/H | {pro/con} |

**Recommend** best effort/impact ratio.

### 5. Create Atomic Tasks
Break into smallest possible commits:
- Each task = 1 logical change
- Each task = independently testable
- Each task = 1 commit

### 6. Verify
| Check | Question |
|-------|----------|
| Files exist? | Read/list to confirm |
| Behavior matches? | Trace code |
| Understanding current? | Check latest comments |

## Output

### Console Summary
```markdown
## Issue #{number}: {title}

**Type:** {classification}
**Complexity:** {level}
**Branch:** `{type}/issue-{number}-{slug}`

### Solution: {recommended approach}
{1-2 sentence description}

### Atomic Tasks
| # | Task | Files | Est |
|---|------|-------|-----|
| 1 | {task} | {files} | S/M/L |
| 2 | {task} | {files} | S/M/L |
| 3 | {task} | {files} | S/M/L |

Ready to start? Run `/code` to begin Task 1.
```

### Create or Update AGENTS.md (Project Root)

If `AGENTS.md` exists, preserve existing content and append/update the Current Task section.
If it doesn't exist, create it with this structure:
```markdown
# AGENTS.md

## Current Task
Issue #{number}: {title}

## Status: IN_PROGRESS

## Branch
`{type}/issue-{number}-{slug}`

## Context
{selected approach description}

## Tasks
| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | {task description} | `[TODO]` | |
| 2 | {task description} | `[TODO]` | |
| 3 | {task description} | `[TODO]` | |
| 4 | Run tests | `[TODO]` | |
| 5 | Self-review | `[TODO]` | |

## Files to Modify
- `{file1}` — {what to change}
- `{file2}` — {what to change}

## Acceptance Criteria
- [ ] {from issue}
- [ ] {from issue}
- [ ] Tests pass
- [ ] Issue can be closed

## Notes
{any important context from research}
```

### Create Branch
```bash
git checkout main && git pull
git checkout -b {type}/issue-{number}-{slug}
```

## Constraints
- **Research-first**: Understand before planning
- **Atomic tasks**: Smallest possible commits
- **Verified refs**: Confirm files exist
- **AGENTS.md**: Create or update `AGENTS.md` in project root (preserve existing content)
