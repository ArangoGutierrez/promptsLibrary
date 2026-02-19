# Environment Replication — Design Document

**Date:** 2026-02-19
**Status:** Approved
**Branch:** refactor/flatten-claude-structure

## Problem

The promptsLibrary repo has drifted from the live environment (`~/.claude`, `~/.cursor`). The live environment is the gold standard. The repo needs to become a mirror of the live config so anyone can `clone + deploy` and replicate the exact setup.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Audience | Personal dotfiles | Opinionated, fork-friendly. No over-abstraction |
| Source of truth | Live environment wins | ~/.claude and ~/.cursor are canonical |
| Repo structure | Bare mirror | .claude/ and .cursor/ at repo root mirror ~/ exactly |
| Scope | Config only | No runtime data (teams, tasks, debug, sessions, caches) |

## Repo Structure

```
promptsLibrary/
├── .claude/                      # ~/.claude mirror (config only)
│   ├── CLAUDE.md                 # Engineering standards
│   ├── settings.json             # Permissions, hooks, plugins, env
│   ├── remote-settings.json      # Remote/sandbox restrictions
│   ├── policy-limits.json        # Policy restrictions
│   ├── .claudeignore             # Context exclusions
│   ├── hooks/                    # 6 hook scripts
│   │   ├── inject-date.sh
│   │   ├── sign-commits.sh
│   │   ├── prevent-push-workbench.sh
│   │   ├── enforce-worktree.sh
│   │   ├── validate-year.sh
│   │   └── tdd-guard.sh
│   └── plugins/
│       └── installed_plugins.json
│
├── .cursor/                      # ~/.cursor mirror (config only)
│   ├── agents/                   # 12 custom agents
│   ├── rules/                    # 5 .mdc rules (core, tdd, workbench, go, k8s)
│   ├── hooks/                    # 5 hook scripts
│   ├── hooks.json                # Hook configuration
│   ├── commands/                 # 17 commands (real files, not symlinks)
│   ├── skills-cursor/            # 5 Cursor-native skills
│   ├── mcp.json                  # MCP server config
│   └── .gitignore                # Selective tracking
│
├── scripts/
│   ├── deploy.sh                 # Unified deploy: rsync .claude/ and .cursor/ to ~/
│   ├── diff.sh                   # Show differences between repo and live env
│   └── capture.sh                # Capture live env changes back into repo
│
├── .github/
│   └── workflows/                # CI: lint, links, validation (paths updated)
│
├── docs/                         # Documentation & plans
├── .gitignore                    # Exclude runtime dirs
├── README.md                     # Quick start + customization guide
├── LICENSE
├── CONTRIBUTING.md
└── CODE_OF_CONDUCT.md
```

## What Gets Removed

- `claude/` directory → replaced by `.claude/`
- `cursor/` directory → replaced by `.cursor/`
- `cursor/_optimized/` and `cursor/_lazy/` → unnecessary for personal dotfiles
- `prompts/` → deprecated
- Old deploy scripts → replaced by unified `scripts/deploy.sh`
- `snippets/`, `configs/` → folded into mirror structure

## Scripts

### deploy.sh

1. Backup existing `~/.claude` and `~/.cursor` configs (timestamped tarball in `~/.config/dotfiles-backup/`)
2. Rsync `.claude/` → `~/.claude/` and `.cursor/` → `~/.cursor/`
   - Excludes runtime dirs (teams/, tasks/, debug/, projects/, sessions, caches)
   - Optional `--delete` flag to remove files in target not in repo
3. Install plugins from `installed_plugins.json`
4. Optionally install Cursor extensions
5. Verify hooks are executable, settings are valid JSON

**Flags:** `--dry-run`, `--force`, `--claude-only`, `--cursor-only`, `--no-plugins`

### capture.sh

- Copies config files from `~/` back to repo
- Excludes runtime data
- Shows `git diff` for review before committing

### diff.sh

- Runs `diff -r` between repo and live, excluding runtime dirs
- Color-coded output

## .gitignore Strategy

Excludes all runtime/transient data:

```gitignore
# Claude Code runtime
.claude/debug/
.claude/projects/
.claude/teams/
.claude/tasks/
.claude/todos/
.claude/cache/
.claude/file-history/
.claude/session-env/
.claude/shell-snapshots/
.claude/paste-cache/
.claude/telemetry/
.claude/backups/
.claude/ide/
.claude/plans/
.claude/history.jsonl
.claude/stats-cache.json
.claude/plugins/cache/
.claude/plugins/known_marketplaces.json

# Cursor runtime
.cursor/extensions/
.cursor/projects/
.cursor/ai-tracking/
.cursor/snapshots/
.cursor/ide_state.json
.cursor/argv.json
.cursor/unified_repo_list.json
.cursor/worktrees/
```

## CI Updates

- `validate-cursor.yml` → update paths from `cursor/` to `.cursor/`
- `validate-prompts.yml` → remove or update for new structure
- Lint and link checks → update file paths

## Migration Steps

1. Create new branch from `refactor/flatten-claude-structure`
2. Remove old directories (`claude/`, `cursor/`, `prompts/`, `snippets/`, `configs/`)
3. Run `capture.sh` equivalent to copy live env configs into `.claude/` and `.cursor/`
4. Write `scripts/deploy.sh`, `scripts/diff.sh`, `scripts/capture.sh`
5. Update `.gitignore` with runtime exclusions
6. Update `README.md` with new quick-start instructions
7. Update `.github/workflows/` for new paths
8. Test deploy on a clean directory
9. PR to main
