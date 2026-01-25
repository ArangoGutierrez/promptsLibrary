# Audit

Deep defensive audit with integrated fix workflow.

## Usage
- (no args) — Audit recent changes (`git diff`)
- `--full` — Full codebase audit
- `--fix` — Generate fixes for findings

## Scope Priority
| P | Scope | When |
|---|-------|------|
| P0 | `git diff --name-only` | Default |
| P1 | handlers, db, auth | Always |
| P2 | Full codebase | `--full` |

## Audit Categories

### A. EffectiveGo
- [ ] Race conditions
- [ ] Channel misuse, goroutine leaks
- [ ] Error swallowing (`_ = f()`)
- [ ] Panic misuse, missing wrap

### B. Defensive
- [ ] Input validation at public fns
- [ ] Nil safety at deep chains
- [ ] Timeout with `ctx.Context`
- [ ] `defer Close` on Closers

### C. K8sReady
- [ ] Graceful shutdown
- [ ] Structured JSON logging
- [ ] Liveness + readiness probes
- [ ] No hardcoded secrets

### D. Security
- [ ] No hardcoded tokens/creds
- [ ] Injection prevention
- [ ] Input sanitization
- [ ] Safe error messages
- [ ] Authorization checks

## Balance (Do NOT Flag)
- Style preferences as Critical
- Premature optimization
- Architectural rewrites
- Already-mitigated risks
- Test file patterns

## Verification
For each finding:
1. "Does `file:line` contain pattern?"
2. Re-read INDEPENDENTLY
3. ✓confirmed / ✗drop

## Output → AUDIT_REPORT.md
```markdown
## [Critical] {category}
- File: `path:line`
- Issue: {desc}
- Fix: {code}

## [Major] {category}
{same}

## [Minor]
- {desc}

## Summary
- Generated: N | Confirmed: X | Dropped: Y
```

## Fix Workflow (`--fix`)

After audit:
1. For each Critical/Major:
   - Verify finding still valid
   - Apply fix
   - Add test
   - Re-run audit on file
2. Commit: `fix({scope}): {desc} - Audit finding`

## Constraints
- **Evidence-based**: cite `file:line`
- **Verification gate**: Critical/Major pass CoVe
- **No hallucinate**: Flag uncertainty
