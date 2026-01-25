# Cursor Prompts Library

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/ArangoGutierrez/promptsLibrary?style=social)](https://github.com/ArangoGutierrez/promptsLibrary/stargazers)
[![Lint](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/lint.yml/badge.svg)](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/lint.yml)
[![Validate Prompts](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/validate-prompts.yml/badge.svg)](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/validate-prompts.yml)

> Research-backed prompt templates, commands, skills, and subagents for Cursor IDE

A curated collection of AI configurations for software engineering. Built for [Cursor](https://cursor.sh/), leveraging native features like Commands, Skills, Subagents, and Hooks.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/ArangoGutierrez/promptsLibrary.git
cd promptsLibrary
```

### 2. Deploy to Your System

```bash
# Deploy globally (to ~/.cursor/)
./scripts/deploy-cursor.sh

# Or deploy to a specific project
./scripts/deploy-cursor.sh --project /path/to/your/project
```

### 3. Restart Cursor

Restart Cursor to load the new configurations.

### 4. Try It Out

Type `/` in any Cursor chat to see available commands:

- `/task` — Create a spec-first task prompt
- `/review-pr` — Rigorous PR review with confidence scoring
- `/audit-go` — Deep defensive audit for Go code
- `/research` — Research a GitHub issue
- `/plan` — Two-phase planning workflow

## What's Included

### Commands (`/command`)
Slash commands for common workflows:

| Command | Description |
|---------|-------------|
| `/task` | Generate spec-first task prompt |
| `/review-pr` | Code review with confidence scoring |
| `/audit-go` | Go/K8s production audit |
| `/research` | Deep issue research |
| `/plan` | Two-phase planning |
| `/preflight` | Codebase reconnaissance |
| `/deep-mode` | Anti-satisficing analysis |
| `/git-polish` | Rewrite commits atomically |

### Skills (Agent-Decided)
Cursor automatically invokes these based on context:

| Skill | Auto-triggers on |
|-------|------------------|
| `go-audit` | "audit", "production-ready", "race condition" |
| `pr-review` | "review PR", "code review", "check changes" |
| `spec-first` | "create task", "implement", "build feature" |
| `deep-analysis` | "think carefully", "complex problem" |

### Subagents (Isolated Execution)
Specialized agents for parallel/isolated work:

| Agent | Purpose |
|-------|---------|
| `verifier` | Skeptically validate claimed completions |
| `researcher` | Deep issue investigation |
| `auditor` | Security and reliability checks |

### Hooks (Automation)
Automatic behaviors:

| Hook | Trigger | Action |
|------|---------|--------|
| `format.sh` | After file edit | Auto-format (Go, TS, Python, Rust) |
| `security-gate.sh` | Before shell | Block dangerous commands |
| `grind.sh` | On stop | Auto-continue iteration loops |

### Rules (Always-On)
Project rules applied to every conversation:

- **Depth-forcing** — Anti-satisficing, enumerate≥3 options
- **Verification** — Factor+Revise CoVe on all claims
- **Security** — Explicit security constraints
- **Token optimization** — Efficient output for large codebases

## Deployment Options

```bash
# Default: symlink to ~/.cursor/ (updates auto-propagate)
./scripts/deploy-cursor.sh

# Copy files instead (standalone, no auto-updates)
./scripts/deploy-cursor.sh --copy

# Deploy to specific project
./scripts/deploy-cursor.sh --project /path/to/project

# Preview what would be done
./scripts/deploy-cursor.sh --dry-run

# Overwrite existing files
./scripts/deploy-cursor.sh --force

# Remove deployed configurations
./scripts/deploy-cursor.sh --uninstall
```

## Project Structure

```
cursor/                 → Cursor configurations (deploy these)
├── commands/           → Slash commands (/command)
├── skills/             → Agent skills (auto-invoked)
├── agents/             → Custom subagents
├── hooks/              → Automation scripts
├── hooks.json          → Hook configuration
└── rules/              → Project rules

scripts/
└── deploy-cursor.sh    → Deployment script

prompts/                → [DEPRECATED] Original prompts (reference only)
docs/                   → Documentation
snippets/               → Cursor rules snippets
```

## How It Works

These configurations use techniques from recent research:

- **Chain of Verification (CoVe)** — Claims verified independently before reporting
- **Multi-perspective reflection (PR-CoT)** — Considers logic, completeness, edge cases
- **Spec-first workflow** — Defines "done" before coding
- **Confidence scoring** — Only reports high-confidence findings
- **Token optimization** — Efficient output for large codebases

The result: fewer hallucinations, more thorough analysis, and outputs you can trust.

## Documentation

- [Getting Started](docs/getting-started.md) — Full setup walkthrough
- [Cursor Setup](docs/cursor-setup.md) — Configuration options
- [Prompt Catalog](docs/prompt-catalog.md) — All prompts explained

## Migrating from `prompts/`

> **Note:** The `prompts/` folder is deprecated. Use the new `cursor/` structure instead.

The original prompts have been migrated to Cursor's native format:
- `prompts/*.md` → `cursor/commands/*.md`
- Key prompts also converted to Skills for auto-invocation

The `prompts/` folder is kept for reference but will be removed in a future version.

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

When adding configurations:
- Explain what problem it solves
- Include research citations if relevant
- Test the deployment script before submitting

## Requirements

- **Cursor IDE** (latest version recommended)
- **macOS or Linux** (Windows/WSL not currently supported)
- **jq** (for hooks that parse JSON)

## License

[MIT](LICENSE) — Use freely, attribution appreciated.

---

*Built on research from META AI, Peking University, Intel Labs, Anthropic, and the prompt engineering community.*
