# Architect Agent Enhancement Design

**Date:** 2026-02-14
**Status:** Approved
**Type:** Agent Enhancement

## Problem Statement

The Systems Architect agent in team-coordination currently makes architectural decisions and reviews integration, but lacks comprehensive guidance frameworks. Similar to how we created a language-aware QA validator library, the Architect needs structured references for technology selection, design patterns, architecture validation, and security guidance to be more intelligent and useful across diverse projects.

## Solution

Create four modular libraries in `skills/team-coordination/lib/` that provide:
- Technology/framework selection frameworks with decision criteria
- Design patterns and best practices across languages
- Architecture validation checks and quality gates
- Security architecture guidance (STRIDE, OWASP, threat modeling)

## Design

### Section 1: Library Structure

Four modular libraries in `lib/`:

#### 1. `architect-decisions.md`
**Purpose:** Technology and framework selection frameworks

**Coverage:**
- Storage decisions (database, filesystem, cloud)
- Framework/library selection by language (Go, TypeScript, Rust, Python)
- API design patterns (REST, GraphQL, gRPC)
- Data modeling approaches
- Integration patterns

**Structure:**
```markdown
## Storage Decisions

### Decision Framework
[Criteria: data volume, consistency, query patterns, scalability]

### Decision Tree
[Visual decision tree with yes/no branches]

### Options Matrix
| Option | Best For | Trade-offs | Languages |
|--------|----------|------------|-----------|
| PostgreSQL | ACID, relations | Vertical scaling | All |
| Redis | Caching, pub/sub | Memory-bound | All |
...
```

#### 2. `architect-patterns.md`
**Purpose:** Design patterns and best practices

**Coverage:**
- Architectural patterns (layered, hexagonal, microservices)
- Design patterns by category (creational, structural, behavioral)
- Language-specific idioms (Go channels, TypeScript decorators, Rust traits, Python context managers)
- Testing patterns (test doubles, fixtures, property-based)
- Error handling patterns by language

**Structure:**
```markdown
## Repository Pattern

### Intent
Separate domain logic from data access

### When to Use
- Multiple data sources
- Complex queries
- Testability important

### Go Implementation
[Code example with interface + concrete type]

### TypeScript Implementation
[Code example with class + dependency injection]
...
```

#### 3. `architect-validation.md`
**Purpose:** Architecture quality checks

**Coverage:**
- Dependency analysis (cycle detection, layer violations)
- Metrics collection (complexity, coupling, cohesion)
- API contract validation (OpenAPI, proto validation)
- Performance checks (N+1 queries, unbounded loops)
- Concurrency checks (race detection, deadlock potential)

**Structure:**
```markdown
## Dependency Cycle Detection

### Purpose
Prevent circular dependencies that cause maintenance issues

### Go Check
```bash
go mod graph | awk '{print $1}' | sort -u | while read pkg; do
  go list -f '{{ .ImportPath }}: {{ join .Imports ", " }}' $pkg
done | python3 detect_cycles.py
```

### TypeScript Check
```bash
npx madge --circular --extensions ts src/
```

### What to Look For
- Direct cycles (A → B → A)
- Transitive cycles (A → B → C → A)
...
```

#### 4. `architect-security.md`
**Purpose:** Security architecture guidance

**Coverage:**
- STRIDE threat model (Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation)
- OWASP Top 10 prevention patterns
- Authentication/authorization patterns (OAuth, JWT, RBAC)
- Input validation frameworks
- Secure coding by language (SQL injection, XSS, command injection)
- Secrets management (vault integration, env vars, key rotation)

**Structure:**
```markdown
## STRIDE: Spoofing

### Threat
Attacker impersonates user/service

### Mitigations by Component

#### API Layer
- Mutual TLS for service-to-service
- JWT signature validation
- API key rotation

#### Go Implementation
[Code example with middleware]

#### TypeScript Implementation
[Code example with guards]
...
```

### Section 2: Content Structure for Each Library

#### Decision Framework Pattern (architect-decisions.md)

```markdown
## [Decision Category]

### Decision Criteria
1. [Criterion 1 with weight]
2. [Criterion 2 with weight]
...

### Decision Tree
```dot
digraph decision {
    "Start" -> "Question 1?" [shape=diamond];
    "Question 1?" -> "Option A" [label="yes"];
    "Question 1?" -> "Question 2?" [label="no"];
    ...
}
```

### Options Matrix
| Option | Best For | Pros | Cons | Languages | When to Avoid |
|--------|----------|------|------|-----------|---------------|
| ... | ... | ... | ... | ... | ... |

### Example Scenarios
**Scenario 1:** [Concrete example with recommended choice + reasoning]
**Scenario 2:** [Different context, different recommendation]
```

#### Pattern Reference Pattern (architect-patterns.md)

```markdown
## [Pattern Name]

### Category
[Creational/Structural/Behavioral/Architectural]

### Intent
[One sentence: what problem does this solve?]

### When to Use
- [Use case 1]
- [Use case 2]
...

### When to Avoid
- [Anti-use-case 1]
- [Anti-use-case 2]
...

### Go Implementation
```go
// Complete working example
```

### TypeScript Implementation
```typescript
// Complete working example
```

### Rust Implementation
```rust
// Complete working example
```

### Python Implementation
```python
# Complete working example
```

### Trade-offs
**Pros:** [Benefits]
**Cons:** [Costs]

### Related Patterns
- [Pattern A] - [How it relates]
- [Pattern B] - [How it relates]
```

#### Validation Check Pattern (architect-validation.md)

```markdown
## [Validation Category]

### Purpose
[What does this check prevent?]

### Language-Specific Checks

#### Go
```bash
# Detection command
[command]

# Expected output format
[example output]

# Interpretation
[How to read results]
```

#### TypeScript
```bash
# Detection command
[command with tool]
```

#### Rust
```bash
# Detection command
[command with tool]
```

#### Python
```bash
# Detection command
[command with tool]
```

### What to Look For
- [Warning sign 1]
- [Warning sign 2]
...

### Remediation
**Problem:** [Description]
**Fix:** [Concrete steps]
**Example:** [Before/after code]
```

#### Security Guidance Pattern (architect-security.md)

```markdown
## [Threat Category]

### Threat Description
[What is the attack? How does it work?]

### Attack Vectors
1. [Vector 1 with example]
2. [Vector 2 with example]
...

### Mitigations by Layer

#### Network/Infrastructure
- [Control 1]
- [Control 2]

#### Application Layer
- [Control 1]
- [Control 2]

#### Data Layer
- [Control 1]
- [Control 2]

### Language-Specific Prevention

#### Go
```go
// Secure implementation example
```
**Explanation:** [Why this is secure]

#### TypeScript
```typescript
// Secure implementation example
```
**Explanation:** [Why this is secure]

### Detection Scripts
```bash
# Check for vulnerability
[command to detect this issue]
```

### Testing
```bash
# How to test mitigation works
[test command]
```

### OWASP Reference
[Link to OWASP guidance]
```

### Section 3: Usage Workflow Integration

#### Escalation Scenario 1: Worker → Architect (Technology Decision)

**Worker hits decision point:**
```
Worker: "I need architectural guidance on storage approach.

Context:
- Feature: User profile caching
- Requirements: Read-heavy (10k reads/sec), Write-light (10 writes/sec), <10ms p99 latency
- Current stack: Go backend, PostgreSQL primary DB

Options considered:
A) Redis cache layer (pros: fast, mature; cons: more infra, cache invalidation)
B) In-memory cache with sync (pros: simple, no new dep; cons: memory pressure, sync complexity)
C) PostgreSQL materialized views (pros: no new infra; cons: may not meet latency)

Recommendation: A (Redis) because latency requirement and read volume

Questions:
- Do we have Redis infrastructure?
- Cache invalidation strategy?"
```

**Architect consults libraries:**
1. Opens `architect-decisions.md` → Storage Decisions → Caching section
2. Checks decision criteria matrix against worker's context
3. Reviews options matrix for Redis vs alternatives
4. Checks `architect-patterns.md` → Cache Patterns → Cache-Aside pattern
5. Checks `architect-security.md` → Info Disclosure → Caching Sensitive Data

**Architect responds:**
```
Architect: "Decision: Redis cache layer (Option A)

Reasoning:
- Decision criteria match: Read-heavy + low latency = cache-friendly (architect-decisions.md)
- Pattern: Use Cache-Aside (see architect-patterns.md § Cache-Aside)
- Invalidation: Event-driven (publish profile_updated, cache subscribes)

Implementation guidance:
- Go Redis client: go-redis/redis (architect-decisions.md § Go → Caching Libraries)
- Pattern: Repository with cache decorator (architect-patterns.md § Repository Pattern)
- Security: Don't cache PII; TTL 5 min (architect-security.md § Info Disclosure → Caching)

Next steps:
1. Confirm Redis available in infra (check with lead)
2. Implement Repository interface with PostgreSQL
3. Add CachedRepository decorator with go-redis
4. Add event listener for cache invalidation
5. Load test to confirm <10ms p99

Document decision in .agents/decisions/user-profile-caching.md"
```

#### Escalation Scenario 2: Worker → Architect (Code Review)

**Worker submits for review:**
```
Worker: "User profile caching complete. Ready for architectural review.

Changes:
- Added Redis cache layer with Cache-Aside pattern
- Repository pattern with decorator
- Event-driven invalidation
- Tests: 15/15 passing, coverage 92%

Commit range: abc123..def456"
```

**Architect reviews with validation checks:**
1. Opens `architect-validation.md` → runs checks:
   ```bash
   # Dependency cycles
   go mod graph | check_cycles.py

   # Complexity
   gocyclo -over 10 .

   # Race detection
   go test -race ./...
   ```

2. Opens `architect-patterns.md` → verifies Repository + Decorator implemented correctly

3. Opens `architect-security.md` → checks:
   - No PII in cache keys
   - TTL configured
   - Cache poisoning prevention

**Architect responds:**
```
Architect: "Code review findings:

✅ **Strengths:**
- Repository pattern correctly implemented
- Cache-Aside pattern matches architect-patterns.md
- No dependency cycles detected
- Race-free (go test -race passed)

⚠️ **Issues (Important):**
1. PII in cache keys (architect-security.md § Info Disclosure)
   - Line 45: `key := fmt.Sprintf("profile:%s", user.Email)`
   - Fix: Use user ID: `key := fmt.Sprintf("profile:%d", user.ID)`

2. No TTL configured (architect-patterns.md § Cache-Aside § Step 4)
   - Line 67: `client.Set(ctx, key, value, 0)`
   - Fix: Add TTL: `client.Set(ctx, key, value, 5*time.Minute)`

3. Cache stampede risk (architect-patterns.md § Caching § Thundering Herd)
   - No singleflight on cache miss
   - Fix: Add `golang.org/x/sync/singleflight`

📋 **Re-review after fixes:**
Assign back to me after addressing issues above."
```

#### Escalation Scenario 3: QA → Architect (Architecture Validation)

**QA finds architecture concern:**
```
QA: "Found architecture issue in user-profile-caching feature.

Issue: Service layer directly calls Redis client (line 89)
- Violates layering (services shouldn't know about cache)
- Makes testing harder
- See: architect-patterns.md § Layered Architecture

Should this block PR?"
```

**Architect evaluates:**
1. Opens `architect-patterns.md` → Layered Architecture section
2. Opens `architect-validation.md` → Layer Violations check
3. Opens original design in `.agents/decisions/user-profile-caching.md`

**Architect responds:**
```
Architect: "Yes, this blocks PR.

Violation: Service layer accessing infrastructure (Redis) directly
Severity: High (architecture principle violation)

Required fix:
- Repository interface should hide caching (architect-patterns.md § Repository)
- Service calls repository, not Redis
- Cache is repository implementation detail

Pattern to follow:
```go
// Service layer (domain)
type UserService struct {
    repo UserRepository // interface, no cache knowledge
}

// Infrastructure layer
type CachedUserRepository struct {
    cache  *redis.Client
    source UserRepository // decorated
}
```

Assign back to Worker with fix instructions.
Reference: architect-patterns.md § Repository Pattern + Decorator Pattern"
```

#### Integration with team-execute Command

Update `team-execute.md` to reference Architect libraries:

```markdown
### 1. Systems Architect (MANDATORY - Must Spawn First)

**Location:** agents-workbench branch

**Responsibilities:**
- Make architectural decisions using `lib/architect-decisions.md`
- Guide design patterns using `lib/architect-patterns.md`
- Validate architecture using `lib/architect-validation.md`
- Ensure security using `lib/architect-security.md`
- Document decisions in `.agents/decisions/`

**When Workers escalate:**
1. Identify decision category (storage, framework, API design, etc.)
2. Consult relevant section in architect-decisions.md
3. Apply decision framework with worker's context
4. Reference patterns from architect-patterns.md
5. Check security implications in architect-security.md
6. Provide guidance with library references
7. Document decision in `.agents/decisions/<topic>.md`

**When reviewing code:**
1. Run validation checks from architect-validation.md
2. Verify patterns match architect-patterns.md
3. Check security against architect-security.md
4. Provide specific line-level feedback with library references
```

### Section 4: Implementation & Maintenance

#### File Sizes and Scope

**Target sizes:**
- `architect-decisions.md`: ~500-600 lines (15-20 decision categories)
- `architect-patterns.md`: ~700-800 lines (25-30 patterns)
- `architect-validation.md`: ~400-500 lines (15-20 validation checks)
- `architect-security.md`: ~600-700 lines (STRIDE + OWASP Top 10 + language specifics)

**Total addition:** ~2,200-2,600 lines of architectural guidance

#### Language Coverage

**Tier 1 (Full coverage):**
- Go (primary language, most examples)
- TypeScript (weekend projects, frontend)
- Rust (emerging usage)
- Python (scripting, ML)

**Tier 2 (Basic coverage):**
- Java (enterprise patterns)
- C# (.NET patterns)

**Tier 3 (References only):**
- Other languages as needed

#### Decision Documentation

**Template: `.agents/decisions/<topic>.md`**
```markdown
# [Decision Title]

**Date:** YYYY-MM-DD
**Decider:** Architect agent
**Status:** Approved | Superseded | Deprecated

## Context
[What decision was needed? Why?]

## Decision
[What was chosen?]

## Rationale
[Why this option?]
- [Reason 1 with library reference]
- [Reason 2 with library reference]

## Alternatives Considered
### Option A
- Pros: ...
- Cons: ...
- Why rejected: ...

### Option B
- Pros: ...
- Cons: ...
- Why rejected: ...

## Consequences
- [Positive consequence 1]
- [Negative consequence 1]

## Implementation Notes
[Specific guidance for workers]

## References
- [Library section]: architect-decisions.md § Storage → Caching
- [Pattern]: architect-patterns.md § Repository Pattern
- [Security]: architect-security.md § Info Disclosure
```

#### Maintenance Strategy

**Quarterly reviews:**
- Update patterns with new language idioms
- Add emerging technologies to decision frameworks
- Update security guidance for new vulnerabilities
- Add new validation checks based on issues found

**Versioning:**
- Date-stamp major updates in file headers
- Keep deprecated content with "⚠️ DEPRECATED" markers
- Add "Last updated: YYYY-MM-DD" to each major section

**Feedback loop:**
- Track which sections Architect actually uses
- Identify gaps when Architect struggles with decisions
- Workers can suggest additions via issues/PRs

#### Testing Checklist Additions

Add to `TESTING.md`:

**Architect Library Usage:**
- [ ] Architect consults correct library for decision category
- [ ] Architect provides library references in guidance
- [ ] Decisions documented in `.agents/decisions/`
- [ ] Validation checks run from architect-validation.md
- [ ] Security guidance applied from architect-security.md

**Decision Documentation:**
- [ ] Decision files created with template structure
- [ ] Rationale includes library references
- [ ] Alternatives documented with trade-offs
- [ ] Workers can find and understand documented decisions

**Library Coverage:**
- [ ] Go examples work for Go projects
- [ ] TypeScript examples work for TS projects
- [ ] Rust examples work for Rust projects
- [ ] Python examples work for Python projects

## Success Criteria

1. **Architect agent can reference comprehensive guidance** for technology decisions, patterns, validation, and security
2. **Workers receive structured decisions** with library references and clear implementation guidance
3. **QA can validate architecture** using automated checks from architect-validation.md
4. **Security concerns caught early** through STRIDE/OWASP guidance in architect-security.md
5. **Decisions documented** in `.agents/decisions/` with rationale and library references
6. **Multi-language support** covers Go, TypeScript, Rust, and Python effectively

## Integration Points

### With Existing Team Structure
- Architect stays on agents-workbench branch
- Libraries accessible via Read tool
- Decision docs in `.agents/decisions/` tracked in AGENTS.md
- Works with existing wave management (Architect persists across waves)

### With QA Validator
- QA uses architect-validation.md checks
- QA escalates architecture issues to Architect with library references
- Architect provides fixes referencing architect-patterns.md

### With Workers
- Workers escalate to Architect with structured questions
- Architect responds with library-backed guidance
- Workers implement following patterns from architect-patterns.md
- Workers can read decision docs for context

## Open Questions

None - design approved.
