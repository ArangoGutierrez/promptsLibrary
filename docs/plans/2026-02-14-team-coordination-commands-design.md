# Team Coordination Commands Design

**Date:** 2026-02-14
**Status:** Approved
**Type:** Skill to Command Migration

## Problem Statement

The `team-coordination` skill references `/team:plan`, `/team:execute`, `/team:shutdown` as workflow commands, but these commands don't exist. Users only see `/team-coordination` in the command menu, creating confusion about how to use the multi-phase workflow.

## Solution

Convert the team-coordination skill into three separate commands that follow the established superpowers pattern:
- `/team-plan` - Planning and branch strategy phase
- `/team-execute` - Agent spawning and implementation phase
- `/team-shutdown` - Cleanup and context hygiene phase

All commands invoke the underlying `team-coordination` skill logic but guide users through specific phases with appropriate validation and checks.

## Design

### Command Structure

```
skills/team-coordination/
├── SKILL.md                    # Core team coordination logic (unchanged)
├── commands/
│   ├── team-plan.md           # Planning phase entry point
│   ├── team-execute.md        # Execution phase entry point
│   └── team-shutdown.md       # Cleanup phase entry point
└── lib/
    ├── branch-validator.md    # Upstream/origin validation logic
    └── qa-validator.md        # Language-aware QA validation
```

### `/team-plan` Command

**Purpose:** Plan team structure, branch strategy, and task assignments.

**Location Enforcement:** Must run on `agents-workbench` branch.

**Critical: Branch Validation Before Worktree Creation**

ALWAYS check upstream/origin status before branching:

```bash
# 1. Fetch latest from remote
git fetch origin

# 2. Check if local branch is behind remote
LOCAL=$(git rev-parse <branch>)
REMOTE=$(git rev-parse origin/<branch>)
BASE=$(git merge-base <branch> origin/<branch>)

if [ $LOCAL != $REMOTE ]; then
  if [ $LOCAL = $BASE ]; then
    echo "⚠️  Local branch is BEHIND origin by $(git rev-list --count $LOCAL..$REMOTE) commits"
    echo "Run: git pull origin <branch>"
    exit 1
  fi
fi

# 3. Show branch status
git status -sb <branch>
```

**Mandatory Branching Strategy Question:**

After validating upstream status, ask:

```
Where should each worktree branch from?

A) origin/<default-branch> (main/master/develop) - RECOMMENDED
   ✓ Always up-to-date with remote
   ✓ Clean slate for each feature
   ✓ Standard workflow
   Command: git worktree add .worktrees/<name> -b <branch> origin/<default>

B) Local <default-branch> (after confirming it's up-to-date)
   ⚠️  Only if you just pulled
   Command: git worktree add .worktrees/<name> -b <branch> <default>

C) Specific feature branch (after validating upstream)
   ⚠️  For building on in-progress work
   Requires: branch name + upstream validation

D) Current agents-workbench state
   ⚠️  Advanced: for coordinating dependent local changes
   Risky - requires careful merge management
```

**Output:**
- `.agents/plans/<project-name>.md` documenting:
  - Branch source with validation commands
  - Worktree paths
  - Task assignments
  - Wave structure (if >3 tasks)
  - Integration points
- `AGENTS.md` updated with task assignments

### `/team-execute` Command

**Purpose:** Spawn team agents and execute implementation.

**Pre-execution Validation:**
1. Verify on `agents-workbench` branch
2. Confirm plan exists (`.agents/plans/<project>.md`)
3. Validate branch source is still up-to-date

**Worktree Creation (using validated branch source):**
```bash
# From plan document
SOURCE_BRANCH="origin/main"  # or whatever was validated in planning

# Create worktrees
git worktree add .worktrees/<feature> -b <branch> $SOURCE_BRANCH
```

**Spawn Order (Enforced):**
1. **Systems Architect** (agents-workbench) - MANDATORY
2. **QA Agent** (agents-workbench) - MANDATORY
3. **Worker agents** (each in own worktree) - 1-3 workers

### QA Agent Enhanced Validation

**Language Detection:**

QA agent detects project type and runs appropriate validation:

```bash
# Detect project type
if [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
elif [ -f "package.json" ]; then
  PROJECT_TYPE="typescript" # or node
elif [ -f "Cargo.toml" ]; then
  PROJECT_TYPE="rust"
# ... etc
fi
```

**Validation Checks (Language-Specific):**

#### 1. Git Signature Validation (All Projects)
```bash
# Verify all commits in PR have both signatures
git log --show-signature origin/<base>..<feature-branch>

# Check for:
# - Signed-off-by: <name> <email>  (git commit -s)
# - GPG Signature (git commit -S)

# If missing → Report to Architect → Worker must fix with:
# git rebase --exec 'git commit --amend --no-edit -s -S' origin/<base>
```

#### 2. Language-Specific Quality Gates

**Go Projects:**
```bash
# Format check
gofmt -l . | grep . && echo "❌ Format issues" && exit 1

# Vet
go vet ./...

# Lint (if golangci-lint available)
golangci-lint run

# Tests
go test -v ./...

# Security
govulncheck ./...
gosec ./...
trivy fs .
```

**TypeScript/Node Projects:**
```bash
# Install dependencies (if needed)
npm ci || yarn install --frozen-lockfile

# Format check (if prettier available)
npx prettier --check .

# Lint (if eslint available)
npx eslint .

# Type check (TypeScript)
npx tsc --noEmit

# Tests
npm test

# Security
npm audit --audit-level=moderate
# or: yarn audit
```

**Rust Projects:**
```bash
# Format check
cargo fmt -- --check

# Lint
cargo clippy -- -D warnings

# Tests
cargo test

# Security
cargo audit
```

#### 3. CI/CD Pre-flight Checks

```bash
if [ -d ".github/workflows" ]; then
  echo "📋 GitHub Actions workflows detected"

  # Option A: Use act to run workflows locally
  if command -v act &> /dev/null; then
    act pull_request
  else
    # Option B: Parse workflow files and run test commands
    # Extract test/lint commands from workflow YAML
    # Run them manually
    echo "⚠️  Install 'act' for local workflow testing: brew install act"
  fi
fi

if [ -f ".gitlab-ci.yml" ]; then
  echo "📋 GitLab CI detected"
  # Similar detection and validation
fi

if [ -f "Jenkinsfile" ]; then
  echo "📋 Jenkins pipeline detected"
  # Similar detection and validation
fi
```

**QA Approval Gate:**

QA blocks PR creation if ANY check fails:
- Unsigned commits → Worker must rebase with signatures
- Tests fail → Worker must fix
- Security issues → Architect decides on fix or exception
- CI checks fail → Worker must fix before PR

### `/team-shutdown` Command

**Purpose:** Clean shutdown of team infrastructure and worktrees.

**Cleanup Sequence:**

1. **Verify completion status**
   ```bash
   # Check all PRs merged or explicitly abandoned
   git branch --merged | grep -E '<feature-branches>'
   ```

2. **Shutdown agents**
   ```bash
   # Use TeamDelete to terminate all spawned agents
   TeamDelete
   ```

3. **Clean worktrees**
   ```bash
   # Remove all feature worktrees
   git worktree list | grep '.worktrees/' | while read -r path _; do
     git worktree remove "$path"
   done
   ```

4. **Update coordination branch**
   ```bash
   git checkout agents-workbench
   # Update AGENTS.md marking all tasks complete
   # Commit coordination updates (local only - never push)
   git commit -m "chore: complete <project> team coordination"
   ```

5. **Context hygiene**
   ```
   /compact Focus on next task
   ```

## Integration Points

### agents-workbench Workflow
- Commands verify `agents-workbench` branch before coordination
- `AGENTS.md` is source of truth for task status
- `.agents/plans/` stores planning artifacts
- Worktrees enforce isolation (Architect/QA read-only on source)
- agents-workbench is local-only (never pushed)

### Git Workflow
- **Always** validate upstream/origin before branching
- Workers commit with `-s -S` (enforced by QA)
- PRs created from worktree feature branches
- After merge, worktree removed immediately
- Branch source explicitly documented in plan

### Language Support
- QA agent detects project type automatically
- Runs language-appropriate validation
- Extensible pattern for adding new languages
- Falls back to basic checks if language unknown

## Success Criteria

1. Users see `/team-plan`, `/team-execute`, `/team-shutdown` in command menu
2. Commands prevent outdated branch errors through upstream validation
3. QA validates git signatures on all commits
4. QA runs appropriate checks for Go, TypeScript, and other detected languages
5. CI/CD workflows validated before PR creation
6. Cleanup is complete (agents + worktrees + context)

## Implementation Notes

- Commands are simple wrappers that invoke skill with phase context
- Core logic stays in `SKILL.md` (single source of truth)
- Branch validation logic reusable across commands
- QA validation extensible for new languages
- Follow superpowers pattern: `brainstorm.md`, `execute-plan.md`, etc.

## Open Questions

None - design approved.
