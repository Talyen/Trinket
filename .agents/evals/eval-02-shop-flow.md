# Eval 02 — Shop affordance

Use in a disposable worktree; this is a scoped UI probe.

## Request for the evaluator

In Shop, make an unaffordable offer's price visually distinguishable using the
existing design system. Preserve purchase rules, offer layout, and navigation.
Use the apple-design skill and verify the affordable and unaffordable states.

## Setup

The screen is `Trinket/Features/Play/Shop/ShopEncounterView.swift`. Route the actual
changed paths for current guides and smoke ownership. Use existing Shop fixtures
and test identifiers where possible; do not invent a new flow for the probe.

## Reviewer criteria

- The price treatment distinguishes the two states and uses a semantic design-system
  role. It preserves the current price, purchase eligibility, and navigation.
- No unrelated animation, glass, layout, or new public abstraction appears.
- Existing identifiers and image semantics remain intact. A styling change does not
  manufacture a new AccessibilityID merely to satisfy a checklist.
- Visual evidence covers both states. A screenshot supports appearance; any claim
  about purchasing requires exercising that action or relevant existing tests.
- Coverage follows Testing.md: extend meaningful existing coverage only if needed.
  Use the routed isolated handoff and targeted smoke when interaction verification
  calls for it; do not bypass generation with an unconditional environment flag.
- Report what was actually observed and any blocked verification. The probe does
  not enter the main product checkout.
