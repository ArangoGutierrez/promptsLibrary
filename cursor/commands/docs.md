# Docs

Generate and maintain documentation following project conventions.

## Usage
- `/docs {target}` — Generate docs for target (file, module, or package)
- `/docs {target} --api` — Focus on API documentation
- `/docs {target} --readme` — Update README with target info
- `/docs {target} --inline` — Add inline code comments
- `/docs {target} --verify` — Verify existing docs match implementation

## Workflow

### Phase 1: Analyze
Identify undocumented public interfaces and documentation gaps.

**Input**: Target code path or module identifier
**Output**: Analysis of documentation needs

**Actions**:
1. Read target code and identify public APIs
2. Check existing documentation (README, inline comments, docstrings)
3. Identify undocumented exports, functions, types
4. Review project documentation style and conventions
5. List documentation gaps

### Phase 2: Extract
Pull function signatures, types, and patterns from code.

**Input**: Target code
**Output**: Extracted API information

**Actions**:
1. Parse function/method signatures
2. Extract type definitions and interfaces
3. Identify parameters, return types, errors
4. Note usage patterns and examples in code
5. Extract any existing docstrings/comments

### Phase 3: Generate
Create documentation following project style.

**Input**: Extracted API information and style guide
**Output**: Generated documentation

**Actions**:
1. Generate API documentation for public interfaces
2. Add inline comments for complex logic (if `--inline`)
3. Update README sections (if `--readme`)
4. Follow project documentation conventions
5. Include examples where helpful

### Phase 4: Verify
Check documentation accuracy against implementation.

**Input**: Generated documentation
**Output**: Verification report

**Actions**:
1. Compare documentation with actual code signatures
2. Verify parameter names and types match
3. Check return types and error conditions
4. Validate examples work as documented
5. Ensure no hallucinated details

### Phase 5: Format
Apply consistent formatting and style.

**Input**: Verified documentation
**Output**: Formatted documentation

**Actions**:
1. Apply project markdown formatting rules
2. Ensure consistent code block formatting
3. Check link references are valid
4. Verify table formatting
5. Run documentation linters if available

## Output Format

```markdown
# Documentation: {target}

## Analysis

### Public APIs Identified
| Name | Type | Documented | Location |
|------|------|------------|----------|
| {name} | {function/type/const} | {yes/no} | {file:line} |

### Documentation Gaps
- {gap 1}: {description}
- {gap 2}: {description}

### Style Notes
- Format: {markdown/godoc/jsdoc/etc}
- Examples: {included/not included}
- Inline comments: {style used}

## Generated Documentation

### {API Name}
{Generated documentation following project style}

**Signature**: `{function signature}`
**Parameters**:
- `{param}`: {description}
- `{param}`: {description}

**Returns**: {return type description}
**Errors**: {error conditions}

**Example**:
```{language}
{example code}
```

## Verification

### Accuracy Check
- [x] Signatures match implementation
- [x] Parameter names correct
- [x] Return types accurate
- [x] Error conditions documented
- [x] Examples work as written

### Style Compliance
- [x] Follows project conventions
- [x] Formatting consistent
- [x] Links valid
- [x] No typos or grammar issues
```

## Constraints
- **Accuracy**: Never hallucinate parameters or behavior
- **Consistency**: Match existing documentation style
- **Minimal**: Document what matters, not everything
- **Verify**: Always check docs against implementation
- **Examples**: Include examples for complex APIs
- **Public only**: Focus on public interfaces, not internals

## Troubleshooting

### Cannot Determine Documentation Style
**Problem**: No existing docs to reference for style
**Actions**:
1. Check for style guide in project docs
2. Look at similar projects in ecosystem
3. Use language-standard format (godoc, jsdoc, etc.)
4. Ask user for preferred style
5. Use minimal, clear format as default

### Code Has No Public APIs
**Problem**: Target is internal/private code
**Solution**:
1. If `--inline` flag: Add inline comments for complex logic
2. Otherwise: Skip or document internal architecture
3. Focus on public entry points only
4. Consider if target should be documented at all

### Documentation Out of Sync
**Problem**: Existing docs don't match implementation
**Actions**:
1. If `--verify` flag: Report mismatches
2. Otherwise: Update docs to match current code
3. Note what changed in documentation
4. Consider if code or docs are wrong

### Examples Don't Work
**Problem**: Generated examples fail when tested
**Solution**:
1. Test examples against actual code
2. Fix examples to match current API
3. Update examples if API changed
4. Remove examples if too complex to maintain

### Too Much Documentation
**Problem**: Generated docs are verbose or overwhelming
**Actions**:
1. Focus on public APIs only
2. Remove obvious/redundant documentation
3. Consolidate similar functions
4. Use tables for API listings
5. Keep examples minimal but clear

### Missing Type Information
**Problem**: Cannot extract types from dynamic language
**Solution**:
1. Use type hints/annotations if available
2. Infer types from usage patterns
3. Document as "any" or "unknown" if unclear
4. Add type annotations to code if possible
5. Note limitations in documentation
