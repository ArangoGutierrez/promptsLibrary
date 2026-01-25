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

## Patterns
- Accept interfaces, return structs
- Error wrapping with `fmt.Errorf("%w", err)`
- Context as first parameter for I/O operations
- `defer Close()` on all Closer types

## Naming
- Exported: PascalCase
- Unexported: camelCase
- Acronyms: consistent case (URL or Url, not mixed)

## Error Handling
- Never swallow errors with `_ = f()`
- Always wrap errors with context
- Use sentinel errors sparingly

## Concurrency
- Protect shared state with mutex or channels
- Always have goroutine exit strategy
- Use `context.Context` for cancellation

## Testing
- Table-driven tests preferred
- Parallel tests where safe (`t.Parallel()`)
- Test file naming: `*_test.go`
