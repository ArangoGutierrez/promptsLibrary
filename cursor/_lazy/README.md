# Lazy Loading Framework

Token-optimized Cursor configuration using tiered loading.

## How It Works

Cursor's rule system supports:
- `alwaysApply: true` - Rule loaded every conversation
- `globs: ["**/*.go"]` - Rule loaded when matching files are in context

This framework exploits these features to minimize always-on token usage.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ALWAYS LOADED (~200 tokens)          │
│  core.md - Minimal constraints + mode dispatch hints    │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  FILE-MATCHED │   │  ON-DEMAND    │   │  FULL CMD     │
│  (Cursor globs)│  │  (modes/)     │   │  (optimized)  │
├───────────────┤   ├───────────────┤   ├───────────────┤
│ go.md         │   │ /deep         │   │ /task         │
│ ts.md         │   │ /security     │   │ /audit        │
│ k8s.md        │   │ /perf /tdd    │   │ /issue        │
└───────────────┘   └───────────────┘   └───────────────┘
    ~100 tokens       ~200 tokens         ~300 tokens
    (auto-loaded)     (when invoked)      (when invoked)
```

## Token Budget

| Tier | Trigger | Tokens | Context % |
|------|---------|--------|-----------|
| Core | Always | ~200 | 0.1% |
| Lang rule | File in context | ~100 | 0.05% |
| Mode cmd | `/deep` etc. | ~200 | 0.1% |
| Full cmd | `/task` etc. | ~300 | 0.15% |

**Typical session**: 200-400 tokens always-on (vs ~2,000+ full load)

## Usage

```bash
# Deploy lazy framework
./scripts/deploy-cursor.sh --lazy

# Or compare token impact first
./scripts/deploy-cursor.sh --check
```

### In Cursor

```
/deep       # Activate deep analysis protocol
/security   # Activate security audit mode
/perf       # Activate performance review mode
/tdd        # Activate test-driven mode

# Then use regular commands
/task #123  # Full task workflow (loads optimized version)
/audit      # Full audit workflow
```

### Deactivation

Modes persist for the conversation. To deactivate:
- Start new conversation (recommended)
- Or explicitly: "Return to normal mode, disable deep analysis"

## Files

```
_lazy/
├── rules/               # → ~/.cursor/rules/
│   ├── core.md          # alwaysApply: true (~200 tok)
│   ├── go.md            # globs: ["**/*.go"] (~100 tok)
│   ├── ts.md            # globs: ["**/*.ts","**/*.tsx"]
│   ├── k8s.md           # globs: ["**/k8s/**","**/*.yaml"]
│   └── python.md        # globs: ["**/*.py"]
├── modes/               # → ~/.cursor/commands/
│   ├── deep.md          # /deep command
│   ├── security.md      # /security command
│   ├── perf.md          # /perf command
│   └── tdd.md           # /tdd command
└── README.md
```

## Comparison

```
Mode        Always-On    Max Per Session
──────────────────────────────────────────
Normal      ~2,000 tok   ~4,000 tok
Optimized   ~1,200 tok   ~2,500 tok
Lazy        ~200 tok     ~1,000 tok (typical)
```

## When to Use Each

| Scenario | Recommended |
|----------|-------------|
| Large codebase, long sessions | `--lazy` |
| Quick tasks, familiar code | `--lazy` |
| Complex audit/review | `--optimized` |
| Learning the system | Normal (full) |
| Token budget constrained | `--lazy` |
