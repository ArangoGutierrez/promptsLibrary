# Lazy Loading Framework

Token-optimized Cursor configuration using tiered loading.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ALWAYS LOADED (~200 tokens)          │
│  core.md - Minimal dispatcher + essential constraints   │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  FILE-MATCHED │   │  ON-DEMAND    │   │  COMMAND      │
│  (globs)      │   │  (via /cmd)   │   │  INVOKED      │
├───────────────┤   ├───────────────┤   ├───────────────┤
│ go.md         │   │ /deep         │   │ /task         │
│ ts.md         │   │ /security     │   │ /audit        │
│ k8s.md        │   │ /perf         │   │ /review       │
└───────────────┘   └───────────────┘   └───────────────┘
    ~100 tokens       ~200 tokens         ~500 tokens
    (when matched)    (when invoked)      (when invoked)
```

## Token Budget

| Tier | Trigger | Est. Tokens | % of 200k |
|------|---------|-------------|-----------|
| Core | Always | ~200 | 0.1% |
| Lang | File glob | ~100 | 0.05% |
| Mode | /cmd invoke | ~200 | 0.1% |
| Full cmd | /cmd invoke | ~500 | 0.25% |

**Typical session**: ~300-500 tokens (vs ~4,000+ with full load)

## Usage

Deploy with:
```bash
./scripts/deploy-cursor.sh --lazy
```

Invoke modes on-demand:
```
/deep       # Load deep analysis mode
/security   # Load security audit mode  
/task #123  # Load full task workflow
```

## Files

```
_lazy/
├── rules/
│   ├── core.md          # Always loaded (~200 tokens)
│   ├── go.md            # Glob: **/*.go (~100 tokens)
│   ├── ts.md            # Glob: **/*.ts,tsx (~100 tokens)
│   └── k8s.md           # Glob: **/k8s/**,**/*.yaml (~100 tokens)
├── modes/
│   ├── deep.md          # /deep command (~200 tokens)
│   ├── security.md      # /security command (~200 tokens)
│   └── perf.md          # /perf command (~150 tokens)
└── commands/
    └── (existing optimized commands)
```
