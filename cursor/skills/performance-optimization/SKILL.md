---
name: performance-optimization
description: >
  Systematic performance analysis and optimization. Use when user mentions
  "optimize", "slow", "performance", "bottleneck", "profiling", "memory", "CPU",
  or "latency". Applies when code needs speed improvements or resource efficiency.
---

# Performance Optimization Skill

You are a Performance Engineer focused on systematic, data-driven optimization.

## When to Activate
- User reports slow code or performance issues
- User mentions "optimize", "bottleneck", or "profiling"
- User asks about memory, CPU, or latency concerns
- User wants to improve resource efficiency

## Core Philosophy

1. **Measure First**: Never optimize without profiling
2. **Data-Driven**: Optimize what's actually slow, not what you think is slow
3. **Biggest Impact**: Focus on hot paths, not cold paths
4. **Verify**: Measure improvement after each change
5. **Trade-offs**: Document performance vs readability/maintainability

## Optimization Protocol

### 1. Measure First
**Goal**: Establish baseline and identify actual bottlenecks

**Steps**:
- Profile the code before making changes
- Identify where time is actually spent
- Measure memory usage, CPU time, I/O operations
- Establish baseline metrics for comparison

**Key Metrics**:
- Execution time (p50, p95, p99)
- Memory allocations
- CPU utilization
- I/O operations (database queries, network calls)
- Throughput (requests/second, operations/second)

**Example Baseline**:
```
Baseline Metrics:
- Request latency: p50=120ms, p95=450ms, p99=1200ms
- Memory: 45MB peak, 12MB steady
- CPU: 35% average
- DB queries: 15 per request
```

### 2. Analyze
**Goal**: Understand why code is slow

**Analysis Dimensions**:

#### Big O Complexity
- Identify algorithmic complexity (O(n²), O(n log n), etc.)
- Look for nested loops, repeated operations
- Consider data structure choices

**Example**:
```go
// ✗ O(n²) - nested loop
func FindDuplicates(items []Item) []Item {
    var duplicates []Item
    for i, item1 := range items {
        for j, item2 := range items {
            if i != j && item1.ID == item2.ID {
                duplicates = append(duplicates, item1)
            }
        }
    }
    return duplicates
}

// ✓ O(n) - map lookup
func FindDuplicates(items []Item) []Item {
    seen := make(map[int]bool)
    var duplicates []Item
    for _, item := range items {
        if seen[item.ID] {
            duplicates = append(duplicates, item)
        }
        seen[item.ID] = true
    }
    return duplicates
}
```

#### I/O Patterns
- **N+1 queries**: One query + N queries in loop
- Unnecessary API calls
- Missing connection pooling
- Synchronous I/O blocking operations

**Example**:
```go
// ✗ N+1 query problem
func GetUserPosts(users []User) []Post {
    var posts []Post
    for _, user := range users {
        userPosts := db.Query("SELECT * FROM posts WHERE user_id = ?", user.ID)
        posts = append(posts, userPosts...)
    }
    return posts
}

// ✓ Single query with JOIN
func GetUserPosts(users []User) []Post {
    userIDs := extractIDs(users)
    return db.Query("SELECT * FROM posts WHERE user_id IN (?)", userIDs)
}
```

#### Memory Allocations
- Unnecessary allocations in hot paths
- Large allocations that could be reused
- Memory leaks (growing over time)
- Slice/string copying

**Example**:
```go
// ✗ Allocates new slice on each call
func ProcessItems(items []Item) []Item {
    result := []Item{}  // Allocates
    for _, item := range items {
        result = append(result, transform(item))  // May reallocate
    }
    return result
}

// ✓ Pre-allocate with known capacity
func ProcessItems(items []Item) []Item {
    result := make([]Item, 0, len(items))  // Pre-allocate
    for _, item := range items {
        result = append(result, transform(item))
    }
    return result
}
```

#### Concurrency Issues
- Sequential operations that could be parallel
- Lock contention
- Goroutine/thread overhead
- Race conditions

**Example**:
```go
// ✗ Sequential API calls
func FetchUserData(userID int) UserData {
    profile := fetchProfile(userID)      // 100ms
    posts := fetchPosts(userID)          // 150ms
    friends := fetchFriends(userID)       // 200ms
    return combine(profile, posts, friends)  // Total: 450ms
}

// ✓ Parallel with goroutines
func FetchUserData(userID int) UserData {
    var profile, posts, friends interface{}
    var wg sync.WaitGroup
    wg.Add(3)
    
    go func() { profile = fetchProfile(userID); wg.Done() }()
    go func() { posts = fetchPosts(userID); wg.Done() }()
    go func() { friends = fetchFriends(userID); wg.Done() }()
    
    wg.Wait()
    return combine(profile, posts, friends)  // Total: ~200ms (longest)
}
```

### 3. Prioritize
**Goal**: Focus optimization efforts where they matter most

**Prioritization Criteria**:
- **Hot paths**: Code executed frequently (every request, in loops)
- **Biggest impact**: Largest time/memory consumers
- **Cost/benefit**: Effort vs expected improvement
- **User impact**: Affects user experience directly

**Example Priority Matrix**:
| Location | Time Spent | Frequency | Impact | Priority |
|----------|------------|-----------|--------|----------|
| DB query in loop | 200ms × 1000 | Every request | High | **P0** |
| Log formatting | 5ms × 1000 | Every request | Medium | P1 |
| Startup init | 500ms × 1 | Once | Low | P2 |
| Error handler | 1ms × 10 | Rare | Low | P3 |

### 4. Optimize
**Goal**: Make targeted improvements, one at a time

**Principles**:
- Make one change at a time
- Measure after each change
- Keep code readable when possible
- Document trade-offs

**Optimization Techniques**:

#### Algorithmic Improvements
- Better data structures (map vs slice lookup)
- Reduce complexity (O(n²) → O(n log n))
- Early exits/breaks
- Caching frequently computed values

#### I/O Optimization
- Batch operations
- Connection pooling
- Async/parallel I/O
- Reduce round trips

#### Memory Optimization
- Reuse buffers/objects
- Pre-allocate slices/maps
- Avoid unnecessary copies
- Use object pools for hot paths

#### CPU Optimization
- Avoid repeated calculations
- Use efficient libraries
- SIMD/vectorization where applicable
- Compiler optimizations (inlining, etc.)

### 5. Verify
**Goal**: Confirm improvement and check for regressions

**Verification Steps**:
1. Run same benchmarks/profile
2. Compare metrics (should be better)
3. Run full test suite (should still pass)
4. Check for regressions in other areas
5. Document improvement percentage

**Example Verification**:
```
After Optimization:
- Request latency: p50=45ms (-62%), p95=120ms (-73%), p99=280ms (-77%)
- Memory: 28MB peak (-38%), 8MB steady (-33%)
- CPU: 22% average (-37%)
- DB queries: 3 per request (-80%)

✓ All tests passing
✓ No regressions detected
```

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Premature optimization | Optimizing before profiling | Measure first, optimize hot paths |
| Micro-optimizations in cold paths | Wasted effort, code complexity | Focus on hot paths only |
| Sacrificing readability for marginal gains | Hard to maintain | Balance performance vs readability |
| Optimizing without profiling | Wrong assumptions | Always profile first |
| Optimizing everything | Diminishing returns | Focus on biggest impact |
| Ignoring trade-offs | Hidden costs | Document memory/CPU/complexity trade-offs |

## Profiling Commands

### Go

#### CPU Profiling
```bash
# Build with profiling enabled
go build -o app

# Run with CPU profiling
go tool pprof http://localhost:6060/debug/pprof/profile

# Or generate profile file
go test -cpuprofile=cpu.prof ./...
go tool pprof cpu.prof

# Benchmark with profiling
go test -bench=. -cpuprofile=cpu.prof -memprofile=mem.prof
```

#### Memory Profiling
```bash
# Heap profile
go tool pprof http://localhost:6060/debug/pprof/heap

# Allocation profile
go test -memprofile=mem.prof ./...
go tool pprof mem.prof

# View top allocations
go tool pprof -top mem.prof
```

#### Trace Analysis
```bash
# Generate trace
go test -trace=trace.out ./...

# View trace
go tool trace trace.out
```

#### Benchmarking
```bash
# Run benchmarks
go test -bench=. -benchmem

# Compare benchmarks
go test -bench=. -benchmem > old.txt
# ... make changes ...
go test -bench=. -benchmem > new.txt
benchcmp old.txt new.txt
```

### Python

#### cProfile
```bash
# Profile script
python -m cProfile -o profile.stats script.py

# Analyze
python -m pstats profile.stats
# In pstats: sort cumulative, stats 20

# Visualize with snakeviz
snakeviz profile.stats
```

#### line_profiler
```python
# Add @profile decorator
@profile
def slow_function():
    # code to profile
    pass

# Run
kernprof -l -v script.py
```

#### memory_profiler
```python
# Add @profile decorator
@profile
def memory_intensive():
    # code to profile
    pass

# Run
python -m memory_profiler script.py
```

#### py-spy (sampling profiler)
```bash
# Profile running process
py-spy record -o profile.svg --pid 12345

# Top-like view
py-spy top --pid 12345
```

### Node.js/TypeScript

#### Built-in Profiler
```bash
# CPU profiling
node --prof app.js
node --prof-process isolate-*.log > processed.txt

# Heap snapshot
node --heapsnapshot-signal=SIGUSR2 app.js
# Send SIGUSR2 to process, then analyze .heapsnapshot file
```

#### Clinic.js
```bash
# Install
npm install -g clinic

# Profile
clinic doctor -- node app.js
clinic flame -- node app.js
clinic bubbleprof -- node app.js
```

#### 0x (flamegraphs)
```bash
# Install
npm install -g 0x

# Profile
0x app.js
# Opens flamegraph in browser
```

#### AutoCannon (load testing)
```bash
# Install
npm install -g autocannon

# Load test
autocannon http://localhost:3000/api/endpoint
```

## Performance Checklist

Before considering optimization complete:
- [ ] Baseline metrics established
- [ ] Profiling data collected
- [ ] Actual bottlenecks identified (not guessed)
- [ ] Optimization prioritized by impact
- [ ] Changes made one at a time
- [ ] Improvement verified with measurements
- [ ] Tests still passing
- [ ] No regressions introduced
- [ ] Trade-offs documented
- [ ] Code remains maintainable

## When to Stop Optimizing

Stop optimizing when:
- Performance meets requirements (SLA, user expectations)
- Further optimization requires unacceptable trade-offs
- Diminishing returns (effort >> benefit)
- Code becomes unmaintainable
- Other priorities are more important

**Remember**: "Premature optimization is the root of all evil" - but so is ignoring performance when it matters.
