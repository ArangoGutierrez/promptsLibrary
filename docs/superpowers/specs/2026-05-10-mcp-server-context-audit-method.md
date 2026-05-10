# MCP Server Context Audit — Method

**Date:** 2026-05-10
**Scope:** Reusable methodology for auditing the context-window cost of any MCP server attached to Claude Code or Cursor.
**Audience:** Senior engineers managing personal/team MCP server inventories who notice context bloat.

## Why this exists

Reddit and community feedback in early 2026 named "MCP server context bloat" the #1 daily-driver complaint for Claude Code and Cursor. Each MCP server adds:

1. **Tool name listing** in deferred-tools system reminders (~12-15 tokens per tool name).
2. **Tool schema bytes** when ToolSearch loads them (~500-1000 tokens per schema).
3. **Per-call response bodies** (variable; can be 1-10K tokens for `status`/`search`-style calls).
4. **SessionStart wake-hook reminders** that some MCP setups emit (~100-300 tokens persistent).
5. **CLAUDE.md routing rules** if the server is referenced (~50-200 tokens persistent).

A single MCP server with 30 deferred tools, a verbose `status` response, and an autoload wake-hook can easily cost 1.5-2K tokens of persistent floor + several K tokens per call. Across multiple servers, this becomes a meaningful fraction of a session's window.

## Method (six steps)

### 1. Inventory the surface

Count the MCP server's tools (deferred or autoloaded) and categorize them:

- **Read** (status, list, search, get) — usually low call volume but read-heavy responses
- **Write** (add, update, delete) — usually small calls
- **Stats / metadata** — sometimes verbose responses
- **Subsystem-specific** (knowledge graph, tunnels, diary, schema) — flag for usage check

Sample command (Claude Code):
```
# Tool names appear in <system-reminder> blocks. Count them.
```

### 2. Measure persistent floor

Tokens that load every session regardless of usage:

- SessionStart hook output (read the hook script and `wc -c` its emitted text)
- CLAUDE.md routing section (read it, count)
- Deferred tool name listing (`tool_count × ~14 tokens`)

Express as a single "persistent floor" number per MCP server.

### 3. Measure per-call cost

For each commonly-called tool, capture a representative response and count its tokens. Watch for:

- **Protocol blocks** in `status` responses (some servers emit a multi-paragraph protocol/dialect spec on every call)
- **Repeated metadata** (palace size, last-updated timestamps, etc. that don't change between calls)
- **Embedded help text** (long descriptions of how to use other tools)

### 4. Identify dormant subsystems

Run the server's stats endpoints and look for zero-state indicators:

| Subsystem | Zero-state signal | If zero |
|-----------|-------------------|---------|
| Knowledge graph | `kg_stats` reports 0 edges | The kg_* tools are pure surface; mark do-not-use |
| Tunnels / cross-references | `list_tunnels` returns empty or only auto-generated rooms | Tunnel mgmt tools are dormant |
| Diary / time-series | `diary_read` returns empty | Diary tools are dormant |
| Domain dialects (compressed encodings, custom DSLs) | Stored content uses plain text | The dialect spec in `status` is dead weight |

### 5. Apply the "Use / Do NOT use / Avoid" routing pattern

In `~/.claude/CLAUDE.md` (or your project's CLAUDE.md), restructure the MCP server's section:

```markdown
## <Server Name>
<one-sentence description of what it does>.

**Use** (canonical, real call paths):
- `tool_a` — purpose, when to call
- `tool_b` — purpose, when to call

**Do NOT use** (dormant subsystems, pure context cost):
- `tool_c_*` — reason it's dormant (e.g., "0 edges in the graph")
- `tool_d_*` — reason

**Avoid:** routine `status`-style calls that emit verbose protocol blocks. Only call when actually auditing.

**Retired:** any old paths that should not be written to.
```

This serves three purposes:
- Tells future-Claude what to call
- Tells future-Claude what NOT to call (avoids the schema-load cost)
- Documents *why* (so the rule survives re-evaluation in 6 months)

### 6. Slim the wake hook

If the SessionStart hook duplicates routing info that's already in CLAUDE.md, replace it with a one-line existence-reminder pointing at CLAUDE.md:

```bash
echo "MEMORY: <ServerName> (MCP) available. Routing rules per CLAUDE.md ## <ServerName>."
```

The duplication cost is ~200-500 tokens per session; the slim version is ~70 tokens.

## Example: anonymized findings from a real audit

Audited an MCP server with this profile (May 2026):

| Metric | Value |
|--------|-------|
| Total entries stored | 27 |
| MCP tools exposed | 29 |
| Knowledge-graph edges | 0 |
| Active tunnel rooms | 0 (2 auto-generated) |

**Persistent floor before trim:** ~430 tokens (wake hook 280 + CLAUDE.md 150).
**Persistent floor after trim:** ~354 tokens (wake hook 74 + restructured CLAUDE.md 280).

**The big win was avoidance**, not floor reduction:

- The server's `status` response embedded a custom dialect spec (~800 tokens) that was never used because all entries were stored in plain English. Adding "Avoid routine `status` calls" to CLAUDE.md saved ~800 tokens per call.
- Tagging the dormant KG/tunnel/diary subsystems "do NOT use" prevented future schema loads (~500-1000 tokens each).

**Total estimated savings:** 1-3K tokens per session that touches the server, depending on call patterns.

## When to apply this

Apply when ANY of:

- You notice context burning faster than expected
- A new MCP server has been registered for >2 weeks but you can't recall calling its tools
- An MCP server's `status` or `help` responses are noticeably verbose
- You're seeing the same dormant tool names in every system reminder

Re-audit cadence: 90 days, or when adding a new MCP server.

## Anti-patterns

- **Premature trimming.** Don't mark a tool "do NOT use" before checking whether the user/team is using it elsewhere. Search past sessions / git history first.
- **Removing the server entirely.** The fix is usually to slim its surface, not uninstall. Servers exist for reasons; preserve the value.
- **Patching the server itself.** Modifying upstream MCP server code to remove protocol blocks is brittle (next update overwrites). Document avoidance in CLAUDE.md instead.
- **Trusting wake-hook output as a substitute for CLAUDE.md.** Wake hooks emit text every session start regardless of relevance; CLAUDE.md sections load with appropriate context-relevance weighting. CLAUDE.md is the canonical place for routing rules.

## Out of scope

- Auditing multiple MCP servers in a single pass — do them one at a time; each has different call patterns.
- Replacing MCP servers with file-based memory — that's a separate architectural decision (see e.g. native auto-memory at `~/.claude/memory/MEMORY.md`).
- Cross-IDE sync architecture — orthogonal to context-cost.

## Related

- Anthropic's prompt caching docs — once you've identified high-cost calls, mark them with `cache_control` if calling the API directly.
- Cursor v3.3 "Context Usage Breakdown" feature — provides per-rule/skill/MCP token attribution; useful for the inventory step.
