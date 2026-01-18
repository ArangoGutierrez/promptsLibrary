# promptsLibrary

A research-backed collection of AI prompt templates for software engineering workflows. Designed for use with [Cursor IDE](https://cursor.sh/) and Claude.

## Features

- **Research-Backed**: Every pattern cites academic papers (CoVe, Self-Planning, PR-CoT, PASR)
- **Verification Built-In**: Factor+Revise Chain of Verification reduces hallucinations
- **Token-Optimized**: Compressed variants and efficient output formats for large codebases
- **Production-Ready**: Prompts for audits, PR reviews, issue research, and task generation

## Quick Start

```bash
# Clone the repository
git clone https://github.com/ArangoGutierrez/promptsLibrary.git
cd promptsLibrary

# Optional: Set environment variable
export PROMPTS_LIB="$(pwd)"
```

### Configure Cursor

1. Open Cursor → Settings → Rules → User Rules
2. Copy contents from `snippets/cursor-rules.md`
3. Update the `# LIB` path to your installation

### Try Your First Prompt

In Cursor chat:
```
@prompts/preflight.md
```

This scans your current repository and reports its state.

## Prompts Overview

| Trigger | Prompt | Purpose |
|---------|--------|---------|
| "Run Audit" | `audit-go.md` | Deep Go/K8s code audit |
| "Git Polish" | `git-polish.md` | Clean up git history |
| "Plan Mode" | `workflow.md` | Two-phase planning |
| "Pre-Flight" | `preflight.md` | Scan repo state |
| "Research Issue #N" | `research-issue.md` | Deep issue analysis |
| "Review PR" | `pr_review.md` | Code review |
| "Create prompt for..." | `task-prompt.md` | Generate task prompt |
| "Deep Mode" | `master-agent.md` | Complex analysis |

See [docs/prompt-catalog.md](docs/prompt-catalog.md) for the complete reference.

## Repository Structure

```
promptsLibrary/
├── prompts/                 # Core prompt templates
│   ├── audit-go.md          # Go/K8s code audit
│   ├── audit-to-prompt.md   # Convert audits to tasks
│   ├── git-polish.md        # Git history cleanup
│   ├── issue-to-prompt.md   # Issue → task prompt
│   ├── master-agent.md      # Depth-forcing agent
│   ├── meta-enhance.md      # Self-improvement loop
│   ├── pr_review.md         # PR code review
│   ├── preflight.md         # Repository scan
│   ├── research-issue.md    # Issue deep-dive
│   ├── task-prompt.md       # Task prompt generator
│   ├── workflow.md          # Two-phase planning
│   ├── _compressed/         # Token-optimized variants
│   └── _kickoff/            # Quick-start guides
├── snippets/                # Copy-paste configs
│   ├── cursor-rules.md      # Cursor User Rules
│   └── cursor-rules-depth.md# Rules explanation
├── configs/                 # Tool configurations
│   └── .golangci.yml        # Go linter config
├── scripts/                 # Automation
│   └── init-project.sh      # Project bootstrap
├── docs/                    # Documentation
│   ├── getting-started.md   # Setup guide
│   ├── cursor-setup.md      # Cursor configuration
│   └── prompt-catalog.md    # Complete reference
└── research/                # Research & evolution
    ├── EVOLUTION_LOG.md     # Change tracking
    └── PROMPT_RESEARCH_360.md # Research basis
```

## Research Basis

These prompts incorporate findings from:

| Technique | Source | Improvement |
|-----------|--------|-------------|
| Factor+Revise CoVe | META 2023 | +27% precision |
| Self-Planning | PKU 2024 | +25% code correctness |
| PR-CoT Reflection | 2026 | +15-20% reasoning |
| PASR Iteration | 2025 | -41% tokens, +8% accuracy |
| Security Prefixes | 2025 | -56% vulnerabilities |

See [PROMPT_RESEARCH_360.md](prompts/PROMPT_RESEARCH_360.md) for the complete research review.

## Documentation

- [Getting Started](docs/getting-started.md) — Installation and first steps
- [Cursor Setup](docs/cursor-setup.md) — Detailed configuration guide
- [Prompt Catalog](docs/prompt-catalog.md) — Complete prompt reference

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Key points:
- Cite research when proposing changes
- Follow the existing prompt structure
- Test prompts before submitting

## License

[MIT](LICENSE)

## Acknowledgments

Built on research from META AI, PKU, Intel Labs, and the broader prompt engineering community.
