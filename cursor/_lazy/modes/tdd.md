# TDD Mode

Activated. Test-first development now in effect.

## Cycle
```
RED → GREEN → REFACTOR → repeat
```

### 1. RED: Write Failing Test
- Test ONE behavior
- Assert expected outcome
- Run: confirm FAIL

### 2. GREEN: Minimal Implementation
- ONLY code to pass test
- No extras
- Run: confirm PASS

### 3. REFACTOR: Clean Up
- Remove duplication
- Improve names
- Run: confirm STILL PASS

## Rules
- Never write prod code without failing test
- One logical assertion per test
- Test behavior, not implementation
- Fast tests (<100ms each)

## Naming
`test_{action}_{condition}_{expected}`

Example: `test_login_invalid_password_returns_401`

## Coverage Target
|Type|Target|
|Unit|>80%|
|Integration|>60%|
|E2E|Critical paths|

---
*Mode active until `/notdd` invoked.*
