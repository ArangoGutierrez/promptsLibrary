# Team Coordination Commands Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert team-coordination skill into three separate commands (`/team-plan`, `/team-execute`, `/team-shutdown`) following superpowers pattern with upstream validation and language-aware QA.

**Architecture:** Create command wrappers that invoke team-coordination skill with phase context, add branch validation and QA validation libraries, update skill to handle phase-based invocation.

**Tech Stack:** Markdown command files, bash validation scripts (embedded in markdown), skill system integration

---

## Task 1: Create Commands Directory Structure

**Files:**
- Create: `/Users/eduardoa/.claude/skills/team-coordination/commands/`
- Create: `/Users/eduardoa/.claude/skills/team-coordination/lib/`

**Step 1: Create directories**

```bash
mkdir -p /Users/eduardoa/.claude/skills/team-coordination/commands
mkdir -p /Users/eduardoa/.claude/skills/team-coordination/lib
```

**Step 2: Verify structure**

Run: `ls -la /Users/eduardoa/.claude/skills/team-coordination/`

Expected: See `commands/` and `lib/` directories

**Step 3: Commit**

```bash
cd /Users/eduardoa/.claude
git add skills/team-coordination/commands skills/team-coordination/lib
git commit -s -S -m "chore: add team-coordination command structure"
```

---

## Task 2: Create /team-plan Command

**Files:**
- Create: `/Users/eduardoa/.claude/skills/team-coordination/commands/team-plan.md`

**Step 1: Write command file**

```markdown
---
description: Plan team structure, branch strategy, and task assignments for parallel work
disable-model-invocation: true
---

You are in the PLANNING phase of team coordination.

**Context:** User invoked `/team-plan` to plan parallel team work.

**Your responsibilities:**
1. Verify current branch is `agents-workbench`
2. Check upstream/origin status for target branch
3. Ask mandatory branching strategy question
4. Create plan in `.agents/plans/<project>.md`
5. Update `AGENTS.md` with task assignments

**Critical:** Use @skills/team-coordination/lib/branch-validator.md for upstream validation.

Invoke the team-coordination skill and follow the PLANNING phase instructions.

ARGUMENTS (if any): {{ARGUMENTS}}
```

**Step 2: Verify file created**

Run: `cat /Users/eduardoa/.claude/skills/team-coordination/commands/team-plan.md`

Expected: See command content with frontmatter and planning phase instructions

**Step 3: Commit**

```bash
git add skills/team-coordination/commands/team-plan.md
git commit -s -S -m "feat: add /team-plan command"
```

---

## Task 3: Create /team-execute Command

**Files:**
- Create: `/Users/eduardoa/.claude/skills/team-coordination/commands/team-execute.md`

**Step 1: Write command file**

```markdown
---
description: Spawn team agents (Architect, QA, Workers) and execute implementation
disable-model-invocation: true
---

You are in the EXECUTION phase of team coordination.

**Context:** User invoked `/team-execute` to spawn agents and implement.

**Your responsibilities:**
1. Verify on `agents-workbench` branch
2. Confirm plan exists in `.agents/plans/`
3. Validate branch source still up-to-date
4. Create worktrees using validated source
5. Spawn agents in order: Architect → QA → Workers
6. Coordinate implementation

**Critical:**
- Use @skills/team-coordination/lib/branch-validator.md before worktree creation
- QA agent must use @skills/team-coordination/lib/qa-validator.md for validation

Invoke the team-coordination skill and follow the EXECUTION phase instructions.

ARGUMENTS (if any): {{ARGUMENTS}}
```

**Step 2: Verify file created**

Run: `cat /Users/eduardoa/.claude/skills/team-coordination/commands/team-execute.md`

Expected: See command content with execution phase instructions

**Step 3: Commit**

```bash
git add skills/team-coordination/commands/team-execute.md
git commit -s -S -m "feat: add /team-execute command"
```

---

## Task 4: Create /team-shutdown Command

**Files:**
- Create: `/Users/eduardoa/.claude/skills/team-coordination/commands/team-shutdown.md`

**Step 1: Write command file**

```markdown
---
description: Clean shutdown of team agents, worktrees, and context
disable-model-invocation: true
---

You are in the SHUTDOWN phase of team coordination.

**Context:** User invoked `/team-shutdown` to clean up after team work.

**Your responsibilities:**
1. Verify completion status (PRs merged or abandoned)
2. Shutdown agents with TeamDelete
3. Remove all worktrees in `.worktrees/`
4. Update `agents-workbench` AGENTS.md
5. Run `/compact` for context hygiene

**Critical:** Complete cleanup prevents resource leaks and context pollution.

Invoke the team-coordination skill and follow the SHUTDOWN phase instructions.

ARGUMENTS (if any): {{ARGUMENTS}}
```

**Step 2: Verify file created**

Run: `cat /Users/eduardoa/.claude/skills/team-coordination/commands/team-shutdown.md`

Expected: See command content with shutdown phase instructions

**Step 3: Commit**

```bash
git add skills/team-coordination/commands/team-shutdown.md
git commit -s -S -m "feat: add /team-shutdown command"
```

---

## Task 5: Create Branch Validator Library

**Files:**
- Create: `/Users/eduardoa/.claude/skills/team-coordination/lib/branch-validator.md`

**Step 1: Write validator documentation**

```markdown
# Branch Validator

Validation logic for ensuring local branches are up-to-date with upstream/origin before creating worktrees.

## Critical Problem

Users frequently create worktrees from outdated local branches, causing merge conflicts and wasted work. ALWAYS validate upstream status.

## Validation Commands

### Step 1: Fetch Latest

```bash
git fetch origin
```

### Step 2: Check Branch Status

```bash
# Replace <branch> with actual branch name (main, develop, etc.)
LOCAL=$(git rev-parse <branch>)
REMOTE=$(git rev-parse origin/<branch>)
BASE=$(git merge-base <branch> origin/<branch>)

if [ "$LOCAL" != "$REMOTE" ]; then
  if [ "$LOCAL" = "$BASE" ]; then
    BEHIND=$(git rev-list --count $LOCAL..$REMOTE)
    echo "⚠️  ERROR: Local <branch> is BEHIND origin/<branch> by $BEHIND commits"
    echo ""
    echo "Fix with: git checkout <branch> && git pull origin <branch>"
    echo ""
    echo "DO NOT create worktrees until branch is up-to-date."
    exit 1
  elif [ "$REMOTE" = "$BASE" ]; then
    AHEAD=$(git rev-list --count $REMOTE..$LOCAL)
    echo "⚠️  WARNING: Local <branch> is AHEAD of origin/<branch> by $AHEAD commits"
    echo "You have unpushed commits. Verify this is intentional."
  else
    echo "⚠️  ERROR: Local <branch> has DIVERGED from origin/<branch>"
    echo "Fix with: git checkout <branch> && git pull origin <branch>"
    exit 1
  fi
fi
```

### Step 3: Show Branch Status

```bash
git status -sb <branch>
```

## Usage in Commands

**In /team-plan:** Run validation when user selects branch source, block planning if outdated.

**In /team-execute:** Re-run validation before creating worktrees (time may have passed since planning).

## Branching Strategy Options

After validation passes, present:

**A) origin/<default-branch> - RECOMMENDED**
- Always up-to-date
- Command: `git worktree add .worktrees/<name> -b <branch> origin/<default>`

**B) Local <default-branch> - After Update**
- Only if validation confirmed up-to-date
- Command: `git worktree add .worktrees/<name> -b <branch> <default>`

**C) Specific feature branch - After Validation**
- For building on in-progress work
- Must run validation on feature branch first

**D) Current agents-workbench**
- Advanced scenario only
- User must understand merge implications
```

**Step 2: Verify file created**

Run: `cat /Users/eduardoa/.claude/skills/team-coordination/lib/branch-validator.md`

Expected: See validation logic and usage instructions

**Step 3: Commit**

```bash
git add skills/team-coordination/lib/branch-validator.md
git commit -s -S -m "feat: add branch validation library"
```

---

## Task 6: Create QA Validator Library

**Files:**
- Create: `/Users/eduardoa/.claude/skills/team-coordination/lib/qa-validator.md`

**Step 1: Write QA validation documentation**

```markdown
# QA Validator

Language-aware validation checks for QA agents in team coordination workflow.

## Overview

QA agent runs these checks before approving PRs. Blocks merge if any check fails.

## Language Detection

```bash
# Detect project type
if [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
elif [ -f "package.json" ]; then
  if grep -q '"typescript"' package.json; then
    PROJECT_TYPE="typescript"
  else
    PROJECT_TYPE="node"
  fi
elif [ -f "Cargo.toml" ]; then
  PROJECT_TYPE="rust"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  PROJECT_TYPE="python"
else
  PROJECT_TYPE="unknown"
fi

echo "📦 Detected project type: $PROJECT_TYPE"
```

## Validation Checks

### 1. Git Signature Validation (ALL PROJECTS)

**Required:** Every commit must have BOTH signatures:
- `-s` flag: Signed-off-by line
- `-S` flag: GPG signature

```bash
echo "🔐 Validating commit signatures..."

# Get base branch (usually main/master/develop)
BASE_BRANCH="origin/main"  # Adjust based on project
FEATURE_BRANCH=$(git branch --show-current)

# Check all commits in feature branch
git log --format="%H %s" $BASE_BRANCH..$FEATURE_BRANCH | while read commit msg; do
  # Check for Signed-off-by
  if ! git log -1 --format="%B" $commit | grep -q "Signed-off-by:"; then
    echo "❌ FAIL: Commit $commit missing Signed-off-by"
    echo "   Message: $msg"
    UNSIGNED_COMMITS=true
  fi

  # Check for GPG signature
  if ! git log -1 --show-signature $commit | grep -q "gpg: Good signature"; then
    echo "❌ FAIL: Commit $commit missing GPG signature"
    echo "   Message: $msg"
    UNSIGNED_COMMITS=true
  fi
done

if [ "$UNSIGNED_COMMITS" = true ]; then
  echo ""
  echo "⚠️  Found unsigned commits. Worker must fix with:"
  echo "git rebase --exec 'git commit --amend --no-edit -s -S' $BASE_BRANCH"
  exit 1
fi

echo "✅ All commits properly signed"
```

### 2. Go Project Validation

```bash
if [ "$PROJECT_TYPE" = "go" ]; then
  echo "🔍 Running Go validation..."

  # Format check
  echo "→ Checking formatting..."
  UNFORMATTED=$(gofmt -l .)
  if [ -n "$UNFORMATTED" ]; then
    echo "❌ FAIL: Files need formatting:"
    echo "$UNFORMATTED"
    exit 1
  fi

  # Vet
  echo "→ Running go vet..."
  go vet ./... || exit 1

  # Lint (if available)
  if command -v golangci-lint &> /dev/null; then
    echo "→ Running linter..."
    golangci-lint run || exit 1
  fi

  # Tests
  echo "→ Running tests..."
  go test -v ./... || exit 1

  # Security scans
  echo "→ Running security scans..."
  if command -v govulncheck &> /dev/null; then
    govulncheck ./... || exit 1
  fi

  if command -v gosec &> /dev/null; then
    gosec ./... || exit 1
  fi

  if command -v trivy &> /dev/null; then
    trivy fs . || exit 1
  fi

  echo "✅ Go validation passed"
fi
```

### 3. TypeScript/Node Project Validation

```bash
if [ "$PROJECT_TYPE" = "typescript" ] || [ "$PROJECT_TYPE" = "node" ]; then
  echo "🔍 Running TypeScript/Node validation..."

  # Install dependencies if needed
  if [ ! -d "node_modules" ]; then
    echo "→ Installing dependencies..."
    if [ -f "package-lock.json" ]; then
      npm ci || exit 1
    elif [ -f "yarn.lock" ]; then
      yarn install --frozen-lockfile || exit 1
    else
      npm install || exit 1
    fi
  fi

  # Format check
  if [ -f ".prettierrc" ] || grep -q "prettier" package.json; then
    echo "→ Checking formatting..."
    npx prettier --check . || exit 1
  fi

  # Lint
  if [ -f ".eslintrc" ] || grep -q "eslint" package.json; then
    echo "→ Running linter..."
    npx eslint . || exit 1
  fi

  # Type check (TypeScript only)
  if [ "$PROJECT_TYPE" = "typescript" ]; then
    echo "→ Type checking..."
    npx tsc --noEmit || exit 1
  fi

  # Tests
  echo "→ Running tests..."
  npm test || exit 1

  # Security audit
  echo "→ Running security audit..."
  if [ -f "package-lock.json" ]; then
    npm audit --audit-level=moderate || exit 1
  elif [ -f "yarn.lock" ]; then
    yarn audit || exit 1
  fi

  echo "✅ TypeScript/Node validation passed"
fi
```

### 4. Rust Project Validation

```bash
if [ "$PROJECT_TYPE" = "rust" ]; then
  echo "🔍 Running Rust validation..."

  # Format check
  echo "→ Checking formatting..."
  cargo fmt -- --check || exit 1

  # Lint
  echo "→ Running clippy..."
  cargo clippy -- -D warnings || exit 1

  # Tests
  echo "→ Running tests..."
  cargo test || exit 1

  # Security audit
  if command -v cargo-audit &> /dev/null; then
    echo "→ Running security audit..."
    cargo audit || exit 1
  fi

  echo "✅ Rust validation passed"
fi
```

### 5. Python Project Validation

```bash
if [ "$PROJECT_TYPE" = "python" ]; then
  echo "🔍 Running Python validation..."

  # Format check (if black available)
  if command -v black &> /dev/null; then
    echo "→ Checking formatting..."
    black --check . || exit 1
  fi

  # Lint (if ruff/flake8 available)
  if command -v ruff &> /dev/null; then
    echo "→ Running linter..."
    ruff check . || exit 1
  elif command -v flake8 &> /dev/null; then
    flake8 . || exit 1
  fi

  # Type check (if mypy available)
  if command -v mypy &> /dev/null; then
    echo "→ Type checking..."
    mypy . || exit 1
  fi

  # Tests
  echo "→ Running tests..."
  pytest || exit 1

  echo "✅ Python validation passed"
fi
```

### 6. CI/CD Pre-flight Checks

```bash
echo "🚀 Checking CI/CD configuration..."

# GitHub Actions
if [ -d ".github/workflows" ]; then
  echo "📋 GitHub Actions workflows detected"

  if command -v act &> /dev/null; then
    echo "→ Running workflows locally with act..."
    act pull_request || exit 1
  else
    echo "⚠️  'act' not installed. Install with: brew install act"
    echo "→ Manually verify workflows will pass"
  fi
fi

# GitLab CI
if [ -f ".gitlab-ci.yml" ]; then
  echo "📋 GitLab CI detected"
  echo "→ Verify pipeline will pass (consider using gitlab-runner locally)"
fi

# Jenkins
if [ -f "Jenkinsfile" ]; then
  echo "📋 Jenkins pipeline detected"
  echo "→ Verify pipeline will pass"
fi
```

## Usage in /team-execute

QA agent should:
1. Run validation after worker reports feature complete
2. Block PR creation if ANY check fails
3. Report specific failures to Architect
4. Provide fix commands to Worker

## Approval Gate

```
✅ All checks passed → Approve PR creation
❌ Any check failed → Block and report issues
```
```

**Step 2: Verify file created**

Run: `cat /Users/eduardoa/.claude/skills/team-coordination/lib/qa-validator.md`

Expected: See comprehensive validation logic for multiple languages

**Step 3: Commit**

```bash
git add skills/team-coordination/lib/qa-validator.md
git commit -s -S -m "feat: add language-aware QA validation library"
```

---

## Task 7: Update SKILL.md to Reference Commands

**Files:**
- Modify: `/Users/eduardoa/.claude/skills/team-coordination/SKILL.md:232-250`

**Step 1: Read current workflow commands section**

Run: `sed -n '232,250p' /Users/eduardoa/.claude/skills/team-coordination/SKILL.md`

Expected: See old `/team:*` syntax

**Step 2: Update workflow commands section**

Replace lines 232-250 with:

```markdown
## Workflow Commands

This skill is invoked through three separate commands:

### `/team-plan` - Planning Phase
**Location:** agents-workbench branch

Invokes team-coordination skill with planning phase context.

See: `commands/team-plan.md` for details
Reference: `lib/branch-validator.md` for upstream validation logic

**Steps:**
1. Run brainstorming for overall approach
2. Validate branch source (CRITICAL - prevents outdated branch errors)
3. Ask mandatory branching strategy question
4. Identify independent tasks (candidates for parallelization)
5. Create plan document in `.agents/plans/[project-name].md`
6. Document in AGENTS.md:
   - Task assignments
   - Branch source with validation status
   - Architectural decisions needed
   - Integration points
   - Success criteria
7. Assign tasks to workers (plan their worktrees)

**Output:** Plan document + AGENTS.md updated

### `/team-execute` - Execution Phase

Invokes team-coordination skill with execution phase context.

See: `commands/team-execute.md` for details
Reference: `lib/qa-validator.md` for QA validation logic

**Steps:**
1. Verify on agents-workbench branch
2. Confirm plan exists
3. Re-validate branch source (time may have passed since planning)
4. Create worktrees for each worker:
   ```bash
   git worktree add .worktrees/[feature-name] -b [branch-name] [validated-source]
   ```

5. Spawn team in this EXACT order (MANDATORY):
   ```
   1. Systems Architect (on agents-workbench) - REQUIRED
   2. QA Agent (on agents-workbench) - REQUIRED
   3. Worker agents sequentially (each in own worktree)
   ```

   **DO NOT skip Architect or QA.** Every team MUST have both.

6. Workers implement following TDD
7. Workers report to QA when ready
8. QA validates (signatures, tests, security, CI/CD)
9. QA reports to Architect if issues found
10. Architect unblocks architectural decisions

**Output:** Features implemented, tested, PRs created

### `/team-shutdown` - Cleanup Phase

Invokes team-coordination skill with shutdown phase context.

See: `commands/team-shutdown.md` for details

**When:** All tasks complete, PRs merged

**Steps:**
1. **Verify completion:**
   ```bash
   git branch --merged | grep -E '<feature-branches>'
   ```

2. **Shut down team:**
   ```
   Use TeamDelete to remove team infrastructure
   ```

3. **Clean up worktrees:**
   ```bash
   git worktree remove .worktrees/[each-feature]
   ```

4. **Update agents-workbench:**
   ```bash
   git checkout agents-workbench
   # Update AGENTS.md marking tasks complete
   # Commit coordination updates (local only)
   ```

5. **Context hygiene:**
   ```
   /compact Focus on next task
   ```

**Critical:** Do NOT skip TeamDelete. Leaving team infrastructure running wastes resources.
```

**Step 3: Verify changes**

Run: `sed -n '232,350p' /Users/eduardoa/.claude/skills/team-coordination/SKILL.md`

Expected: See new command references with proper paths

**Step 4: Commit**

```bash
git add skills/team-coordination/SKILL.md
git commit -s -S -m "docs: update SKILL.md to reference new commands"
```

---

## Task 8: Test Command Discovery

**Files:**
- Test: Command menu shows new commands

**Step 1: Verify commands are discoverable**

The commands should now appear when typing `/` in Claude Code.

Expected commands to appear:
- `/team-plan`
- `/team-execute`
- `/team-shutdown`

**Step 2: Test command invocation**

Try invoking `/team-plan` (will fail if not on agents-workbench, which is expected behavior).

Expected: Command loads and starts planning phase

**Step 3: Document test results**

Create: `/Users/eduardoa/.claude/skills/team-coordination/TESTING.md`

```markdown
# Team Coordination Commands Testing

## Test Date: 2026-02-14

### Command Discovery
- [ ] `/team-plan` appears in command menu
- [ ] `/team-execute` appears in command menu
- [ ] `/team-shutdown` appears in command menu

### Branch Validation
- [ ] `/team-plan` validates upstream before branching
- [ ] `/team-plan` blocks if local branch outdated
- [ ] `/team-execute` re-validates before worktree creation

### QA Validation
- [ ] QA detects Go projects correctly
- [ ] QA detects TypeScript projects correctly
- [ ] QA validates git signatures (-s and -S)
- [ ] QA blocks PRs with unsigned commits
- [ ] QA runs language-specific checks

### Integration
- [ ] Commands work with agents-workbench workflow
- [ ] Worktrees created from validated sources
- [ ] Cleanup removes all worktrees and agents

## Next Steps
- Test with real project (Go)
- Test with real project (TypeScript)
- Verify QA validation catches issues
```

**Step 4: Commit test documentation**

```bash
git add skills/team-coordination/TESTING.md
git commit -s -S -m "test: add testing checklist for team commands"
```

---

## Task 9: Update README

**Files:**
- Modify: `/Users/eduardoa/.claude/skills/team-coordination/baseline-analysis.md` → Move to `docs/`
- Modify: `/Users/eduardoa/.claude/skills/team-coordination/baseline-scenarios.md` → Move to `docs/`
- Create: `/Users/eduardoa/.claude/skills/team-coordination/README.md`

**Step 1: Move baseline docs**

```bash
mkdir -p /Users/eduardoa/.claude/skills/team-coordination/docs
mv /Users/eduardoa/.claude/skills/team-coordination/baseline-*.md \
   /Users/eduardoa/.claude/skills/team-coordination/docs/
```

**Step 2: Create README**

```markdown
# Team Coordination

Structured team workflow for parallel implementation with architectural oversight and quality gates.

## Commands

- `/team-plan` - Plan team structure, branch strategy, and task assignments
- `/team-execute` - Spawn agents and execute implementation
- `/team-shutdown` - Clean shutdown of agents and worktrees

## Quick Start

1. Navigate to agents-workbench branch
2. Run `/team-plan` to plan your parallel work
3. Run `/team-execute` to spawn team and implement
4. Run `/team-shutdown` when complete

## Key Features

- **Upstream validation** - Prevents outdated branch errors
- **Language-aware QA** - Supports Go, TypeScript, Rust, Python
- **Git signature enforcement** - All commits require -s and -S
- **CI/CD pre-flight** - Validates workflows before PR creation

## Structure

```
team-coordination/
├── SKILL.md              # Core coordination logic
├── commands/             # Command entry points
│   ├── team-plan.md
│   ├── team-execute.md
│   └── team-shutdown.md
├── lib/                  # Reusable validation logic
│   ├── branch-validator.md
│   └── qa-validator.md
└── docs/                 # Design and analysis docs
```

## Documentation

- [Design Document](../../../../docs/plans/2026-02-14-team-coordination-commands-design.md)
- [Implementation Plan](../../../../docs/plans/2026-02-14-team-coordination-commands-implementation.md)
- [Testing Checklist](TESTING.md)

## Requirements

- Git worktree support
- agents-workbench branch setup
- GPG signing configured (for -S flag)

## See Also

- @skills/superpowers:brainstorming
- @skills/superpowers:writing-plans
- @skills/superpowers:executing-plans
```

**Step 3: Verify structure**

Run: `tree /Users/eduardoa/.claude/skills/team-coordination/`

Expected: See organized directory structure

**Step 4: Commit**

```bash
git add skills/team-coordination/
git commit -s -S -m "docs: organize team-coordination structure and add README"
```

---

## Task 10: Final Integration Test

**Files:**
- Test: Full workflow in real project

**Step 1: Prepare test scenario**

Create test plan for validating:
1. Command discovery works
2. Branch validation prevents errors
3. QA validation catches issues
4. Cleanup is complete

**Step 2: Document completion**

Update: `/Users/eduardoa/.claude/skills/team-coordination/TESTING.md`

Mark completed tests with [x]

**Step 3: Final commit**

```bash
git add skills/team-coordination/TESTING.md
git commit -s -S -m "test: complete team coordination commands implementation"
```

**Step 4: Verify git log**

Run: `git log --oneline -10`

Expected: See all commits with proper messages and signatures

---

## Success Criteria

✅ Three commands created and discoverable
✅ Branch validation prevents outdated branch errors
✅ QA validation supports multiple languages
✅ Git signature validation enforced
✅ Commands integrate with agents-workbench workflow
✅ Documentation complete
✅ All commits signed with -s and -S

## Testing Checklist

- [ ] `/team-plan` command works
- [ ] `/team-execute` command works
- [ ] `/team-shutdown` command works
- [ ] Branch validation catches outdated branches
- [ ] QA validates Go projects
- [ ] QA validates TypeScript projects
- [ ] QA enforces git signatures
- [ ] Cleanup removes all resources

## Notes

- Commands follow superpowers pattern (simple wrappers)
- Core logic stays in SKILL.md (DRY principle)
- Validation logic in lib/ is reusable
- Design supports future language additions
