---
description: Essential security constraints
alwaysApply: true
---
# Security

## MUST
- No hardcoded secrets/tokens
- Parameterized queries (no SQL concat)
- Validate all external input
- No sensitive data in errors
- Auth check on protected endpoints

## SCAN
secrets:`git secrets --scan`|deps:`npm audit`/`gosec`|input:review Query/Body/Form
