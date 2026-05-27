# Repo Resync — Design Spec

**Date:** 2026-05-06
**Status:** Draft, awaiting user review
**Author:** Claude Code (brainstorming session with @ArangoGutierrez)

## Problem

The dotfiles repo at `ArangoGutierrez/promptsLibrary` has drifted significantly
from the live `~/.claude/` and `~/.cursor/` environments it mirrors.
`./scripts/diff.sh` reports:

- `.claude/`: 7 changed config files, ~122 live-only entries
- `.cursor/`: 12 changed files, many live-only entries (including a 406 MB
  Python virtualenv)

Two structural issues compound the drift:

1. **Broken contract** — the live `CLAUDE.md` references `rules/constitution.md`,
   `rules/go-conventions.md`, and similar files that do not exist in the repo.
   A fresh deploy from the repo produces a `CLAUDE.md` whose `@`-references
   point to missing files.
2. **Capture excludes are too narrow** — the live `~/.claude/.gitignore`
   excludes `audit/`, `archive/`, `sessions/`, `cache/`, etc., but
   `scripts/capture.sh` does not. A naive capture would pull ~9 MB of bash
   audit logs and a 406 MB Python virtualenv into the repo.

There is also a **disclosure risk**: the live config contains NVIDIA-internal
references (MemPalace MCP, `nvinfo-cli` skill, `managing-omnistation` skill,
internal Atlassian/LMS hosts in the network allowlist) and a private project
path leaking through `installed_plugins.json` (`frontend-design` scoped to
`/Users/eduardoa/src/github/staiconnected/stayconnected`). The repo is public.

## Goals

1. Bring the repo back in sync with the live environment for everything that
   should ship publicly.
2. Make `capture.sh` produce a public-safe result by default — no manual
   scrubbing required.
3. Make this resync reproducible: future drift can be resolved by running
   `capture.sh` without re-deriving the same exclusion policy.
4. Keep doc accuracy at the surface level (README "What's Included" table).

## Non-goals

- Updating deep doc files (`docs/claude-code.md`, `docs/cursor.md`,
  `docs/skills-and-commands.md`) — follow-up work.
- Adding new features to the dotfiles. This is a sync, not a feature change.
- Changing `deploy.sh`. Only `capture.sh` and `diff.sh` need updates.
- Tracking ephemeral or environment-specific runtime state.

## Approach (selected: B — Tooling-first)

Three approaches were considered:

- **A) One-pass, light tooling** — update excludes for runtime cruft only;
  manually `rm` NVIDIA-internal files before staging. Rejected: fragile,
  forgets the policy on the next sync.
- **B) Tooling-first** *(selected)* — encode both runtime-cruft exclusions
  and a public-safe NVIDIA exclusion list in `capture.sh`; add a sanitizer
  step for files containing mixed public/private content. Future captures
  stay clean.
- **C) Two-PR split** — separate tooling PR from content PR. Rejected: doubles
  review round-trips with no benefit; the maintainer is reviewing both.

## Tooling changes (`scripts/capture.sh`, `scripts/diff.sh`)

Three exclusion concerns, applied in this order during capture:

### 1. Runtime cruft (always excluded; both `capture.sh` and `diff.sh`)

Aligns capture with the user's existing `~/.claude/.gitignore`:

```
# .claude
audit/                                  archive/
sessions/                               image-cache/
*.bak-*                                 .cleaned-this-week
cleanup-errors.log                      audit.md
migration.md                            proposal.md
plugins/install-counts-cache.json       plugins/blocklist.json

# .cursor
mcp-servers/venv/                       mcp-servers/*.retired/
```

### 2. Public-safe NVIDIA exclusion list

Stored as a separate constant `NVIDIA_EXCLUDES` in both scripts so policy
intent is explicit and auditable:

```
# .claude
skills/nvinfo-cli/                      skills/managing-omnistation/
hooks/mempalace-wake.sh

# .cursor
commands/recall.md                      commands/ingest-pr.md
hooks/extract-learnings.sh              hooks/inject-context.sh
entities.json
```

### 3. Sanitizer pass (post-rsync)

Three files contain mixed public/private content. They sync, then a sanitizer
edits the captured copies:

| File | Filter | What it removes |
|---|---|---|
| `.claude/installed_plugins.json` | `jq` | Entries where `scope == "local"` (private project paths) |
| `.claude/settings.json` | `jq` | Hook entries whose `command` ends in `mempalace-wake.sh` |
| `.claude/CLAUDE.md` | `awk` | The `## Memory` section (4 lines about MemPalace MCP) |

The sanitizer must be **idempotent**: running `capture.sh` twice in succession
must produce no second-round diff. Verified by acceptance test in §Verification.

`.claude/remote-settings.json` is **not** synced. It is replaced once with a
curated public allowlist (see Approach (iii) under Section 2 of brainstorming)
and added to capture excludes from then on. The repo's existing minimal
allowlist is the basis; adding only generic dev hosts (e.g. `pypi.org`,
`docker.com`, `go.dev`, `cache.nixos.org`, `arxiv.org`) that do not disclose
NVIDIA-specific tooling.

## Commit plan

11 commits on a single branch `chore/repo-resync`, created from `origin/main`
in a worktree (per `.claude/CLAUDE.md` worktree workflow). All commits
GPG-signed and DCO signed-off.

| # | Type | Subject |
|---|------|---------|
| 1 | `chore(scripts)` | tighten capture/diff runtime-cruft excludes |
| 2 | `feat(scripts)` | add public-safe NVIDIA exclude list and sanitizer |
| 3 | `chore(.claude)` | replace remote-settings.json with curated public allowlist |
| 4 | `chore(.claude)` | sync CLAUDE.md, settings.json, policy-limits.json (sanitized) |
| 5 | `chore(.claude)` | sync installed_plugins.json + hook updates (enforce-worktree, tdd-guard) |
| 6 | `feat(.claude)` | add agents/ (doc-writer, explorer, principal-engineer, qa-engineer) |
| 7 | `feat(.claude)` | add rules/ (constitution, conventions, security, learned-anti-patterns) |
| 8 | `feat(.claude)` | add skills/ (eureka, go-review, k8s-debug, pr-review-ingest, reflection, tdd-protocol, team-{plan,execute,shutdown}, worktree-guide) |
| 9 | `feat(.claude)` | add hooks (auto-format, bash-audit-log, mutation-gate, pre-compact-context, reflection-staleness, test-dep-map, test-quality-lint) |
| 10 | `chore(.cursor)` | sync cursor config drift (hooks, skills-cursor, mcp.json) |
| 11 | `docs` | refresh README counts and feature lists |

**Ordering rationale:**

- Commits 1–2 land first so the scripts are correct before content is captured.
- Commit 3 is a one-time replacement, not a sync.
- Commits 4–5 update existing tracked files; commits 6–9 add new categories.
  Separating updates from additions keeps each diff readable.
- Commit 10 batches cursor changes (lower volume than `.claude`).
- Commit 11 lands last so docs reflect the final tracked state.

## README updates (commit 11)

In the `.claude/` table:

- **Hooks** count: `6 → 13`. Add to the description: auto-format,
  bash-audit-log, mutation-gate, pre-compact-context, reflection-staleness,
  test-dep-map, test-quality-lint.
- New row: `Agents | 4 | doc-writer, explorer, principal-engineer, qa-engineer`.
- New row: `Rules | 7 | constitution, go/k8s/container conventions,
  git-workflow, security, learned-anti-patterns`.
- New row: `Skills | 10 | eureka, go-review, k8s-debug, pr-review-ingest,
  reflection, tdd-protocol, team-{plan,execute,shutdown}, worktree-guide`.
- **Plugins** row: add `clangd-lsp` to the list.

In the "Key Behaviors Enforced" list, add one bullet for the post-tool-use
auto-format and test-quality-lint hooks.

`docs/claude-code.md`, `docs/cursor.md`, `docs/skills-and-commands.md` are
**not** updated in this PR — surface-level only per agreed scope.

## Verification

Before pushing:

1. `./scripts/diff.sh` exits 0 — or shows only the NVIDIA-internal entries
   from `NVIDIA_EXCLUDES` as `LIVE ONLY` (intentional).
2. **No-leak check** — `grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian.net|gm\.com|brainshark|adobe.*learning" .claude/ .cursor/`
   returns zero hits in tracked content (the standard public Kubernetes
   resource name `nvidia.com/gpu` is allowed).
3. **Sanitizer idempotence** — `./scripts/capture.sh && git status --porcelain`
   shows clean working tree; `./scripts/capture.sh` again then
   `git status --porcelain` still clean.
4. **Commit hygiene** — `git log --show-signature upstream/main..HEAD` shows
   11 signed commits.
5. `markdownlint .` (CI's `lint.yml` invocation) passes.
6. **Manual eyeball** of each commit's diff for any path or string referencing
   NVIDIA-internal tooling.

## Open questions / risks

- **Sanitizer false positives** — the `awk` filter for `## Memory` in
  `CLAUDE.md` matches the heading exactly. If the user later adds a different
  `## Memory` section that *isn't* about MemPalace, the sanitizer will strip
  it. Mitigated by anchoring on `## Memory\nPersistent memory is MemPalace`.
- **`installed_plugins.json` schema drift** — Anthropic could change the
  scope field semantics. Mitigated by the jq filter being explicit:
  `del(.plugins[][] | select(.scope == "local"))`. If the schema changes,
  the filter no-ops.
- **Cursor `entities.json` is auto-generated** — added to `NVIDIA_EXCLUDES`
  because its content (`"projects": ["Active", "Cursor", "Audit", ...]`)
  is local IDE state, not config-as-code.

## Out of scope (follow-up)

- Refresh `docs/claude-code.md`, `docs/cursor.md`, and
  `docs/skills-and-commands.md` to describe the new agents/rules/skills
  categories in depth.
- Consider whether `.cursor/skills-cursor/` should be renamed back to
  `skills/` to match Cursor's native convention (separate refactor PR).
- Document the public-safe sanitizer policy in `docs/deployment.md`.
