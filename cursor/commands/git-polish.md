# Git Polish

Rewrite local history into atomic, signed commits.

## Setup
```bash
export GIT_EDITOR="true"
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true
```

## Workflow

### 1. Reset
```bash
git log --oneline -n 10
```
Ask: "How many commits back?" → `git reset --soft [TARGET]`

### 2. Analyze
`git status` → Group by type:
- **Chore**: configs (go.mod, Dockerfile)
- **Refactor**: renames, moves
- **Feat/Fix**: logic changes (by domain)

### 3. Verify Groupings
For each group:
- Contains ONLY stated type?
- Cross-cutting changes?
- Compiles independently?
- Message accurate?

Answer INDEPENDENTLY → ✓valid / ✗split / ?review

### 4. Reconstruct
```bash
git commit -S -s -m "type(scope): description"
```
- `-S`: SSH-sign
- `-s`: DCO signoff
- `-m`: inline

### 5. Verify
```bash
git log --show-signature -n [COUNT]
```

- [ ] All signed ✓
- [ ] Each compiles ✓
- [ ] Conventional Commits ✓

## Constraints
- **No editor**: use `-m`
- **Atomic**: each commit compiles
- **Conventional Commits**: type(scope): desc
