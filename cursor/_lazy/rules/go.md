---
description: Go patterns
globs: ["**/*.go"]
---
# Go

## Chain
gofmt→vet→lint→test

## Pattern
interfaces-in,structs-out|ctx 1st|defer Close|%w wrap

## Error
Never `_=f()`|wrap+ctx|sentinel sparingly

## Concurrency
mutex/chan for shared|goroutine exit strategy|ctx cancel

## Test
table-driven|t.Parallel()|*_test.go
