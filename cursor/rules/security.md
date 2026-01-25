---
description: Security constraints for all code changes
alwaysApply: true
---

# Security Rules

## Secrets
- [ ] No hardcoded tokens, credentials, or API keys
- [ ] Secrets via environment variables or secret managers
- [ ] No secrets in comments or documentation

```go
// ✗ Bad: hardcoded secret
const apiKey = "sk-1234567890abcdef"

// ✓ Good: from environment
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    return errors.New("API_KEY environment variable required")
}
```

```go
// ✗ Bad: secret in comment
// API key for testing: sk-test-12345

// ✓ Good: reference without exposing
// API key configured via SECRET_MANAGER_PATH
```

## Input Validation
- [ ] Validate all external input at public interfaces
- [ ] Sanitize user input before use
- [ ] Boundary checks on numeric inputs

```go
// ✗ Bad: no validation
func GetUser(id string) (*User, error) {
    return db.Query("SELECT * FROM users WHERE id = " + id)
}

// ✓ Good: validate and use parameterized query
func GetUser(id string) (*User, error) {
    if !isValidUUID(id) {
        return nil, ErrInvalidUserID
    }
    return db.QueryRow("SELECT * FROM users WHERE id = $1", id)
}

// ✓ Good: boundary checks
func SetPageSize(size int) error {
    if size < 1 || size > 100 {
        return fmt.Errorf("page size must be 1-100, got %d", size)
    }
    // ...
}
```

## Injection Prevention
- [ ] Parameterized queries for SQL (no string concatenation)
- [ ] Shell command arguments escaped/validated
- [ ] Path traversal prevention (no `../` in user paths)

```go
// ✗ Bad: SQL injection vulnerable
query := "SELECT * FROM users WHERE name = '" + name + "'"

// ✓ Good: parameterized query
query := "SELECT * FROM users WHERE name = $1"
rows, err := db.Query(query, name)
```

```go
// ✗ Bad: command injection vulnerable
cmd := exec.Command("sh", "-c", "echo " + userInput)

// ✓ Good: pass arguments separately
cmd := exec.Command("echo", userInput)
```

```go
// ✗ Bad: path traversal vulnerable
path := filepath.Join(baseDir, userInput) // userInput could be "../../../etc/passwd"

// ✓ Good: validate path stays within base
func SafePath(baseDir, userInput string) (string, error) {
    // Clean the path first
    cleaned := filepath.Clean(userInput)
    
    // Ensure no parent directory references
    if strings.Contains(cleaned, "..") {
        return "", ErrInvalidPath
    }
    
    // Join and verify it's under baseDir
    fullPath := filepath.Join(baseDir, cleaned)
    if !strings.HasPrefix(fullPath, filepath.Clean(baseDir)+string(os.PathSeparator)) {
        return "", ErrPathTraversal
    }
    return fullPath, nil
}
```

## Error Handling
- [ ] No sensitive data in error messages
- [ ] No stack traces exposed to users
- [ ] Log sensitive operations without exposing data

```go
// ✗ Bad: exposes internal details
return fmt.Errorf("failed to connect to postgres://admin:secret@db:5432")

// ✓ Good: generic user message, detailed internal log
log.Error("db connection failed", "host", dbHost, "error", err)
return ErrServiceUnavailable // Generic to user
```

```go
// ✗ Bad: stack trace to user
http.Error(w, fmt.Sprintf("%+v", err), 500)

// ✓ Good: log stack, return generic message
log.Error("request failed", "error", err, "stack", debug.Stack())
http.Error(w, "internal server error", 500)
```

## Authentication & Authorization
- [ ] Auth checks on all protected endpoints
- [ ] Session/token validation
- [ ] Principle of least privilege

```go
// ✗ Bad: no auth check
func HandleDeleteUser(w http.ResponseWriter, r *http.Request) {
    userID := r.URL.Query().Get("id")
    db.DeleteUser(userID)
}

// ✓ Good: auth + authz checks
func HandleDeleteUser(w http.ResponseWriter, r *http.Request) {
    // Authentication: who is making the request?
    user, err := authenticate(r)
    if err != nil {
        http.Error(w, "unauthorized", 401)
        return
    }
    
    // Authorization: are they allowed to do this?
    targetID := r.URL.Query().Get("id")
    if !user.CanDelete(targetID) {
        http.Error(w, "forbidden", 403)
        return
    }
    
    db.DeleteUser(targetID)
}
```

## Dependencies
- [ ] No known vulnerable packages
- [ ] Dependencies from trusted sources
- [ ] Lock files committed (go.sum, package-lock.json)

```bash
# Check for vulnerabilities
go list -m all | nancy sleuth          # Go
npm audit                               # Node
pip-audit                               # Python

# Verify lock files are committed
git ls-files | grep -E "(go\.sum|package-lock\.json|yarn\.lock|Pipfile\.lock)"
```

## Security Checklist for Code Review
| Check | Command/Action |
|-------|----------------|
| Secrets scan | `git secrets --scan` or `trufflehog` |
| Dependency audit | `go list -m all \| nancy`, `npm audit` |
| Static analysis | `gosec ./...`, `semgrep` |
| Input validation | Review all `r.URL.Query()`, `r.Body`, `r.FormValue()` |
| SQL queries | Search for string concatenation near `Query`, `Exec` |
| Shell commands | Review all `exec.Command` calls |
