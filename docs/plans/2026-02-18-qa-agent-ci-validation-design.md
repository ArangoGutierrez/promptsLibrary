# QA Agent CI Validation Fix

**Date:** 2026-02-18
**Status:** Approved
**Problem:** QA agent passes PRs that fail GitHub Actions CI

## Root Cause

The QA agent runs generic language checks from `qa-validator.md` but does not:
1. Read the project's actual CI workflow files to replicate what CI runs
2. Verify PR metadata (milestone, labels) required by AGENTS.md
3. Wait for GitHub Actions to pass after push before declaring PASS

## Solution: Approach 1 — Enrich QA spawn instructions + update qa-validator

### Changes

#### File 1: `~/.claude/team/lib/qa-validator.md`

Add 3 new sections:

- **Section 7: CI Pipeline Replication** — Read `.github/workflows/`, extract commands, run them locally in the worktree
- **Section 8: PR Metadata Validation** — Check AGENTS.md for PR requirements, verify via `gh pr view`
- **Section 9: Post-Push CI Verification** — Run `gh pr checks --watch`, read failure logs, report actionable fixes
- **Update Approval Gate** — Add CI replication and remote CI pass as required conditions

#### File 2: `~/.claude/commands/team-execute.md`

- Expand QA spawn instructions (lines 62-63) with explicit validation protocol
- Expand step 9 (line 72) with detailed QA validation sequence

### Languages Covered

All existing languages (Go, TypeScript/Node, Rust, Python) plus the new CI-replication logic which is language-agnostic (reads whatever CI runs).
