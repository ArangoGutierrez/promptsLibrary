# Push

Push changes and create PR.

## Usage
- (no args) — Push and create PR

## Pre-Push Checklist
Before pushing, verify:
- [ ] All tasks in AGENTS.md are `[DONE]`
- [ ] Tests pass (`/test`)
- [ ] Self-review done (`/self-review`)

If any unchecked, warn and suggest running missing step.

## Workflow

### 1. Check Status
```bash
# Verify clean state
git status

# Verify tests pass
{test_command}
```

### 2. Read AGENTS.md
Get issue number and context from `AGENTS.md`

### 3. Push Branch
```bash
git push -u origin HEAD
```

### 4. Create PR
```bash
gh pr create \
  --title "{type}({scope}): {issue title}" \
  --body "Closes #{issue_number}

## Summary
{from AGENTS.md context}

## Changes
{list of commits}

## Checklist
- [x] Tests pass
- [x] Self-reviewed
- [x] Follows codebase patterns

## Testing
{how to verify manually}"
```

### 5. Report
```
## 🚀 PR Created

**PR:** #{pr_number}
**Branch:** {branch}
**Closes:** #{issue_number}

**Link:** {pr_url}

### Next Steps
1. Wait for CI
2. Address review feedback
3. Merge when approved
```

### 6. Update AGENTS.md
```markdown
## Status: PR_OPEN

**PR:** #{pr_number}
**Link:** {url}
```

## If Pre-Checks Fail
```
## ⚠️ Not Ready to Push

### Missing Steps
- [ ] Task #{N} still [TODO]
- [ ] Tests not run
- [ ] Self-review not done

Run missing steps first:
- `/code` — Complete remaining tasks
- `/test` — Verify tests pass
- `/self-review` — Review changes
```

## Constraints
- **Pre-checks**: Verify all tasks done before push
- **Link issue**: PR must close the issue
- **Clean commits**: All commits signed and reference issue
- **Update AGENTS.md**: Record PR number
