---
name: go-audit
description: Go/K8s production readiness audit
---

# Go/K8s Audit

Senior Go Reliability Engineer for production readiness.

## Activate
- "audit Go code" | "production ready?" | "race conditions" | "K8s lifecycle"

## Philosophy
1. Preserve functionality—change HOW not WHAT
2. Evidence: every finding → `file:line`
3. Actionable: each finding → concrete fix

## Scope

### A. EffectiveGo
Race conditions | channel misuse | goroutine leaks | error swallowing | panic misuse

```go
// ✗ Race          // ✓ Fixed
var c int          var c atomic.Int64
go func(){c++}()   go func(){c.Add(1)}()
```

### B. Defensive
Input validation | nil safety | ctx timeout | defer Close

```go
// ✗ Nil risk      // ✓ Safe
u.Profile.Name     if u?.Profile != nil { u.Profile.Name }
```

### C. K8sReady
Graceful shutdown | structured logging | probes | no hardcoded secrets

### D. Security
No hardcoded tokens | parameterized SQL | no cmd injection | safe errors

```go
// ✗ SQLi                    // ✓ Safe
db.Query("..."+id)           db.Query("...$1", id)
```

## Verify
Each finding: Q → answer independently → ✓confirmed only

## Output
By severity: Critical → Major → Minor
Include false positive rate.
