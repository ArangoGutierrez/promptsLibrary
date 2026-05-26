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

#### F-RULES-01 — rules/ auto-load surface: ~2.9 K tokens every session
- **Severity:** P1
- **Token impact:** ~2,900 tokens/session (153 lines × ~19 tokens/line average, 7 files)
- **Friction:** high
- **Confidence:** high
- **Effort:** small
- **Current state:** All 7 files in `~/.claude/rules/` are auto-loaded every session by Claude Code. Total surface is 153 lines / 8,039 bytes. At ~19 tokens/line this costs ~2,900 tokens before the first user message arrives, on top of CLAUDE.md's ~1,200 tokens. The combined auto-loaded surface is ~4,100 tokens, and several findings below show a material fraction of that is duplicate content already present elsewhere in the auto-loaded set.
- **Recommended fix:** Apply the per-file fixes in F-RULES-02 through F-RULES-06. After those are done, re-measure: target ≤100 lines total across all rules/ files, eliminating duplicate content that is also in CLAUDE.md or a sibling rules/ file. Set an enforced per-file ceiling of 50 lines.
- **Evidence:** `~/.claude/rules/` (all 7 files); `cat ~/.claude/rules/*.md | wc -l -c` → `153 / 8039`; spec §1 (auto-load cost rubric) and §5 P1 item 3.

#### F-RULES-02 — constitution.md "Implementation Discipline" duplicates CLAUDE.md "TDD Protocol"
- **Severity:** P1
- **Token impact:** ~40 tokens/session (2 duplicate lines × ~20 tokens/line)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `constitution.md` lines 17-19 contain `## Implementation Discipline` with two bullets: `"When a test fails, fix the implementation. Modify the test only when the test itself has a genuine bug."` and `"Change tests and implementation in separate turns and separate commits."` CLAUDE.md lines 41-43 contain the `## TDD Protocol` section which includes: `"Tests are contracts: if a test fails, fix the implementation (unless the test has a genuine bug)."` and `"Change tests and implementation in separate turns; commit them in separate commits."` Both files are auto-loaded; this rule is loaded twice every session.
- **Recommended fix:** Delete `## Implementation Discipline` (lines 17-19) from `constitution.md`. The rule is authoritative in CLAUDE.md. If F-CLAUDEMD-01 strips the "enforced by hook" language from CLAUDE.md, the TDD Protocol section remains the canonical home for this rule.
- **Evidence:** `~/.claude/rules/constitution.md:17-19`; `~/.claude/CLAUDE.md:41-43`; see also F-CLAUDEMD-02.

#### F-RULES-03 — constitution.md "Theater Tests" partially duplicates learned-anti-patterns.md
- **Severity:** P1
- **Token impact:** ~180 tokens/session (9 lines of theater-test content in constitution.md vs 1 line summary in learned-anti-patterns.md — both auto-loaded)
- **Friction:** medium
- **Confidence:** high
- **Effort:** small
- **Current state:** `constitution.md` devotes 9 lines (5-10, 12-15, 21-24) across three sections to theater-test rules. `learned-anti-patterns.md` line 8 contains the same root problem as a structured pattern entry: `"Pattern: Theater tests — tautological assertions, missing assertions, over-mocking | Fix: Delete and rewrite…"`. The two files approach the same failure mode from different angles (detailed rules vs. curated pattern log), but the overlap means the model receives the theater-test warning twice every session in different phrasings, diluting each.
- **Recommended fix:** Keep `constitution.md` as the authoritative detailed rules source for theater tests (it has the highest signal density). Remove the theater-test entry from `learned-anti-patterns.md` line 8, since it is fully covered by constitution.md. `learned-anti-patterns.md` should record patterns NOT already in constitution.md — new emergence, not restatement.
- **Evidence:** `~/.claude/rules/constitution.md:5-15,21-24`; `~/.claude/rules/learned-anti-patterns.md:8`; spec §1 (redundancy across rules/).

#### F-RULES-04 — security.md Containers section duplicates container-conventions.md Security section
- **Severity:** P1
- **Token impact:** ~60 tokens/session (3 duplicate lines × ~20 tokens/line)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `security.md` lines 12-14 read: `"No --privileged/hostPID/hostNetwork without documented threat model"` and `"Drop all caps, add back only needed."` `container-conventions.md` lines 11 and 13 cover the same ground: `"No --privileged, no hostPID, no hostNetwork unless documented with justification"` and `"Scan images with trivy before push; block on critical/high CVEs"`. The `trivy` rule also appears in `security.md` line 8. Three distinct instances of the no-privileged rule and two instances of the trivy rule exist across auto-loaded files.
- **Recommended fix:** Delete `## Containers` section (lines 12-14) from `security.md`. Container security is owned by `container-conventions.md`. Keep the `trivy` scan reference only in `security.md` line 8 (SAST & Supply Chain context) and remove the duplicate from `container-conventions.md` line 13, or vice versa — one source of truth for each tool rule.
- **Evidence:** `~/.claude/rules/security.md:8,12-14`; `~/.claude/rules/container-conventions.md:11,13`; spec §1 (redundancy across rules/).

#### F-RULES-05 — security.md RBAC rule duplicates k8s-conventions.md RBAC rule
- **Severity:** P2
- **Token impact:** ~20 tokens/session (1 duplicate line × ~20 tokens)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `security.md` line 17: `"Namespaced Role over ClusterRole. One SA per workload, never default."` `k8s-conventions.md` line 16: `"Namespaced Role over ClusterRole. +kubebuilder:rbac markers. Audit ClusterRoleBindings."` Both files auto-load every session. The namespaced-Role-over-ClusterRole rule appears twice; the two versions have different addenda (SA constraint vs. kubebuilder markers) but share the same core dictum, which means neither is fully authoritative.
- **Recommended fix:** Merge both lines into `k8s-conventions.md` line 16: `"Namespaced Role over ClusterRole; one SA per workload, never default. +kubebuilder:rbac markers. Audit ClusterRoleBindings."` Delete `## RBAC` section (lines 16-17) from `security.md`.
- **Evidence:** `~/.claude/rules/security.md:16-17`; `~/.claude/rules/k8s-conventions.md:15-16`; spec §1 (redundancy across rules/).

#### F-RULES-06 — git-workflow.md mentions agents-workbench in same terms as CLAUDE.md
- **Severity:** P2
- **Token impact:** ~20 tokens/session (1 line × ~20 tokens)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `git-workflow.md` line 12: `"agents-workbench is the coordination branch — read-only for source code"`. CLAUDE.md line 47: `"Implementation happens in worktrees. agents-workbench is read-only for source code; writes are blocked by enforce-worktree.sh."` CLAUDE.md line 59: `"Commit context to agents-workbench before ending long sessions."` The agents-workbench read-only constraint is stated in both auto-loaded files.
- **Recommended fix:** Remove line 12 from `git-workflow.md`. The constraint is already authoritative in CLAUDE.md and is enforced by `enforce-worktree.sh`. The git-workflow.md file should remain focused on commit format, branch naming, PR process, and review protocol — all of which are absent from CLAUDE.md.
- **Evidence:** `~/.claude/rules/git-workflow.md:12`; `~/.claude/CLAUDE.md:47`; spec §1 (redundancy with CLAUDE.md).

### 2.3 settings.json

#### F-SETTINGS-01 — Stop hook `"type": "prompt"` fires an LLM round-trip on every turn end
- **Severity:** P0
- **Token impact:** ~9,000–24,000 tokens/session (~300–800 tokens × ~30 turns/session: input prompt + output "OK"/"STOP" response)
- **Friction:** high
- **Confidence:** high
- **Effort:** small
- **Current state:** `hooks.Stop[0].hooks[0]` has `"type": "prompt"` with a 395-character / ~99-token verification check. This fires a separate LLM call at the end of every turn to ask "did the assistant just claim completion without running verification?" The binary yes/no output costs a full model round-trip, adding perceptible latency and burning hundreds of tokens per turn. With Opus 4.7 at ~35% tokenizer expansion vs prior models, the per-turn cost is higher than legacy estimates assumed. The same discipline is already expressed in CLAUDE.md line 17 ("Verify before claiming") and in `constitution.md` (Test Quality Gate section).
- **Recommended fix:** Replace `hooks.Stop[0]` (the prompt-type entry) with a command-type hook that runs a fast regex against the response text: `grep -qiE "(tests pass|complete|fixed|it works)" "$CLAUDE_LAST_RESPONSE"` and exits non-zero only if no `Bash(go test|make test|build)` command was run in the last turn. Alternatively, delete the entry entirely and rely on the CLAUDE.md principle plus user review. The command hook path costs ~5 tokens (environment variable, no LLM call). If the user wants to keep the check, budget ~200 tokens/turn instead of ~600 by capping the prompt to 1 sentence: `"Did the assistant just claim completion? If yes and no test/build output was shown, respond STOP. Otherwise OK."`.
- **Evidence:** `~/.claude/settings.json` `hooks.Stop[0].hooks[0].type = "prompt"`; spec §4.1 (Stop-hook LLM prompt cost, P0 action item); `~/.claude/CLAUDE.md:17`; `~/.claude/rules/constitution.md` Test Quality Gate.

#### F-SETTINGS-02 — `gh` CLI sandbox resolution path generates unnecessary friction
- **Severity:** P1
- **Token impact:** ~100–200 tokens/session (1-2 retry turns × ~100 tokens each, on sessions that invoke gh)
- **Friction:** medium
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `permissions.allow` contains `"Bash(gh *)"` (index 4) and `sandbox.autoAllowBashIfSandboxed = true`. This means `gh` commands are already pre-approved and will execute without a permission prompt. However, CLAUDE.md and rules/ contain no explicit note that `gh *` is pre-approved. Subagents and the model itself may still apply a "sandbox-first, retry unsandboxed" heuristic for `gh` commands if the allow-list entry is not part of the loaded context. The settings config is correct; the gap is in CLAUDE.md documentation (see F-CLAUDEMD-05).
- **Recommended fix:** The `settings.json` side is correctly configured — no change needed here. Add documentation to CLAUDE.md (tracked as F-CLAUDEMD-05): `"gh CLI is pre-approved via permissions.allow; never retry sandboxed-first."` Optionally consolidate the gh-related allow entries (`"Bash(gh *)"`) immediately after git entries to signal intent more clearly to human readers.
- **Evidence:** `~/.claude/settings.json` `permissions.allow[4] = "Bash(gh *)"`, `sandbox.autoAllowBashIfSandboxed = true`; spec §5 P0 item 6; F-CLAUDEMD-05 (documentation gap).

#### F-SETTINGS-03 — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is an deprecated env var path
- **Severity:** P1
- **Token impact:** N/A (no direct token cost — indirect risk of deprecated behavior)
- **Friction:** medium
- **Confidence:** medium
- **Effort:** small
- **Current state:** `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` enables the experimental agent-teams feature. Official Claude Code docs (2026) now ship `isolation: worktree` as the GA path for subagent isolation, and `teammateMode: in-process` is also set. The experimental flag predates the GA worktree isolation path and may be co-existing with it, deprecated, or redundant. Running stale experimental flags risks undocumented behavior changes as the flag is phased out. The `isolation` key is absent from `settings.json` (`has("isolation") = false`), suggesting the GA worktree path has not been adopted yet.
- **Recommended fix:** Verify with official Claude Code release notes whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is still required alongside `teammateMode: in-process`. If the GA path is `isolation: worktree` on individual subagent definitions (in `agents/*.md`), add that field to each agent definition and remove the env var. Update `team-execute` skill and `worktree-guide` skill accordingly. This is the P1 migration tracked in spec §4.6 and §5 P1 item 2.
- **Evidence:** `~/.claude/settings.json` `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`, `teammateMode = "in-process"`, `has("isolation") = false`; spec §4.6 (Worktrees: experimental flag vs GA); spec §5 P1 item 2.

#### F-SETTINGS-04 — `clangd-lsp` plugin enabled for a Go/Kubernetes engineer
- **Severity:** P2
- **Token impact:** ~200–500 tokens/session (LSP plugin loads tool definitions into every session)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `enabledPlugins` contains `"clangd-lsp@claude-plugins-official": true`. `clangd` is a C/C++/Objective-C language server. The primary workload is Go/Kubernetes, and side projects are Node.js/GitHub Pages — neither uses C/C++. The `gopls-lsp` plugin (also enabled) is the correct LSP for Go. `clangd-lsp` loads tool schemas and potentially LSP tooling into every session regardless of whether C/C++ files are present.
- **Recommended fix:** Set `"clangd-lsp@claude-plugins-official": false` in `enabledPlugins`. If C/C++ work occasionally arises (e.g., a CUDA kernel or NCCL patch), re-enable it per-project via a project-scoped `.claude/settings.json`. This is the P2 polish item in spec §5 P2 item 3.
- **Evidence:** `~/.claude/settings.json` `enabledPlugins["clangd-lsp@claude-plugins-official"] = true`; primary workload is Go/K8s, side projects are Node.js; `gopls-lsp` already enabled; spec §3.7 (plugins enabled) and §5 P2 item 3.

#### F-SETTINGS-05 — `effortLevel: "high"` applies maximum token budget globally
- **Severity:** P1
- **Token impact:** ~15–30% token overhead per response on non-complex tasks (extended thinking activated on tasks that don't need it)
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** `effortLevel = "high"` sets the global effort level, which on Opus 4.7 activates extended-thinking mode for most tasks. While appropriate for complex architecture and debugging sessions, it applies the same budget to trivial tasks (documentation edits, git operations, config tweaks). With Opus 4.7's 35% tokenizer expansion, "high" effort on simple tasks compounds cost further. No per-task override mechanism is documented in CLAUDE.md.
- **Recommended fix:** Evaluate lowering to `"medium"` as the global default. Add a comment in CLAUDE.md or the skills that invoke heavy analysis (team-plan, architecture) to note they can request `effortLevel: high` via the session override mechanism. Alternatively, keep "high" but add a `Bash(* --help)` and `Bash(* --version)` exclusion path in CLAUDE.md to suppress extended thinking for trivial commands. Measure actual extended-thinking activation rate in a representative session before and after.
- **Evidence:** `~/.claude/settings.json` `effortLevel = "high"`; spec §1 (effort cost rubric); spec §4.3 (Opus 4.7 tokenizer expansion ~35%).

#### F-SETTINGS-06 — `model: "opus[1m]"` and 5-minute cache TTL regression interact badly
- **Severity:** P1
- **Token impact:** ~5,000–15,000 tokens/session (cold-cache re-read of CLAUDE.md + rules on sessions with >5min idle gaps)
- **Friction:** medium
- **Confidence:** high
- **Effort:** small
- **Current state:** `model = "opus[1m]"` requests the 1-million-token context window variant of Opus. Cache TTL silently regressed from 1h to 5min default in March 2026. The 1M context window combined with the 5min TTL means any idle gap (Bash command running, user thinking, `sleep` in a hook) causes the large auto-loaded surface (CLAUDE.md + 7 rules files + skill descriptions = ~4,100 tokens) to be re-read as a cold-cache write. At Opus pricing, cold-cache writes cost ~3–5x cached reads. Sessions with multiple idle gaps effectively lose the cache benefit entirely.
- **Recommended fix:** Three actions: (a) Apply findings F-CLAUDEMD-01 through F-RULES-06 to reduce the auto-loaded surface by ≥25% first — smaller surface = lower cold-cache cost. (b) For long-running team-execute sessions, document the explicit 1h-TTL opt-in: add cache-control markers to CLAUDE.md sections that are stable across a session (Principles, Workflow — but not TDD/tool-specific sections that change with P0). (c) Audit hook scripts for unnecessary Bash `sleep` calls that idle the cache without benefit (cross-ref F-HOOK findings).
- **Evidence:** `~/.claude/settings.json` `model = "opus[1m]"`; spec §4.2 (Cache-TTL regression, 1h→5m); spec §4.3 (Opus 4.7 tokenizer expansion); auto-loaded surface measured at ~4,100 tokens in F-RULES-01.

#### F-SETTINGS-07 — `attribution` block is present but empty
- **Severity:** P2
- **Token impact:** ~5 tokens/session (empty JSON object keys loaded)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `attribution = {"commit": "", "pr": ""}` is present in `settings.json` with both fields as empty strings. This block is a Claude Code feature for tagging generated content with commit and PR references. With both fields empty, it provides no value — it adds two empty JSON keys to the settings payload without populating attribution metadata. There is no observable behavior difference from removing the block.
- **Recommended fix:** Either populate the fields with meaningful values (`"commit": "auto"` to auto-tag with the current commit hash, if the feature supports it) or remove the empty `attribution` block entirely. If the feature is experimental or unused, deletion is the cleaner path. Check Claude Code docs for whether `"auto"` is a valid value for commit attribution before committing either choice.
- **Evidence:** `~/.claude/settings.json` `attribution = {"commit": "", "pr": ""}`; no downstream reference to the attribution block in any hook, skill, or rule.

#### F-SETTINGS-08 — `autoMemoryEnabled: true` with no audit trail for auto-saved memory entries
- **Severity:** P2
- **Token impact:** variable (~100–500 tokens/session if auto-memory re-reads stale context)
- **Friction:** low
- **Confidence:** medium
- **Effort:** small
- **Current state:** `autoMemoryEnabled = true` enables automatic context saving by Claude Code. Saved memory entries accumulate in `~/.claude/memory/` (or equivalent) and are re-loaded in future sessions. Without periodic review, stale, contradictory, or low-signal entries accumulate and add to the per-session token cost. The `consolidate-memory` skill exists (`anthropic-skills:consolidate-memory`) but requires manual invocation — there is no scheduled or session-triggered audit of the memory store. The `autoMemoryEnabled` flag also interacts with `mempalace` (MCP tool present in available tools list), creating potential for duplicate storage.
- **Recommended fix:** Add a SessionStart hook entry that runs `~/.claude/hooks/memory-staleness.sh` (analogous to `reflection-staleness.sh`) to detect if the auto-memory store has not been consolidated in >30 days, and prompt the user. Alternatively, schedule `anthropic-skills:consolidate-memory` as a monthly cron via `mcp__scheduled-tasks__create_scheduled_task`. Review the interaction with `mempalace` to avoid duplicate storage paths.
- **Evidence:** `~/.claude/settings.json` `autoMemoryEnabled = true`; `hooks.SessionStart` contains `reflection-staleness.sh` but no memory-staleness equivalent; `anthropic-skills:consolidate-memory` is available in skills list but not scheduled.

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
