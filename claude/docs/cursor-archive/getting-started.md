# Getting Started

This guide will help you set up and start using the prompts library with Cursor and Claude.

## Prerequisites

- [Cursor IDE](https://cursor.sh/) installed
- Claude access (via Cursor's built-in AI or API)
- Git (for version control workflows)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/ArangoGutierrez/promptsLibrary.git
cd promptsLibrary
```

### 2. Set Up Environment (Optional)

For convenience, set an environment variable pointing to your library:

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export PROMPTS_LIB="/path/to/promptsLibrary"
```

### 3. Deploy to Your System

```bash
# Deploy globally (to ~/.cursor/)
./scripts/deploy-cursor.sh

# Or deploy to a specific project
./scripts/deploy-cursor.sh --project /path/to/your/project
```

The deployment script will:

- Install commands, skills, agents, hooks, and rules
- Set up automation (auto-format, security gates, task loops)

### 4. Test a Command

Try your first command:

1. Open any project in Cursor
2. In the chat, type: `/research #123` (replace with a real issue number)
3. Or try `/task describe what you want to build`

## Core Concepts

### Trigger Commands

Each command has a **trigger** - a slash command that tells Claude which workflow to execute:

| Command | What It Does |
|---------|--------------|
| `/audit` | Deep code audit for Go/K8s |
| `/git-polish` | Clean up git history |
| `/architect` | Architecture exploration with prototyping |
| `/research #{N}` | Deep dive on GitHub issue |
| `/review-pr` | Code review workflow |
| `/task {desc}` | Generate spec-first task |

### Using Slash Commands

In Cursor, use slash commands to trigger workflows:

```text
/audit Run Audit on the auth package
```

This loads the command and applies it to your request.

### Verification Pattern

Most prompts include a **Factor+Revise CoVe** verification step. This means:

1. Claude generates findings
2. Creates verification questions for each finding
3. Answers questions **independently** (without looking at original findings)
4. Only reports verified findings

This reduces hallucinations and false positives.

## Next Steps

- Read [Cursor Setup](cursor-setup.md) for detailed configuration
- Browse the [Prompt Catalog](prompt-catalog.md) to see all available prompts
- Check out the [Workflow Guide](workflow-guide.md) for best practices

## Troubleshooting

### Commands Not Loading

Make sure:

- You've run the deployment script (`./scripts/deploy-cursor.sh`)
- You're using the `/command` syntax correctly: `/audit`, `/research`, etc.

### Claude Ignoring Instructions

Try:

- Using the `/architect` command for complex tasks
- Checking that commands are properly installed via the deployment script

### Path Issues

If you see path errors:

- Use relative paths in prompts: `./prompts/` instead of `~/src/dev/prompts/`
- Set `PROMPTS_LIB` environment variable for scripts
