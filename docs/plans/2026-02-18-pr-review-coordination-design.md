# PR Review Coordination — Architect + QA + External Bots

**Date:** 2026-02-18
**Status:** Approved
**Depends on:** 2026-02-18-qa-agent-ci-validation-design.md

## Problem

After workers create PRs and QA validates CI, there is no step for:
- Architect to review the PR diff for architecture/security/pattern issues
- Waiting for external review bots (GitHub Copilot, CodeRabbitAI)
- Triaging external bot comments (address vs ignore)
- Coordinating workers to address review feedback
- Re-validating after fixes

## Solution

### New Step 10 in team-execute: PR Review Cycle

Inserted after QA CI validation (step 9), before wave transitions. A loop:

1. Architect reviews full diff (architecture, security, patterns)
2. QA monitors for external bot reviews (Copilot, CodeRabbit) — up to 5 min
3. Architect triages ALL feedback (own + external): address / ignore / discuss
4. Architect sends consolidated feedback to Worker
5. Worker pushes fixes
6. QA re-validates (qa-validator sections 7-9)
7. Loop until Architect approves AND QA re-validates AND no unresolved comments

### New qa-validator Section 10: External Review Monitoring & Triage

- `gh pr reviews` and `gh api` commands to poll for bot reviews
- Triage categories: Address, Ignore (false positive), Ignore (already handled), Discuss
- Consolidated feedback format for Worker
- Re-validation protocol after fixes

### Changes to existing sections

- team-execute: updated Architect and QA spawn instructions
- team-execute: Code Review Workflow section references Step 10
- qa-validator: Approval Gate adds condition 9 (Architect approved after review)

## Files Modified

1. `~/.claude/commands/team-execute.md`
2. `~/.claude/team/lib/qa-validator.md`
