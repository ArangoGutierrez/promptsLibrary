# QA Draft PR Gate Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enforce that workers create only draft PRs and QA is the sole agent that can promote them to ready-for-review.

**Architecture:** Instruction-based enforcement across two files. Workers are restricted to `gh pr create --draft`, QA gains `gh pr ready` responsibility as a gate after all validations pass.

**Tech Stack:** Markdown instruction files (team-execute.md, qa-validator.md)

---

### Task 1: Add Draft PR Restriction to Worker Role Description

**Files:**
- Modify: `commands/team-execute.md:11`

**Step 1: Edit worker role line**

Change line 11 from:
```
3. **Workers (1-3)**: Implement tasks following TDD. Ask Architect for design decisions. Report to QA when ready for testing. Location: dedicated worktrees (one per task).
```
To:
```
3. **Workers (1-3)**: Implement tasks following TDD. Ask Architect for design decisions. Create **draft PRs only** (`--draft` flag). Report to QA when ready for testing. Location: dedicated worktrees (one per task).
```

**Step 2: Verify the edit**

Read `commands/team-execute.md:11` and confirm the draft PR mention is present.

---

### Task 2: Add Draft PR Row to Common Mistakes Table

**Files:**
- Modify: `commands/team-execute.md:26-31`

**Step 1: Add new row to Common Mistakes table**

After line 31 (`| Workers making architectural decisions | Workers escalate to Architect |`), add:
```
| Worker creates non-draft PR | Always use `gh pr create --draft`. Only QA promotes to ready via `gh pr ready` |
| Worker runs `gh pr ready` | FORBIDDEN. Only QA may run `gh pr ready` after all validations pass |
```

**Step 2: Verify the table renders correctly**

Read `commands/team-execute.md:24-35` and confirm the table has 6 rows now.

---

### Task 3: Add Draft Restriction to Worker Spawn Instructions

**Files:**
- Modify: `commands/team-execute.md:74`

**Step 1: Expand worker spawn instruction**

Change line 74 from:
```
   c. **Workers LAST** (each in own worktree, sequentially)
```
To:
```
   c. **Workers LAST** (each in own worktree, sequentially)
      - Workers MUST create PRs with `gh pr create --draft` — never without `--draft`
      - Workers are FORBIDDEN from running `gh pr ready` — only QA can promote a draft PR to ready-for-review
      - Workers push code and create draft PR, then notify QA for validation
```

**Step 2: Verify the edit**

Read `commands/team-execute.md:74-78` and confirm the three bullet points are present.

---

### Task 4: Update Worker Steps 6-8 to Enforce Draft PRs

**Files:**
- Modify: `commands/team-execute.md:76-80`

**Step 1: Add draft PR instruction between steps 6 and 8**

The current step 8 (line 80) says workers notify QA. Insert a new step between current 7 and 8.

Change lines 76-80 from:
```
6. **Workers implement** following TDD protocol (Plan, Red, Green, Refactor).

7. **Workers escalate to Architect** for design decisions. Workers present at least 3 options with trade-offs. Architect consults the relevant library and makes the call.

8. **Workers notify QA** when ready for testing. Include: feature name, summary of changes, current test status.
```
To:
```
6. **Workers implement** following TDD protocol (Plan, Red, Green, Refactor).

7. **Workers escalate to Architect** for design decisions. Workers present at least 3 options with trade-offs. Architect consults the relevant library and makes the call.

8. **Workers create draft PR** when implementation is complete:
   ```
   gh pr create --draft --title "<title>" --body "<description>"
   ```
   **CRITICAL:** The `--draft` flag is MANDATORY. Workers MUST NOT create non-draft PRs. Workers MUST NOT run `gh pr ready`.

9. **Workers notify QA** when ready for testing. Include: feature name, summary of changes, current test status, and the draft PR URL.
```

Note: This renumbers all subsequent steps (old 9→10, old 10→11, old 11→12). All internal references to step numbers must be updated accordingly.

**Step 2: Update all step number references in the file**

The following references need updating:
- Line 82 area: old "Step 9" → "Step 10" (QA validates)
- Line 92 area: old "Step 10" → "Step 11" (PR Review Cycle)
- Line 106 area: old "Step 11" → "Step 12" (Wave transitions)
- Line 130-134: Code Review Workflow section references "Steps 9 and 10" → "Steps 10 and 11"
- Line 132: "QA CI Validation (Step 9)" → "QA CI Validation (Step 10)"
- Line 133: "PR Review Cycle (Step 10)" → "PR Review Cycle (Step 11)"
- Line 134: "QA CI validation passes (Step 9)" → "QA CI validation passes (Step 10)"
- Line 134: "Architect approves the code (Step 10)" → "Architect approves the code (Step 11)"

**Step 3: Verify all step numbers are consistent**

Read the full file and confirm steps are numbered 1-12 with no gaps or duplicates, and all cross-references match.

---

### Task 5: Add QA PR Promotion Responsibility to QA Spawn Instructions

**Files:**
- Modify: `commands/team-execute.md:65-73`

**Step 1: Add PR promotion bullet to QA spawn section**

After line 73 (`QA assists Architect in triaging external bot comments on quality/test-related feedback`), add:
```
      - QA is the ONLY agent authorized to run `gh pr ready <PR-URL>` — this promotes the draft PR to ready-for-review
      - QA MUST verify the PR is in draft state before starting validation. If a PR is already marked ready-for-review without QA approval, report it as a VIOLATION to Team Lead
```

**Step 2: Verify the edit**

Read `commands/team-execute.md:65-76` and confirm the two new bullets are present.

---

### Task 6: Add Draft PR Verification and Promotion to QA Validation Steps

**Files:**
- Modify: `commands/team-execute.md` (the QA validates section, currently step 9, will become step 10)

**Step 1: Add draft verification as first QA sub-step and promotion as last**

The QA validation step (renumbered to 10) should now read:

```
10. **QA validates** by performing ALL of the following in order:
   a. **Verify PR is draft:** Run `gh pr view <PR-URL> --json isDraft -q '.isDraft'`. If the PR is NOT a draft, report VIOLATION to Team Lead and halt validation
   b. `cd` to the worker's worktree directory (`.worktrees/<feature>`)
   c. Run git signature checks (qa-validator section 1)
   d. Run language-specific checks (qa-validator sections 2-5)
   e. Run CI/CD config validation (qa-validator section 6)
   f. **Read `.github/workflows/` and run the EXACT commands CI runs** (qa-validator section 7) — this is the most critical step
   g. Verify PR metadata: milestone, labels per AGENTS.md (qa-validator section 8)
   h. **Wait for GitHub Actions CI to pass** via `gh pr checks --watch` (qa-validator section 9)
   i. Only declare PASS when ALL of the above succeed — local passes alone are NOT sufficient
   j. **Promote PR:** Upon PASS, run `gh pr ready <PR-URL>` to mark the draft PR as ready-for-review. This is the QA gate — only QA can do this
```

**Step 2: Verify the edit**

Read the QA validation step and confirm sub-steps a (draft check) and j (promotion) are present.

---

### Task 7: Update qa-validator.md — Add Draft PR State Verification

**Files:**
- Modify: `team/lib/qa-validator.md` (insert after Section 6, before Section 7)

**Step 1: Add new section between 6 and 7**

Insert after line 677 (end of Section 6, before the `---` separator) and before the current Section 7:

```markdown
## 6b. Draft PR State Verification

**Before running CI replication (Section 7), QA MUST verify the PR is in draft state.**

### Check: PR is Draft

```bash
echo "=== Verifying PR Draft State ==="

PR_URL="<PR-URL>"

IS_DRAFT=$(gh pr view "$PR_URL" --json isDraft -q '.isDraft')

if [ "$IS_DRAFT" = "true" ]; then
    echo "✅ PR is in draft state — proceeding with validation"
else
    echo "❌ VIOLATION: PR is NOT a draft!"
    echo "Workers MUST create PRs with 'gh pr create --draft'"
    echo "Only QA can promote a draft PR to ready-for-review"
    echo ""
    echo "Action: Report this violation to Team Lead. Halt validation."
    exit 1
fi
```

**If the PR is not a draft, QA MUST:**
1. Report the violation to Team Lead immediately
2. Halt all validation — do NOT proceed to Sections 7-10
3. The Worker must explain why they created a non-draft PR

---
```

**Step 2: Verify the new section is in place**

Read `team/lib/qa-validator.md` around the insertion point and confirm Section 6b exists between Section 6 and Section 7.

---

### Task 8: Update qa-validator.md — Add PR Promotion to Section 9

**Files:**
- Modify: `team/lib/qa-validator.md:905-920` (Section 9c area)

**Step 1: Add Step 9d for PR promotion**

After Section 9c (Report Actionable Failures), add a new sub-section:

```markdown
### Step 9d: Promote Draft PR to Ready

**After ALL checks pass (Sections 1-9c), QA promotes the draft PR:**

```bash
echo "=== Promoting Draft PR to Ready ==="

PR_URL="<PR-URL>"

# Final verification that we're about to promote a draft
IS_DRAFT=$(gh pr view "$PR_URL" --json isDraft -q '.isDraft')

if [ "$IS_DRAFT" = "true" ]; then
    gh pr ready "$PR_URL"
    echo "✅ PR promoted to ready-for-review"
    echo "QA gate passed — PR is now visible for review"
else
    echo "⚠️  PR is already ready-for-review — skipping promotion"
fi
```

**QA MUST NOT promote the PR if any validation failed.** The `gh pr ready` command is the QA seal of approval.
```

**Step 2: Verify the new sub-section is in place**

Read `team/lib/qa-validator.md` around Section 9 and confirm Step 9d exists.

---

### Task 9: Update qa-validator.md — Update Approval Gate

**Files:**
- Modify: `team/lib/qa-validator.md:1051-1092` (Approval Gate section)

**Step 1: Add draft verification and promotion to approval conditions**

In the approval gate list (lines 1055-1064), add after condition 5 and update the final action:

Add new condition after line 1059:
```
6. **PR verified as draft:** PR was in draft state at start of validation (Section 6b) — if it wasn't, validation was halted
```

Renumber remaining conditions (old 6→7, old 7→8, old 8→9, old 9→10, old 10→11).

**Step 2: Add promotion as final action in approval signal**

Update the approval signal block to include the promotion step. After "Ready to merge PR." add:

Change:
```
Ready to merge PR.
```
To:
```
Draft PR promoted to ready-for-review via `gh pr ready`.
Ready for Architect review and merge.
```

**Step 3: Update validation order paragraph**

Update the validation order paragraph (line 1066) to include Section 6b:

Change:
```
**Validation order:** Run sections 1-6 first (local checks), then section 7 (CI replication), then section 8 (PR metadata after PR creation), then section 9 (post-push CI verification), then section 10 (external review monitoring and Architect triage). QA MUST NOT skip section 9 — local passes do NOT guarantee remote CI passes. Section 10 runs as a loop until all parties approve.
```
To:
```
**Validation order:** Run sections 1-6 first (local checks), then section 6b (draft PR state verification), then section 7 (CI replication), then section 8 (PR metadata after PR creation), then section 9 (post-push CI verification including PR promotion via `gh pr ready`), then section 10 (external review monitoring and Architect triage). QA MUST NOT skip section 9 — local passes do NOT guarantee remote CI passes. Section 10 runs as a loop until all parties approve.
```

**Step 4: Verify the full approval gate**

Read `team/lib/qa-validator.md` from the Approval Gate section to end of file. Confirm all 11 conditions are listed, the approval signal includes PR promotion, and the validation order mentions Section 6b.

---

### Task 10: Commit All Changes

**Step 1: Stage both modified files**

```bash
git add commands/team-execute.md team/lib/qa-validator.md
```

**Step 2: Commit with signing**

```bash
git commit -s -S -m "feat: enforce draft PR gate — only QA can promote PRs to ready-for-review

Workers must create draft PRs (--draft flag). QA validates and
promotes to ready-for-review via gh pr ready. Non-draft PRs
without QA approval are reported as violations."
```

**Step 3: Verify commit**

```bash
git log -1 --oneline
git diff HEAD~1 --stat
```

Expected: 2 files changed (commands/team-execute.md, team/lib/qa-validator.md).
