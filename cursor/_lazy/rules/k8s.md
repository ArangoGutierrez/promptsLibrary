---
description: Kubernetes patterns
globs: ["**/k8s/**", "**/*.yaml", "**/manifests/**", "**/deploy/**"]
---
# K8s

## Lifecycle
graceful shutdown(SIGTERM)|probes(liveness+readiness)|resource limits

## Config
no hardcoded secrets→Secret/ConfigMap|env from refs

## Labels
app,version,component,part-of

## Security
non-root|read-only rootfs|drop capabilities
