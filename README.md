# Prompts Library

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/ArangoGutierrez/promptsLibrary?style=social)](https://github.com/ArangoGutierrez/promptsLibrary/stargazers)
[![Lint](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/lint.yml/badge.svg)](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/lint.yml)
[![Validate Prompts](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/validate-prompts.yml/badge.svg)](https://github.com/ArangoGutierrez/promptsLibrary/actions/workflows/validate-prompts.yml)

> Research-backed prompt templates for Cursor IDE and Claude

A curated collection of AI prompt templates for software engineering. Built for [Cursor](https://cursor.sh/) and Claude, grounded in prompt engineering research.

## What's This?

This library contains battle-tested prompts that help you:

- **Review code** with systematic checklists
- **Research issues** before diving into implementation
- **Plan changes** with verification steps
- **Clean up git history** into atomic commits
- **Generate task prompts** from requirements

Each prompt is designed to make Claude think deeper, verify its work, and produce reliable outputs.

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/ArangoGutierrez/promptsLibrary.git
```

### 2. Set Up Cursor

Copy the rules from `snippets/cursor-rules.md` into your Cursor settings:

1. Open Cursor
2. Go to **Settings** → **Rules** → **User Rules**
3. Paste the contents
4. Update the path to point to your local clone

### 3. Try It Out

In any Cursor chat, type:

```
@prompts/preflight.md
```

This scans your current project and reports what it finds.

## Available Prompts

| What You Want | Command | Prompt |
|---------------|---------|--------|
| Deep code audit | "Run Audit" | `audit-go.md` |
| Review a pull request | "Review PR #123" | `pr_review.md` |
| Research a GitHub issue | "Research Issue #456" | `research-issue.md` |
| Plan before coding | "Plan Mode" | `workflow.md` |
| Clean up git commits | "Git Polish" | `git-polish.md` |
| Scan a new codebase | "Pre-Flight" | `preflight.md` |
| Create a task prompt | "Create prompt for..." | `task-prompt.md` |
| Complex analysis | "Deep Mode" | `master-agent.md` |

See [docs/prompt-catalog.md](docs/prompt-catalog.md) for the complete list.

## How It Works

These prompts use techniques from recent research:

- **Chain of Verification** — Claude checks its own work before reporting
- **Multi-perspective reflection** — Considers logic, completeness, edge cases
- **Spec-first workflow** — Defines what "done" looks like before coding
- **Token optimization** — Efficient output for large codebases

The result: fewer hallucinations, more thorough analysis, and outputs you can trust.

## Project Structure

```
prompts/           → The prompt templates
docs/              → Setup guides and reference
snippets/          → Cursor configuration to copy-paste
configs/           → Tool configs (linter, etc.)
scripts/           → Automation helpers
```

## Documentation

- [Getting Started](docs/getting-started.md) — Full setup walkthrough
- [Cursor Setup](docs/cursor-setup.md) — Detailed configuration options
- [Prompt Catalog](docs/prompt-catalog.md) — Every prompt explained

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

If you're adding or improving prompts:
- Explain what problem it solves
- Include research citations if relevant
- Test before submitting

## License

[MIT](LICENSE) — Use freely, attribution appreciated.

---

*Built on research from META AI, Peking University, Intel Labs, and the prompt engineering community.*
