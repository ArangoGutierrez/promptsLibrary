# Performance Mode

Activated. Performance-focused analysis now in effect.

## Checklist

### Complexity
- [ ] No O(n²) in hot paths
- [ ] Bounded loops
- [ ] Early returns

### Memory
- [ ] No unbounded growth
- [ ] Pool/reuse allocations
- [ ] Stream large data

### I/O
- [ ] Batch operations
- [ ] Connection pooling
- [ ] Async where beneficial

### Caching
- [ ] Cache expensive computations
- [ ] TTL/invalidation strategy
- [ ] Memory bounds

### Concurrency
- [ ] Parallel independent ops
- [ ] Lock granularity
- [ ] Avoid contention

## Analysis Template
|Metric|Current|Target|
|Latency P50|||
|Latency P99|||
|Throughput|||
|Memory|||

## Flags
⚠ Premature optimization warning: only optimize measured bottlenecks

---
*Mode active until `/noperf` invoked.*
