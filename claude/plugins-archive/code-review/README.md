# Code Review Plugin Documentation

The Code Review Plugin is an automated system for pull request auditing using multiple specialized agents with confidence-based filtering.

## Core Functionality

The plugin operates through the `/code-review` command, which:

1. **Pre-checks** skip closed, draft, trivial, or previously-reviewed PRs
2. **Gathers guidelines** from CLAUDE.md files in the repository
3. **Summarizes changes** in the pull request
4. **Launches parallel agents**:
   - Two agents audit CLAUDE.md compliance
   - One scans for bugs in modifications
   - One analyzes git history for context-based issues
5. **Scores issues** from 0-100 confidence
6. **Filters results** keeping only scores ≥80
7. **Posts findings** as a review comment

## Key Features

- **Confidence-based filtering** reduces false positives
- **Independent agent review** provides comprehensive coverage
- **Guideline verification** explicitly checks CLAUDE.md requirements
- **Change-focused bug detection** ignores pre-existing issues
- **Historical context analysis** via git blame
- **Automatic PR filtering** eliminates unnecessary reviews
- **Direct code links** using full SHA and line ranges

## Requirements

- Git repository with GitHub integration
- Installed and authenticated GitHub CLI
- Optional: CLAUDE.md files for guideline checking

## Confidence Scoring Scale

Scores range from 0 (not confident/false positive) to 100 (absolutely certain). The default 80-point threshold "ensures only high-quality, actionable feedback is posted."