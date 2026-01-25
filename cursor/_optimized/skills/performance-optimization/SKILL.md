---
name: performance-optimization
description: Systematic perf analysis. Use for "slow", "optimize", "bottleneck", "profiling".
---

# Performance Optimization

## Activate

perf issues|"optimize"|"slow"|"bottleneck"|memory/CPU/latency concerns

## Protocol

1.MEASURE:profile first→baseline(p50/p95/p99,mem,CPU,I/O,throughput)
2.ANALYZE:BigO|N+1|allocs|concurrency bottlenecks
3.PRIORITIZE:hot paths×frequency×impact→P0-P3
4.OPTIMIZE:one change→measure→verify→repeat
5.VERIFY:compare baseline|tests pass|no regression|document tradeoffs

## Analysis Patterns

| Issue | Signal | Fix |
|-------|--------|-----|
| BigO | nested loops O(n²) | map/set O(1) lookup |
| N+1 | query in loop | batch query/JOIN/IN clause |
| Allocs | hot path allocations | pre-alloc capacity/sync.Pool |
| Sequential | independent I/O serial | parallel goroutines/Promise.all |
| Copies | large struct pass by value | pass by pointer |
| Lock contention | mutex in hot path | sharding/atomic/lock-free |

## Profile Commands

| Lang | CPU | Memory | Trace |
|------|-----|--------|-------|
| Go | `go test -bench -cpuprofile` | `-memprofile` | `go tool trace` |
| Py | `cProfile -o prof.stats` | `memory_profiler` | `py-spy record` |
| JS | `node --prof` | `--heapsnapshot-signal` | `clinic flame` |

## Prioritization

| Location | Time×Freq | Impact | Priority |
|----------|-----------|--------|----------|
| hot path (every req) | high×high | high | P0 |
| warm path (common) | med×med | med | P1 |
| cold path (startup) | high×low | low | P2 |
| rare path (errors) | low×low | low | P3 |

## Anti-patterns

- Premature optimization (no profile)
- Micro-optimize cold paths
- Sacrifice readability for marginal gains
- Optimize without measuring after

## Stop When

meets SLA|diminishing returns|unacceptable tradeoffs|code unmaintainable
