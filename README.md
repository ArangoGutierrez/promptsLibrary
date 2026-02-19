# AI Engineering Dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lint](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/lint.yml/badge.svg)](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/lint.yml)
[![Validate Config](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/validate-cursor.yml/badge.svg)](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/validate-cursor.yml)

Personal dotfiles for **Claude Code** and **Cursor IDE**. Opinionated engineering setup with TDD enforcement, signed commits, agent-driven workflows, and worktree-based development.

## Quick Start

```bash
git clone https://github.com/ArangoGutierrez/promptsLibrary.git
cd promptsLibrary
./scripts/deploy.sh
```

That's it. The deploy script rsyncs `.claude/` and `.cursor/` to your home directory with automatic backup.

## What's Included

### Claude Code (`.claude/`)

| Component | Count | Purpose |
|-----------|-------|---------|
| **CLAUDE.md** | 1 | Engineering standards (TDD, worktrees, iteration budgets) |
| **settings.json** | 1 | Permissions, plugin config, environment variables |
| **Hooks** | 6 | inject-date, sign-commits, prevent-push-workbench, enforce-worktree, validate-year, tdd-guard |
| **Policies** | 2 | remote-settings.json, policy-limits.json |
| **.claudeignore** | 1 | Context exclusions for large/irrelevant files |

### Cursor IDE (`.cursor/`)

| Component | Count | Purpose |
|-----------|-------|---------|
| **Agents** | 12 | researcher, auditor, arch-explorer, task-analyzer, perf-critic, api-reviewer, devil-advocate, prototyper, synthesizer, verifier, review-triager, ci-doctor |
| **Rules** | 5 | core, tdd, workbench, go, k8s (.mdc format) |
| **Hooks** | 5 | format, sign-commits, security-gate, task-loop, context-monitor |
| **Commands** | 17 | /architect, /audit, /code, /research, /review-pr, /test, and more |
| **Skills** | 5 | Cursor-native config skills (create-rule, create-skill, etc.) |
| **Schemas** | 3 | JSON schemas for hooks and state validation |

### Key Behaviors Enforced

- **TDD Guard**: Blocks implementation files without corresponding test files
- **Signed Commits**: All commits require `-s -S` (DCO + GPG)
- **Worktree Isolation**: Source code is read-only on `agents-workbench`; implementation happens in `.worktrees/`
- **Year Validation**: New files must use current year in copyright headers
- **Security Gate**: Blocks dangerous commands (`rm -rf /`, force-push to main)

## Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/deploy.sh` | Deploy configs to `~/` (rsync with backup) |
| `./scripts/capture.sh` | Capture live changes back into repo |
| `./scripts/diff.sh` | Show drift between repo and live environment |

### Deploy Options

```bash
./scripts/deploy.sh              # Full deploy with backup
./scripts/deploy.sh --dry-run    # Preview without changes
./scripts/deploy.sh --force      # Skip backup
./scripts/deploy.sh --claude-only # Deploy only Claude Code config
./scripts/deploy.sh --cursor-only # Deploy only Cursor config
./scripts/deploy.sh --delete     # Remove files not in repo (careful!)
```

## Workflow

```
Edit live environment → capture.sh → review diff → commit → push
```

When you tweak configs in `~/.claude/` or `~/.cursor/`, run `capture.sh` to sync changes back to the repo. Review with `git diff`, commit, push.

## Customization

1. **Fork** this repo
2. **Edit** configs in `.claude/` and `.cursor/` directly
3. **Deploy** with `./scripts/deploy.sh`
4. Or edit live, then `./scripts/capture.sh` to pull changes back

## Project Structure

```
.claude/              → Claude Code config (mirrors ~/.claude/)
  ├── CLAUDE.md       → Engineering standards
  ├── settings.json   → Permissions and hooks config
  ├── hooks/          → 6 lifecycle hooks
  └── plugins/        → Plugin manifest

.cursor/              → Cursor IDE config (mirrors ~/.cursor/)
  ├── agents/         → 12 custom subagents
  ├── rules/          → 5 project rules (.mdc)
  ├── hooks/          → 5 automation hooks
  ├── commands/       → 17 slash commands
  ├── skills-cursor/  → 5 config skills
  └── schemas/        → 3 JSON schemas

scripts/              → Deploy, capture, diff utilities
docs/plans/           → Design documents
```

## Requirements

- **macOS or Linux** (Windows/WSL untested)
- **jq** (for hooks that parse JSON)
- **GPG** (for signed commits)
- **rsync** (for deploy/capture scripts)

## License

[MIT](LICENSE)
