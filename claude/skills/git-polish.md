---
name: git-polish
description: Rewrite messy local commit history into clean, atomic, signed commits following Conventional Commits. Interactive workflow that groups changes logically, verifies each commit compiles and is accurate, then creates properly signed commits with DCO and GPG signatures.
disable-model-invocation: true
allowed-tools: Bash, Read
model: haiku
---

# Git History Polish

Rewrite local commits into clean, atomic, signed commits.

## Setup (First Time)

Configure GPG signing and DCO:

```bash
# Use SSH for signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub

# Enable automatic signing
git config --global commit.gpgsign true

# Set editor for interactive operations
export GIT_EDITOR="true"
```

## Workflow

### Step 1: Review Current History

Show recent commits to understand what needs polishing:

```bash
git log --oneline -n 10
```

**Ask user**: How many commits back to rewrite?

### Step 2: Soft Reset

Reset to target commit, keeping all changes staged:

```bash
git reset --soft HEAD~{N}
```

**Result**: All changes from last N commits are now in staging area

### Step 3: Check Current State

```bash
git status
```

Review all files that will be reorganized.

### Step 4: Group Changes

Organize changes into logical, atomic commits:

**Grouping rules**:

- `chore(config)`: Configuration changes (`.json`, `.yaml`, `.toml`, `.env.example`)
- `refactor(rename)`: Renames without logic changes
- `feat(scope)`: New features by domain
- `fix(scope)`: Bug fixes by domain
- `docs`: Documentation only
- `test`: Test additions/changes
- `perf`: Performance improvements
- `style`: Formatting/style changes

**By domain**: Group related functional changes together

- auth: Authentication/authorization
- api: API endpoints
- db: Database/storage
- ui: User interface
- core: Core business logic

### Step 5: Verify Each Commit

Before creating each commit, verify:

**Questions to ask**:

- ✓ **Single type**: Does this commit contain ONLY the stated type (no mixing feat + refactor)?
- ✓ **No cross-cutting**: Does it touch only related files?
- ✓ **Compiles**: Will the codebase compile after this commit?
- ✓ **Message accurate**: Does the message precisely describe changes?

**Validation**:

- ✓ Valid: Create commit
- ✗ Split: Too large or mixed, split into multiple commits
- ? Review: Unclear, ask user

### Step 6: Create Atomic Commits

For each logical group:

```bash
# Stage specific files
git add path/to/file1.go path/to/file2.go

# Create signed commit with DCO
git commit -S -s -m "type(scope): description

Optional longer explanation.

Breaking change notes if applicable."
```

**Flags**:

- `-S`: GPG sign the commit
- `-s`: Add DCO Signed-off-by trailer
- `-m`: Inline message (no editor)

**Conventional Commit format**:

```
type(scope): short description

[optional body]

[optional footer]
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change without behavior change
- `docs`: Documentation only
- `test`: Test additions/changes
- `chore`: Build process, tooling, dependencies
- `perf`: Performance improvement
- `style`: Formatting, whitespace
- `ci`: CI/CD changes

### Step 7: Verify Signatures

After creating all commits, verify they're properly signed:

```bash
git log --show-signature -n {COUNT}
```

**Check**:

- ✓ **Signed**: GPG signature present
- ✓ **DCO**: "Signed-off-by" trailer present
- ✓ **Conventional**: Format follows "type(scope): desc"
- ✓ **Compiles**: Each commit builds successfully (optional but recommended)

## Output Format

```markdown
## Git History Polished

### Before
```

abc1234 WIP
def5678 fix stuff
ghi9012 more changes
jkl3456 actually works now

```

### After
```

aaa1111 feat(auth): add JWT authentication
bbb2222 refactor(api): extract validation logic
ccc3333 test(auth): add login handler tests
ddd4444 docs: update API documentation
eee5555 chore(deps): update go.mod dependencies

```

### Verification
✓ All commits GPG signed
✓ All commits have DCO signoff
✓ All commits follow Conventional Commits
✓ Each commit compiles independently

### Summary
- **Original commits**: 4 messy commits
- **Polished commits**: 5 atomic commits
- **Signed**: ✓ All
- **DCO**: ✓ All
- **Ready to push**: ✓ Yes
```

## Constraints

- **Atomic commits**: Each commit must be self-contained and compilable
- **Signed commits**: All commits must have both GPG signature (-S) and DCO signoff (-s)
- **Conventional format**: Follow Conventional Commits specification
- **No mixed types**: Don't mix feat + fix in same commit
- **Descriptive messages**: Message must accurately describe changes
- **Preserve work**: Never lose changes during rewriting

## When to Use

**Use /git-polish when**:

- Before pushing to shared branch
- Local history is messy
- Want clean, reviewable history
- Preparing PR for review

**Don't use /git-polish for**:

- Already pushed commits (use with caution)
- Shared branch history
- Single clean commit (unnecessary)

## Related Skills

- `/code` - Implements with automatic signed commits
- `/task` - Creates atomic commits by design
- `/self-review` - Review before polishing
