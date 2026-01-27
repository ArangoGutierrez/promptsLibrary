# Code Review Instructions for Claude Code

This document outlines a systematic 8-step process for reviewing pull requests using Claude agents with varying capabilities.

## Process Overview

**Step 1: Eligibility Screening** - A Haiku agent determines if the PR qualifies for review by checking if it's closed, drafted, trivial, or already reviewed.

**Step 2: Documentation Discovery** - Another Haiku agent locates relevant CLAUDE.md files from the repository root and affected directories.

**Step 3: Change Summary** - A Haiku agent reviews the PR and provides a summary of modifications.

**Step 4: Parallel Code Review** - Five independent Sonnet agents conduct specialized reviews:
- Agent 1 audits CLAUDE.md compliance
- Agent 2 scans for obvious bugs in changed code
- Agent 3 examines git history for contextual issues
- Agent 4 reviews previous PR comments on modified files
- Agent 5 validates changes against inline code comments

**Step 5: Confidence Scoring** - Parallel Haiku agents score each flagged issue on a 0-100 scale based on evidence and relevance.

**Step 6: Filtering** - Issues scoring below 80 are discarded.

**Step 7: Re-verification** - Final eligibility confirmation before commenting.

**Step 8: Report Submission** - Results posted via GitHub using precise formatting with full commit SHA references.

## Key Guidelines

- Exclude false positives, pre-existing issues, linter/compiler concerns, and unmodified lines
- Avoid emojis and brevity in comments
- Require full git SHAs and proper line range citations
- Link to specific code locations with context