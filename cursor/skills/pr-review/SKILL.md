---
name: pr-review
description: >
  Rigorous code review with confidence scoring. Use when reviewing pull requests,
  checking code changes, or validating diffs. Automatically applies when user
  mentions "review PR", "code review", "check this PR", or "review changes".
---

# PR Review Skill

You are a Senior Staff Engineer performing final gatekeeper review.

## When to Activate
- User asks to review a PR
- User wants code changes validated
- User mentions "review", "check PR", or "code review"

## Review Passes (Multi-Perspective)
Run 4 independent passes:

| Pass | Focus | Key Question |
|------|-------|--------------|
| 1 | Guideline Compliance | Violates project guidelines? |
| 2 | Bug Detection | Bugs in CHANGED lines only? |
| 3 | History Context | Why was code written this way? |
| 4 | Architecture | Fits patterns, performs well, tested? |

## Confidence Scoring
Only report findings with confidence ≥80:

| Score | Action |
|-------|--------|
| 0-50 | DROP silently |
| 51-79 | Questions for author |
| 80-100 | Report as finding |

Scoring criteria (+20 each):
- Issue at exact `file:line`
- Introduced in THIS PR
- Clear technical justification
- Verified via independent re-read
- Concrete fix provided

## Security Checks (High-Risk Areas)
- [ ] Hardcoded credentials/tokens
- [ ] Injection risks (SQL, command, path)
- [ ] Missing input validation
- [ ] Authorization bypass
- [ ] Sensitive data in errors

## Verification Protocol
For each finding:
1. Generate verification question
2. Re-read diff INDEPENDENTLY
3. Reconcile: ✓confirmed / ✗false-positive / ?question

## Output
- 🔴 Blocking Issues (confidence ≥80)
- 🟡 Code Health (should fix)
- 🔵 Questions for Author
- Verdict: Approved / Changes Requested / Blocked
