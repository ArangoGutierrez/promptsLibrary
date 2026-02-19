# agents-workbench Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up the agents-workbench branch as a local-only coordination hub with AGENTS.md, .agents/plans/, and .worktrees/ gitignore entry.

**Architecture:** A single local-only git branch (`agents-workbench`) serves as the read-only coordination hub. All future implementation happens in isolated worktrees under `.worktrees/`, each branched from the remote default branch.

**Tech Stack:** Git (worktrees), Markdown

**Design doc:** `docs/plans/2026-02-19-agents-workbench-migration-design.md`

---

### Task 1: Create the agents-workbench branch

**Step 1: Fetch origin**

```bash
git fetch origin
```

Expected: refs updated, no errors.

**Step 2: Create the branch from origin/main**

```bash
git checkout -b agents-workbench origin/main
```

Expected: `Switched to a new branch 'agents-workbench'`. Branch tracks origin/main content.

**Step 3: Verify**

```bash
git branch --show-current
```

Expected: `agents-workbench`

---

### Task 2: Update .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: Add .worktrees/ entry**

Append after the `.prototypes/` section at the end of `.gitignore`:

```
# Worktrees (agents-workbench workflow)
.worktrees/
```

**Step 2: Verify**

```bash
grep -q '.worktrees/' .gitignore && echo "OK"
```

Expected: `OK`

---

### Task 3: Create .agents/plans/ directory

**Files:**
- Create: `.agents/plans/.gitkeep`

**Step 1: Create directory with .gitkeep**

```bash
mkdir -p .agents/plans
touch .agents/plans/.gitkeep
```

**Step 2: Verify**

```bash
ls -la .agents/plans/.gitkeep
```

Expected: file exists.

---

### Task 4: Create AGENTS.md

**Files:**
- Create: `AGENTS.md`

**Step 1: Write AGENTS.md**

Create `AGENTS.md` with the following content:

```markdown
# Agents Workbench — promptsLibrary

## Project Overview

**Repo:** ArangoGutierrez/promptsLibrary
**Purpose:** Curated collection of AI prompts, agents, commands, skills, hooks, and rules for Cursor IDE and Claude Code.
**Remote:** origin (git@github.com:ArangoGutierrez/promptsLibrary.git)
**Default branch:** main

### Repository Structure

```
cursor/              Cursor IDE configurations (primary)
├── commands/        Slash commands (/command)
├── skills/          Agent skills (auto-invoked)
├── agents/          Custom subagents
├── hooks/           Automation scripts + hooks.json
├── rules/           Project rules
├── workflows/       Workflow guides
├── _optimized/      Token-optimized variants (~60% smaller)
└── _lazy/           Lazy-loading variants (~95% smaller)

claude/              Claude Code configurations
├── agents/          Claude Code agents
├── skills/          Claude Code skills
├── hooks/           Claude Code hooks
├── rules/           Claude Code rules
├── docs/            Claude-specific documentation
└── output-styles/   Output format templates

prompts/             [DEPRECATED] Original prompts (reference only)
scripts/             Deployment and utility scripts
configs/             Shared config files (.golangci.yml)
docs/                Documentation and plans
snippets/            Cursor rules snippets
```

### Key Files

| File | Purpose |
|------|---------|
| `scripts/deploy-cursor.sh` | Deploy Cursor configs (symlink/copy/optimized/lazy) |
| `scripts/deploy-claude.sh` | Deploy Claude Code configs |
| `claude/CLAUDE.md` | Claude Code project context |
| `.github/workflows/` | CI: lint, link check, prompt validation |

## Active Branches

| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Default branch | stable |
| `refactor/flatten-claude-structure` | Flatten Claude directory layout | in-progress |

## Current Task

_None — workbench just initialized._

## Next Tasks

- [ ] Merge `refactor/flatten-claude-structure` via PR
- [ ] Evaluate consolidating cursor/ and claude/ directories

## Conventions

### Branch Naming

- Features: `feat/<short-name>`
- Fixes: `fix/<short-name>`
- Refactors: `refactor/<short-name>`
- Docs: `docs/<short-name>`

### Worktree Naming

Worktree directory name matches the branch suffix:
- Branch `feat/new-skill` → `.worktrees/new-skill`
- Branch `fix/deploy-bug` → `.worktrees/deploy-bug`

### Creating a Worktree

```bash
git fetch origin
git worktree add .worktrees/<name> -b <branch> origin/main
```

### Removing a Worktree

```bash
git worktree remove .worktrees/<name>
```

### Rules

1. **agents-workbench is local-only** — NEVER push this branch
2. **Source code is READ-ONLY** on agents-workbench — all edits happen in worktrees
3. **AGENTS.md is the exception** — it is updated on agents-workbench to track coordination state
4. **Plans go in .agents/plans/** — one file per task/feature
```

**Step 2: Verify**

```bash
head -3 AGENTS.md
```

Expected: Shows the header lines.

---

### Task 5: Commit all scaffolding

**Step 1: Stage all new/modified files**

```bash
git add .gitignore .agents/plans/.gitkeep AGENTS.md
```

**Step 2: Commit**

```bash
git commit -m "chore: initialize agents-workbench coordination hub

Add scaffolding for the agents-workbench workflow:
- AGENTS.md with project context and conventions
- .agents/plans/ for plan documents
- .gitignore entry for .worktrees/"
```

**Step 3: Verify**

```bash
git log --oneline -1
```

Expected: Shows the commit message.

```bash
git branch -vv | grep agents-workbench
```

Expected: Shows the branch with NO remote tracking (local-only).

---

### Task 6: Return to previous branch

**Step 1: Switch back**

```bash
git checkout refactor/flatten-claude-structure
```

Expected: `Switched to branch 'refactor/flatten-claude-structure'`

**Step 2: Final verification**

```bash
git branch -a | grep agents-workbench
```

Expected: Shows `agents-workbench` as a local branch only (no `remotes/origin/agents-workbench`).
