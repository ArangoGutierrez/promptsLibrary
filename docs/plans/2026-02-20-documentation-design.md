# Documentation Design

**Date:** 2026-02-20
**Status:** Approved
**Approach:** Option A — Flat `/docs` with topic files

## Context

The repo is a bare-mirror dotfiles layout for Claude Code and Cursor IDE. It contains 6 Claude hooks, 12 Cursor agents, 17 commands, 5 rules, 3 deployment scripts, and the agents-workbench architecture. The existing README is 115 lines and covers basics but lacks depth on architecture, individual components, and onboarding.

## Audience

Broader developer community — people who may be new to Claude Code or Cursor and want to understand or adopt this workflow.

## Decisions

- **Format:** GitHub-rendered Markdown with Mermaid diagrams, no build step
- **Structure:** Flat `/docs` directory with one file per topic
- **Coverage:** Equal treatment of Claude Code and Cursor
- **Existing docs:** `docs/plans/` preserved as-is (internal planning artifacts)

## File Structure

```
README.md                        # Rewritten: overview + value prop + links to /docs
docs/
├── README.md                    # Docs index with brief descriptions + links
├── getting-started.md           # Extended quickstart for newcomers
├── architecture.md              # agents-workbench deep-dive (Mermaid diagrams, full feature cycle)
├── claude-code.md               # Hooks, settings, plugins, policy — all Claude Code config
├── cursor.md                    # Agents, commands, rules, hooks — all Cursor config
├── deployment.md                # deploy.sh / capture.sh / diff.sh explained with examples
├── skills-and-commands.md       # Complete reference of all slash commands and skills
└── plans/                       # (preserved, unchanged)
```

## Document Specifications

### Root `README.md` (~150-200 lines)

- Overview and value proposition
- "What This Gives You" — before/after of deploying this config
- Single Mermaid diagram: repo → deploy → ~/.claude/ + ~/.cursor/
- Links to each doc with one-liner descriptions
- Requirements, license, contributing at bottom

### `docs/architecture.md` (~400-600 lines)

Centerpiece doc. Explains agents-workbench from first principles.

1. **The Problem** — Why vanilla workflows break down
2. **Core Concepts** — agents-workbench branch, worktrees, hook enforcement
3. **Architecture Diagram** — Mermaid showing repo structure, branches, worktrees
4. **Lifecycle of a Feature** — Full walkthrough with actual commands (plan → worktree → TDD → push → cleanup)
5. **Hook Enforcement Matrix** — Table of all hooks: trigger, enforces, blocks
6. **Design Decisions & Rationale** — Why each architectural choice was made

### `docs/claude-code.md` (~300-400 lines)

Reference guide to everything in `.claude/`:

1. Overview
2. CLAUDE.md — system prompt breakdown
3. Settings — permissions model, sandbox, network
4. Hooks — each of 6 hooks with examples
5. Plugins — 4 installed plugins
6. Policy & Ignore — policy-limits, .claudeignore, remote-settings

### `docs/cursor.md` (~400-500 lines)

Reference guide to everything in `.cursor/`:

1. Overview
2. Agents (12) — name, purpose, constraints
3. Commands (17) — name, usage, agent orchestration
4. Rules (5) — what each enforces
5. Hooks (5) — trigger, purpose, behavior
6. Schemas — brief mention

### `docs/getting-started.md` (~200-300 lines)

Extended quickstart:

1. Prerequisites (macOS/Linux, Git, jq, GPG, rsync)
2. Install (clone + deploy.sh)
3. Verify (check hooks, test signed commit, trigger TDD guard)
4. First Workflow (mini walkthrough: worktree → test → implement → commit → push)
5. Customization (disable/modify hooks, change settings, add agents)
6. Troubleshooting (common issues)

### `docs/deployment.md` (~200-250 lines)

All three scripts:

1. Overview — deploy/capture/diff triad
2. deploy.sh — flags, backup behavior, exclude lists
3. capture.sh — reverse flow, symlink resolution
4. diff.sh — drift detection, output format, exit codes
5. Exclude Lists — full table with rationale

### `docs/skills-and-commands.md` (~200-300 lines)

Complete reference:

1. Claude Code Skills (superpowers plugin)
2. Cursor Slash Commands (17)
3. Cursor Skills (5 config-specific)
4. How They Relate — mapping between ecosystems

## Total Estimated Scope

- 7 new/rewritten files
- ~1700-2850 lines of documentation
- Mermaid diagrams in architecture.md and README.md
