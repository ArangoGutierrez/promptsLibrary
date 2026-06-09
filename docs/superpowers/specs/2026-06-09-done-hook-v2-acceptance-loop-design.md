# Done-Hook v2 — Acceptance Loop (NVIDIA Inference Hub)

- **Date:** 2026-06-09
- **Status:** Draft (awaiting user review)
- **Author:** Eduardo (with Claude)
- **Topic:** Augment `done-hook.sh` into an active control loop that uses NVIDIA Inference
  Hub to judge whether the session's original goal / prompt intent was fulfilled, and
  re-prompts the agent ("triggers a new loop") when it was not.
- **Origin:** The "Skills … Control Loops Are" email (Di Chen, NIM Factory) + the
  "DEVELOPMENT PATH" V-model image. This implements the **Requirements ↔ Acceptance**
  verification pair (the image's `Agent → Remediation` arrow), the semantic counterpart
  to the deterministic `completion-gate` (Coding ↔ Unit pair).
- **Sibling spec:** `2026-06-09-completion-gate-design.md` (separate feature, separate PR).

## 1. Problem

`done-hook.sh` today is **passive**: it computes a deterministic evidence heuristic
(`LIKELY_MET` / `PARTIAL` / `NO_EVIDENCE`) against the `/goal` acceptance bullets, prints
an informational block to stderr, and **always `exit 0`**. It never pulls the agent back
to finish unmet work — exactly the "static stop condition" the email says doesn't change
behavior. Two gaps:

1. **No active loop.** A `PARTIAL`/`NO_EVIDENCE` verdict should be able to re-prompt the
   agent, not just whisper to stderr.
2. **"Fulfilled?" is semantic, not deterministic.** Whether work satisfies the *intent*
   of a goal or opening prompt cannot be answered by bullet-token matching; it needs a
   reviewer with judgment. Per the email, that reviewer is an LLM **inside a deterministic
   control loop** (stop-condition, bounded retries, escape hatch).

## 2. Why an LLM here, when completion-gate *removes* one

Not a contradiction — the governing rule:

- **Deterministic** checks where the question is observable ("did a test run after an
  edit" → completion-gate replaces the LLM-judge).
- **LLM reviewer** where the question is inherently semantic ("was the intent fulfilled").
- **Always wrap the LLM in a deterministic shell**: engagement gate, budget cap,
  state-hash debounce, escape hatch. The email's own *data-wall reviewer* is an LLM in a
  loop; its failure was static prompts with no loop, not "used an LLM."

## 3. Goals / Non-goals

### Goals
- Turn `done-hook.sh` into an **active acceptance loop**: on a credible "not fulfilled"
  verdict, `exit 2` with the reviewer's next-steps as the reprompt.
- Judge fulfillment of the **`/goal` if present, else the opening user prompt's intent**
  (incl. a task-skill like `/review`) — so goal-less sessions are covered.
- Keep it **affordable and non-intrusive** via a deterministic engagement gate; never
  fire on trivial Q&A / read-only sessions.
- **Fail-open** (Inference Hub down/timeout/no key → allow stop) and **loop-safe**
  (bounded retries + debounce + escape).
- **Reuse** the proven Inference Hub plumbing in `validate-recommendation`
  (`panel dispatch` → `ChatNVIDIA`); do not reinvent the client.

### Non-goals (YAGNI)
- Not a replacement for the deterministic heuristic — it **layers on top** of it.
- No autonomous-agent aggressiveness. This runs in **interactive** sessions; the reviewer
  biases toward `PASS` on ambiguity (see §8 calibration).
- No coverage of correctness of code edits — that's `completion-gate`'s job.

## 4. Inference Hub mechanism (reused, verified)

`validate-recommendation`'s `panel dispatch` already calls Inference Hub:
- Client: `langchain_nvidia_ai_endpoints.ChatNVIDIA`
- Auth: `PANEL_DA_API_KEY` (fallback `NVIDIA_API_KEY`) — in `~/.zshenv`
- Endpoint: `CLAUDE_PANEL_DA_ENDPOINT` (normalized to `/v1`)
- Model: `nvidia/nvidia/nemotron-3-ultra`, `timeout_seconds: 60`
- Output: a verdict file with `VERDICT: / RATIONALE: / …` lines

**Plan:** add an `acceptance` panelist to `~/.claude/panel/config.yml` (backend `nat-nim`,
same model) and a persona `personas/acceptance-reviewer.md`. `done-hook.sh` shells out:
```
python3.12 -m panel dispatch --panelist acceptance --config <cfg> \
  --persona <acceptance-reviewer.md> --prompt-file <built> --output <verdict>
```
then parses the `VERDICT:` line itself (no `aggregate`, which is recommendation-specific).
**Dependency note:** this couples the hook to the `panel` package — acceptable reuse;
recorded as a risk.

## 5. Intent resolution

- **`/goal` present** → primary intent = `Goal:` line + `Acceptance:` bullets from
  `session-goals/<uuid>.md`; opening prompt passed as context.
- **No `/goal`** → intent = the **first user message** in the transcript (verbatim,
  including any leading `/skill` command, e.g. `/review <PR>`).

## 6. Engagement gate (deterministic — the cost/intrusiveness control)

Call the reviewer **only if ALL** hold:
1. Budget not exhausted (ledger re-prompt count < cap).
2. State-hash changed since the last review (don't re-judge identical state).
3. The session is **task work**, i.e. ANY of:
   - a `/goal` file exists, **or**
   - the opening prompt invokes a **deliverable task-skill** (allowlist: `/review`,
     `/debug`, `/k8s-debug`, `/go-review`, … — tunable), **or**
   - the session made **mutating** changes (≥1 `Write`/`Edit`, `git push`, `kubectl apply`,
     PR ops). *Read-only tool use (searches, reads) does **not** count.*
4. (Goal-present only) deterministic heuristic ≠ `LIKELY_MET`. *(Goal-less has no bullet
   heuristic; rely on the task-work signal.)*

**Skip → silent `exit 0`** otherwise. This is what spares trivial sessions (e.g. opening
with "read email …", pure Q&A) from any LLM call or reprompt.

## 7. Reviewer contract

**Input (prompt-file):** intent (§5), acceptance bullets if any, the original opening
prompt, and an **evidence digest** (the deterministic evidence block + a compact tail of
the transcript: tool actions + final assistant message).

**Output (verdict file):**
```
VERDICT: PASS | CONTINUE | DATA-WALL
RATIONALE: <one paragraph>
NEXT-STEPS: <only for CONTINUE: 1-3 concrete, reachable actions>
```

## 8. Calibration (interactive, not autonomous)

The reviewer persona must **default to `PASS` when fulfillment is ambiguous**, returning
`CONTINUE` only when there is a **concrete, reachable, clearly-unmet** part of the intent.
The email's NIM Factory agent is autonomous (continue aggressively); this gate runs with a
human present, so over-eager looping is a UX cost. Budget + escape bound the worst case;
calibration prevents routine nagging.

## 9. Decision flow at Stop

```
v1 deterministic heuristic runs (unchanged: evidence block + outcomes log)
if not engaged (gate §6 fails):              exit 0   (silent)
build prompt-file (intent + bullets + opening prompt + evidence digest)
verdict = panel dispatch acceptance reviewer (timeout 60s)
  dispatch error / timeout / no key:         exit 0   + log (fail-open)
case verdict:
  PASS:                                      exit 0   + log
  DATA-WALL:                                 exit 0   + log
  CONTINUE:
     if last assistant msg has ^VERIFY-WAIVED: exit 0 + log waiver
     ledger.count++ ; if count > cap:        exit 0   + log "budget exhausted"
     else:                                   exit 2   + reprompt = RATIONALE + NEXT-STEPS
```

## 10. Loop safety

- **Budget cap:** default **3** re-prompts per goal/intent (≈ CLAUDE.md "Moderate"; reuse
  the `re_brainstorm.max_cycles` idea). After cap → allow stop, logged.
- **State-hash debounce:** key on (session, intent-hash, evidence-hash). Identical state →
  don't re-review; allow stop.
- **Escape hatch:** `VERIFY-WAIVED: <reason>` in the final message → allow stop (shared
  with completion-gate).
- **`stop_hook_active`** honored as a backstop.

## 11. Error handling / cost

- Any failure (no `transcript_path`, dispatch non-zero, timeout, missing key, parse fail)
  → **`exit 0`** (fail-open) + one audit line. A judge outage must never wedge a session.
- Latency bounded by the 60s dispatch timeout; the engagement gate keeps calls rare.
- Audit: append to `session-outcomes-*.log` + `~/.claude/panel/decisions.jsonl`.

## 12. Testing (TDD — deterministic seams; LLM mocked)

The reviewer call is injected through an overridable command (e.g. `$DONE_REVIEW_CMD`,
default `python3.12 -m panel dispatch …`) so tests feed a **canned verdict file** — same
seam panel tests use to fake `ChatNVIDIA`. `done-hook_test.sh` adds:

| # | Fixture | Expect |
|---|---|---|
| 1 | Goal-less session opened with non-task prompt ("read email"), read-only tools | exit 0, reviewer **not** invoked (gate skip) |
| 2 | Opening prompt `/review <PR>`, canned verdict `PASS` | exit 0 |
| 3 | Opening prompt `/review <PR>`, canned `CONTINUE` + NEXT-STEPS | exit 2, reprompt contains NEXT-STEPS |
| 4 | `/goal` set, heuristic `LIKELY_MET` | exit 0, reviewer **not** invoked (cost gate) |
| 5 | `/goal` set, heuristic `PARTIAL`, canned `CONTINUE` | exit 2 |
| 6 | `CONTINUE` but ledger count == cap | exit 0 (budget exhausted) |
| 7 | `CONTINUE` but final msg has `VERIFY-WAIVED:` | exit 0 (waiver logged) |
| 8 | Identical state already reviewed (debounce) | exit 0, reviewer not invoked |
| 9 | Dispatch returns non-zero / no key | exit 0 (fail-open) |
| 10 | Session with file edits but no goal/skill, canned `CONTINUE` | exit 2 (mutating-work engages gate) |

**Mutation check:** removing the `CONTINUE ⇒ exit 2` branch breaks #3, #5, #10; removing
the gate breaks #1.

## 13. Relationship to completion-gate

| | completion-gate | done-hook v2 |
|---|---|---|
| Pair | Coding ↔ Unit | Requirements ↔ Acceptance |
| Trigger | unverified source edit | goal/intent possibly unmet |
| Mechanism | deterministic | LLM reviewer in a loop |
| Cost | ~free | gated Inference Hub call |
| Ships as | own PR | own PR |

They compose; neither depends on the other.

## 14. Open questions

- **Budget value:** 3 (default) — tie to CLAUDE.md iteration budget by task size, or fixed?
- **Task-skill allowlist:** initial set `/review /debug /k8s-debug /go-review`; confirm.
- **`acceptance` panelist vs reuse `da-nemotron`:** new panelist is cleaner; confirm adding
  it to `config.yml`.

## 15. Decision Log

- **No-`/goal` coverage:** user requires judging goal-less sessions via the opening prompt
  (e.g. `/review`), not only when `/goal` is set.
- **Engagement gate** added (deterministic) to keep that affordable / non-intrusive.
- **LLM-in-loop** reconciled with completion-gate's LLM-judge removal via the
  observable-vs-semantic rule (§2).
- **Reuse** `panel dispatch` for Inference Hub rather than a new client.
