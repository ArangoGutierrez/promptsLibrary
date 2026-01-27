---
description: Go-specific coding standards and patterns
globs:
  - "**/*.go"
---

# Go Style Rules

## Toolchain
Run in order: `gofmt` → `go vet` → `golangci-lint` → `go test`

## Documentation
- Doc comments ≤80 characters per line
- Package comments required for non-internal packages

```go
// Package auth provides authentication and authorization primitives
// for the user management service.
package auth
```

## Patterns

### Accept Interfaces, Return Structs
```go
// ✗ Bad: accepts concrete type
func ProcessUser(u *User) error { ... }

// ✓ Good: accepts interface, returns concrete
type UserGetter interface {
    GetID() string
    GetEmail() string
}

func ProcessUser(u UserGetter) (*Result, error) { ... }
```

### Error Wrapping
```go
// ✗ Bad: loses context
if err != nil {
    return err
}

// ✓ Good: wraps with context
if err != nil {
    return fmt.Errorf("failed to fetch user %s: %w", userID, err)
}
```

### Context First for I/O
```go
// ✗ Bad: context not first
func FetchUser(id string, ctx context.Context) (*User, error)

// ✓ Good: context is first parameter
func FetchUser(ctx context.Context, id string) (*User, error)
```

### Defer Close
```go
// ✓ Good: defer close with error check
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()

// ✓ Better: handle close error for writers
f, err := os.Create(path)
if err != nil {
    return err
}
defer func() {
    if cerr := f.Close(); cerr != nil && err == nil {
        err = cerr
    }
}()
```

## Naming
| Type | Convention | Example |
|------|------------|---------|
| Exported | PascalCase | `UserService`, `HTTPClient` |
| Unexported | camelCase | `userCache`, `httpClient` |
| Acronyms | Consistent case | `URL` or `Url`, never `URl` |
| Interfaces | `-er` suffix for single method | `Reader`, `Writer`, `Closer` |

## Error Handling

```go
// ✗ Bad: swallowed error
_ = file.Close()

// ✗ Bad: naked return
if err != nil {
    return err
}

// ✓ Good: wrapped with context
if err != nil {
    return fmt.Errorf("closing config file: %w", err)
}

// Sentinel errors: use sparingly, define at package level
var ErrNotFound = errors.New("resource not found")
```

## Concurrency

### Protect Shared State
```go
// ✓ Good: mutex for shared state
type SafeCounter struct {
    mu    sync.Mutex
    count int
}

func (c *SafeCounter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}
```

### Goroutine Exit Strategy
```go
// ✓ Good: goroutine with context cancellation
func worker(ctx context.Context, jobs <-chan Job) {
    for {
        select {
        case <-ctx.Done():
            return // Clean exit
        case job := <-jobs:
            process(job)
        }
    }
}
```

### Channel Patterns
```go
// ✓ Good: buffered channel to prevent blocking
results := make(chan Result, 10)

// ✓ Good: close channel when done sending
go func() {
    defer close(results)
    for _, item := range items {
        results <- process(item)
    }
}()
```

## Testing

### Table-Driven Tests
```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // Safe for independent tests
            got := Add(tt.a, tt.b)
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d", 
                    tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

### Test Helpers
```go
// t.Helper() marks function as test helper
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```
