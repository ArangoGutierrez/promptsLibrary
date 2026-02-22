# QA Draft PR Gate Design

**Date:** 2026-02-19
**Status:** Approved

## Problem

Workers bypass QA entirely — they push code, create PRs, and merge without waiting for QA validation. There is no structural enforcement preventing this. The QA validator is comprehensive (10 sections, 1,113 lines) but advisory-only.

## Root Cause

- Workers can call `gh pr create` and `gh pr ready` directly
- `team-execute.md` says "workers notify QA when ready" but doesn't enforce it
- No mechanism prevents a non-draft PR from being created without QA approval

## Approach: Draft PR Gate with QA Promotion

Workers create **draft PRs only**. QA is the sole agent authorized to promote a draft PR to ready-for-review via `gh pr ready`.

### Design

#### Worker Changes (team-execute.md)

1. Steps 6-8: Workers MUST use `gh pr create --draft` — never `gh pr create` without `--draft`
2. Workers are FORBIDDEN from running `gh pr ready`
3. Add to "Common Mistakes" table: "Worker creates non-draft PR" -> "Always use --draft. QA promotes to ready"
4. Worker spawn instructions explicitly include the draft-only restriction

#### QA Agent Changes

**team-execute.md (Step 9):**
- Add final sub-step after all validations pass: QA runs `gh pr ready <PR-URL>` to promote the draft PR

**team-execute.md (Step 10 - PR Review Cycle):**
- After review fixes that require re-validation, QA re-promotes if needed

**qa-validator.md:**
- Add early validation check: Verify PR is in draft state. If PR is already ready-for-review and QA hasn't approved, flag as VIOLATION and report to Team Lead
- Update Approval Gate: Final action after all 10 conditions pass is `gh pr ready <PR-URL>`
- Add PR state management logic to Section 9 (Post-Push CI Verification)

#### Team Lead Verification

- After QA reports PASS, verify via `gh pr view <PR-URL> --json isDraft` that PR is no longer draft
- Any ready-for-review PR without QA approval is a workflow violation

### Files to Modify

1. `/Users/eduardoa/.claude/commands/team-execute.md` — Worker instructions, QA step 9, step 10, common mistakes
2. `/Users/eduardoa/.claude/team/lib/qa-validator.md` — Draft state check, approval gate update, PR promotion

### Trade-offs

- (+) Simple, uses GitHub's native draft PR feature
- (+) Minimal changes — instruction updates + QA gets `gh pr ready` responsibility
- (+) Visible in GitHub UI — draft vs ready state is clear
- (+) QA controls the gate — only QA can promote to ready
- (-) Relies on worker compliance (instructions, not hard technical enforcement)
- (-) No technical block if worker ignores `--draft` flag

### Alternatives Considered

1. **QA owns PR creation entirely** — Workers never create PRs, QA creates them. Strongest enforcement but adds bottleneck and bigger workflow change.
2. **Hook-based enforcement** — Intercept `gh pr create` calls, enforce `--draft`. Technical enforcement but complex, fragile, and harder to debug.
