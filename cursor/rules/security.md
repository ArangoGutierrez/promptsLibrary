---
description: Security constraints for all code changes
alwaysApply: true
---

# Security Rules

## Secrets
- [ ] No hardcoded tokens, credentials, or API keys
- [ ] Secrets via environment variables or secret managers
- [ ] No secrets in comments or documentation

## Input Validation
- [ ] Validate all external input at public interfaces
- [ ] Sanitize user input before use
- [ ] Boundary checks on numeric inputs

## Injection Prevention
- [ ] Parameterized queries for SQL (no string concatenation)
- [ ] Shell command arguments escaped/validated
- [ ] Path traversal prevention (no `../` in user paths)

## Error Handling
- [ ] No sensitive data in error messages
- [ ] No stack traces exposed to users
- [ ] Log sensitive operations without exposing data

## Authentication & Authorization
- [ ] Auth checks on all protected endpoints
- [ ] Session/token validation
- [ ] Principle of least privilege

## Dependencies
- [ ] No known vulnerable packages
- [ ] Dependencies from trusted sources
- [ ] Lock files committed (go.sum, package-lock.json)
