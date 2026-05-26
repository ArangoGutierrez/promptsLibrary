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
