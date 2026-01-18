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

### 3. Configure Cursor Rules

Copy the rules from `snippets/cursor-rules.md` to your Cursor settings:

1. Open Cursor
2. Go to **Settings** → **Rules** → **User Rules**
3. Paste the contents of `snippets/cursor-rules.md`
4. Update the `# LIB` section with your actual path:
   ```
   # LIB /path/to/promptsLibrary/prompts/
   ```

### 4. Test a Prompt

Try your first prompt:

1. Open any project in Cursor
2. In the chat, type: `@prompts/preflight.md`
3. Watch as Claude scans your repository

## Core Concepts

### Trigger Commands

Each prompt has a **trigger** - a command that tells Claude which workflow to execute:

| Command | Prompt | What It Does |
|---------|--------|--------------|
| "Run Audit" | `audit-go.md` | Deep code audit for Go/K8s |
| "Git Polish" | `git-polish.md` | Clean up git history |
| "Plan Mode" | `workflow.md` | Two-phase planning workflow |
| "Pre-Flight" | `preflight.md` | Scan repo before changes |
| "Research Issue #N" | `research-issue.md` | Deep dive on GitHub issue |
| "Review PR" | `pr_review.md` | Code review workflow |
| "Create prompt for..." | `task-prompt.md` | Generate task prompt |

### Using @-mentions

In Cursor, reference prompts using `@` syntax:

```
@prompts/audit-go.md Run Audit on the auth package
```

This loads the prompt file and applies it to your request.

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
- Check out the research basis in `prompts/PROMPT_RESEARCH_360.md`

## Troubleshooting

### Prompts Not Loading

Make sure:
- The path in your Cursor rules matches your actual installation
- You're using the `@` syntax correctly: `@prompts/filename.md`

### Claude Ignoring Instructions

Try:
- Loading the prompt explicitly: paste the content directly
- Using the "Deep Mode" master agent for complex tasks

### Path Issues

If you see path errors:
- Use relative paths in prompts: `./prompts/` instead of `~/src/dev/prompts/`
- Set `PROMPTS_LIB` environment variable for scripts
