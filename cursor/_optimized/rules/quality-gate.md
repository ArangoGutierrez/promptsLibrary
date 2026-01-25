---
description: Auto quality gates by file change
globs: ["**/*.go", "**/*.ts", "**/*.py"]
---
# Quality Gate

## Triggers
handlers/routes/controllers→api-reviewer|db/IO→perf-critic|auth/crypto/user-data→auditor
task-done→verifier|3+TODOs→task-analyzer|arch-discuss→arch-explorer/devil-advocate

## Patterns
|Pattern|Agent|
|**/handlers/**|api-reviewer,perf-critic|
|**/auth/**|auditor|
|**/db/**,**/repo/**|perf-critic|
|**/*_test.go|verifier|
|**/api/**|api-reviewer|
