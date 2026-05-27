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

**Summary:** 15 active hook scripts registered across 7 event types (SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, PermissionDenied, plus unregistered helpers). 6 `.bak` files in `~/.claude/hooks/` are iteration debris. `tdd-guard.sh` is locked for removal per spec §4.4. The Stop hook includes a `"type": "prompt"` entry that spawns a full Claude inference pass on every stop event. `validate-recommendation.sh` triggers via `AskUserQuestion` hook and writes to `~/.claude/panel/work/` which is outside the sandbox writable paths.

Total registered SessionStart output measured: **504 bytes** (inject-date.sh: 400 bytes; reflection-staleness.sh: 104 bytes; session-goal-init.sh: 0 bytes when transcript absent). `mempalace-wake.sh` (6803 bytes) is present in `~/.claude/hooks/` but is **not registered** in settings.json.

---

#### F-HOOK-01 — Stale `.bak` iteration-debris files in hooks directory
- **Severity:** P2
- **Token impact:** N/A (not loaded by runtime, but pollutes the directory and confuses audits)
- **Friction:** low (noise; any grep across hooks/ picks up stale logic)
- **Confidence:** high
- **Effort:** trivial
- **Current state:** Six backup files were created during iterative hook development and never removed: `tdd-guard.sh.bak-pre-electron-glue-exemption`, `tdd-guard.sh.bak-pre-mirror-tree-edit`, `tdd-guard.sh.bak-pre-openkurama-additions`, `tdd-guard.sh.bak-pre-worktree-fix`, `enforce-worktree.sh.bak-pre-outside-repo-fix`, and `test-quality-lint.sh.bak-pre-architect-edit`. They are not registered in settings.json and serve no operational purpose. They also preserve older, less-correct versions of logic (pre-electron-glue-exemption, pre-worktree-fix) that would be confusing if re-activated by accident.
- **Recommended fix:** `rm ~/.claude/hooks/*.bak*` — all six files. The canonical versions are the live `.sh` scripts; git history preserves all prior revisions. Since `tdd-guard.sh` is being removed (F-HOOK-02), its four `.bak` siblings are superseded entirely.
- **Evidence:** `~/.claude/hooks/tdd-guard.sh.bak-pre-electron-glue-exemption` (8376 bytes, 2026-05-04), `~/.claude/hooks/tdd-guard.sh.bak-pre-mirror-tree-edit` (6936 bytes, 2026-04-28), `~/.claude/hooks/tdd-guard.sh.bak-pre-openkurama-additions` (6376 bytes, 2026-04-28), `~/.claude/hooks/tdd-guard.sh.bak-pre-worktree-fix` (7363 bytes, 2026-04-28), `~/.claude/hooks/enforce-worktree.sh.bak-pre-outside-repo-fix` (2539 bytes), `~/.claude/hooks/test-quality-lint.sh.bak-pre-architect-edit` (6322 bytes).

---

#### F-HOOK-02 — `tdd-guard.sh` locked for removal — settings.json must be updated
- **Severity:** P1
- **Token impact:** ~100 tokens per Write/Edit tool call (script exec overhead + stderr on false-positive blocks)
- **Friction:** high (false-positive blocks on valid implementation writes; 229 lines of exemption case-statements that keep growing)
- **Confidence:** high
- **Effort:** small
- **Current state:** `tdd-guard.sh` (229 lines, 9438 bytes) is registered in `settings.json` at **two** separate locations: `PreToolUse.Write` (line 123) and `PreToolUse.Edit` (line 136). The script enforces Red-Green-Refactor by blocking implementation writes when no test file is recently changed. Per spec §4.4, this is a locked decision for removal: the exemption list (lines 52–137) has grown to cover most real file types and the guard fires on legitimate writes regularly enough to cause workflow friction without catching actual TDD violations in practice. Four `.bak` variants (F-HOOK-01) document repeated scope-creep iterations.
- **Recommended fix:** (1) Remove both `tdd-guard.sh` entries from `~/.claude/settings.json` (lines 119–124 and 132–138, the `Write` and `Edit` hook lists). (2) Delete `~/.claude/hooks/tdd-guard.sh`. (3) Delete all four `tdd-guard.sh.bak-*` files (covered by F-HOOK-01). TDD discipline is enforced by the `/tdd-protocol` skill and CLAUDE.md wording — the hook is not needed. Verify: no `tdd-guard` references remain in `settings.json` after edit.
- **Evidence:** `~/.claude/settings.json:123`, `~/.claude/settings.json:136`; spec §4.4 (locked decision); `~/.claude/hooks/tdd-guard.sh:52–137` (exemption list length); four `.bak` files documenting repeated fixes.

---

#### F-HOOK-03 — Stop hook `"type": "prompt"` — full LLM inference on every session stop
- **Severity:** P0
- **Token impact:** ~800–1200 tokens per stop event (prompt: 395 chars + transcript tail injected as context; response: short but model must read the prompt and generate `OK` or `STOP: …`)
- **Friction:** medium (adds latency to every stop; occasionally blocks valid responses when the model misclassifies the conversation)
- **Confidence:** high
- **Effort:** small
- **Current state:** `~/.claude/settings.json:179–180` registers a `"type": "prompt"` Stop hook with a 395-character prompt that re-reads the transcript and checks for unverified completion claims. This fires on **every** stop event, including mid-session tool-use stops. Unlike `"type": "command"` hooks (which run a script), `"type": "prompt"` hooks spawn a second Claude inference pass, incurring ~800–1200 tokens. This is the primary driver of the P0 cost finding documented in **F-SETTINGS-01**; this finding captures the hook-side mechanics.
- **Recommended fix:** Replace the `"type": "prompt"` entry with a `"type": "command"` hook (`verify-completion.sh`) that uses `grep`/`jq` to heuristically detect unverified claims in the last assistant message text — no LLM call needed. If the heuristic fires, it should exit 2 with a message directing the user to run verification manually. This is the approach analyzed in the spec §3.1 cross-cutting theme. See **F-SETTINGS-01** for the full cost analysis and recommended replacement.
- **Evidence:** `~/.claude/settings.json:179–180` (`"type": "prompt"`); Stop hook prompt text (395 chars); cross-ref **F-SETTINGS-01**; spec §3.1.

---

#### F-HOOK-04 — `validate-recommendation.sh` writes verdict files to `~/.claude/panel/work/` — sandbox-write friction
- **Severity:** P0
- **Token impact:** N/A (correctness issue, not token cost)
- **Friction:** high (hook and skill silently fail when sandbox blocks the write; panel dispatch appears to succeed but no verdict file is written, causing the skill to fall back on error path every time)
- **Confidence:** high
- **Effort:** small
- **Current state:** `validate-recommendation.sh` is **not registered** in `settings.json` (it is a helper invoked by the harness AskUserQuestion hook path). The skill's `SKILL.md:89` instructs Claude to create `WORKDIR="${HOME}/.claude/panel/work/${CLAUDE_SESSION_ID:-$PPID}"` and write per-panelist `.verdict` files there. The path `~/.claude/panel/work/` is outside the sandbox write-allowed paths (sandbox allows `$TMPDIR`, `.`, and `/tmp/claude` variants). During the brainstorm for this audit, a live friction incident was observed: the panel dispatch completed but the skill could not read verdict files because the write had been silently blocked by the sandbox. The hook itself uses `$TMPDIR` correctly for the state file (line 58–59), but the skill's WORKDIR is not sandbox-safe.
- **Recommended fix:** Two-track edit: (1) In `SKILL.md:89`, change `WORKDIR="${HOME}/.claude/panel/work/..."` to `WORKDIR="${TMPDIR:-/tmp}/claude-panel-work/${CLAUDE_SESSION_ID:-$PPID}"` — uses `$TMPDIR`, which is always sandbox-writable. (2) Add `~/.claude/panel/work` to the project sandbox `write.allowOnly` list in `settings.json` as a belt-and-suspenders fallback. The `TMPDIR`-based path is the primary fix; the allowlist entry guards against any remaining hardcoded references. Cross-ref: `~/.claude/panel/config.yml` and `config.yml.bak`/`config.yml.smoke-bak` (two additional `.bak` files in the panel dir that should also be cleaned up).
- **Evidence:** `~/.claude/skills/validate-recommendation/SKILL.md:89` (`WORKDIR="${HOME}/.claude/panel/work/..."`); `~/.claude/skills/validate-recommendation/README.md:221,276,303` (hardcoded `~/.claude/panel/work/` path); sandbox policy (write allowOnly excludes `~/.claude/panel/`); live friction incident during audit brainstorm (2026-05-25).

---

#### F-HOOK-05 — SessionStart hook aggregate output: 504 bytes per session start
- **Severity:** P1
- **Token impact:** ~126 tokens per session start (504 bytes ÷ 4 bytes/token), plus session-goal-init.sh emits ~60 bytes (~15 tokens) when a goal file is absent
- **Friction:** low (no blocking; purely additive context overhead)
- **Confidence:** high (measured, not estimated)
- **Effort:** trivial
- **Current state:** Three hooks fire on every SessionStart: `inject-date.sh` outputs **400 bytes** (current date + year rule), `reflection-staleness.sh` outputs **104 bytes** (staleness reminder when >7 days since last run), and `session-goal-init.sh` outputs **0 bytes** when transcript path is absent (typically on cold start) or ~60 bytes when goal file is missing. Total registered SessionStart output: **504 bytes** (~126 tokens). This is within acceptable range (spec §2 budget is 500 tokens for SessionStart hooks), but the `inject-date.sh` output contains a verbose rule sentence (3 lines) that could be trimmed. Additionally, `mempalace-wake.sh` exists in `~/.claude/hooks/` (6803 bytes, ~1701 tokens) but is **not registered** in settings.json — if ever registered, it would push SessionStart context well past the budget.
- **Recommended fix:** Current registered output (504 bytes) is borderline acceptable. Trim `inject-date.sh` to emit only `TODAY: <date>\nCURRENT YEAR: <year>\n` (removing the verbose `RULE:` paragraph, which duplicates `inject-date.sh`'s intent already captured in CLAUDE.md). This reduces SessionStart output by ~270 bytes (~68 tokens). Do NOT register `mempalace-wake.sh` without first measuring its actual output under live conditions (it calls a Python subprocess that may produce variable-length drawer content).
- **Evidence:** measured output: `inject-date.sh` = 400 bytes (tested `echo '{}' | inject-date.sh | wc -c`); `reflection-staleness.sh` = 104 bytes; `session-goal-init.sh` = 0 bytes (no transcript); `mempalace-wake.sh` = 6803 bytes (unregistered); `~/.claude/settings.json:81–89` (SessionStart hook list).

---

#### F-HOOK-06 — `probe-approve.sh` is an expired viability probe left in the hooks directory
- **Severity:** P1
- **Token impact:** N/A (not registered)
- **Friction:** low (present but inert; risk if accidentally registered)
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `~/.claude/hooks/probe-approve.sh` (1534 bytes) is a script explicitly commented as `TEMPORARY: remove from settings.json after the probe is complete.` It auto-approves every PreToolUse call by emitting `permissionDecision="allow"` and was written to test whether hook-based permission overrides could bypass enterprise-managed `ask` rules. The probe is complete (the comment implies it was already removed from settings.json — confirmed: not registered). The script remains on disk with no operational purpose and with dangerous semantics (blanket PreToolUse approval). Accidental registration would silently bypass all permission prompts.
- **Recommended fix:** Delete `~/.claude/hooks/probe-approve.sh`. If probe results need to be preserved, they belong in `docs/audits/` as a write-up, not as an executable script in the hooks directory.
- **Evidence:** `~/.claude/hooks/probe-approve.sh:13` (`TEMPORARY: remove from settings.json after the probe is complete`); script not present in `jq '.hooks' ~/.claude/settings.json` output; semantics: `permissionDecisionReason: "probe: auto-approving to test hook override of managed-settings"`.

---

#### F-HOOK-07 — `validate-recommendation.sh` is not registered in settings.json despite being an active system component
- **Severity:** P1
- **Token impact:** N/A (hooks fire via AskUserQuestion path, not direct settings registration)
- **Friction:** medium (discoverability gap; unclear how it is invoked from settings.json audit perspective)
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `validate-recommendation.sh` is described in its header as a `PreToolUse hook for AskUserQuestion` but does not appear in `settings.json` under any event type. The script is 122 lines with a full test suite (`validate-recommendation_test.sh`, 160 lines), a companion skill (`~/.claude/skills/validate-recommendation/`), and active use. It is triggered by the AskUserQuestion tool intercept path rather than direct `PreToolUse` matcher. This architecture means its registration location is not in the standard `hooks` JSON but is implicit in the skill invocation chain — which is not auditable from settings.json alone.
- **Recommended fix:** Add a comment block to `settings.json` (or a companion `hooks/README.md`) documenting that `validate-recommendation.sh` is invoked via the AskUserQuestion intercept path, not via a direct matcher entry. This makes the hook registration model explicit for future auditors. If the AskUserQuestion interception can be expressed as a `PreToolUse` matcher (`"matcher": "AskUserQuestion"`), add it to settings.json for consistency.
- **Evidence:** `~/.claude/hooks/validate-recommendation.sh:1–8` (header describes hook purpose); not present in `jq '.hooks' ~/.claude/settings.json`; companion skill at `~/.claude/skills/validate-recommendation/SKILL.md`.

---

#### F-HOOK-08 — `mempalace-wake.sh` is present in hooks directory but not registered — 6803 bytes of latent SessionStart cost
- **Severity:** P1
- **Token impact:** 1701 tokens per session start if registered (6803 bytes ÷ 4)
- **Friction:** low (currently inert; becomes P0 if registered without review)
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `~/.claude/hooks/mempalace-wake.sh` (2513 bytes on disk, but outputs 6803 bytes at runtime including Python subprocess output for pre-loading critical MemPalace drawers) exists in the hooks directory but is not registered in `settings.json`. The script pre-fetches 3 specific drawer IDs via a Python venv subprocess and outputs their content to session context. If registered as a SessionStart hook, it would add ~1701 tokens to every session start — pushing total SessionStart context from the current 126 tokens to ~1827 tokens, a 14× increase. The script has no `_test.sh` companion.
- **Recommended fix:** Make a deliberate registration decision before adding to settings.json: (1) If MemPalace pre-fetch is desired, add it to SessionStart and establish a token budget limit (recommended: gate output at 500 bytes via truncation). (2) If not needed, delete the file — the MemPalace reminder text at the top of the script (lines 10–17) could be folded into CLAUDE.md instead. Either way, document the decision. Do not leave it as an undecided orphan.
- **Evidence:** `~/.claude/hooks/mempalace-wake.sh` (not in `jq '.hooks.SessionStart' ~/.claude/settings.json`); measured output = 6803 bytes (tested `echo '{}' | mempalace-wake.sh | wc -c`); no `mempalace-wake_test.sh` companion.

---

#### F-HOOK-09 — `tdd-guard.sh` has no test suite (`tdd-guard_test.sh` missing)
- **Severity:** P2
- **Token impact:** N/A
- **Friction:** low (moot given locked removal, but illustrates the gap)
- **Confidence:** high
- **Effort:** trivial (moot — script is being deleted)
- **Current state:** `tdd-guard.sh` is the most complex hook in the directory (229 lines, 9438 bytes) and enforces a critical workflow gate, yet it has no `tdd-guard_test.sh` companion. By contrast, `done-hook.sh` (187 lines) has `done-hook_test.sh` (263 lines, 10504 bytes), and `enforce-worktree.sh` has `enforce-worktree_test.sh`. The absence of tests means the exemption list changes (4 `.bak` files, reflecting 4 iterations) were made without a safety net. This is noted for the record; with the locked removal (F-HOOK-02) this finding is moot operationally.
- **Recommended fix:** No action required — `tdd-guard.sh` is being deleted. For future hook development: any hook >50 lines should have a `_test.sh` companion before being registered. The scripts lacking tests that ARE active: `inject-date.sh`, `auto-format.sh`, `sign-commits.sh`, `prevent-push-workbench.sh`, `validate-year.sh`, `reflection-staleness.sh`, `test-quality-lint.sh`. These are lower-priority but should be addressed incrementally.
- **Evidence:** `ls ~/.claude/hooks/tdd-guard_test.sh` (file absent); `~/.claude/hooks/tdd-guard.sh` (229 lines, registered at `settings.json:123,136`); contrast with `done-hook_test.sh`, `enforce-worktree_test.sh`.

---

#### F-HOOK-10 — `build-helpers.sh` and `test-dep-map.sh` are unregistered helpers with unclear ownership
- **Severity:** P2
- **Token impact:** N/A (not loaded by runtime)
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** `build-helpers.sh` (987 bytes) compiles Go helpers in `hooks/src/` and `hooks/bin/`. `test-dep-map.sh` (5801 bytes) is a dependency-mapping helper called from within `tdd-guard.sh` (line 212). Neither is registered in settings.json as a hook. `test-dep-map.sh` has a full test suite (`test-dep-map_test.sh`, 10595 bytes) but is only useful as a dependency of `tdd-guard.sh`, which is being removed. `build-helpers.sh` has no tests and its build target (`hooks/src/`, `hooks/bin/`) needs review.
- **Recommended fix:** After `tdd-guard.sh` is removed (F-HOOK-02), delete `test-dep-map.sh` and `test-dep-map_test.sh` — they serve only `tdd-guard.sh`. Evaluate whether `build-helpers.sh` and the `hooks/src/`, `hooks/bin/` directory contents are still needed by any active hook; if not, delete them too.
- **Evidence:** `~/.claude/hooks/build-helpers.sh` (unregistered); `~/.claude/hooks/test-dep-map.sh` (unregistered; called at `tdd-guard.sh:212`); `ls ~/.claude/hooks/bin/` (compiled artifacts).

### 2.5 skills

25 skills under `~/.claude/skills/`. All descriptions are pre-loaded into every Claude Code session as part of the skill-registration manifest. Measurements use character counts from actual frontmatter (Python-parsed for folded YAML blocks); token estimates use chars÷4.

---

#### F-SKILL-01 — Aggregate skill-description auto-load cost
- **Severity:** P0
- **Token impact:** ~1,359 tokens/session (5,438 chars across 25 skill descriptions)
- **Friction:** high
- **Confidence:** high
- **Effort:** medium (requires trimming each offending description)
- **Current state:** All 25 skill descriptions are injected into every session context regardless of whether those skills are relevant. Total measured description payload is 5,438 chars (~1,359 tokens). The 12 skills with descriptions >200 chars collectively account for 4,133 chars (~1,033 tokens) — 76% of the total description load. The 7 CFO skills alone contribute 2,358 chars (~590 tokens), 43% of total.
- **Recommended fix:** (1) Relocate CFO subtree per spec §4.5 (see F-SKILL-02) to eliminate 2,358 chars (~590 tokens), leaving 3,080 chars. (2) Trim the 5 remaining bloat offenders to ≤200 chars each (see F-SKILL-03), saving ~880 chars of excess. Combined effect reduces description payload to ~2,200 chars (~550 tokens), an ~60% reduction.
- **Evidence:** `~/.claude/skills/*/SKILL.md` frontmatters; measured 2026-05-27. Full per-skill table: `cfo`=604, `nvinfo-cli`=373, `cfo-earnings-review`=372, `cfo-tax-check`=362, `gh-activity-gather`=292, `cfo-rsu-decision`=277, `managing-omnistation`=272, `cfo-dcf`=271, `goal`=240, `cfo-state-refresh`=238, `cfo-rebalance`=234, `gh-jira-activity`=216. Spec §5 P1 item 4.

---

#### F-SKILL-02 — CFO subtree must relocate out of global skills
- **Severity:** P1
- **Token impact:** 590 tokens/session reclaimed (2,358 chars eliminated from global load)
- **Friction:** medium (requires new `~/cfo/` project + `.claude/skills/` symlinks or plugin)
- **Confidence:** high
- **Effort:** small
- **Current state:** 7 CFO skills (`cfo`, `cfo-dcf`, `cfo-earnings-review`, `cfo-rebalance`, `cfo-rsu-decision`, `cfo-state-refresh`, `cfo-tax-check`) live in `~/.claude/skills/` and are injected into every session. These skills are exclusively relevant when working in the `~/cfo/` personal-finance project. Combined description payload: 2,358 chars (590 tokens). Individual sizes: `cfo`=5,111 B, `cfo-dcf`=7,473 B, `cfo-earnings-review`=6,521 B, `cfo-rebalance`=5,421 B, `cfo-rsu-decision`=6,592 B, `cfo-state-refresh`=4,686 B, `cfo-tax-check`=4,713 B (total: 40,517 B / ~10,129 tokens of body).
- **Recommended fix:** Move all 7 skills to `~/cfo/.claude/skills/`. They will only load when the `~/cfo/` project is active. This is a locked decision per spec §4.5; no design debate needed — execute it.
- **Evidence:** `~/.claude/skills/cfo*/SKILL.md`; spec §4.5 (locked). Cross-ref F-SKILL-01.

---

#### F-SKILL-03 — Description bloat: 5 non-CFO skills exceed 200-char limit
- **Severity:** P1
- **Token impact:** ~220 tokens/session over-budget (880 chars excess across 5 skills)
- **Friction:** low (description trimming is in-place edit)
- **Confidence:** high
- **Effort:** trivial
- **Current state:** After CFO relocation (F-SKILL-02), 5 non-CFO skills still have descriptions >200 chars: `nvinfo-cli` (373 chars, 173 over budget), `gh-activity-gather` (292 chars, 92 over), `managing-omnistation` (272 chars, 72 over), `goal` (240 chars, 40 over), `gh-jira-activity` (216 chars, 16 over). The 200-char target is per spec §5 P1 item 4; Anthropic guidance is "pushy but compact."
- **Recommended fix:** Trim each description to ≤200 chars. Remove internal trigger-phrase lists from the description field — those belong in the skill body or a `trigger:` frontmatter key, not in the description that loads every session. Target: convey what the skill does and the primary invocation signal only.
- **Evidence:** `~/.claude/skills/nvinfo-cli/SKILL.md:3` (373 chars); `~/.claude/skills/gh-activity-gather/SKILL.md:3` (292 chars); `~/.claude/skills/managing-omnistation/SKILL.md:3` (272 chars); `~/.claude/skills/goal/SKILL.md:3` (240 chars); `~/.claude/skills/gh-jira-activity/SKILL.md:3` (216 chars). Spec §5 P1 item 4.

---

#### F-SKILL-04 — validate-recommendation body approaching size threshold
- **Severity:** P2
- **Token impact:** negligible (body only loads on invocation, not per-session)
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** `validate-recommendation` has 359 body lines (13,605 bytes), the largest skill body in the set. The 400-line hard limit is not breached but is close. The skill includes verbose panel-dispatch protocol, JSON schema examples, and full error-case handling inline. Two other skills are in the 250–275 range: `nvinfo-cli` (271 lines) and `gh-activity-gather` (268 lines).
- **Recommended fix:** Extract the JSON schema examples and panel-wiring details from `validate-recommendation` into a separate referenced doc (`~/.claude/skills/validate-recommendation/PANEL-PROTOCOL.md`) and reference it by path. Keeps invocation body under 200 lines. Lower priority than P1 items; address if editing the skill for other reasons.
- **Evidence:** `~/.claude/skills/validate-recommendation/SKILL.md` (359 body lines, 13,605 bytes); `~/.claude/skills/nvinfo-cli/SKILL.md` (271 body lines); `~/.claude/skills/gh-activity-gather/SKILL.md` (268 body lines).

---

#### F-SKILL-05 — YAML frontmatter syntax errors in 2 CFO skills
- **Severity:** P2
- **Token impact:** N/A
- **Friction:** low (only matters if a YAML-strict loader processes frontmatter)
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `cfo-earnings-review` and `cfo-tax-check` have unquoted colons inside their `description:` values (e.g., `description: Post-earnings review: auto-fetches…`). Python `yaml.safe_load` fails with `mapping values are not allowed here`. Claude Code's runtime likely parses these with a more lenient parser, so no functional regression, but the files are technically invalid YAML.
- **Recommended fix:** Quote the description values: `description: "Post-earnings review: auto-fetches…"`. Moot if CFO skills are relocated (F-SKILL-02) — fix en passant during the move.
- **Evidence:** `~/.claude/skills/cfo-earnings-review/SKILL.md:3`; `~/.claude/skills/cfo-tax-check/SKILL.md:3`; `yaml.safe_load` traceback (measured 2026-05-27). Cross-ref F-SKILL-02.

---

#### F-SKILL-06 — Semantic overlap: local tdd-protocol shadows plugin superpowers:test-driven-development
- **Severity:** P2
- **Token impact:** ~17 tokens/session (66-char description, benign)
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** Local `tdd-protocol` (66-char description, 36 body lines) coexists with plugin `superpowers:test-driven-development`. They are not pure duplicates: the local skill adds NVIDIA-specific extensions (mutation gate with `gremlins`, DORA cycle labeling `[RED]/[GREEN]/[MUTATE]/[REFACTOR]`, `tdd-guard.sh` hook integration, `SKIP_TDD_GUARD=1` escape hatch). However, both appear in the session skill manifest and both trigger on overlapping phrases ("starting implementation work"). This creates router ambiguity.
- **Recommended fix:** Add a `supersedes: superpowers:test-driven-development` marker (if supported) or rename the local skill to `tdd-protocol-nvidia` to signal intentional extension. Document in the skill body that it extends the plugin. No deletion needed — the local extensions are substantive.
- **Evidence:** `~/.claude/skills/tdd-protocol/SKILL.md` (66-char description); `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/test-driven-development/SKILL.md`; description overlap on "starting implementation work".

---

#### F-SKILL-07 — Semantic overlap: local worktree-guide shadows plugin superpowers:using-git-worktrees
- **Severity:** P2
- **Token impact:** ~26 tokens/session (102-char description, benign)
- **Friction:** low
- **Confidence:** medium
- **Effort:** trivial
- **Current state:** Local `worktree-guide` (102-char description, 30 body lines) coexists with plugin `superpowers:using-git-worktrees`. The local skill is substantively different: it encodes `agents-workbench` branch topology, the `enforce-worktree.sh` / `prevent-push-workbench.sh` hook guards, and the fetch-from-remote-ref worktree creation pattern specific to this workflow. The plugin provides generic git worktree mechanics. Both trigger on "starting implementation work in isolated branches."
- **Recommended fix:** Same as F-SKILL-06: document in the skill body that it extends the plugin. Consider adding a `note:` frontmatter field pointing at the plugin. Ambiguity is lower risk here since the trigger phrases are distinct enough in practice.
- **Evidence:** `~/.claude/skills/worktree-guide/SKILL.md` (102-char description, 30 body lines); `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/using-git-worktrees/SKILL.md`.

---

#### F-SKILL-08 — nvinfo-cli description missing: awk parsing returns 2 chars (folded YAML block)
- **Severity:** P2
- **Token impact:** N/A
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `nvinfo-cli` uses a YAML `>-` folded block scalar for its `description:` field. The awk-based measurement script in this audit's Task 7 returned `desc_chars=2` (the `>-` characters), indicating the skill body extraction script is brittle. Python YAML parsing returns the correct 373-char description. The skill itself is functionally correct; this is an audit-tooling observation.
- **Recommended fix:** Convert `nvinfo-cli` description from folded block `>-` to a single quoted string. Keeps the frontmatter consistent with all other skills and makes the description parseable by simple line-oriented tools. Also reduces the description to ≤200 chars per F-SKILL-03 when rewriting.
- **Evidence:** `~/.claude/skills/nvinfo-cli/SKILL.md:3-9` (folded block); awk measurement returned 2; Python returned 373. Cross-ref F-SKILL-03.

### 2.6 agents

4 agents present: `doc-writer` (sonnet), `explorer` (haiku), `principal-engineer` (opus), `qa-engineer` (opus). Total size: ~8.2 KB / ~2 K tokens. All are sub-agents invoked on demand, not auto-loaded — no baseline session cost.

#### F-AGENT-01 — `principal-engineer` carries `Agent` tool; no sub-agent spawning documented
- **Severity:** P2
- **Token impact:** N/A (the tool is available but invocation is rare and demand-driven)
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `~/.claude/agents/principal-engineer.md` declares `tools: [Read, Grep, Glob, Bash, Agent]`. The `Agent` tool lets PE spawn further sub-agents. Nothing in the PE role body documents when or why this is used; team-execute does not reference it.
- **Recommended fix:** Either document the intended sub-agent use case in the PE body (e.g., "May dispatch `explorer` for large-scope codebase searches during review") or remove `Agent` from the tool list to enforce a flat invocation graph and prevent accidental recursive agent spawning.
- **Evidence:** `~/.claude/agents/principal-engineer.md:5` (`- Agent`); `~/.claude/skills/team-execute/SKILL.md` — no mention of PE spawning sub-agents.

#### F-AGENT-02 — Role name mismatch between `commands/team-execute.md` and `skills/team-execute/SKILL.md`
- **Severity:** P1
- **Token impact:** N/A — runtime confusion risk, not token cost
- **Friction:** medium — a user following the command sees "Distinguished Systems Engineer"; one following the skill sees "Principal Engineer" referencing `agents/principal-engineer.md`. Two different invocation paths produce structurally different teams.
- **Confidence:** high
- **Effort:** small
- **Current state:** `~/.claude/commands/team-execute.md` defines the senior role as "Distinguished Systems Engineer" and instructs it to read 8 `architect-*.md` libraries from `~/.claude/team/lib/`. `~/.claude/skills/team-execute/SKILL.md` defines the same slot as "Principal Engineer" and references `agents/principal-engineer.md`. These two artefacts are both active; either path can be invoked.
- **Recommended fix:** Decide on one canonical role name. If `principal-engineer.md` is the canonical agent, update `commands/team-execute.md` to reference it and remove the `team/lib/architect-*.md` library-loading step (or move those libraries into the agent). If "Distinguished Systems Engineer" is preferred, rename `agents/principal-engineer.md` and update the skill. Add a deprecation notice on the superseded file.
- **Evidence:** `~/.claude/commands/team-execute.md:7` ("Distinguished Systems Engineer"); `~/.claude/skills/team-execute/SKILL.md:12` ("Principal Engineer (see `agents/principal-engineer.md`)").

#### F-AGENT-03 — `qa-engineer` body duplicates QA validation logic already in `commands/team-execute.md`
- **Severity:** P2
- **Token impact:** ~1.3 K tokens when qa-engineer is loaded (5 520 bytes / ~4 chars per token). The duplication itself adds no session cost but creates drift risk.
- **Friction:** low
- **Confidence:** high
- **Effort:** small
- **Current state:** `~/.claude/agents/qa-engineer.md` contains a full 11-point gate checklist, CI replication steps, bot review triage logic, and mutation testing instructions — most of which is also present in `~/.claude/commands/team-execute.md` (step 10, qa-validator sections). Two sources of truth for the QA protocol will drift.
- **Recommended fix:** Slim `qa-engineer.md` to a role-identity + pointer document ("See `~/.claude/team/lib/qa-validator.md` for the full validation sequence") mirroring the approach used by `principal-engineer.md`. Authoritative checklist lives in one place.
- **Evidence:** `~/.claude/agents/qa-engineer.md:1-5520`; `~/.claude/commands/team-execute.md` steps 10-11 (parallel content). Size delta vs `principal-engineer.md`: 5 520 vs 1 421 bytes.

### 2.7 plugins enabled

5 plugins active: `code-review`, `code-simplifier`, `superpowers`, `gopls-lsp`, `clangd-lsp`.

#### F-PLUGIN-01 — `code-simplifier` agent hardcodes JavaScript/TypeScript/React style rules for a Go/K8s project
- **Severity:** P1
- **Token impact:** ~600 tokens when `code-simplifier` sub-agent is loaded (agent body is ~2.4 KB). Actual cost is per-invocation; the harm is correctness, not tokens.
- **Friction:** high — when invoked it will apply ES module import sorting, arrow function style, and React component patterns to Go code.
- **Confidence:** high
- **Effort:** trivial — disable the plugin.
- **Current state:** `~/.claude/plugins/cache/claude-plugins-official/code-simplifier/1.0.0/agents/code-simplifier.md` contains "Use ES modules with proper import sorting", "Prefer `function` keyword over arrow functions", "Follow proper React component patterns with explicit Props types". The primary stack is Go and Kubernetes; there is no TypeScript or React in the codebase.
- **Recommended fix:** Disable `code-simplifier@claude-plugins-official` in `settings.json`. If code cleanup automation is desired, add a local `code-simplifier` agent with Go-specific rules (gofmt idioms, receiver consistency, error wrapping).
- **Evidence:** `~/.claude/plugins/cache/claude-plugins-official/code-simplifier/1.0.0/agents/code-simplifier.md:17-22`; `settings.json` `enabledPlugins`.

#### F-PLUGIN-02 — `code-review` plugin overlaps with local `code-review` skill and `principal-engineer` agent review responsibilities
- **Severity:** P2
- **Token impact:** ~300 tokens/session for the plugin command description being available. Invocation adds 4 parallel agent calls.
- **Friction:** low — both paths produce review output; users must know which to invoke.
- **Confidence:** medium — depends on whether the local skill and plugin skill are being used for different scenarios.
- **Effort:** small
- **Current state:** Three review paths exist: (1) `code-review@claude-plugins-official` — 4 parallel agents with confidence scoring, CLAUDE.md compliance, git blame; (2) local `~/.claude/skills/code-review/` — referenced in system-reminder as `code-review`; (3) `principal-engineer` agent review as part of team-execute. The plugin and local skill do not document how they divide responsibility.
- **Recommended fix:** Document the intended division: plugin `/code-review` for async/automated PR review; local `code-review` skill for interactive review sessions; PE agent for team-execute review gate. Or consolidate by disabling the plugin and folding its confidence-scoring approach into the local skill. Add a one-line comment to `settings.json` `enabledPlugins` entry.
- **Evidence:** `~/.claude/plugins/cache/claude-plugins-official/code-review/f9178d73a2f5/README.md`; system-reminder listing `code-review` skill; `~/.claude/agents/principal-engineer.md` review section.

#### F-PLUGIN-03 — `clangd-lsp` plugin enabled for a Go/Kubernetes engineer (cross-ref F-SETTINGS-04)
- **Severity:** P2
- **Token impact:** See F-SETTINGS-04 — LSP handshake + diagnostics tokens on every `.c`/`.cpp` file open; zero benefit on a Go-only stack.
- **Friction:** high
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `clangd-lsp@claude-plugins-official` is enabled. Primary language is Go. No C/C++ files exist in the active repositories. This is a locked decision in F-SETTINGS-04.
- **Recommended fix:** `"clangd-lsp@claude-plugins-official": false` in `settings.json`. Already captured in F-SETTINGS-04; this entry cross-references that finding for the plugin dimension.
- **Evidence:** `settings.json` `enabledPlugins`; `~/.claude/plugins/cache/claude-plugins-official/clangd-lsp/1.0.0/README.md` (supported extensions: `.c .h .cpp .cc .cxx .hpp .hxx .C .H`). Cross-ref: F-SETTINGS-04.

#### F-PLUGIN-04 — Two cached versions of `superpowers` plugin (4.3.0 and 5.1.0) are content-identical, consuming duplicate disk space
- **Severity:** P2
- **Token impact:** N/A — both versions load the same ~114 KB of skill content; only 5.1.0 is active.
- **Friction:** low
- **Confidence:** high
- **Effort:** trivial
- **Current state:** `~/.claude/plugins/cache/claude-plugins-official/superpowers/` contains both `4.3.0/` and `5.1.0/`. A recursive diff shows identical skill content (only `.in_use` marker files differ). The stale `4.3.0/` cache is ~114 KB of redundant disk state.
- **Recommended fix:** Remove the stale version directory: `rm -rf ~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.0`. Plugin manager should handle this automatically on next update; if it does not, file a bug.
- **Evidence:** `ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/` shows `4.3.0` and `5.1.0`; `diff -r` shows no content delta between the two (only `.in_use` markers).

### 2.8 meta-skills (router / gating patterns — currently empty; finding describes the gap)

#### F-META-01 — Missing `pick-planner` router (gap finding)
- **Severity:** P1
- **Token impact:** estimated 2-4 K tokens saved per simple plan invocation. Breakeven at ~1 simple invocation per session; classifier itself costs ~500-800 tokens.
- **Friction:** medium — currently every brainstorm → plan flow produces a heavyweight plan regardless of complexity.
- **Confidence:** high (architecturally identical to `validate-recommendation`).
- **Effort:** small — one new skill dir, one new persona file, one edit to brainstorming's "Transition to implementation" step.
- **Current state:** No router/gating skills exist except `validate-recommendation` (which gates `AskUserQuestion`, not skill invocations). `writing-plans` is invoked unconditionally regardless of task complexity.
- **Recommended fix:** Build `~/.claude/skills/pick-planner/SKILL.md` + `~/.claude/skills/validate-recommendation/personas/plan-complexity.md`. Classifier returns SIMPLE / MODERATE / COMPLEX. SIMPLE inlines 3-5 bullets; MODERATE writes a lite plan; COMPLEX invokes `superpowers:writing-plans`. Env-var disable via `SKIP_PLAN_ROUTER=1`. Update brainstorming's "Transition to implementation" wording.
- **Evidence:** spec §3.8 (area definition), §4.8 (theme), §5 P1 item 6.

## 3. Cross-cutting themes

### 3.1 Stop-hook LLM prompt cost

**Summary:** The `"type": "prompt"` Stop hook (F-SETTINGS-01, F-HOOK-03) fires a full Claude inference pass on every turn end. At ~395 chars / ~99 tokens for the prompt itself, plus transcript-tail injection and a `OK`/`STOP` response, the actual per-stop cost lands at ~800–1,200 tokens. Across a 30-turn session that is ~9,000–24,000 tokens consumed solely to enforce a rule already expressed in CLAUDE.md line 17 and `constitution.md`'s Test Quality Gate. With Opus 4.7's ~35% tokenizer expansion the real cost is higher than any pre-2026 estimate would suggest (see §3.3).

**Cross-references:** F-SETTINGS-01, F-HOOK-03, F-CLAUDEMD-06.

**Recommendation direction:** Replace the `"type": "prompt"` entry with a `"type": "command"` hook (`verify-completion.sh`) that uses `grep`/`jq` to detect unverified completion claims — no LLM round-trip, ~5 tokens overhead. If the check is deemed unnecessary given the CLAUDE.md principle, delete the Stop hook entry entirely. Do not retain the prompt-type entry in any form.

---

### 3.2 Cache-TTL regression (1h → 5m, March 2026)

**Summary:** Anthropic silently regressed the default prompt-cache TTL from 1h to 5min in March 2026. Every idle gap longer than 5 minutes — a Bash command running, user review time, a `sleep` call in a hook — causes the full auto-loaded surface to be written as a cold-cache entry again. The per-session auto-loaded surface is measured at ~4,100 tokens (CLAUDE.md ~1,200 + rules ~2,900 per F-RULES-01, plus ~1,359 tokens of skill descriptions per F-SKILL-01 = ~5,459 tokens total). Cold-cache writes on Opus cost ~3–5× cached reads; sessions with multiple idle gaps lose the cache benefit entirely.

**Cross-references:** F-RULES-01, F-SKILL-01, F-SETTINGS-06.

**Recommendation direction:** Reduce the auto-loaded surface by ≥25% first (apply F-CLAUDEMD-01 through F-RULES-06 and F-SKILL-02) so each cold-cache write is smaller. For long-running team-execute sessions, add explicit cache-control markers on stable CLAUDE.md sections to request 1h TTL. Audit hook scripts for unnecessary `sleep` calls that idle the cache without benefit.

---

### 3.3 Opus 4.7 tokenizer expansion (~35%)

**Summary:** The Opus 4.7 tokenizer produces ~35% more tokens per line of prose compared to earlier model assumptions. All token estimates in this audit (§1, §2) use the current 2026 assumption: ~18–25 tokens/line for English prose, ~12–18 tokens/line for code/config. Any pre-2026 budget or sizing heuristic based on character counts or line counts underestimates actual spend by ~35%. This amplifies every other cost finding: the Stop-hook prompt cost (§3.1), the cold-cache write cost (§3.2), the skill-description load (F-SKILL-01), and the rules/ surface (F-RULES-01).

**Cross-references:** F-SETTINGS-01, F-SETTINGS-05, F-SETTINGS-06, F-RULES-01, F-SKILL-01 (and all findings with a token estimate).

**Recommendation direction:** Recalibrate all hard-coded token budgets (e.g., skill description 200-char ceiling from spec §5 P1 item 4) using the 2026 tokenizer ratio, not the prior model. When measuring progress after applying P0/P1 fixes, use `tiktoken` or the Claude tokenizer API to verify actual reduction, not line-count arithmetic.

---

### 3.4 TDD-guard removal — mechanics

**Summary:** `tdd-guard.sh` is locked for removal (spec §4.4, F-HOOK-02). The 229-line script is registered at two locations in `settings.json` (lines 123 and 136), has no test suite (`tdd-guard_test.sh` absent, F-HOOK-09), and has four `.bak` siblings documenting repeated exemption-list scope creep (F-HOOK-01). The guard fires on legitimate writes regularly enough to cause workflow friction without catching actual TDD violations in practice.

**Cross-references:** F-HOOK-01, F-HOOK-02, F-HOOK-09, F-HOOK-10, F-CLAUDEMD-01, F-CLAUDEMD-02.

**Recommendation direction:** Execute the five-step removal: (1) remove both `tdd-guard.sh` entries from `settings.json`; (2) delete `tdd-guard.sh`; (3) delete all four `.bak` siblings; (4) delete `test-dep-map.sh` and `test-dep-map_test.sh` (only consumer is `tdd-guard.sh`); (5) rewrite CLAUDE.md TDD section heading and body per F-CLAUDEMD-01 to remove "enforced by hook" language. TDD discipline is enforced by `/tdd-protocol` skill and the rewritten CLAUDE.md wording.

---

### 3.5 CFO skill relocation — mechanics

**Summary:** Seven CFO skills living in `~/.claude/skills/` inject 2,358 chars (~590 tokens) of description text into every session — even sessions with no personal-finance context (F-SKILL-02, F-SKILL-01). This is 43% of the total 5,438-char skill-description load. Individual skill bodies total 40,517 bytes (~10,129 tokens) available per invocation. The relocation is a locked decision per spec §4.5.

**Cross-references:** F-SKILL-01, F-SKILL-02, F-SKILL-05.

**Recommendation direction:** Move all 7 skills (`cfo`, `cfo-dcf`, `cfo-earnings-review`, `cfo-rebalance`, `cfo-rsu-decision`, `cfo-state-refresh`, `cfo-tax-check`) to `~/cfo/.claude/skills/`. Fix the YAML unquoted-colon syntax errors in `cfo-earnings-review` and `cfo-tax-check` during the move (F-SKILL-05). Remove any CFO references from `~/.claude/CLAUDE.md` after relocation.

---

### 3.6 Worktrees: experimental flag vs official GA

**Summary:** `settings.json` sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and `teammateMode: in-process`. Official Claude Code docs (2026) now ship `isolation: worktree` as the GA path for subagent isolation. The `isolation` key is absent from `settings.json` (`has("isolation") = false`), indicating the GA worktree path has not been adopted. Running a stale experimental env var alongside the GA mechanism risks undocumented behavior changes as the flag is phased out (F-SETTINGS-03).

**Cross-references:** F-SETTINGS-03, F-AGENT-01, F-AGENT-02.

**Recommendation direction:** Verify with Claude Code release notes whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is still required with `teammateMode: in-process`. If the GA path is `isolation: worktree` on per-agent definitions, add that field to each `agents/*.md` file and remove the env var from `settings.json`. Update `team-execute` skill and `worktree-guide` skill to document the adopted isolation model.

---

### 3.7 Security posture

**Summary:** A live incident during audit brainstorming printed `PANEL_DA_API_KEY` to stdout via a shell expansion error. This key must be rotated before any audit changes land. The broader `settings.json` deny and ask posture is sound: `.env`, `.pem`, `.key`, credentials, kubeconfig, AWS dir, and SSH keys are correctly blocked; `rm`, `git rebase --hard`, `git push --force`, and `sudo` correctly require prompt. `sign-commits.sh` enforces `-s -S` on every commit. The one structural gap is `validate-recommendation.sh` writing verdict files to `~/.claude/panel/work/`, which is outside sandbox-writable paths — causing silent failures (F-HOOK-04).

**Cross-references:** F-HOOK-04, F-SETTINGS-02.

**Recommendation direction:** Rotate `PANEL_DA_API_KEY` immediately. In `validate-recommendation/SKILL.md:89`, change `WORKDIR` from `${HOME}/.claude/panel/work/...` to `${TMPDIR:-/tmp}/claude-panel-work/${CLAUDE_SESSION_ID:-$PPID}` to use a sandbox-safe path. Add `~/.claude/panel/work` to `settings.json` `write.allowOnly` as a belt-and-suspenders fallback. No changes needed to the permissions.deny or permissions.ask posture.

---

### 3.8 Plan-routing via cheap classifier (new)

**Summary:** The `superpowers:writing-plans` skill produces a full heavyweight plan (~500–800 lines) regardless of task complexity. For simple, single-file tasks this generates 3–5K tokens of boilerplate the executor must read to find 3–5 actual bullets of real work (F-META-01). A `pick-planner` classifier, modeled on the existing `validate-recommendation` pattern, would cost ~500–800 tokens per call (Nemotron 3 Super via the existing panel infrastructure) and route SIMPLE tasks to an inline 3-5 bullet list, saving 2–4K tokens per simple plan invocation. Breakeven is ~1 simple-plan invocation per session.

**Cross-references:** F-META-01.

**Recommendation direction:** Build `~/.claude/skills/pick-planner/SKILL.md` and `~/.claude/skills/validate-recommendation/personas/plan-complexity.md`. The classifier returns SIMPLE / MODERATE / COMPLEX; SIMPLE emits an inline checklist, MODERATE writes a lite plan to `docs/superpowers/plans/`, COMPLEX invokes `superpowers:writing-plans` as today. Add `SKIP_PLAN_ROUTER=1` env-var override for the user to bypass the router when needed. Update the brainstorming skill's "Transition to implementation" step to call `pick-planner` before writing any plan document.

## 4. Phased action plan

### 4.1 P0 — Quick wins
### 4.2 P1 — Structural
### 4.3 P2 — Polish

## 5. Validation gate
