# Validate-Recommendation E2E Gate

Paste this entire message into a sibling Claude Code session. The instructions below drive 4 `AskUserQuestion` calls against the `validate-recommendation` hook, then a final bash block renders a PASS/FAIL gate.

**Important:** do not run while another Claude Code session is active in the same user account — concurrent writes to `panel-trace.log` will pollute the snapshot diffs.

---

## Phase 1 — Pre-flight

<!-- PREFLIGHT_BLOCK -->

---

## Phase 2 — Scenarios

<!-- S1_BLOCK -->

<!-- S2_BLOCK -->

<!-- S3_BLOCK -->

<!-- S4_BLOCK -->

---

## Phase 3 — Verifier

<!-- VERIFIER_BLOCK -->
