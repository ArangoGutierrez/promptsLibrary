# Design: Migrate to agents-workbench Architecture

**Date:** 2026-02-19
**Status:** Approved
**Scope:** Full workflow setup (scaffold only)

## Context

This repo (`ArangoGutierrez/promptsLibrary`) is a prompts/agents/configs library
for Cursor IDE and Claude Code. It currently has no agents-workbench infrastructure.
The goal is to adopt the agents-workbench workflow so all future development uses
isolated worktrees branched from the remote default branch.

## Decision

**Option 1: Single-commit scaffold** was selected over:

- Option 2 (scaffold + deploy script update) — deferred as separate concern
- Option 3 (full migration + demo) — too much scope for initial setup

## What We're Creating

On a new `agents-workbench` branch (from `origin/main`, **never pushed**):

1. **`AGENTS.md`** — Coordination hub with project context, active branches,
   current/next task sections, and conventions
2. **`.agents/plans/`** — Directory for plan documents
3. **`.gitignore` update** — Add `.worktrees/` entry
4. No other changes to existing content

## Workflow After Migration

```
agents-workbench (local only, READ-ONLY source)
+-- AGENTS.md
+-- .agents/plans/
+-- .worktrees/        (gitignored)
    +-- <feature>/     (each branched from origin/main)
```

Future work pattern:

1. Update AGENTS.md on agents-workbench with the task
2. `git worktree add .worktrees/<name> -b <branch> origin/main`
3. Implement in the worktree
4. Push, PR, merge
5. `git worktree remove .worktrees/<name>`

## Implementation Steps

1. Fetch origin to ensure up-to-date refs
2. Create `agents-workbench` branch from `origin/main`
3. Add `.worktrees/` to `.gitignore`
4. Create `.agents/plans/.gitkeep`
5. Create `AGENTS.md` with rich project context
6. Commit all scaffolding in one atomic commit
7. Verify branch is local-only (no push)
