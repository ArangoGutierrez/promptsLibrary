"""Lane A (ALLOW) and Lane B (DENY) regex tables.

Each Lane A pattern is anchored at start-of-command (^) — the leading verb
decides. Lane B (added in Task 5) uses word boundaries (\\b) so DENY patterns
match anywhere in the command, including after `;`, `&&`, `bash -c`.

After editing this file, run `rm -rf $TMPDIR/nemotron-approve-cache` to flush
cached classifier verdicts that may now be stale.
"""
from __future__ import annotations
import re
from typing import Optional


LANE_A_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("kubectl-read", re.compile(
        r"^kubectl\s+(version|config\s+(view|current-context|get-contexts|get-clusters)|"
        r"api-resources|api-versions|get|describe|logs|top|auth\s+can-i|explain|"
        r"cluster-info|wait|rollout\s+(status|history)|events|debug)\b"
    )),
    ("gh-read", re.compile(
        r"^gh\s+(auth\s+status|repo\s+(view|list|clone)|pr\s+(view|list|diff|checks|status)|"
        r"issue\s+(view|list)|release\s+(view|list)|workflow\s+(view|list)|extension\b|"
        r"run\s+(view|list|watch)|browse|search|status|cache\s+list|"
        r"gist\s+(view|list)|label\s+list|codespace\s+(list|view))\b"
    )),
    ("gh-author-writes", re.compile(
        r"^gh\s+(pr\s+(create|edit|comment|ready|review)|"
        r"issue\s+(create|edit|comment|reopen|transfer|lock|unlock|pin|unpin)|"
        r"release\s+(upload|download)|gist\s+(create|edit)|label\s+(create|edit)|"
        r"cache\s+delete)\b"
    )),
    ("gh-recoverable-runtime", re.compile(
        r"^gh\s+(run\s+(rerun|cancel)|extension\s+(install|upgrade|remove))\b"
    )),
    ("gh-api-get", re.compile(
        r"^gh\s+api\b(?!.*\s-X\s+(POST|PATCH|DELETE|PUT))"
    )),
    ("git-read", re.compile(
        r"^git\s+(status|log|show|diff|branch|remote(\s+-v)?|fetch\s+--dry-run|"
        r"tag\s+--list|describe|reflog|stash\s+(list|show)|config\s+--get|"
        r"rev-parse|ls-(files|tree)|blame|grep|show-ref)\b"
    )),
    ("go-safe", re.compile(
        r"^go\s+(version|env|vet|build|test|mod\s+(tidy|verify|graph|why|download)|"
        r"doc|fmt|fix|list|tool|run)\b"
    )),
    ("python-pip-read", re.compile(
        r"^(python3?\s+--version|pip3?\s+(show|list|search|--version|install\s+--user))\b"
    )),
    # Fix vs plan: split npx from npm/pnpm/yarn. `npx <anything>` runs arbitrary
    # locally-installed binaries (e.g., `npx tsc`), so it can't share npm's
    # subcommand allowlist. Also `install(?!\s+-g\b)` rejects `npm install -g foo`
    # — global installs are mutating system state; the plan's draft would have
    # matched it, contradicting the test that expects a Lane A miss.
    ("node-ecosystem-npx", re.compile(r"^npx\s+\S+")),
    ("node-ecosystem", re.compile(
        r"^(npm|pnpm|yarn)\s+(install(?!\s+-g\b)|i|ci|update|up|add|rm|remove|uninstall|"
        r"prune|dedupe|view|info|ls|list|outdated|search|config\s+get|root|bin|"
        r"prefix|run|test|build|start|dev|lint|typecheck|format|exec|pack|doctor|"
        r"why|fund|audit(?!\s+fix)|cache\s+(ls|verify)|completion|help|docs|home|"
        r"repo|hook|init|create)\b"
    )),
    ("build-tools", re.compile(
        r"^(make|cmake|ninja|bazel|cargo|mvn|gradle|kustomize|kind|trivy|grype|"
        r"gosec|govulncheck|controller-gen|setup-envtest)\s"
    )),
    ("helm-read", re.compile(
        r"^helm\s+(version|list|search|get|history|status|show|template|repo\s+list)\b"
    )),
    ("local-fs-read", re.compile(
        r"^(ls|cat|head|tail|less|grep|rg|find|file|stat|wc|sort|uniq|awk|sed|jq|yq|"
        r"tr|cut|diff|cmp|md5sum|sha256sum|date|env|hostname|uname|whoami|id|pwd|"
        r"which|whereis|type|tree|du|df|ps|netstat|ss|host|dig|nslookup)\b"
    )),
    # Fix vs plan: require EVERY arg to start with non-`/`, non-`~` (not just
    # the first). Plan's draft let `cp src ~/dst` through because only the
    # first arg was checked; the test expects miss (destination is under $HOME).
    ("local-fs-safe-write", re.compile(
        r"^(mkdir|touch|cp|mv|ln\s+-s)(\s+[^/~\s]\S*)+\s*$"
    )),
    ("version-help-wildcard", re.compile(r"\s(--version|--help|-h)\s*$")),
    # Fix vs plan: server portion uses `[\w-]+` so hyphenated server names like
    # `mcp__MaaS-Jira__jira_search` match. Plan's draft `\w+` rejected hyphens.
    ("mcp-read", re.compile(
        r"^mcp__[\w-]+__\w+_(get|search|list|find|view|read|status|stats|describe)(_\w+)?$"
    )),
]


def lane_a_match(command: str) -> Optional[str]:
    """Return the name of the first matching Lane A pattern, or None."""
    if not command or not command.strip():
        return None
    for name, pattern in LANE_A_PATTERNS:
        if pattern.search(command):
            return name
    return None
