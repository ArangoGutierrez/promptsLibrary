"""Lane A ALLOW regex tests. Each pattern needs >=1 positive and >=1 negative case."""
import pytest
from nemotron_approve.patterns import lane_a_match


@pytest.mark.parametrize("command", [
    # kubectl read
    "kubectl version --client",
    "kubectl config current-context",
    "kubectl config get-contexts",
    "kubectl get pods -n kube-system",
    "kubectl describe pod foo",
    "kubectl logs deploy/api",
    "kubectl top nodes",
    "kubectl auth can-i list pods",
    "kubectl explain pod",
    "kubectl cluster-info",
    "kubectl rollout status deploy/api",
    # gh read
    "gh auth status",
    "gh repo list --limit 5",
    "gh repo view octocat/hello",
    "gh pr list --limit 3",
    "gh pr view 42",
    "gh pr diff 42",
    "gh issue list",
    "gh api /user",
    "gh run list",
    "gh search code 'foo bar'",
    # gh author writes
    "gh pr create --title foo --body bar",
    "gh pr edit 42 --add-label backend",
    "gh pr comment 42 --body LGTM",
    "gh issue create --title bug --body 'broken'",
    "gh issue comment 42 --body 'fixed'",
    # gh api GET (no -X)
    "gh api /repos/foo/bar/issues",
    "gh api /user --jq .login",
    # git read
    "git status --short",
    "git log --oneline -10",
    "git diff HEAD",
    "git branch --show-current",
    "git remote -v",
    "git fetch --dry-run",
    # go safe
    "go version",
    "go env GOOS",
    "go vet ./...",
    "go build ./...",
    "go test ./...",
    "go mod tidy",
    # node ecosystem
    "npm install",
    "npm ci",
    "npm run test",
    "npm run build",
    "pnpm install",
    "yarn test",
    "npx tsc --noEmit",
    "npm audit",
    "npm view react",
    # build tools
    "make build",
    "make test",
    "cargo build --release",
    "helm version --short",
    "helm list --all-namespaces",
    "kustomize build .",
    # local FS read
    "ls -la /tmp",
    "cat /etc/hosts",
    "grep -r 'foo' .",
    "find . -name '*.go'",
    "jq '.x' data.json",
    # local FS safe-write (relative paths only)
    "mkdir build/output",
    "touch foo.txt",
    "cp src.txt dst.txt",
    "mv old.txt new.txt",
    # version/help wildcard
    "anything-tool --version",
    "any-cli --help",
    # MCP read
    "mcp__MaaS-Jira__jira_search",
    "mcp__mempalace__mempalace_get_drawer",
    "mcp__github__gh_pr_list",
])
def test_lane_a_matches_allowed(command):
    assert lane_a_match(command) is not None, f"Lane A should match: {command!r}"


@pytest.mark.parametrize("command", [
    # Negative: similar but NOT allowed (these will fall to Lane B or C)
    "kubectl delete pod foo",
    "kubectl apply -f deploy.yaml",
    "kubectl exec foo -- bash",
    "gh pr merge 42",
    "gh repo delete foo",
    "gh secret set FOO=bar",
    "gh api /repos/x/y -X DELETE",
    "git push origin main",
    "git reset --hard HEAD~1",
    "npm publish",
    "npm install -g foo",
    "rm -rf /tmp/foo",
    "sudo apt update",
    "mkdir /absolute/path",
    "cp src ~/dst",
    "mv ~/.ssh/id_rsa /tmp/leak",
    "echo hello",
    "curl https://example.com",
])
def test_lane_a_rejects_others(command):
    assert lane_a_match(command) is None, f"Lane A should NOT match: {command!r}"


def test_lane_a_handles_empty():
    assert lane_a_match("") is None


def test_lane_a_handles_whitespace_only():
    assert lane_a_match("   ") is None
