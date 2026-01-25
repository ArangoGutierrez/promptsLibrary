---
name: testing-tdd
description: Test-first development. Use for "write tests", "TDD", "coverage", "test this".
---

# Testing TDD

## Activate

write tests|"TDD"|"test-first"|"red-green-refactor"|add coverage|verify behavior

## Cycle

1.RED:write failing test→verify fails for right reason(not syntax)
2.GREEN:minimal impl→just enough to pass→no extras
3.REFACTOR:clean up→DRY→extract→tests still pass

## Test Types

| Type | Scope | Speed | Deps | Use For |
|------|-------|-------|------|---------|
| Unit | func/method | <ms | mocked | isolated logic |
| Integration | components | ms-s | real | interactions |
| Edge | boundaries | varies | both | nil/empty/max/errors |

## Coverage Principles

- Test behavior, not implementation
- Public API, not private helpers
- Include error paths + edge cases
- Table-driven for multiple scenarios

## Table-Driven Pattern

```go
tests := []struct{name,input,want,wantErr}{}
for _, tt := range tests { t.Run(tt.name, func(t *testing.T){...}) }
```

## Edge Cases Checklist

nil/empty input|zero/negative|boundary values|max+1|concurrent access|error conditions

## Anti-patterns

| Bad | Why | Fix |
|-----|-----|-----|
| Test impl details | breaks on refactor | test behavior |
| One mega-test | hard to debug | one concept per test |
| Flaky tests | timing/random | deterministic deps |
| Skip red phase | no TDD discipline | always fail first |
| Test private funcs | impl coupling | test via public API |

## Quality Gate

- [ ] Fails before impl (red)
- [ ] Passes with minimal code (green)
- [ ] Passes after refactor
- [ ] Name describes behavior
- [ ] Isolated + deterministic
- [ ] Edges + errors covered
