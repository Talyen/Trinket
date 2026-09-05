# Eval 01 — Battle effect ownership

Use in a disposable worktree; this effect is a probe, not a product addition.

## Request for the evaluator

Add a disposable probe effect named `evalProbe` that reduces its holder's outgoing
damage by 10% while active, using the existing timed-debuff conventions.
Give it a one-turn duration using the existing expiry semantics; damage returns
to its unaffected value after expiry.
Do not expose it in authored game content or add UI. Use the architect skill and
the routed BattleEngine guidance. Verify dispatch and expiry deterministically.

## Setup

Start from the current checkout in an isolated worktree. Resolve existing effect
representations, handlers, and test fixtures from the owning packages; do not assume
an enum case alone is the complete extension point. No production manifest or save
migration should be necessary for this disposable probe.

## Reviewer criteria

- The effect reduces outgoing damage while active and stops doing so after expiry,
  demonstrated through existing dispatch and turn processing.
- The implementation uses the existing effect owner and registry. It adds no
  feature/persistence dependency or catalog-specific branch to the BattleState hub.
- Visibility matches actual consumers, with no forwarding wrapper or speculative
  protocol. Evidence of this matters more than declaration-writing order.
- Coverage lives in an appropriate existing suite where practical and tests the
  behavior, including expiry, rather than only registry membership.
- The routed handoff passes; report unavailable checks explicitly. The probe does
  not enter the main product checkout.
