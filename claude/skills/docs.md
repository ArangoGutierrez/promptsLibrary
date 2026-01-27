---
name: docs
description: Generate and maintain documentation following project conventions. Analyzes code for undocumented APIs, generates language-appropriate documentation (GoDoc, JSDoc, Python docstrings), and optionally updates READMEs or adds inline comments. Verifies accuracy against implementation.
argument-hint: "[target] [--api] [--readme] [--inline] [--verify]"
disable-model-invocation: false
allowed-tools: Task, Read, Write, Edit, Bash
model: sonnet
---

# Documentation Generator

Generate and maintain code documentation following project conventions.

## Usage

```bash
/docs {target}               # Generate docs for target (file, module, package)
/docs {target} --api         # Focus on API documentation
/docs {target} --readme      # Update README with target info
/docs {target} --inline      # Add inline code comments
/docs {target} --verify      # Verify existing docs match implementation
```

## Workflow

### Phase 1: Analyze

Identify undocumented public interfaces and documentation gaps.

**Input**: Target code path or module identifier

**Actions**:
1. Read target code and identify public APIs (exported functions, classes, methods)
2. Check existing documentation (README, inline comments, docstrings)
3. Identify undocumented exports, functions, types
4. Review project documentation style and conventions
5. List documentation gaps

**Output**: Analysis report of what needs documentation

### Phase 2: Extract

Pull function signatures, types, and patterns from code.

**Actions**:
1. Parse function/method signatures
2. Extract type definitions and interfaces
3. Identify parameters, return types, errors/exceptions
4. Note usage patterns and examples in codebase
5. Extract any existing docstrings/comments

**Output**: Structured API information

### Phase 3: Generate

Create documentation following project style.

Use the documenter agent from `~/.claude/agents/documenter.md`:

```
Use the documenter agent to generate documentation for: $ARGUMENTS

Target: {file/module/package path}
Flags: {--api, --readme, --inline, --verify}

The agent should:
1. Match project documentation style
2. Generate accurate API documentation
3. Include examples where helpful
4. Apply language-appropriate formats (GoDoc, JSDoc, etc.)
5. Verify accuracy against implementation

Output should include generated documentation and verification report.
```

**Language-specific formats**:

**Go (GoDoc)**:
```go
// FunctionName does X and returns Y.
// It returns an error if condition Z.
//
// Example:
//
//	result, err := FunctionName(input)
//	if err != nil {
//		return err
//	}
func FunctionName(param Type) (ReturnType, error) {
```

**JavaScript/TypeScript (JSDoc)**:
```typescript
/**
 * Brief description of function.
 *
 * @param {Type} param - Description of parameter
 * @returns {ReturnType} Description of return value
 * @throws {ErrorType} When error occurs
 *
 * @example
 * const result = functionName(input);
 */
```

**Python (docstrings)**:
```python
def function_name(param: Type) -> ReturnType:
    """Brief description of function.

    Args:
        param: Description of parameter

    Returns:
        Description of return value

    Raises:
        ErrorType: When error occurs

    Example:
        >>> result = function_name(input)
    """
```

### Phase 4: Verify

Check documentation accuracy against implementation.

**Actions**:
1. Compare documentation with actual code signatures
2. Verify parameter names and types match
3. Check return types and error conditions
4. Validate examples work as documented
5. Ensure no hallucinated details

**Verification checklist**:
- [x] Signatures match implementation
- [x] Parameter names correct
- [x] Return types accurate
- [x] Error conditions documented
- [x] Examples work as written

### Phase 5: Format

Apply consistent formatting and style.

**Actions**:
1. Apply project markdown formatting rules
2. Ensure consistent code block formatting
3. Check link references are valid
4. Verify table formatting
5. Run documentation linters if available (markdownlint, etc.)

## Output Format

```markdown
# Documentation: {target}

## Analysis

### Public APIs Identified
| Name | Type | Documented | Location |
|------|------|------------|----------|
| `GetUser` | function | no | user.go:42 |
| `User` | type | yes | user.go:15 |
| `ErrNotFound` | const | no | errors.go:8 |

### Documentation Gaps
- `GetUser`: Missing parameter descriptions and error conditions
- `ErrNotFound`: No explanation of when this error occurs

### Style Notes
- Format: GoDoc
- Examples: Included for complex functions
- Inline comments: Minimal, only for non-obvious logic

## Generated Documentation

### GetUser

```go
// GetUser retrieves a user by ID from the database.
// It returns ErrNotFound if no user exists with the given ID.
//
// Example:
//
//	user, err := GetUser(ctx, 123)
//	if errors.Is(err, ErrNotFound) {
//		// Handle user not found
//	}
func GetUser(ctx context.Context, id int64) (*User, error)
```

**Signature**: `func GetUser(ctx context.Context, id int64) (*User, error)`

**Parameters**:
- `ctx`: Request context for cancellation and timeouts
- `id`: Unique identifier for the user

**Returns**: Pointer to User struct, or nil if not found

**Errors**:
- `ErrNotFound` if user doesn't exist
- `ErrDatabase` if query fails

## Verification

### Accuracy Check
- [x] Signatures match implementation
- [x] Parameter names correct
- [x] Return types accurate
- [x] Error conditions documented
- [x] Examples work as written

### Style Compliance
- [x] Follows GoDoc conventions
- [x] Formatting consistent
- [x] No typos or grammar issues
```

## Flags Behavior

### --api (API Documentation)
Focus on generating API reference documentation:
- Document all exported/public functions
- Include parameters, return values, errors
- Provide usage examples
- Skip internal implementation details

### --readme (README Update)
Update or create README sections:
- Add "Usage" section with examples
- Document installation/setup
- Include API overview
- Add "Examples" section

### --inline (Inline Comments)
Add code comments within implementation:
- Comment complex algorithms
- Explain non-obvious decisions
- Document gotchas or edge cases
- Keep comments minimal and meaningful

### --verify (Verification Only)
Check existing documentation accuracy:
- Report mismatches between docs and code
- Identify outdated documentation
- Don't generate new docs, only verify
- Output verification report

## Constraints

- **Accuracy**: Never hallucinate parameters or behavior
- **Consistency**: Match existing documentation style
- **Minimal**: Document what matters, not everything
- **Verify**: Always check docs against implementation
- **Examples**: Include examples for complex APIs
- **Public only**: Focus on public interfaces, not internals

## Troubleshooting

### Cannot Determine Documentation Style
**Problem**: No existing docs to reference
**Actions**:
1. Check for style guide in project docs
2. Look at similar projects in ecosystem
3. Use language-standard format (godoc, jsdoc, etc.)
4. Ask user for preferred style

### Code Has No Public APIs
**Problem**: Target is internal/private code
**Solution**:
1. If `--inline`: Add inline comments for complex logic
2. Otherwise: Document internal architecture
3. Focus on public entry points only

### Documentation Out of Sync
**Problem**: Existing docs don't match implementation
**Actions** (if `--verify`):
1. Report mismatches
2. Show what changed
3. Ask if code or docs are correct

**Actions** (without `--verify`):
1. Update docs to match current code
2. Note what changed

### Examples Don't Work
**Problem**: Generated examples fail when tested
**Solution**:
1. Test examples against actual code
2. Fix examples to match current API
3. Remove examples if too complex

## When to Use

**Use /docs when**:
- Adding new public APIs
- Preparing for release
- Onboarding new developers
- Existing docs are outdated
- Complex code needs explanation

**Don't use /docs for**:
- Obvious code (self-documenting)
- Internal helper functions
- Test files
- Prototypes or experiments

## Related Skills

- `/task` - Implement features (includes documentation step)
- `/self-review` - Review includes docs check
- `/quality` - Multi-agent review (includes docs verification)
