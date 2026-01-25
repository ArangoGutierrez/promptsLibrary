# Test
(no args)→full|`--quick`→changed|`--file {p}`→specific

## Detect
go.mod→`go test ./...`
package.json→`npm test`
pyproject.toml|requirements.txt→`pytest`
Cargo.toml→`cargo test`

## Run
{cmd}→Status:PASS/FAIL|Tests:{pass}/{total}|Duration

## Fail
|Test|Error|+Suggested fix
→/code→/test

## Update AGENTS.md
pass→[DONE]|fail→[BLOCKED:tests failing]

## Quick
`git diff --name-only HEAD~1`→targeted tests
