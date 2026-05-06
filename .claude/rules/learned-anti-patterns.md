# Learned Anti-Patterns

Curated by /reflection skill. Max 50 lines. Severity-ranked.
Pruning: critical = never auto-pruned; warning = pruned when Count < 2 and Since > 90 days; info = pruned by lowest count when cap exceeded.

## Critical

- **Pattern**: Theater tests — tautological assertions, missing assertions, over-mocking | **Fix**: Delete and rewrite. Every test must fail when implementation is deleted. | **Severity**: critical | **Tags**: testing | **Count**: 5 | **Since**: 2026-01-15
- **Pattern**: Index-based access instability — tests break when list order changes | **Fix**: Use map lookups or sort-then-compare. Never rely on API list ordering. | **Severity**: critical | **Tags**: go,testing,k8s | **Count**: 3 | **Since**: 2026-02-10
- **Pattern**: Array ordering assumptions in K8s resource lists | **Fix**: Sort by name/key before comparison. Use `ElementsMatch` for unordered sets. | **Severity**: critical | **Tags**: go,testing,k8s | **Count**: 3 | **Since**: 2026-02-10

## Warning

- **Pattern**: Verify external references (OCI paths, URLs) exist, don't just pattern-match | **Fix**: Make HTTP HEAD or registry API call to confirm resource exists. | **Severity**: warning | **Tags**: containers,k8s | **Count**: 2 | **Since**: 2026-03-01
- **Pattern**: Never push without local E2E for infrastructure code | **Fix**: Run `kind` cluster E2E or equivalent before pushing operator/controller changes. | **Severity**: warning | **Tags**: k8s,testing | **Count**: 2 | **Since**: 2026-03-15
