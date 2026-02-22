# Architect Agent Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Create four modular Architect libraries providing comprehensive guidance for technology decisions, design patterns, architecture validation, and security.

**Architecture:** Four focused libraries in `skills/team-coordination/lib/` that the Systems Architect agent can reference during team coordination. Each library follows consistent content patterns (decision frameworks, pattern references, validation checks, security guidance) with multi-language support (Go, TypeScript, Rust, Python).

**Tech Stack:** Markdown documentation, decision frameworks, bash validation scripts, code examples in Go/TypeScript/Rust/Python

---

## Task 1: Create architect-decisions.md - Storage Decisions

**Files:**
- Create: `skills/team-coordination/lib/architect-decisions.md`

**Step 1: Create file with header and Storage Decisions section**

Create the file with:
- Frontmatter documenting purpose
- Table of contents
- Storage Decisions section with:
  - Decision Framework (criteria: data volume, consistency, query patterns, scalability)
  - Decision Tree (visual flowchart using dot syntax)
  - Options Matrix (PostgreSQL, Redis, S3, Local filesystem)
  - Example Scenarios (3 concrete examples with recommendations)

Include complete decision frameworks, not placeholders.

**Step 2: Verify structure matches design**

Check:
- Decision criteria are weighted and specific
- Decision tree has yes/no branches leading to recommendations
- Options matrix has: Option, Best For, Pros, Cons, Languages, When to Avoid
- Example scenarios show reasoning process

Expected: Clear, actionable guidance for storage decisions

**Step 3: Commit**

```bash
git add skills/team-coordination/lib/architect-decisions.md
git commit -s -S -m "feat(architect): add storage decisions framework

Add decision framework for storage selection covering:
- PostgreSQL, Redis, S3, filesystem options
- Decision criteria: volume, consistency, query patterns
- Visual decision tree with concrete scenarios"
```

---

## Task 2: Extend architect-decisions.md - Framework Selection

**Files:**
- Modify: `skills/team-coordination/lib/architect-decisions.md`

**Step 1: Add Framework/Library Selection section**

Add section covering:
- Go frameworks (Echo, Gin, Chi, standard lib for HTTP)
- TypeScript frameworks (Express, Fastify, NestJS)
- Rust frameworks (Axum, Actix, Rocket)
- Python frameworks (FastAPI, Flask, Django)

For each language:
- Decision criteria (performance, ecosystem, learning curve, use case)
- Comparison matrix
- When to use standard library vs framework

**Step 2: Verify completeness**

Check:
- All Tier 1 languages covered (Go, TypeScript, Rust, Python)
- Each has comparison matrix with trade-offs
- Guidance on when to skip frameworks

Expected: Clear framework selection guidance per language

**Step 3: Commit**

```bash
git add skills/team-coordination/lib/architect-decisions.md
git commit -s -S -m "feat(architect): add framework selection guidance

Add framework/library selection across languages:
- Go: Echo vs Gin vs Chi vs stdlib
- TypeScript: Express vs Fastify vs NestJS
- Rust: Axum vs Actix vs Rocket
- Python: FastAPI vs Flask vs Django"
```

---

## Task 3: Extend architect-decisions.md - API Design & Data Modeling

**Files:**
- Modify: `skills/team-coordination/lib/architect-decisions.md`

**Step 1: Add API Design Patterns section**

Add:
- REST vs GraphQL vs gRPC comparison
- Decision criteria (client needs, performance, tooling, complexity)
- When to use each pattern
- Hybrid approaches (REST + GraphQL)

**Step 2: Add Data Modeling section**

Add:
- Relational vs Document vs Graph vs Key-Value
- Schema design patterns
- Migration strategies
- When to use ORMs vs raw SQL

**Step 3: Verify target size**

Check file size:
```bash
wc -l skills/team-coordination/lib/architect-decisions.md
```

Expected: ~500-600 lines covering storage, frameworks, APIs, data modeling

**Step 4: Commit**

```bash
git add skills/team-coordination/lib/architect-decisions.md
git commit -s -S -m "feat(architect): add API design and data modeling

Add decision frameworks for:
- API patterns: REST vs GraphQL vs gRPC
- Data modeling: relational vs document vs graph
- Schema design and migration strategies"
```

---

## Task 4: Create architect-patterns.md - Architectural Patterns

**Files:**
- Create: `skills/team-coordination/lib/architect-patterns.md`

**Step 1: Create file with Architectural Patterns section**

Create file with:
- Frontmatter documenting purpose
- Table of contents
- Architectural Patterns section covering:
  - Layered Architecture (3-tier, clean architecture)
  - Hexagonal Architecture (ports & adapters)
  - Microservices Architecture
  - Event-Driven Architecture

For each pattern:
- Intent (one sentence problem statement)
- When to Use (3-4 use cases)
- When to Avoid (3-4 anti-use-cases)
- Structure diagram (dot syntax)
- Trade-offs (pros/cons)

**Step 2: Verify structure**

Check:
- Each pattern has complete Intent/When/Structure/Tradeoffs
- Diagrams use dot syntax
- Trade-offs are specific not generic

Expected: ~150-200 lines covering 4 architectural patterns

**Step 3: Commit**

```bash
git add skills/team-coordination/lib/architect-patterns.md
git commit -s -S -m "feat(architect): add architectural patterns

Add patterns: Layered, Hexagonal, Microservices, Event-Driven
Each with intent, usage guidance, diagrams, trade-offs"
```

---

## Task 5: Extend architect-patterns.md - Creational & Structural Patterns

**Files:**
- Modify: `skills/team-coordination/lib/architect-patterns.md`

**Step 1: Add Creational Patterns section**

Add patterns with multi-language implementations:
- Factory Pattern (Go, TypeScript, Rust, Python)
- Builder Pattern (Go, TypeScript, Rust, Python)
- Singleton Pattern (with concurrency safety notes)

For each:
- Intent
- When to Use/Avoid
- Complete code examples per language
- Related patterns

**Step 2: Add Structural Patterns section**

Add patterns:
- Repository Pattern (critical for team-coordination)
- Decorator Pattern (used in caching example)
- Adapter Pattern
- Facade Pattern

Each with implementations in all Tier 1 languages.

**Step 3: Verify multi-language coverage**

Check:
- Go examples compile (mentally verify syntax)
- TypeScript examples use proper types
- Rust examples use idiomatic traits
- Python examples use type hints

Expected: ~250-300 lines added

**Step 4: Commit**

```bash
git add skills/team-coordination/lib/architect-patterns.md
git commit -s -S -m "feat(architect): add creational and structural patterns

Creational: Factory, Builder, Singleton
Structural: Repository, Decorator, Adapter, Facade
All with Go/TypeScript/Rust/Python implementations"
```

---

## Task 6: Extend architect-patterns.md - Behavioral & Testing Patterns

**Files:**
- Modify: `skills/team-coordination/lib/architect-patterns.md`

**Step 1: Add Behavioral Patterns section**

Add patterns:
- Observer Pattern
- Strategy Pattern
- Command Pattern
- Chain of Responsibility

With language-specific implementations focusing on idiomatic usage:
- Go: channels, interfaces
- TypeScript: classes, decorators
- Rust: traits, enums
- Python: protocols, decorators

**Step 2: Add Testing Patterns section**

Add:
- Test Doubles (Mock, Stub, Fake, Spy)
- Fixture Patterns
- Table-Driven Tests (Go idiom)
- Property-Based Testing

**Step 3: Add Error Handling Patterns section**

Add language-specific error handling:
- Go: error wrapping, sentinel errors
- TypeScript: Result types, error boundaries
- Rust: Result<T, E>, Option<T>
- Python: exceptions, context managers

**Step 4: Verify target size**

Check:
```bash
wc -l skills/team-coordination/lib/architect-patterns.md
```

Expected: ~700-800 lines total

**Step 5: Commit**

```bash
git add skills/team-coordination/lib/architect-patterns.md
git commit -s -S -m "feat(architect): add behavioral, testing, error patterns

Behavioral: Observer, Strategy, Command, Chain
Testing: Test doubles, fixtures, table-driven, property-based
Error handling: Language-specific idiomatic approaches"
```

---

## Task 7: Create architect-validation.md - Dependency & Complexity Analysis

**Files:**
- Create: `skills/team-coordination/lib/architect-validation.md`

**Step 1: Create file with Dependency Analysis section**

Create file with:
- Frontmatter documenting purpose
- Table of contents
- Dependency Cycle Detection:
  - Go: `go mod graph` piped to cycle detector
  - TypeScript: `madge --circular`
  - Rust: `cargo tree` analysis
  - Python: `pydeps` or custom script
- Layer Violation Detection:
  - Check imports respect architecture layers
  - Scripts per language

**Step 2: Add Complexity Metrics section**

Add:
- Cyclomatic Complexity:
  - Go: `gocyclo`
  - TypeScript: `complexity-report`
  - Rust: `cargo-geiger` or `rust-code-analysis`
  - Python: `radon`
- Coupling/Cohesion metrics
- When complexity is acceptable vs problematic

**Step 3: Verify scripts are runnable**

Check:
- Commands are complete (not "run tool X")
- Expected output format documented
- Interpretation guidance provided

Expected: ~150-200 lines

**Step 4: Commit**

```bash
git add skills/team-coordination/lib/architect-validation.md
git commit -s -S -m "feat(architect): add dependency and complexity validation

Add checks for:
- Dependency cycles across Go/TS/Rust/Python
- Layer violations
- Cyclomatic complexity metrics"
```

---

## Task 8: Extend architect-validation.md - API & Performance Checks

**Files:**
- Modify: `skills/team-coordination/lib/architect-validation.md`

**Step 1: Add API Contract Validation section**

Add:
- OpenAPI/Swagger validation (TypeScript/Python)
- gRPC proto validation (Go/Rust)
- GraphQL schema validation
- Breaking change detection

**Step 2: Add Performance Checks section**

Add:
- N+1 Query Detection:
  - Go: `sqlx` query logging analysis
  - TypeScript: Prisma/TypeORM logging
  - Python: SQLAlchemy logging
- Unbounded Loop Detection
- Memory Allocation Patterns:
  - Go: `pprof` heap analysis
  - Rust: Memory leak detection

**Step 3: Add Concurrency Checks section**

Add:
- Race Detection:
  - Go: `go test -race`
  - Rust: Thread sanitizer
- Deadlock Potential Analysis
- Goroutine/Thread Leak Detection

**Step 4: Verify target size**

Check:
```bash
wc -l skills/team-coordination/lib/architect-validation.md
```

Expected: ~400-500 lines total

**Step 5: Commit**

```bash
git add skills/team-coordination/lib/architect-validation.md
git commit -s -S -m "feat(architect): add API, performance, concurrency checks

Add validation for:
- API contracts (OpenAPI, gRPC, GraphQL)
- Performance issues (N+1, unbounded loops)
- Concurrency problems (races, deadlocks)"
```

---

## Task 9: Create architect-security.md - STRIDE Threat Model

**Files:**
- Create: `skills/team-coordination/lib/architect-security.md`

**Step 1: Create file with STRIDE sections**

Create file with:
- Frontmatter documenting purpose
- Table of contents
- STRIDE overview
- Spoofing section:
  - Threat description
  - Attack vectors (API key theft, token hijacking)
  - Mitigations by layer (network, app, data)
  - Go/TypeScript/Rust/Python implementations
  - Detection scripts
- Tampering section:
  - Input validation attacks
  - Mitigations
  - Secure implementations per language
- Repudiation section:
  - Audit logging patterns
  - Implementations

**Step 2: Add Information Disclosure section**

Add:
- Caching sensitive data (relates to profile caching example)
- Logging secrets
- Error messages leaking info
- Mitigations per language

**Step 3: Add Denial of Service section**

Add:
- Rate limiting patterns
- Resource exhaustion prevention
- Timeout configurations
- Go/TS/Rust/Python implementations

**Step 4: Add Elevation of Privilege section**

Add:
- Authorization patterns (RBAC, ABAC)
- Privilege escalation prevention
- Secure defaults

**Step 5: Verify ~300 lines**

Check intermediate progress:
```bash
wc -l skills/team-coordination/lib/architect-security.md
```

Expected: ~300 lines covering STRIDE

**Step 6: Commit**

```bash
git add skills/team-coordination/lib/architect-security.md
git commit -s -S -m "feat(architect): add STRIDE threat model guidance

Add STRIDE categories:
- Spoofing: auth patterns, token validation
- Tampering: input validation, integrity checks
- Repudiation: audit logging
- Information Disclosure: caching, logging, errors
- Denial of Service: rate limiting, timeouts
- Elevation of Privilege: authorization patterns"
```

---

## Task 10: Extend architect-security.md - OWASP Top 10

**Files:**
- Modify: `skills/team-coordination/lib/architect-security.md`

**Step 1: Add OWASP Top 10 section**

Add prevention patterns for:
- A01: Broken Access Control
- A02: Cryptographic Failures
- A03: Injection (SQL, Command, XSS)
- A04: Insecure Design
- A05: Security Misconfiguration
- A06: Vulnerable Components
- A07: Authentication Failures
- A08: Software & Data Integrity
- A09: Logging & Monitoring Failures
- A10: Server-Side Request Forgery

For each:
- Vulnerability description
- Language-specific prevention code (Go/TS/Rust/Python)
- Detection/testing approaches
- OWASP reference link

**Step 2: Add Secrets Management section**

Add:
- Vault integration patterns
- Environment variable handling
- Key rotation strategies
- Language-specific secure storage

**Step 3: Verify target size**

Check:
```bash
wc -l skills/team-coordination/lib/architect-security.md
```

Expected: ~600-700 lines total

**Step 4: Commit**

```bash
git add skills/team-coordination/lib/architect-security.md
git commit -s -S -m "feat(architect): add OWASP Top 10 prevention

Add prevention patterns for all OWASP Top 10:
- Access control, crypto, injection, design, config
- Auth, integrity, monitoring, SSRF
- Secrets management with vault patterns"
```

---

## Task 11: Update team-execute.md - Reference Architect Libraries

**Files:**
- Modify: `skills/team-coordination/commands/team-execute.md`

**Step 1: Find Systems Architect section**

Locate the section that describes Systems Architect responsibilities (should be around line 50-100).

**Step 2: Add library references**

Update the Responsibilities list to reference all four libraries:

```markdown
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

**Step 3: Verify integration**

Check:
- References all four libraries
- Describes workflow for escalations
- Describes workflow for code review

Expected: Clear integration with Architect role

**Step 4: Commit**

```bash
git add skills/team-coordination/commands/team-execute.md
git commit -s -S -m "feat(architect): integrate libraries into team-execute

Update Systems Architect section to reference:
- architect-decisions.md for technology choices
- architect-patterns.md for design guidance
- architect-validation.md for quality checks
- architect-security.md for security review"
```

---

## Task 12: Create Decision Documentation Template

**Files:**
- Create: `skills/team-coordination/lib/decision-template.md`

**Step 1: Create template file**

Create template following the structure from design doc:

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
**Description:** [...]
**Pros:**
- [...]
**Cons:**
- [...]
**Why rejected:** [...]

### Option B
**Description:** [...]
**Pros:**
- [...]
**Cons:**
- [...]
**Why rejected:** [...]

## Consequences

**Positive:**
- [...]

**Negative:**
- [...]

## Implementation Notes
[Specific guidance for workers]

## References
- **Library section**: architect-decisions.md § [Section]
- **Pattern**: architect-patterns.md § [Pattern Name]
- **Security**: architect-security.md § [Threat Category]
- **Validation**: architect-validation.md § [Check Name]
```

**Step 2: Add usage instructions**

Add header comment explaining:
- When to use this template (Architect making decisions)
- Where to save decisions (`.agents/decisions/`)
- How to reference library sections

**Step 3: Commit**

```bash
git add skills/team-coordination/lib/decision-template.md
git commit -s -S -m "feat(architect): add decision documentation template

Add template for documenting architectural decisions with:
- Context, rationale, alternatives
- Library references
- Implementation notes
- Usage instructions for Architect agent"
```

---

## Task 13: Update TESTING.md - Add Architect Library Tests

**Files:**
- Modify: `skills/team-coordination/TESTING.md`

**Step 1: Add Architect Library Usage section**

Add new section before "Future Enhancements":

```markdown
## Architect Library Usage

**Coverage:** Library reference and decision documentation

### Library References
- [ ] Architect consults correct library for decision category
- [ ] Storage decisions → architect-decisions.md § Storage
- [ ] Framework selection → architect-decisions.md § Frameworks
- [ ] Pattern guidance → architect-patterns.md
- [ ] Validation checks → architect-validation.md
- [ ] Security concerns → architect-security.md

### Decision Guidance Quality
- [ ] Architect provides library references in guidance
- [ ] References include section names (e.g., "§ Repository Pattern")
- [ ] Multiple library references when relevant
- [ ] Guidance matches library content (not contradictory)

### Decision Documentation
- [ ] Decisions documented in `.agents/decisions/`
- [ ] Uses decision-template.md structure
- [ ] Rationale includes library references
- [ ] Alternatives documented with trade-offs
- [ ] Implementation notes specific and actionable
- [ ] Workers can find and understand documented decisions

### Validation Checks
- [ ] Architect runs checks from architect-validation.md
- [ ] Scripts execute without errors
- [ ] Output interpreted correctly
- [ ] Findings communicated to QA/Workers

### Multi-Language Coverage
- [ ] Go examples work for Go projects
- [ ] TypeScript examples work for TS projects
- [ ] Rust examples work for Rust projects
- [ ] Python examples work for Python projects
- [ ] Language detection works correctly
```

**Step 2: Update coverage estimate**

Update total coverage comment:
```markdown
**Estimated Coverage:** ~75% (from ~65-70% with library additions)
```

**Step 3: Commit**

```bash
git add skills/team-coordination/TESTING.md
git commit -s -S -m "test(architect): add library usage test checklist

Add tests for:
- Library reference accuracy
- Decision guidance quality
- Decision documentation completeness
- Validation check execution
- Multi-language example coverage

Update estimated coverage to ~75%"
```

---

## Task 14: Update README.md - Document Architect Libraries

**Files:**
- Modify: `skills/team-coordination/README.md`

**Step 1: Add Architect Libraries section**

Add section after "Quick Start" or before "Testing":

```markdown
## Architect Libraries

The Systems Architect agent has access to four comprehensive libraries:

### `lib/architect-decisions.md` (~500-600 lines)
**Purpose:** Technology and framework selection frameworks

**Coverage:**
- Storage decisions (PostgreSQL, Redis, S3, filesystem)
- Framework selection (Go, TypeScript, Rust, Python)
- API patterns (REST, GraphQL, gRPC)
- Data modeling approaches

**Usage:** Architect references when Workers need technology guidance

### `lib/architect-patterns.md` (~700-800 lines)
**Purpose:** Design patterns and best practices

**Coverage:**
- Architectural patterns (Layered, Hexagonal, Microservices, Event-Driven)
- Creational patterns (Factory, Builder, Singleton)
- Structural patterns (Repository, Decorator, Adapter, Facade)
- Behavioral patterns (Observer, Strategy, Command)
- Testing patterns (Test doubles, fixtures, property-based)
- Error handling (language-specific idioms)

**Usage:** Architect references for design guidance and code review

### `lib/architect-validation.md` (~400-500 lines)
**Purpose:** Architecture quality checks

**Coverage:**
- Dependency analysis (cycle detection, layer violations)
- Complexity metrics (cyclomatic, coupling, cohesion)
- API contract validation (OpenAPI, gRPC, GraphQL)
- Performance checks (N+1 queries, unbounded loops)
- Concurrency checks (race detection, deadlocks)

**Usage:** Architect and QA run validation checks before PR approval

### `lib/architect-security.md` (~600-700 lines)
**Purpose:** Security architecture guidance

**Coverage:**
- STRIDE threat model (Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation)
- OWASP Top 10 prevention patterns
- Authentication/Authorization patterns (OAuth, JWT, RBAC)
- Secure coding (SQL injection, XSS, command injection prevention)
- Secrets management (vault, env vars, key rotation)

**Usage:** Architect reviews security implications of all decisions

### Decision Documentation

Architectural decisions are documented in `.agents/decisions/` using `lib/decision-template.md`:
- Context and rationale
- Alternatives considered with trade-offs
- Library references
- Implementation notes for Workers
```

**Step 2: Update Key Features list**

Add to Key Features:
- Comprehensive Architect libraries for decisions, patterns, validation, security
- Multi-language support (Go, TypeScript, Rust, Python)
- Decision documentation with library references

**Step 3: Commit**

```bash
git add skills/team-coordination/README.md
git commit -s -S -m "docs(architect): document library structure in README

Add Architect Libraries section describing:
- Four library purposes and coverage
- File sizes and scope
- Usage patterns
- Decision documentation workflow"
```

---

## Task 15: Create Example Decision Document

**Files:**
- Create: `skills/team-coordination/examples/decision-user-profile-caching.md`

**Step 1: Create examples directory**

```bash
mkdir -p skills/team-coordination/examples
```

**Step 2: Create example decision document**

Create the example decision from the design doc (user profile caching with Redis):

```markdown
# User Profile Caching Storage Decision

**Date:** 2026-02-14
**Decider:** Systems Architect agent
**Status:** Approved

## Context

Worker implementing user profile feature needs caching layer for performance:
- **Requirement:** Read-heavy workload (10k reads/sec, 10 writes/sec)
- **Latency target:** <10ms p99
- **Current stack:** Go backend, PostgreSQL primary DB
- **Scale:** 100k active users, 10MB cache data

## Decision

**Selected:** Redis cache layer with Cache-Aside pattern

## Rationale

- **Performance:** Redis provides <1ms p99 latency, easily meets <10ms requirement
  - *Reference:* architect-decisions.md § Storage Decisions → Caching
- **Pattern fit:** Cache-Aside pattern handles read-heavy with simple invalidation
  - *Reference:* architect-patterns.md § Cache-Aside Pattern
- **Language support:** Mature Go Redis client (go-redis/redis) with connection pooling
  - *Reference:* architect-decisions.md § Go → Caching Libraries
- **Operations:** Team has Redis expertise, existing monitoring
- **Scalability:** Redis cluster can handle 10x growth

## Alternatives Considered

### Option A: In-Memory Cache with Sync
**Description:** In-process cache (sync.Map) with event-driven sync across instances

**Pros:**
- No additional infrastructure
- Simplest deployment
- Zero network latency

**Cons:**
- Memory pressure on app instances (10MB × N instances)
- Complex sync logic (event handling, conflict resolution)
- No cache warming on restart
- Limited observability

**Why rejected:** Memory overhead and sync complexity outweigh infrastructure savings. Team prefers battle-tested Redis over custom sync logic.

### Option B: PostgreSQL Materialized Views
**Description:** Use PostgreSQL materialized views for read optimization

**Pros:**
- No new infrastructure
- Leverages existing database
- ACID guarantees

**Cons:**
- Refresh latency (REFRESH MATERIALIZED VIEW takes seconds)
- Cannot meet <10ms p99 requirement
- Locks during refresh
- Less flexible than cache

**Why rejected:** Cannot meet latency requirement. Materialized views add 50-200ms to queries, exceeds <10ms target.

### Option C: CDN Caching
**Description:** Use CloudFront or similar CDN for profile data

**Pros:**
- Global distribution
- DDoS protection included

**Cons:**
- Overkill for internal API
- Cache invalidation harder (per-region)
- Cost higher than Redis
- Not designed for this use case

**Why rejected:** Over-engineered for internal service. CDN optimizes edge delivery; we need fast database backing.

## Consequences

**Positive:**
- Meets <10ms p99 latency requirement with room to spare
- Scales horizontally (Redis cluster)
- Well-known operational patterns
- Rich ecosystem (monitoring, debugging tools)
- Cache warming possible on deployment

**Negative:**
- Additional infrastructure to manage
- Cache invalidation complexity (must publish events)
- Cache stampede risk (mitigated with singleflight)
- Memory sizing needs monitoring

## Implementation Notes

**For Worker:**

1. **Add Redis dependency:**
   ```bash
   go get github.com/redis/go-redis/v9
   ```

2. **Implement Repository Pattern:**
   - *Reference:* architect-patterns.md § Repository Pattern
   - Create `UserRepository` interface
   - Implement `PostgresUserRepository` (data source)
   - Implement `CachedUserRepository` (decorator)

3. **Use Cache-Aside Pattern:**
   - *Reference:* architect-patterns.md § Cache-Aside Pattern
   - Read: Check cache → miss → fetch DB → write cache → return
   - Write: Update DB → invalidate cache
   - TTL: 5 minutes (balances freshness vs load)

4. **Prevent Cache Stampede:**
   - *Reference:* architect-patterns.md § Caching § Thundering Herd
   - Use `golang.org/x/sync/singleflight` to coalesce concurrent misses

5. **Security:**
   - *Reference:* architect-security.md § Information Disclosure → Caching
   - **DO NOT** cache PII in keys: Use `profile:{userID}` not `profile:{email}`
   - **DO NOT** cache passwords/tokens
   - Set TTL to limit exposure window

6. **Event-Driven Invalidation:**
   - Publish `profile_updated` event on writes
   - Cache subscribes to event and invalidates
   - *Reference:* architect-patterns.md § Event-Driven Architecture

7. **Testing:**
   - *Reference:* architect-patterns.md § Testing Patterns § Test Doubles
   - Mock Redis for unit tests
   - Use `miniredis` for integration tests
   - Load test to confirm <10ms p99

## References

- **Storage decision:** architect-decisions.md § Storage Decisions → Caching
- **Pattern:** architect-patterns.md § Repository Pattern
- **Pattern:** architect-patterns.md § Cache-Aside Pattern
- **Security:** architect-security.md § Information Disclosure → Caching Sensitive Data
- **Validation:** architect-validation.md § Performance Checks → N+1 Queries
```

**Step 3: Commit**

```bash
git add skills/team-coordination/examples/
git commit -s -S -m "docs(architect): add example decision document

Add user-profile-caching decision example showing:
- Complete decision documentation structure
- Library references throughout
- Alternatives with trade-offs
- Implementation notes for Workers"
```

---

## Verification

After all tasks complete:

**File Structure Check:**
```bash
ls -lh skills/team-coordination/lib/
```

Expected files:
- architect-decisions.md (~500-600 lines)
- architect-patterns.md (~700-800 lines)
- architect-validation.md (~400-500 lines)
- architect-security.md (~600-700 lines)
- branch-validator.md (existing)
- qa-validator.md (existing)
- decision-template.md

**Line Count Verification:**
```bash
wc -l skills/team-coordination/lib/architect-*.md
```

Expected: ~2,200-2,600 lines total for architect libraries

**Integration Check:**
```bash
grep -n "architect-decisions.md" skills/team-coordination/commands/team-execute.md
grep -n "Architect Library Usage" skills/team-coordination/TESTING.md
```

Expected: References found in team-execute.md and TESTING.md

**Documentation Check:**
```bash
ls skills/team-coordination/examples/
```

Expected: decision-user-profile-caching.md example

---

## Notes

**Content Quality:**
- All code examples must be complete and compilable (no `// ...` placeholders)
- Decision frameworks must have specific criteria (not "consider performance")
- Validation scripts must be runnable commands (not "use tool X")
- Security guidance must cite OWASP/STRIDE references

**Multi-Language Support:**
- Tier 1 (full coverage): Go, TypeScript, Rust, Python
- Each pattern should have implementations in all Tier 1 languages
- Language-specific idioms matter (Go channels, Rust traits, etc.)

**Library Size:**
- If any library significantly exceeds target size, split into subsections
- Keep each library focused on its domain
- Cross-reference between libraries (don't duplicate content)

**Testing:**
- Use TESTING.md checklist to verify implementation
- Example decision document serves as usage reference
- Subagent can verify structure matches design doc
