---
description: Go standards
globs: ["**/*.go"]
---
# Go Style

## Chain
gofmt→go vet→golangci-lint→go test

## Doc
≤80ch/line|pkg comments req for non-internal

## Patterns
Accept interfaces,return structs|fmt.Errorf("%w",err)|ctx 1st param for I/O|defer Close()

## Naming
Export:PascalCase|Unexport:camelCase|Acronyms:consistent(URL or Url)

## Errors
Never _=f()|always wrap+ctx|sentinel sparingly

## Concurrency
Protect shared:mutex/chan|goroutine exit strategy|ctx for cancel

## Tests
Table-driven|t.Parallel() where safe|*_test.go
