---
name: go-audit
description: Deep defensive audit for Go/K8s
---
# Go Audit

## Activate
audit Go|production-ready|race condition|resource leak|K8s lifecycle

## Philosophy
Preserve functionality|evidence:`file:line`|actionable fixes

## Scope
A.EffectiveGo:race|chan-misuse|goroutine-leak|err-swallow(_=f())|panic|no-wrap|interface pollution→smaller composable|mutable globals→side effects
B.Defensive:input-val@public/handlers|nil@chains|timeout+ctx@I/O|defer Close
C.K8sReady:graceful(SIGTERM/INT)|json-log|probes|no-secrets
D.Security:no-tokens|injection(SQL,cmd,path)|sanitize|safe-err

## Verify
Each:1.gen Q 2.re-read INDEPENDENTLY 3.report only ✓

## Output
Critical→Major→Minor+verify summary(false positive rate)
