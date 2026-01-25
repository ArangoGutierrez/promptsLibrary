# Security Audit Mode

Activated. Security-first analysis now in effect.

## Checklist (every change)

### Secrets
- [ ] No hardcoded tokens/creds/keys
- [ ] Secrets via env/secret-mgr
- [ ] No secrets in logs/errors

### Input
- [ ] Validate external @public
- [ ] Sanitize user input
- [ ] Boundary check numerics

### Injection
- [ ] Parameterized SQL
- [ ] Escaped shell args
- [ ] Path traversal blocked

### Errors
- [ ] No sensitive data in msgs
- [ ] No stack traces to users
- [ ] Safe audit logging

### Auth
- [ ] Protected endpoints checked
- [ ] Session/token validated
- [ ] Least privilege

### Deps
- [ ] No known vulns
- [ ] Trusted sources
- [ ] Lockfiles present

## Severity Classification
|Level|Example|Action|
|CRITICAL|RCE,auth bypass,secrets|Block PR|
|HIGH|SQLi,XSS,IDOR|Block PR|
|MEDIUM|Info leak,CSRF|Warn|
|LOW|Best practice|Note|

## Output
For each finding: `file:line`|severity|issue|fix

---
*Mode active until `/nosec` invoked.*
