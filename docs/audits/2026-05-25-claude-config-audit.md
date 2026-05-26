# Claude Config PE Audit — 2026-05-25

- **Owner:** eduardoa@nvidia.com
- **Spec:** [docs/superpowers/specs/2026-05-25-claude-config-pe-audit-design.md](../superpowers/specs/2026-05-25-claude-config-pe-audit-design.md)
- **Status:** Draft

## 1. Inventory snapshot

| Area | File / Directory | Lines | Bytes | Role | Status |
|------|------------------|-------|-------|------|--------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | 65 | 3045 | Per-session memory (auto-loaded) | active |
| rules/ | `~/.claude/rules/constitution.md` | 24 | 1570 | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/container-conventions.md` | 23 | 1172 | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/git-workflow.md` | 23 | 977 | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/go-conventions.md` | 24 | 1068 | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/k8s-conventions.md` | 24 | 974 | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/learned-anti-patterns.md` | 15 | 1518 | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/security.md` | 20 | 760 | Auto-loaded rule | active |
| settings.json | `~/.claude/settings.json` | 226 | 5734 | User settings | active |
| hooks/ | `~/.claude/hooks/auto-format.sh` | 37 | 1149 | PostToolUse Write/Edit | active |
| hooks/ | `~/.claude/hooks/bash-audit-log.sh` | 37 | 1341 | PostToolUse Bash | active |
| hooks/ | `~/.claude/hooks/build-helpers.sh` | 38 | 987 | helper | active |
| hooks/ | `~/.claude/hooks/context-watch.sh` | 31 | 892 | Stop | active |
| hooks/ | `~/.claude/hooks/enforce-worktree.sh` | 69 | 2667 | PreToolUse Write/Edit | active |
| hooks/ | `~/.claude/hooks/inject-date.sh` | 23 | 989 | SessionStart | active |
| hooks/ | `~/.claude/hooks/mempalace-wake.sh` | 63 | 2513 | helper | active |
| hooks/ | `~/.claude/hooks/mutation-gate.sh` | 147 | 5065 | helper | active |
| hooks/ | `~/.claude/hooks/permission-denied.sh` | 38 | 1340 | PermissionDenied | active |
| hooks/ | `~/.claude/hooks/pre-compact-context.sh` | 79 | 2626 | PreCompact | active |
| hooks/ | `~/.claude/hooks/prevent-push-workbench.sh` | 36 | 1356 | PreToolUse Bash | active |
| hooks/ | `~/.claude/hooks/probe-approve.sh` | 41 | 1534 | helper | active |
| hooks/ | `~/.claude/hooks/reflection-staleness.sh` | 28 | 992 | SessionStart | active |
| hooks/ | `~/.claude/hooks/sign-commits.sh` | 53 | 1494 | PreToolUse Bash | active |
| hooks/ | `~/.claude/hooks/tdd-guard.sh` | 229 | 9438 | PreToolUse Write/Edit | flagged: locked-removal |
| hooks/ | `~/.claude/hooks/test-quality-lint.sh` | 146 | 6781 | PostToolUse Write/Edit | active |
| hooks/ | `~/.claude/hooks/validate-year.sh` | 60 | 2094 | PreToolUse Write | active |
| hooks/ | `~/.claude/hooks/bash-audit-log_test.sh` | 53 | 1649 | Hook test | active |
| hooks/ | `~/.claude/hooks/context-watch_test.sh` | 52 | 1730 | Hook test | active |
| hooks/ | `~/.claude/hooks/done-hook.sh` | 187 | 6813 | Stop | active |
| hooks/ | `~/.claude/hooks/done-hook_test.sh` | 263 | 10504 | Hook test | active |
| hooks/ | `~/.claude/hooks/enforce-worktree_test.sh` | 55 | 1938 | Hook test | active |
| hooks/ | `~/.claude/hooks/permission-denied_test.sh` | 45 | 1546 | Hook test | active |
| hooks/ | `~/.claude/hooks/pre-compact-context_test.sh` | 59 | 2360 | Hook test | active |
| hooks/ | `~/.claude/hooks/session-goal-init.sh` | 24 | 760 | SessionStart | active |
| hooks/ | `~/.claude/hooks/session-goal-init_test.sh` | 61 | 1995 | Hook test | active |
| hooks/ | `~/.claude/hooks/test-dep-map.sh` | 173 | 5801 | helper | active |
| hooks/ | `~/.claude/hooks/test-dep-map_test.sh` | 343 | 10595 | Hook test | active |
| hooks/ | `~/.claude/hooks/validate-recommendation.sh` | 122 | 4955 | helper | active |
| hooks/ | `~/.claude/hooks/validate-recommendation_test.sh` | 160 | 6506 | Hook test | active |
| hooks/ | (6 `.bak` files in `~/.claude/hooks/`) | — | — | Stale backup | flagged: delete |
| skills/ | `~/.claude/skills/cfo/SKILL.md` | 75 | 5111 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/cfo-dcf/SKILL.md` | 149 | 7473 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/cfo-earnings-review/SKILL.md` | 179 | 6521 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/cfo-rebalance/SKILL.md` | 78 | 5421 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/cfo-rsu-decision/SKILL.md` | 115 | 6592 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/cfo-state-refresh/SKILL.md` | 80 | 4686 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/cfo-tax-check/SKILL.md` | 98 | 4713 | Skill (local) | flagged: relocate (private skill, locked-decision) |
| skills/ | `~/.claude/skills/done/SKILL.md` | 37 | 1681 | Skill (local) | active |
| skills/ | `~/.claude/skills/eureka/SKILL.md` | 48 | 1275 | Skill (local) | active |
| skills/ | `~/.claude/skills/gh-activity-gather/SKILL.md` | 278 | 12088 | Skill (local) | active |
| skills/ | `~/.claude/skills/gh-jira-activity/SKILL.md` | 155 | 7482 | Skill (local) | active |
| skills/ | `~/.claude/skills/go-review/SKILL.md` | 39 | 1018 | Skill (local) | active |
| skills/ | `~/.claude/skills/goal/SKILL.md` | 39 | 1229 | Skill (local) | active |
| skills/ | `~/.claude/skills/handoff/SKILL.md` | 177 | 7280 | Skill (local) | active |
| skills/ | `~/.claude/skills/k8s-debug/SKILL.md` | 72 | 1912 | Skill (local) | active |
| skills/ | `~/.claude/skills/managing-omnistation/SKILL.md` | 65 | 2184 | Skill (local) | active |
| skills/ | `~/.claude/skills/nvinfo-cli/SKILL.md` | 282 | 9240 | Skill (local) | active |
| skills/ | `~/.claude/skills/pr-review-ingest/SKILL.md` | 35 | 1351 | Skill (local) | active |
| skills/ | `~/.claude/skills/reflection/SKILL.md` | 60 | 2375 | Skill (local) | active |
| skills/ | `~/.claude/skills/tdd-protocol/SKILL.md` | 42 | 2053 | Skill (local) | active |
| skills/ | `~/.claude/skills/team-execute/SKILL.md` | 116 | 4131 | Skill (local) | active |
| skills/ | `~/.claude/skills/team-plan/SKILL.md` | 76 | 3302 | Skill (local) | active |
| skills/ | `~/.claude/skills/team-shutdown/SKILL.md` | 91 | 3708 | Skill (local) | active |
| skills/ | `~/.claude/skills/validate-recommendation/SKILL.md` | 364 | 13605 | Skill (local) | active |
| skills/ | `~/.claude/skills/worktree-guide/SKILL.md` | 36 | 1569 | Skill (local) | active |
| agents/ | `~/.claude/agents/doc-writer.md` | 26 | 628 | Agent definition | active |
| agents/ | `~/.claude/agents/explorer.md` | 23 | 595 | Agent definition | active |
| agents/ | `~/.claude/agents/principal-engineer.md` | 49 | 1421 | Agent definition | active |
| agents/ | `~/.claude/agents/qa-engineer.md` | 132 | 5520 | Agent definition | active |
| commands/ | `~/.claude/commands/team-execute.md` | 177 | 13511 | Slash command | active |
| commands/ | `~/.claude/commands/team-plan.md` | 71 | 4228 | Slash command | active |
| commands/ | `~/.claude/commands/team-shutdown.md` | 84 | 3189 | Slash command | active |
| **Auto-loaded surface total** | (CLAUDE.md + rules/) | 218 | 11084 | Pre-loaded every session | baseline |
| **Skill descriptions total** | (25 skills) | — | 7103 | Pre-loaded every session | baseline |

## 2. Findings

### 2.1 CLAUDE.md

#### F-CLAUDEMD-01 — TDD enforcement language references a removed hook
- **Severity:** P0
- **Token impact:** ~140 tokens/session (6 lines × ~23 tokens/line, Opus 4.7 assumption)
- **Friction:** high
- **Confidence:** high
- **Effort:** trivial
- **Current state:** Lines 30 and 40 frame TDD as "enforced by hook": `"Workers: implementation in isolated worktrees (TDD enforced by tdd-guard.sh hook on all Write/Edit, both team and solo paths)"` and the section heading `"## TDD Protocol (enforced by hook)"`. The `tdd-guard.sh` removal is a locked decision (2026-05-25). Every session loads instructions that describe a hook that no longer exists, causing confusion and false mental overhead when the hook does not fire.
- **Recommended fix:** Remove `"enforced by tdd-guard.sh hook"` from line 30. Rewrite the section heading on line 40 to `"## TDD Protocol"`. Replace the body text (lines 41-44) with: `"TDD is the default for production code paths. Red → Green → Refactor. Opt out for docs, install scripts, or exploratory work. Theater tests are a blocking issue — see constitution.md."` Delete the `"See /tdd-protocol for full details"` pointer; the inline text is sufficient for this section and the full skill is invocable on demand.
- **Evidence:** `~/.claude/CLAUDE.md:30,40-44`; spec §4.4 (TDD-guard removal mechanics); spec §6.4 (locked decision traceability).

#### F-CLAUDEMD-02 — TDD section partially duplicates constitution.md (auto-loaded)
- **Severity:** P1
- **Token impact:** ~60 tokens/session (3 lines duplicated at ~20 tokens/line)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** CLAUDE.md lines 42-43 read `"Tests are contracts: if a test fails, fix the implementation (unless the test has a genuine bug). Change tests and implementation in separate turns; commit them in separate commits."` These two rules are also in `~/.claude/rules/constitution.md` lines 18-19 (`"## Implementation Discipline"`), which auto-loads every session. The content is loaded twice every session.
- **Recommended fix:** After applying F-CLAUDEMD-01's rewrite, keep only the opt-out scope note and the theater-test pointer in CLAUDE.md's TDD section. Delete the implementation-discipline sentences; they are already authoritative in constitution.md.
- **Evidence:** `~/.claude/CLAUDE.md:42-43`; `~/.claude/rules/constitution.md:17-19`; spec §3.1 (redundancy with rules/).

#### F-CLAUDEMD-03 — Execution Model section embeds detail better owned by team-execute skill
- **Severity:** P2
- **Token impact:** ~180 tokens/session (8 lines of role descriptions × ~22 tokens/line)
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** Lines 27-38 describe the team path roles verbatim: Principal Engineer responsibilities, QA Engineer responsibilities, Workers producing draft PRs, QA promoting to ready-for-review, and DE rejection mechanics. This detail is redundant with the `team-execute` skill body (116 lines, loaded on demand). The CLAUDE.md level needs only the routing rule ("when to use team vs solo"), not the team's internal role definitions.
- **Recommended fix:** Collapse lines 27-38 to: `"**Team path** (/team-execute) — >=2 source files or design decisions. **Solo path** (superpowers:executing-plans) — single-file fixes, config, docs, debugging."` The role definitions, PR promotion protocol, and DE rejection mechanics stay in the team-execute skill where they are loaded only when a team session starts.
- **Evidence:** `~/.claude/CLAUDE.md:27-38`; `~/.claude/skills/team-execute/SKILL.md` (116 lines); spec §3.1 (signal density).

#### F-CLAUDEMD-04 — Iteration Budget section is dead text: not referenced downstream
- **Severity:** P2
- **Token impact:** ~22 tokens/session (1 line × ~22 tokens)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** Line 51 reads `"Trivial:1 | Simple:2 | Moderate:3 | Complex:4 iterations before escalating to the user."` No skill, rule, agent definition, or hook references this taxonomy by name. It has no enforcement path and no consumer; it is a label without a mechanism.
- **Recommended fix:** Delete lines 50-51 (`## Iteration Budget` heading and its single content line). If the escalation discipline is worth preserving, promote it to a bullet under `## Principles` where it has weight, or delete entirely and rely on user-in-the-loop review.
- **Evidence:** `~/.claude/CLAUDE.md:50-51`; confirmed no downstream references in `~/.claude/skills/`, `~/.claude/rules/`, or `~/.claude/agents/` via grep.

#### F-CLAUDEMD-05 — Missing gh CLI permission note (P0 action item from spec)
- **Severity:** P1
- **Token impact:** 0 tokens (content addition, not removal — but saves retry friction)
- **Friction:** medium
- **Confidence:** high
- **Effort:** trivial
- **Current state:** CLAUDE.md contains no note that `gh` CLI calls are pre-approved in `settings.json`. When the model or a subagent encounters a `gh *` command, it applies the default heuristic of trying sandbox-first, fails, then retries with `dangerouslyDisableSandbox: true`. This generates a permission prompt and wastes ~1-2 turns per gh invocation.
- **Recommended fix:** Add a line under `## Principles` or as a standalone bullet: `"gh CLI is pre-approved; never retry sandboxed-first for gh commands."` Spec §5.P0 item 6 documents this as a P0 quick win.
- **Evidence:** `~/.claude/CLAUDE.md` (no gh mention); `~/.claude/settings.json` (`"Bash(gh *)"` in allow list); spec §5 P0 item 6 lists the underlying action as a P0 quick-win in settings.json; this CLAUDE.md gap is rated P1 because the gap itself is documentation-only friction, not a config-correctness issue.

#### F-CLAUDEMD-06 — "Verify before claiming" principle is redundant with Stop-hook prompt (pending P0 removal)
- **Severity:** P2
- **Token impact:** 0 tokens now; becomes a correctness gap if Stop-hook is deleted without this principle surviving
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** CLAUDE.md line 17 states `"Verify before claiming: any response asserting task completion must contain the output of a verification command…"`. The Stop hook in `settings.json` (lines 175-187) fires a `"type": "prompt"` LLM call on every turn end that enforces the same rule mechanically. Both cover identical ground. The Stop-hook is a P0 removal candidate (spec §4.1); if it is removed, line 17 becomes the sole enforcement mechanism and must survive. If it is retained after P0, the two layers remain redundant.
- **Recommended fix:** Retain line 17 regardless of Stop-hook fate — it is cheap (single line) and becomes the sole safeguard if the hook is removed. When the Stop-hook is removed in P0, add a parenthetical: `"(no hook enforces this — it is enforced by discipline and user review)"` to make the intent explicit. No token impact change.
- **Evidence:** `~/.claude/CLAUDE.md:17`; `~/.claude/settings.json:175-187`; spec §4.1 (Stop-hook LLM prompt cost).

### 2.2 rules/
### 2.3 settings.json
### 2.4 hooks
### 2.5 skills
### 2.6 agents
### 2.7 plugins enabled
### 2.8 meta-skills (router / gating patterns — currently empty; finding describes the gap)

## 3. Cross-cutting themes

### 3.1 Stop-hook LLM prompt cost
### 3.2 Cache-TTL regression (1h → 5m)
### 3.3 Opus 4.7 tokenizer expansion (~35%)
### 3.4 TDD-guard removal — mechanics
### 3.5 CFO skill relocation — mechanics
### 3.6 Worktrees: experimental flag vs official GA
### 3.7 Security posture
### 3.8 Plan-routing via cheap classifier (new)

## 4. Phased action plan

### 4.1 P0 — Quick wins
### 4.2 P1 — Structural
### 4.3 P2 — Polish

## 5. Validation gate
