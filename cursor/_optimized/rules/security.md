---
description: Security constraints
alwaysApply: true
---
# Security

## Secrets
No hardcode tokens/creds/keys|env vars or secret mgr|no secrets in comments/docs

## Input
Validate external@public|sanitize user input|boundary check numerics

## Injection
Parameterized SQL(no concat)|escape shell args|prevent path traversal(no ../)

## Errors
No sensitive data in err msg|no stack traces to users|log ops w/o exposing data

## Auth
Checks on protected endpoints|session/token validation|least privilege

## Deps
No known vulns|trusted sources|lockfiles committed(go.sum,package-lock.json)
