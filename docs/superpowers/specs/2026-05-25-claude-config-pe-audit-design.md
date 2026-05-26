# Claude Config PE Audit — Design Spec

- **Date**: 2026-05-25
- **Owner**: eduardoa@nvidia.com
- **Status**: Draft, awaiting approval
- **Execution method**: solo (audit doc) → team (P1 structural changes)

## 1. Context & methodology

### Goal
A Principal-Engineer-grade audit of the user's global Claude Code configuration (`~/.claude`, mirrored in this repo under `.claude/`), optimizing for token efficiency, friction reduction, and capability leverage on Claude Opus 4.7 with 1M context. Primary user workload: Go/Kubernetes engineering at NVIDIA, with side projects in Node.js / GitHub Pages.

### Trigger
User reports: token waste, over-prompting friction, TDD-guard producing false positives that cost more tokens to work around than they save, stale `.bak` files accumulating in hooks, uncertainty whether the current `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` flow tracks the official worktree GA path.

### What was reviewed
- `~/.claude/CLAUDE.md`
- `~/.claude/rules/*.md` (7 files, 220 lines total)
- `~/.claude/settings.json` and `settings.local.json`
- `~/.claude/hooks/*.sh` (~30 scripts, including 6 stale `.bak` files)
- `~/.claude/skills/*/SKILL.md` (24 skills, ~118KB total)
- `~/.claude/agents/*.md` (4 agent definitions)
- `~/.claude/commands/*.md` (team-execute, team-plan, team-shutdown)
- `enabledPlugins` (5: code-review, code-simplifier, superpowers, gopls-lsp, clangd-lsp)
- `~/.claude/panel/config.yml` (validate-recommendation panelists)

### What was NOT reviewed
- Project-specific `.claude/` directories in other repos
- MCP server internals (treated as black boxes)
- Plugin internals
- The CFO journal repo (referenced by cfo-* skills)

### Method
1. Local context pass — read all files in scope, measure sizes.
2. Targeted web research — Anthropic Claude Code docs (settings, hooks, skills, memory, plugins, worktrees), Opus 4.7 pricing/cache behavior, 2026 practitioner posts on token efficiency.
3. Grade each finding on the rubric below.
4. Group into phases by effort and dependency.

### Grading rubric
Each finding records:
- **Severity** — `P0` (token waste >5%/session OR frequent friction-block), `P1` (1-5% OR occasional block), `P2` (polish).
- **Token impact** — rough per-session estimate in tokens, against current baseline.
- **Friction** — `high` / `medium` / `low`. How often it interrupts flow.
- **Confidence** — `high` (sourced from official docs + measurement), `medium` (inferred), `low` (judgement).
- **Effort to fix** — `trivial` (one edit) / `small` (one PR) / `medium` (multi-file refactor) / `large` (multi-day).

User-prioritized grading axes: Token cost per session, Friction, Capability leverage. Safety/correctness is recorded inline where relevant (e.g., the `PANEL_DA_API_KEY` leak incident during brainstorming) but is not a graded column.

### Locked decisions (entering this spec)
| Decision | Direction |
|---|---|
| TDD guard | **Remove the PreToolUse hook**; move TDD discipline to skill-only (`superpowers:test-driven-development` and CLAUDE.md rule). Trust + skill discipline instead of mechanical enforcement. |
| CFO/personal-finance skills | **Move to dedicated CFO project**, project-scoped. Free ~30KB of skill metadata from every NVIDIA k8s session. |
| Research depth | Targeted (official docs + 2-3 practitioner posts). |
| Editing strategy | **Edit `promptsLibrary/.claude` first, validate, then promote to `~/.claude`.** Repo is the source of truth; live config is downstream. |

### SOTA reference points (2026)
- Cache TTL silently regressed from 1h → 5m default in March 2026; 1h still available at 2x input price.
- `.claude/rules/*.md` is auto-loaded by Claude Code — CLAUDE.md's "do not @-import them" note is correct.
- Skill *descriptions* (YAML frontmatter) are pre-loaded into every session, not just bodies.
- Worktrees are first-class in official docs; subagents support `isolation: worktree`.
- Opus 4.7 tokenizer produces up to 35% more tokens than prior Opus for the same text — old budget assumptions are stale.

## 2. Inventory snapshot

Captured during Phase A. Stored as a table in the audit deliverable; not duplicated in this spec.

## 3. Findings — by area

This spec defines the **shape** of each finding and the **areas to be covered**. The concrete findings list lives in the audit deliverable (`docs/audits/2026-05-25-claude-config-audit.md`) which is produced as **Phase A** of the implementation plan, **before** P0/P1/P2 execution. The audit doc is the source of truth; P0-P2 are the action phases that reference its finding IDs.

Each finding follows the form:
```
### F-<AREA>-<NN> — <short title>
- Severity: P0 | P1 | P2
- Token impact: ~<N> tokens/session
- Friction: high | medium | low
- Confidence: high | medium | low
- Effort: trivial | small | medium | large
- Current state: <2-3 lines>
- Recommended fix: <2-3 lines>
- Evidence: <file/line refs, measurements, sources>
```

### 3.1 CLAUDE.md (`~/.claude/CLAUDE.md`)
Areas to evaluate: content fit (commands, conventions, workflow), redundancy with `rules/*.md`, signal density, line count vs SOTA recommendation (target 80-200 lines; current 65).

### 3.2 rules/ (`~/.claude/rules/*.md`)
Areas: per-file relevance to actual workload (Go/K8s/containers/security/git), auto-load token cost (220 lines = ~3K tokens/session), redundancy across files, currency of `learned-anti-patterns.md` (curated by `/reflection`).

### 3.3 settings.json (`~/.claude/settings.json`)
Areas: permission allow-list completeness (`gh *` already permitted; verify sandbox auto-allow path is working), `enabledPlugins` accuracy, hooks registration list, sandbox config, `effortLevel: high` cost/value, `model: opus[1m]`, `teammateMode: in-process`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env-var status (deprecated path or still required?).

### 3.4 hooks (`~/.claude/hooks/*.sh`)
Areas: stale `.bak` files (6 to delete), false-positive rate per hook, SessionStart hook output size (every byte costs tokens), `tdd-guard.sh` removal mechanics, `validate-recommendation.sh` sandbox-write friction (`~/.claude/panel/work/` is outside sandbox writable paths), Stop hook configuration.

### 3.5 skills (`~/.claude/skills/`)
Areas: description token cost (pre-loaded per session), per-skill body size vs Anthropic <500-line guideline, redundancy with plugin-provided skills (`superpowers:*`), CFO subtree relocation plan (7 cfo-* skills + cfo + state/journal pointers).

### 3.6 agents (`~/.claude/agents/`)
Areas: 4 agents (doc-writer, explorer, principal-engineer, qa-engineer) — used by team-execute. Verify roles still match the team-execute orchestration skill; check tool allowlists per agent.

### 3.7 plugins enabled
Areas: actual usage of each (code-review, code-simplifier, superpowers, gopls-lsp, clangd-lsp) — clangd-lsp value is questionable for a Go/K8s engineer.

## 4. Cross-cutting themes

These themes span multiple areas and warrant explicit treatment in the audit doc rather than being scattered across findings.

### 4.1 Stop-hook LLM prompt cost (P0)
`settings.json` registers two `Stop` hooks. The first uses `"type": "prompt"` to evaluate "did the assistant just claim work was done without verifying?" — this fires a separate LLM round-trip on **every** turn end. Cost: ~300-800 tokens per turn × ~30 turns/session = ~9-24K tokens/session, plus latency. Overlaps three other safeguards: the CLAUDE.md "Verify before claiming" principle, the constitution's verification discipline, and user review.

Recommendation direction (decide during execution): downgrade to a fast command-hook regex (grep response text for "tests pass", "complete", "fixed" and block only when absent of a recent Bash verification), or delete and trust the rule + user review.

### 4.2 Cache-TTL regression (March 2026, 1h→5m)
Sessions that re-read large CLAUDE.md / rules / skill descriptions after >5min idle pay the cold-cache write cost. Three mitigations: (a) keep the auto-loaded surface small (this audit's main lever); (b) explicitly request 1h TTL via cache markers on long-running work (2x input price, breakeven ~8 reads); (c) avoid long Bash sleeps that idle the cache.

### 4.3 Opus 4.7 tokenizer expansion (~35%)
Older line-count heuristics undercount the actual token cost. The audit's per-session token estimates use the 2026 tokenizer assumption (1 line ≈ 18-25 tokens for English prose, 1 line ≈ 12-18 tokens for code/config).

### 4.4 TDD-guard removal (locked decision)
Mechanics: (1) drop `tdd-guard.sh` from `PreToolUse.Write/Edit` arrays in `settings.json`; (2) move TDD discipline language from "MUST" enforcement into "should" guidance in CLAUDE.md and rules/constitution.md; (3) keep theater-test detection (constitution remains the source of truth for what counts as a real test); (4) delete the 229-line script and 4 `.bak` siblings; (5) add a note to CLAUDE.md: "TDD is the default for production code paths; opt out for docs, install scripts, hacky one-offs, and exploratory work. Theater tests are still a blocking issue."

### 4.5 CFO skill relocation (locked decision)
Target structure: `~/cfo/` project root with its own `.claude/skills/cfo*/` subtree, plus `~/.claude/skills/cfo*/` removed. `~/.claude/CLAUDE.md` loses any CFO references; the CFO project gets its own `.claude/CLAUDE.md` with the persona-engine doctrine. State (`state/YYYY-MM-DD-snapshot.md`) and panel config stay where they are if already in the CFO journal repo. Migration commands listed in the implementation plan.

### 4.6 Worktrees pattern — experimental flag vs GA
`settings.json` sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and `teammateMode: in-process`. Official docs now ship `isolation: worktree` on subagents as the GA path. The audit confirms whether the experimental flag is still needed, deprecated, or co-exists. Adjust `agents/`, `team-execute`, and `worktree-guide` skills accordingly.

### 4.7 Security posture (recorded, not a graded axis per user)
- Live incident during brainstorming: `PANEL_DA_API_KEY` was printed to stdout via a shell expansion error in this session. Key must be rotated before any audit changes land.
- `permissions.deny` correctly blocks reads of `.env`, `.pem`, `.key`, credentials, kube config, AWS dir, SSH keys.
- `permissions.ask` correctly prompts on `rm`, `git rebase`, `git reset --hard`, `git push --force`, `sudo`.
- `sign-commits.sh` hook enforces `-s -S` on every commit. Verified present.

## 5. Phased plan

Four phases. **Phase A produces the audit deliverable**; P0/P1/P2 are action phases that consume it. Each action phase is independently shippable with a validation gate.

### Phase A — Produce the audit document (target: one PR adding `docs/audits/2026-05-25-claude-config-audit.md`)
1. Inventory snapshot table — file → size → role → status.
2. Findings list — apply the §1 rubric and §3 area coverage to produce concrete findings with stable IDs (`F-CLAUDEMD-01`, `F-RULES-02`, `F-SETTINGS-03`, `F-HOOK-04`, `F-SKILL-05`, `F-AGENT-06`, `F-PLUGIN-07`).
3. Cross-cutting themes section incorporating §4 of this spec.
4. Phased plan section that maps findings → P0/P1/P2.
5. PR review: user reads the audit doc, can request adjustments before any action phase begins. P0 does NOT start until the audit doc lands.

### P0 — Quick wins (target: one PR to `promptsLibrary/.claude`, <2h work)
1. Delete 6 stale `.bak` files in `hooks/`.
2. Remove `tdd-guard.sh` from `settings.json` PreToolUse arrays. Delete the script.
3. Move TDD language in CLAUDE.md and `rules/constitution.md` from "MUST" to "should + theater-test discipline still required".
4. Replace Stop-hook `"type": "prompt"` with a fast command-hook regex (or delete entirely; spec leaves the choice to execution time after measurement).
5. Fix `validate-recommendation` skill so it doesn't require `dangerouslyDisableSandbox`. Either move `~/.claude/panel/work/` under `$TMPDIR` or add the path to the sandbox `write.allowOnly` list.
6. Document `Bash(gh *)` as the canonical permission (already allowed); add note to CLAUDE.md "gh CLI is allowed; do not retry sandboxed-first".
7. Rotate `PANEL_DA_API_KEY` (out-of-band, not via Claude).

### P1 — Structural (target: 3-5 PRs to `promptsLibrary/.claude`, locked decisions land here)
1. Relocate 7 `cfo-*` skills + `cfo/` skill + journal references to `~/cfo/` project. Update `~/.claude/skills/` accordingly. Sanity-check that no global skill or hook references CFO paths.
2. Migrate from `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to official `isolation: worktree` subagent pattern. Update `agents/`, `team-execute`, `worktree-guide`. Remove the env var if no longer required.
3. Compress `rules/*.md` where redundant with CLAUDE.md (or vice versa). Set per-file line ceilings (suggested: rules ≤50 lines/file, CLAUDE.md ≤120 lines).
4. Tighten skill descriptions across remaining skills. Target ≤200 chars per `description` field. (Anthropic guidance: descriptions should be pushy but compact.)
5. Cache-TTL strategy: document the 5m default; mark which long-running flows (team-execute, multi-worktree) explicitly opt into 1h-TTL writes.

### P2 — Polish
1. Consolidate hook `*_test.sh` files; document the convention so future hooks ship with tests.
2. Add `$schema` line to project copies of `settings.json` if missing.
3. Audit `enabledPlugins` — confirm each is used; disable unused (likely candidate: clangd-lsp for a Go/K8s engineer).
4. Document the team-execute / agents flow now that it uses official worktrees.
5. Refresh `learned-anti-patterns.md` via `/reflection` (last run 11 days ago per session hook).

### Validation gate per phase
After each phase, measure a baseline session's prompt-token count (using `session-env/` telemetry or a fresh session with verbose logging) and compare against pre-audit baseline.

**Target**: P0 + P1 deliver ≥20% reduction in per-session baseline tokens (CLAUDE.md + rules + skill descriptions + SessionStart hook output). Measured against a representative Go/K8s session in this repo.

If a phase fails its validation gate, do not promote to `~/.claude`; debug in the repo first.

## 6. Appendix

### 6.1 Editing & promotion flow
1. All edits land first in `promptsLibrary/.claude/` (this repo).
2. Test in a fresh Claude Code session opened against this repo.
3. Measure: prompt-token count, skill availability, hook behavior.
4. Once validated, promote to `~/.claude/` via a documented sync script (to be defined in the implementation plan; candidate approach: `rsync -av --delete .claude/ ~/.claude/` with explicit excludes for runtime-only paths like `projects/`, `sessions/`, `paste-cache/`).
5. Each phase gets its own promotion event; do not batch P0+P1+P2 into one sync.

### 6.2 Measurement methodology
- Baseline: open a fresh session in this repo, send a no-op prompt, capture the prompt-token count reported by Claude Code's telemetry (`~/.claude/telemetry/`) or status line.
- After each phase, repeat with the same no-op prompt. Difference is the per-session savings.
- For friction findings (hook false-positives), measure by counting how many times the hook blocked across the last 30 days of `bash-audit-log` or hook trace logs.

### 6.3 Sources from research pass
- `https://code.claude.com/docs/en/settings`
- `https://code.claude.com/docs/en/hooks`
- `https://code.claude.com/docs/en/skills`
- `https://code.claude.com/docs/en/memory`
- `https://code.claude.com/docs/en/plugins`
- `https://code.claude.com/docs/en/worktrees`
- `https://code.claude.com/docs/en/best-practices`
- `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`
- `https://platform.claude.com/docs/en/about-claude/pricing`
- `https://github.com/anthropics/claude-code/issues/46829` (cache-TTL regression)
- `https://callsphere.ai/blog/td30-anth-opus47-latency-tradeoffs`
- `https://www.mindstudio.ai/blog/5-claude-code-skills-cut-token-costs-70-percent-benchmarked`
- `https://www.mindstudio.ai/blog/claude-code-agent-teams-shared-task-list`

### 6.4 Locked-decision traceability
- TDD guard removal — decided 2026-05-25 brainstorm session. User chose "Remove the hook, move TDD to skill".
- CFO skills relocation — decided 2026-05-25 brainstorm session. User chose "Move to a dedicated CFO project, project-scope them".
- Editing strategy — decided 2026-05-25. User: "we first edit promptsLibrary/.claude, make sure everything is ok, then promote to ~/.claude".
- Stop-hook scoping confirmed in scope on user prompt 2026-05-25.
- 20% reduction target — accepted 2026-05-25.

### 6.5 Open items (resolved during implementation)
- Exact wording of the "TDD is recommended, not required" language in CLAUDE.md and constitution.md.
- Whether Stop-hook downgrades to a regex command or is deleted entirely.
- Exact sync script for `promptsLibrary/.claude` → `~/.claude` promotion.
- Whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is still required after migrating to official `isolation: worktree`.
- Whether `clangd-lsp` plugin gets disabled.

These are scoped intentionally — they require live measurement or sandboxed testing that belongs in the implementation plan, not the spec.
