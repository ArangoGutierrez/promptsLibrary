# Learned Anti-Patterns

Curated by /reflection skill. Max 50 lines. Severity-ranked.
Pruning: critical = never auto-pruned; warning = pruned when Count < 2 and Since > 90 days; info = pruned by lowest count when cap exceeded.

## Critical

- **Pattern**: Theater tests — tautological assertions, missing assertions, over-mocking | **Fix**: Delete and rewrite. Every test must fail when implementation is deleted. | **Severity**: critical | **Tags**: testing | **Count**: 5 | **Since**: 2026-01-15
- **Pattern**: Index-based access instability — tests break when list order changes | **Fix**: Use map lookups or sort-then-compare. Never rely on API list ordering. | **Severity**: critical | **Tags**: go,testing,k8s | **Count**: 3 | **Since**: 2026-02-10
- **Pattern**: Array ordering assumptions in K8s resource lists | **Fix**: Sort by name/key before comparison. Use `ElementsMatch` for unordered sets. | **Severity**: critical | **Tags**: go,testing,k8s | **Count**: 3 | **Since**: 2026-02-10
- **Pattern**: Ship code without exercising the real caller entry path (env vars, CWD, CLI invocation, kind cluster) — unit tests pass but integration breaks | **Fix**: Before claiming Green, run the actual user-facing entry point in its actual environment. CLIs: `cd /tmp && python -m <pkg>`. Env-driven code: unset test fixtures and re-run with real env vars. Controllers: kind cluster E2E. Doc/expert claims about harness contracts are NOT authoritative — confirm with a live probe (e.g. headless `claude -p`) before building on them. | **Severity**: critical | **Tags**: testing,cli,integration,k8s,harness | **Count**: 5 | **Since**: 2026-06-09

## Warning

- **Pattern**: Verify external references (OCI paths, URLs) exist, don't just pattern-match | **Fix**: Make HTTP HEAD or registry API call to confirm resource exists. | **Severity**: warning | **Tags**: containers,k8s | **Count**: 2 | **Since**: 2026-03-01
- **Pattern**: Spec/plan/handoff numerics and file lists drift from repo reality — written without re-running or re-grepping | **Fix**: Any "N tests pass" or "N files to delete" claim in a plan or handoff must be derived from a command run in that same session. Paste the command output into the doc, don't transcribe a remembered number. | **Severity**: warning | **Tags**: planning,docs | **Count**: 2 | **Since**: 2026-05-20
- **Pattern**: Substring-matching command hooks (e.g. `prevent-push-workbench.sh`) false-block when the trigger word appears ANYWHERE in the command string — incl. a heredoc/PR body that merely mentions it | **Fix**: Keep the trigger substring out of push-command strings (push via `git -C <worktree> push`); longer-term, harden the hook to match the branch being pushed (refspec/current branch), not a whole-command grep. | **Severity**: warning | **Tags**: tooling,git,hooks,worktree | **Count**: 1 | **Since**: 2026-06-09
