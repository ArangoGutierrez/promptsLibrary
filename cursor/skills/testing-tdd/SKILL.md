---
name: testing-tdd
description: >
  Test-first development methodology with comprehensive coverage. Use when user
  wants to write tests, add test coverage, or follow TDD practices. Applies when
  user mentions "write tests", "add tests", "TDD", "test coverage", "test this",
  or "red-green-refactor".
---

# Testing-TDD Skill

You are a Test-Driven Development practitioner ensuring quality through test-first methodology.

## When to Activate
- User wants to write tests or add test coverage
- User mentions "TDD", "test-first", or "red-green-refactor"
- User asks to "test this" or verify behavior
- User needs comprehensive test coverage

## TDD Cycle: Red-Green-Refactor

### 1. Red: Write Failing Test First
**Goal**: Define expected behavior before implementation

**Steps**:
- Define the expected behavior clearly
- Write the test with assertion
- Verify the test fails for the right reason (not a syntax error)
- Ensure test describes the behavior, not implementation

**Example**:
```go
// Red: Test fails because function doesn't exist
func TestCalculateTotal(t *testing.T) {
    items := []Item{{Price: 10}, {Price: 20}}
    total := CalculateTotal(items)
    if total != 30 {
        t.Errorf("expected 30, got %d", total)
    }
}
```

### 2. Green: Minimal Implementation
**Goal**: Write just enough code to pass the test

**Principles**:
- No premature optimization
- No extra features beyond what test requires
- Simplest solution that works
- Don't worry about code quality yet

**Example**:
```go
// Green: Minimal implementation
func CalculateTotal(items []Item) int {
    total := 0
    for _, item := range items {
        total += item.Price
    }
    return total
}
```

### 3. Refactor: Clean Up
**Goal**: Improve code quality while keeping tests passing

**Focus Areas**:
- Remove duplication (DRY)
- Improve readability
- Extract functions/methods
- Optimize if needed
- **All tests must still pass**

**Example**:
```go
// Refactor: Improved but still passes tests
func CalculateTotal(items []Item) int {
    return sumPrices(items)
}

func sumPrices(items []Item) int {
    var total int
    for _, item := range items {
        total += item.Price
    }
    return total
}
```

## Test Types

### Unit Tests
**Purpose**: Test single function/method in isolation

**Characteristics**:
- Fast execution (< milliseconds)
- No external dependencies (mocks/stubs)
- Test one behavior at a time
- Deterministic (same input → same output)

**Example**:
```go
func TestParseUserID(t *testing.T) {
    tests := []struct {
        input    string
        expected int
        wantErr  bool
    }{
        {"123", 123, false},
        {"abc", 0, true},
        {"", 0, true},
    }
    
    for _, tt := range tests {
        got, err := ParseUserID(tt.input)
        if (err != nil) != tt.wantErr {
            t.Errorf("ParseUserID(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
        }
        if !tt.wantErr && got != tt.expected {
            t.Errorf("ParseUserID(%q) = %d, want %d", tt.input, got, tt.expected)
        }
    }
}
```

### Integration Tests
**Purpose**: Test multiple components working together

**Characteristics**:
- Use real dependencies (database, APIs)
- Test component interactions
- Slower than unit tests
- May require test setup/teardown

**Example**:
```go
func TestUserService_CreateUser(t *testing.T) {
    db := setupTestDB(t)
    defer teardownTestDB(t, db)
    
    svc := NewUserService(db)
    user, err := svc.CreateUser("test@example.com")
    
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Email != "test@example.com" {
        t.Errorf("expected email test@example.com, got %s", user.Email)
    }
}
```

### Edge Cases
**Purpose**: Test boundaries, errors, and unusual inputs

**Common Edge Cases**:
- Empty inputs (nil, empty slice, empty string)
- Boundary values (0, -1, max int, max+1)
- Error conditions (network failure, invalid input)
- Null/undefined values
- Very large inputs
- Concurrent access (race conditions)

**Example**:
```go
func TestProcessItems_EdgeCases(t *testing.T) {
    t.Run("empty slice", func(t *testing.T) {
        result := ProcessItems([]Item{})
        if result != nil {
            t.Error("expected nil for empty slice")
        }
    })
    
    t.Run("nil input", func(t *testing.T) {
        result := ProcessItems(nil)
        if result != nil {
            t.Error("expected nil for nil input")
        }
    })
    
    t.Run("single item", func(t *testing.T) {
        result := ProcessItems([]Item{{ID: 1}})
        if len(result) != 1 {
            t.Errorf("expected 1 item, got %d", len(result))
        }
    })
}
```

## Coverage Guidelines

### Focus on Behavior, Not Lines
- Test what the code does, not how it does it
- 100% line coverage ≠ good tests
- Aim for behavior coverage, not line coverage

### Test Public Interfaces, Not Internals
- Test exported functions/methods
- Don't test private helpers directly (test through public API)
- If private function needs testing, it might belong in public API

**Example**:
```go
// ✓ Test public interface
func TestUserService_GetUser(t *testing.T) {
    // Tests GetUser, which internally uses getUserFromDB
}

// ✗ Don't test private function directly
func Test_getUserFromDB(t *testing.T) {
    // This is an implementation detail
}
```

### Include Error Paths
- Test both success and failure cases
- Verify error messages are helpful
- Test error handling logic

**Example**:
```go
func TestFetchUser_ErrorCases(t *testing.T) {
    t.Run("user not found", func(t *testing.T) {
        _, err := FetchUser(999)
        if err == nil {
            t.Fatal("expected error for non-existent user")
        }
        if !errors.Is(err, ErrUserNotFound) {
            t.Errorf("expected ErrUserNotFound, got %v", err)
        }
    })
    
    t.Run("database error", func(t *testing.T) {
        // Mock DB to return error
        _, err := FetchUserWithDB(999, mockErrorDB{})
        if err == nil {
            t.Fatal("expected error")
        }
    })
}
```

### Table-Driven Tests for Multiple Scenarios
Use table-driven tests when testing multiple inputs/outputs:

**Example**:
```go
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {"valid email", "user@example.com", false},
        {"missing @", "userexample.com", true},
        {"missing domain", "user@", true},
        {"empty string", "", true},
        {"just @", "@", true},
        {"multiple @", "user@@example.com", true},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateEmail(%q) error = %v, wantErr %v", tt.email, err, tt.wantErr)
            }
        })
    }
}
```

## Test Quality Checklist

Before marking tests complete, verify:
- [ ] Test fails before implementation (Red phase)
- [ ] Test passes with minimal implementation (Green phase)
- [ ] Test still passes after refactoring
- [ ] Test name clearly describes what it tests
- [ ] Test is isolated (doesn't depend on other tests)
- [ ] Test is deterministic (same result every run)
- [ ] Edge cases are covered
- [ ] Error paths are tested
- [ ] Test is readable and maintainable

## Common Pitfalls to Avoid

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Testing implementation details | Breaks when refactoring | Test behavior, not internals |
| One test for everything | Hard to debug failures | One assertion per test concept |
| Flaky tests | Non-deterministic | Remove timing/randomness dependencies |
| No edge cases | Misses bugs | Test boundaries and errors |
| Skipping Red phase | No TDD discipline | Always write test first |
| Over-testing | Maintenance burden | Test public API, not helpers |

## Language-Specific Notes

### Go
- Use `testing` package
- Table-driven tests preferred
- Use subtests (`t.Run`) for organization
- Benchmark tests with `testing.B`

### Python
- Use `pytest` or `unittest`
- Use fixtures for setup/teardown
- Parametrize tests with `@pytest.mark.parametrize`
- Mock external dependencies with `unittest.mock`

### Node.js/TypeScript
- Use Jest, Vitest, or Mocha
- Use `describe`/`it` blocks
- Mock modules with `jest.mock()`
- Use `beforeEach`/`afterEach` for setup

## Verification Protocol

After writing tests:
1. Run tests to confirm they fail (Red)
2. Implement minimal code (Green)
3. Verify tests pass
4. Refactor code
5. Verify tests still pass
6. Check coverage (aim for >80% on critical paths)
