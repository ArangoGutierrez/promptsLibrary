# Context Reset

Reset or inspect context tracking state managed by `context-monitor.sh`.

## What Context Tracking Does

The `context-monitor.sh` hook estimates token usage using heuristics:
- **Iterations**: Each turn adds ~8% to score
- **Files touched**: Each file adds ~2%
- **Tasks completed**: Each `[DONE]` task adds ~15%
- **Summarizes**: Each `/summarize` recovers ~25%

Score thresholds determine health state:
| Score | State | Action |
|-------|-------|--------|
| 0-50% | Healthy | Continue |
| 50-75% | Filling | Consider `/summarize` |
| 75-90% | Critical | Run `/summarize` |
| 90%+ | Degraded | New session needed |

## Usage

```
/context-reset           # Reset metrics to zero
/context-reset --status  # Show current health without resetting
```

## Workflow

### `--status`
Read `.cursor/context-state.json` and display:
```
Health: {state} | Score: {N}% | Tasks: {N} | Summarizes: {N}
Recommendation: {last_recommendation}
```

### Reset (default)
```bash
rm -f .cursor/context-state.json .cursor/context-state.lock
echo "✓ Context tracking reset."
```

## When to Use

| Situation | Action |
|-----------|--------|
| After manual `/summarize` | `/context-reset` (recalibrate score) |
| "Stuck" detection false positive | `/context-reset` |
| Starting fresh on same branch | `/context-reset` |
| Check health without reset | `/context-reset --status` |

## State File Location

- Session state: `.cursor/context-state.json`
- Global config: `~/.cursor/context-config.json`

## Tuning Thresholds

Create `~/.cursor/context-config.json` to customize:
```json
{
  "thresholds": { "healthy_max": 50, "filling_max": 75, "critical_max": 90 },
  "weights": { "iteration": 8, "file": 2, "task": 15, "summarize_recovery": 25 },
  "tasks_before_new_session": 3
}
```

## Troubleshooting

**"Stuck" detected incorrectly**: Run `/context-reset` to clear stuck counter.

**Score seems too high/low**: Check `~/.cursor/context-config.json` weights or reset to recalibrate.

**No recommendations appearing**: Verify `context-monitor.sh` is in hooks.json `stop` array.
