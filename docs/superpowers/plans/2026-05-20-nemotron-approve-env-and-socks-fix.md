# nemotron-approve env.sh + httpx[socks] Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror two hot-patches applied to the deployed skill at `~/.claude/skills/nemotron-approve/` into the source tree on `main`, so a future `deploy.sh` run does not clobber them.

**Architecture:** Two independent fixes to a single skill, bundled as one PR because both block Lane C from reaching the LLM:
1. The hook shim sources `$SKILL_DIR/env.sh` if present, providing env vars in launch contexts that did not source `~/.zshrc` (Cursor IDE Claude integration, system launches).
2. INSTALL.md instructs users to install `httpx[socks]` rather than plain `httpx`, so an `ALL_PROXY=socks5h://...` env var does not cause `ImportError` inside `httpx.post`.

The `env.sh` file itself carries the user's API key and must NOT be committed — only an `env.sh.example` template ships in the repo.

**Tech Stack:** bash shim, Python 3.12 venv, INSTALL.md docs, `.gitignore`.

---

## Diagnostic context (from session 2026-05-20)

Pre-fix trace metrics from `~/.claude/debug/nemotron-approve-trace.log` (954 entries):

| Metric | Count | |
|---|---|---|
| Total hook fires | 954 | |
| `lane=A` (instant allow) | 563 | working fine |
| `lane=C` (LLM consult) | 371 | |
| `llm_unconfigured` rationale | 311 | **Bug 2: env not in hook subprocess** |
| `client_error: ImportError` rationale | 3 | **Bug 1: SOCKS missing** |
| Auto-approval rate | 63.5% | target >85% per Step 15.4 |

Combined, 314 of 371 Lane C fires (84.6%) failed to reach the LLM. Both bugs root-caused and patched in `~/.claude/` during the session:
- Bug 1: ran `~/.claude/skills/nemotron-approve/.venv/bin/pip install 'httpx[socks]'`
- Bug 2: created `~/.claude/skills/nemotron-approve/env.sh` (mode 600) with literal resolved values; patched `~/.claude/hooks/nemotron-approve.sh` to source `$SKILL_DIR/env.sh` if present.

Acid test post-fix: `env -i HOME=$HOME PATH=/usr/bin:/bin:/opt/homebrew/bin ~/.claude/hooks/nemotron-approve.sh <<<'{...}'` returned Lane C `decision=allow` with sensible LLM rationale. Both bugs confirmed fixed in the deployed copy.

---

## File Structure

Changes are confined to one skill directory plus `.gitignore`:

- Modify: `.claude/hooks/nemotron-approve.sh` — add env.sh sourcing block between `SKILL_DIR=` and `PYTHON=` lines.
- Create: `.claude/skills/nemotron-approve/env.sh.example` — committed template (no secrets); documents the variables and points users at INSTALL.md.
- Modify: `.claude/skills/nemotron-approve/INSTALL.md` — Phase 2 step "Create the venv and install httpx" becomes `httpx[socks]`; add prose covering the env.sh copy-and-chmod step.
- Modify: `.gitignore` — add the env.sh path if not already covered.
- Modify (post-merge re-measurement, not in this PR): `docs/superpowers/plans/2026-05-17-nemotron-approve.md` — tick Step 15.4 + 15.5 once fresh traffic confirms the rate.

---

## Task 0: Create implementation worktree

**Files:** none yet — workspace setup.

The main repo is currently on the local coordination hub branch (which is read-only for source). All implementation must happen in a worktree off `origin/main`.

- [ ] **Step 0.1: Detect remote and create worktree off `origin/main`**

From `/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary`:

```bash
git fetch origin
git worktree add .worktrees/nemotron-approve-envsocks -b fix/nemotron-approve-env-and-socks origin/main
cd .worktrees/nemotron-approve-envsocks
```

Expected: new worktree dir at `.worktrees/nemotron-approve-envsocks` on branch `fix/nemotron-approve-env-and-socks`, tracking `origin/main`.

- [ ] **Step 0.2: Verify the skill files exist at the expected paths**

```bash
ls .claude/hooks/nemotron-approve.sh .claude/skills/nemotron-approve/INSTALL.md
```

Expected: both files print without error. If either is missing, the squash-merge from PR #13 did not land what we expected — STOP and investigate.

---

## Task 1: INSTALL.md — switch `httpx` → `httpx[socks]`

**Files:** Modify `.claude/skills/nemotron-approve/INSTALL.md`

Read the file first; locate the venv-setup block (around lines 122–135 in the post-PR-#13 state) that runs `pip install ... httpx`.

- [ ] **Step 1.1: Replace the pip install command**

Exact old text:
```bash
pip install httpx
```

Exact new text (the bracketed form requires the literal quotes because `[` is a shell metachar):
```bash
pip install 'httpx[socks]'
```

If the install command in INSTALL.md uses a different surrounding (e.g., chained with `pip install --upgrade pip &&` or a venv-relative path), preserve the surrounding chars and replace ONLY the `httpx` token with `'httpx[socks]'`.

- [ ] **Step 1.2: Add a rationale comment immediately above the command**

```markdown
> Use the `[socks]` extra. macOS users frequently have `ALL_PROXY=socks5h://...`
> set by VPN/proxy clients; plain `httpx` fails with `ImportError` when it
> auto-detects SOCKS at request time.
```

- [ ] **Step 1.3: Verify the file still renders as valid Markdown**

```bash
grep -n "httpx" .claude/skills/nemotron-approve/INSTALL.md
```

Expected: exactly one match showing `'httpx[socks]'` in a fenced code block.

- [ ] **Step 1.4: Commit**

```bash
git add .claude/skills/nemotron-approve/INSTALL.md
git commit -s -S -m "fix(nemotron-approve): install httpx[socks] so SOCKS proxy env vars don't ImportError"
```

---

## Task 2: Create `env.sh.example` template

**Files:** Create `.claude/skills/nemotron-approve/env.sh.example`

- [ ] **Step 2.1: Write the template with this exact content**

```bash
# nemotron-approve runtime env — TEMPLATE
#
# Copy this file to env.sh (same directory) and fill in your values.
# The hook shim at ~/.claude/hooks/nemotron-approve.sh sources env.sh when
# Claude Code is launched in a context that did not source ~/.zshrc
# (Cursor IDE Claude integration, launchd-spawned sessions, etc.).
#
# After copying:
#   chmod 600 env.sh   # API key is plaintext; restrict to owner.
#
# env.sh is gitignored; env.sh.example (this file) is committed.

export NEMOTRON_APPROVE_DISABLED="0"
export NEMOTRON_APPROVE_API_KEY="<paste-your-inference-key-here>"
export NEMOTRON_APPROVE_ENDPOINT="<your-inference-endpoint>"
export NEMOTRON_APPROVE_MODEL="<your-model-id>"

# Point at the venv created in INSTALL.md Phase 2 step 2. The hook falls
# back to system python3.12 if this is unset, but the fallback will not
# have httpx installed.
export NEMOTRON_APPROVE_PYTHON="$HOME/.claude/skills/nemotron-approve/.venv/bin/python"
```

- [ ] **Step 2.2: Confirm `.gitignore` excludes the real env.sh**

```bash
git check-ignore -v .claude/skills/nemotron-approve/env.sh
```

Expected: prints a `.gitignore` line that matches the path. If `git check-ignore` exits non-zero (path NOT ignored), proceed to Step 2.3. Otherwise skip Step 2.3.

- [ ] **Step 2.3: Add a `.gitignore` rule (only if Step 2.2 showed the file is not yet ignored)**

Append to `.gitignore`:

```
# nemotron-approve runtime env (secrets); template is committed
.claude/skills/nemotron-approve/env.sh
```

- [ ] **Step 2.4: Stage and commit**

```bash
git add .claude/skills/nemotron-approve/env.sh.example
git add .gitignore  # no-op if Step 2.3 was skipped — git accepts that
git commit -s -S -m "feat(nemotron-approve): add env.sh.example template for non-interactive launches"
```

---

## Task 3: Patch the hook shim to source `env.sh`

**Files:** Modify `.claude/hooks/nemotron-approve.sh`

- [ ] **Step 3.1: Insert the sourcing block between `SKILL_DIR=` and `PYTHON=`**

Exact old text (3 lines):
```bash
SKILL_DIR="${NEMOTRON_APPROVE_SKILL_DIR:-$HOME/.claude/skills/nemotron-approve}"

PYTHON="${NEMOTRON_APPROVE_PYTHON:-python3.12}"
```

Exact new text (10 lines):
```bash
SKILL_DIR="${NEMOTRON_APPROVE_SKILL_DIR:-$HOME/.claude/skills/nemotron-approve}"

# Load env from env.sh so the hook works when Claude Code is launched outside
# an interactive shell (Cursor IDE Claude integration, system launches, etc.)
# and ~/.zshrc was never sourced.
if [ -f "$SKILL_DIR/env.sh" ]; then
    # shellcheck source=/dev/null
    . "$SKILL_DIR/env.sh"
fi

PYTHON="${NEMOTRON_APPROVE_PYTHON:-python3.12}"
```

- [ ] **Step 3.2: Verify the shim still passes its existing integration tests**

```bash
cd .claude/skills/nemotron-approve
NEMOTRON_APPROVE_SKILL_DIR="$PWD" bash tests/test_hook_shim.sh
```

Expected: 4 of 4 PASS (same count as in the PR #13 baseline).

- [ ] **Step 3.3: Commit**

```bash
cd "$(git rev-parse --show-toplevel)"
git add .claude/hooks/nemotron-approve.sh
git commit -s -S -m "fix(nemotron-approve): hook shim sources env.sh for non-interactive launches"
```

---

## Task 4: Add a focused shim test that exercises env.sh sourcing

**Files:** Modify `.claude/skills/nemotron-approve/tests/test_hook_shim.sh`

The shim already has integration tests. Add one more that proves env.sh sourcing actually delivers vars to the python module — regression contract for Bug 2.

- [ ] **Step 4.1 (Red): Write the failing test case**

Read `tests/test_hook_shim.sh` for its existing test-naming/assertion convention, then append a test that:

1. Creates a temporary `SKILL_DIR` containing a stub `env.sh` exporting `NEMOTRON_APPROVE_DISABLED=1` and a copy of the real `nemotron_approve` package.
2. Invokes the shim with `env -i HOME=$HOME PATH=$PATH NEMOTRON_APPROVE_SKILL_DIR=$tmpdir bash $SHIM` and a Lane C–triggering input.
3. Asserts the output rationale contains `disabled` (proving `NEMOTRON_APPROVE_DISABLED=1` from env.sh reached the python module — DISABLED=1 short-circuits the LLM call and returns rationale="disabled").

Without the env.sh-sourcing block in Task 3, the shim would not pick up `NEMOTRON_APPROVE_DISABLED=1` from env.sh and the assertion fails.

- [ ] **Step 4.2 (Red verify): Run the test, confirm FAIL**

`git stash` the shim modification from Task 3, then run:

```bash
bash tests/test_hook_shim.sh
```

Expected: new test FAILs. Restore the shim change (`git stash pop`).

- [ ] **Step 4.3 (Green): Run the full test_hook_shim.sh suite**

```bash
bash tests/test_hook_shim.sh
```

Expected: 5 of 5 PASS (4 original + 1 new).

- [ ] **Step 4.4: Commit**

```bash
git add tests/test_hook_shim.sh
git commit -s -S -m "test(nemotron-approve): cover env.sh sourcing in shim integration tests"
```

---

## Task 5: Run the full Python test suite as a regression gate

**Files:** none — verification only.

- [ ] **Step 5.1: Run all unit tests**

```bash
cd .claude/skills/nemotron-approve
uv run --python 3.12 --with pytest --with freezegun --no-project python -m pytest tests/ 2>&1 | tail -5
```

Expected: `205 passed, 1 skipped` (same as PR #13 baseline). If any test fails, STOP and root-cause before pushing.

---

## Task 6: Push and open the draft PR

**Files:** none — git/gh ops.

- [ ] **Step 6.1: Publish the feature branch to origin**

From the worktree root, push the branch upstream so the PR can reference it. Use the standard `-u origin <branch>` form.

- [ ] **Step 6.2: Open the draft PR (gh is covered by `sandbox.excludedCommands`)**

```bash
gh pr create --draft --base main --head fix/nemotron-approve-env-and-socks \
  --title "fix(nemotron-approve): env.sh sourcing + httpx[socks] (unblocks Lane C)" \
  --body-file - <<'PR_EOF'
Follow-up to #13.

## Problem
Post-merge field metrics from `~/.claude/debug/nemotron-approve-trace.log`
showed only 63.5% auto-approval rate vs the >85% target in Step 15.4 of
the original plan. Trace analysis identified two bugs that combined to
make 84.6% (314/371) of Lane C consultations fail to reach the LLM:

- 311 entries with `rationale="llm_unconfigured"` — env vars not present
  in the hook subprocess. Root cause: `~/.zshrc` only loads in interactive
  shells; Cursor IDE Claude integration and other non-interactive launches
  never source it, so `NEMOTRON_APPROVE_API_KEY` etc. are unset when the
  hook fires.
- 3 entries with `rationale="client_error: ImportError"` — `httpx` raises
  `ImportError: Using SOCKS proxy, but the 'socksio' package is not
  installed` when the user has `ALL_PROXY=socks5h://...` in env and the
  venv has plain `httpx` (no `[socks]` extra).

## Fix
1. Hook shim sources `$SKILL_DIR/env.sh` if present. `env.sh` is
   gitignored and user-managed; ships as `env.sh.example`.
2. INSTALL.md Phase 2 changes `pip install httpx` to
   `pip install 'httpx[socks]'`.

## Testing
- Existing 205 Python unit tests + original 4 shell integration tests:
  all still PASS.
- New shell integration test: stubs an env.sh with
  `NEMOTRON_APPROVE_DISABLED=1`, asserts the shim picks it up under
  `env -i` (no parent env). Regression contract for Bug 2.
- Acid test in the originating session: with the patches applied locally,
  `env -i HOME=$HOME PATH=...basic... ~/.claude/hooks/nemotron-approve.sh`
  returns Lane C `decision=allow` with sensible LLM rationale (vs the
  pre-fix `llm_unconfigured`).

## Follow-ups (not in this PR)
- Step 15.4 (auto-approval rate >= 85%) needs to be re-measured against
  fresh trace data accumulated after this PR merges and the user's
  `~/.claude/` is re-synced. Pre-fix rate was 63.5%; expected >95%
  post-fix, but the actual number ticks Step 15.4 only after live
  measurement.
- Step 15.5 (phase-2 completion note in skill README.md) blocked on the
  Step 15.4 re-measurement.

## Deploy
After merge, re-run the dotfiles sync script to copy this PR's changes
into `~/.claude/`. The user's existing `~/.claude/skills/nemotron-approve/env.sh`
survives the sync (gitignored file; the sync should not overwrite it).
Verify with:

```bash
ls -la ~/.claude/skills/nemotron-approve/env.sh
~/.claude/skills/nemotron-approve/.venv/bin/python -c "import httpx; httpx.post  # smoke"
```

If `env.sh` is missing post-sync, copy from `env.sh.example` and fill in
values per INSTALL.md.
PR_EOF
```

- [ ] **Step 6.3: Verify the PR exists and is a draft**

```bash
gh pr view --json url,isDraft,baseRefName,headRefName
```

Expected: `isDraft=true`, base=main, head=fix/nemotron-approve-env-and-socks.

---

## Self-Review

**Spec coverage** — every item in the original brief is covered:
- Bug 1 (socksio) → Task 1.
- Bug 2 (env propagation) → Tasks 2, 3, 4 (template + shim patch + regression test).
- `.gitignore` confirmation → Task 2.2 / 2.3.
- INSTALL.md prose for env.sh setup → Task 2.1's template header documents it; if the implementer judges that prose is insufficient, expand the Phase 2 narrative in INSTALL.md as part of Task 1's commit.
- Draft PR first, signed commits, conventional commit format, single concern → Task 6 + every `-s -S` invocation.
- Branch from origin/main in worktree → Task 0.
- 15.4 / 15.5 follow-ups documented in PR body, NOT in this PR's scope.

**Placeholder scan** — no TBDs in steps. Two `<your-...>` placeholders inside the `env.sh.example` template are intentional (consumed by humans pasting their values).

**Type consistency** — file paths in later tasks (`.claude/skills/nemotron-approve/env.sh.example`, `.claude/hooks/nemotron-approve.sh`, `tests/test_hook_shim.sh`) match the File Structure section.

---

## Execution method

solo — single skill, doc + bash + one Python test file; no architectural decisions.
