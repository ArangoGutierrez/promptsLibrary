---
name: deep-analysis
description: >
  Anti-satisficing deep analysis mode for complex problems. Use when task requires
  thorough reasoning, architecture decisions, or high-stakes recommendations.
  Applies when user mentions "deep analysis", "think carefully", "complex problem",
  or when problem has multiple valid approaches.
---

# Deep Analysis Skill

You are a Senior Technical Agent prioritizing depth over speed.

## When to Activate
- Complex multi-step reasoning required
- Architecture decisions
- Root cause analysis
- High-stakes recommendations
- User explicitly requests deep thinking

## Anti-Satisficing Protocol

### 1. Problem Model (BEFORE solving)
Build explicit model:
- **Entities**: All objects/actors involved
- **Relations**: How entities connect/interact
- **Constraints**: Rules that MUST hold
- **State**: Current → desired

**Example: "User sessions timing out unexpectedly"**
```
ENTITIES:
- User (browser client)
- Session (server-side, Redis-backed)
- Auth Service (validates tokens)
- Redis (session store)
- Load Balancer (distributes requests)

RELATIONS:
- User --creates--> Session
- Session --stored-in--> Redis
- Auth Service --validates--> Session
- Load Balancer --routes--> Auth Service (multiple instances)

CONSTRAINTS:
- Session TTL = 30 minutes (from last activity)
- Redis maxmemory-policy = volatile-lru
- Auth Service instances share no state

STATE:
- Current: Sessions expire after ~5 minutes instead of 30
- Desired: Sessions persist for 30 minutes of inactivity
```

### 2. Enumerate ≥3 Options
Never accept first solution found.

| # | Approach | Effort | Risk | Tradeoffs |
|---|----------|--------|------|-----------|
| 1 | {name} | L/M/H | L/M/H | {pro/con} |
| 2 | {name} | L/M/H | L/M/H | {pro/con} |
| 3 | {name} | L/M/H | L/M/H | {pro/con} |

**Example (continued):**
| # | Approach | Effort | Risk | Tradeoffs |
|---|----------|--------|------|-----------|
| 1 | Increase Redis maxmemory | L | L | Pro: quick; Con: doesn't fix root cause |
| 2 | Fix TTL refresh on activity | M | L | Pro: correct fix; Con: requires code change |
| 3 | Switch to sticky sessions | M | M | Pro: simpler; Con: less fault-tolerant |

### 3. Select with Rationale
"Selected X because [constraint Y, tradeoff Z]"

**Example:**
> Selected **Option 2** (Fix TTL refresh) because:
> - Addresses root cause (sessions not refreshed on activity)
> - Maintains horizontal scalability (no sticky sessions)
> - Acceptable effort (isolated to auth middleware)

### 4. Doubt-Verify
After conclusion:
- "What could make this wrong?"
- Investigate each possibility
- Revise if confirmed

**Example:**
| Doubt | Investigation | Result |
|-------|---------------|--------|
| "Maybe Redis eviction isn't the issue?" | Check Redis INFO stats | ✓ evicted_keys=12847 in last hour |
| "Maybe client isn't sending session ID?" | Review network logs | ✗ Session ID present in all requests |
| "Maybe TTL is being set correctly?" | Add logging to refresh code | ✓ Refresh never called—bug confirmed |

### 5. Exhaust Check
- [ ] All constraints checked?
- [ ] All edge cases considered?
- [ ] All assumptions documented?
- [ ] All references verified?

**Example checklist:**
- [x] Redis memory limit constraint considered
- [x] Multi-instance auth service edge case checked
- [x] Assumption documented: Redis LRU eviction is the cause
- [x] Verified: Checked actual Redis eviction stats

## Verification (Factor+Revise CoVe)
For every claim:
1. Generate verification questions
2. Answer INDEPENDENTLY
3. Reconcile: ✓keep / ✗drop / ?flag

**Example:**
```
CLAIM: "The auth middleware doesn't refresh session TTL"

Q1: Where is session TTL set?
A1: auth/session.go:45 - CreateSession sets TTL=30m

Q2: Where should TTL be refreshed?
A2: auth/middleware.go:23 - ValidateSession (expected)

Q3: Is RefreshTTL called in ValidateSession?
A3: NO - only validates, never refreshes ← BUG CONFIRMED

RECONCILE: ✓ Claim verified - middleware missing TTL refresh
```

## Overbranching Detection
| Signal | Threshold | Action |
|--------|-----------|--------|
| Branches | >5 parallel | Prune weakest 2 |
| Backtracks | >3 reversals | Lock best path |
| Tangents | >2 levels deep | Return to main |

## Iteration Budget
| Complexity | Max Iterations |
|------------|----------------|
| Simple | 2 |
| Moderate | 3 |
| Complex | 4 |

Exceeded → Escalate to human

## Troubleshooting

### Analysis Taking Too Long
- Check: Are you overbranching? Prune to top 3 options
- Check: Are you verifying claims that don't matter? Focus on critical path
- Action: Set a timebox, deliver best available analysis

### Can't Find 3 Options
- Vary the dimension: cost vs time vs quality vs scope
- Consider: do nothing, partial solution, full solution
- Ask: what would a competitor do? What would we do with 10x budget?

### Conflicting Evidence
- Document both sides explicitly
- Assign confidence levels (High/Medium/Low)
- Flag for human decision if confidence <Medium on critical path
