# Eval 03 — Visual quality

## Request for the evaluator

Improve Shop's composition and visual polish using apple-design. Keep purchase
rules and navigation. Make artwork and the purchase decision clearer, and remove
redundant explanation. Use real offers and costs. Show two distinct compositions
if no visual direction has been selected, then implement the selected direction.

## Setup

Use a disposable worktree and route the current Shop paths. Supply the real
baseline screen and any explicit user references or preferences. For a behavioral
trial, render through a managed simulator/device and keep its implementation out
of the product change. For guidance-only edits, walk through the cases below;
report scenario review separately from an executed rendered trial.

## Reviewer criteria

- Alternatives differ in composition, not just color. No existing screen is
  represented as user-approved without evidence of that preference.
- Artwork, prices, and purchase choices have a deliberate visible hierarchy.
  Essential rules and consequences survive; redundant subtitles and button
  explanations do not become replacement help panels.
- The final implemented UI is actually rendered and inspected at phone size,
  including affordable/unaffordable states and long names. A mockup, successful
  capture command, lint PASS, or interaction test cannot stand in for that review.
- Visible defects lead to a correction and another render/review; a satisfactory
  first render needs a specific review, not a fabricated iteration.
- Motion claims have interaction/recording evidence. Final artifacts remain
  accessible after worktree cleanup and identify the build and state reviewed.
- Missing render tools produce an explicit “implemented, visually unverified”
  blocker, never a claim of visual completion or a request for routine permission.

## Guidance review cases

Trace the instructions for: (1) a new composition with an unresolved direction;
(2) a single redundant subtitle removal; (3) a render with a clipped price needing
revision; (4) unavailable render tooling; (5) an attractive source image whose
shipping crop loses the focal subject. Confirm that small edits avoid redesign
ceremony while all changed visuals retain the completion gate.
