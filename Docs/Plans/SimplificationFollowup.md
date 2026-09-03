---
type: execution-plan
status: active
created: 2026-09-01
updated: 2026-09-03
expires: 2026-09-15
---

# SimplificationFollowup

## Objective

Finish only residual simplification work with a confirmed correctness or
maintenance win. Keep gameplay balance and artwork budgets unchanged.

## Plan

- [ ] **1. Frozen mystery preview.** Make the preview ticket authoritative even
  when pinning fails, then add persistence/reload coverage for the same encounter
  level and reward preview.
- [ ] **2. Codegen correctness.** Replace fragile `publicize`/brace counting with
  schema-driven access emission, fix `swift_escape` round trips, and add focused
  regression cases for quotes, backslashes, and braces.
- [ ] **3. Measured performance proposals.** Benchmark damage-resolution rescans
  and combat-feedback layering first. Implement a snapshot or feedback dedup only
  when measurement confirms a bounded win; otherwise record a non-finding.

## Explicitly deferred

Do not pursue broad trigger-codegen, BattleState/TalentState regrouping, lifecycle
phase renaming, `nextEventID` reseeding, or removal of the primitive
`CombatantRuntime.heal` method without new evidence. The engine phase and runtime
lifecycle represent different state machines, and the hand-buffer/target-resolver
consolidations are already complete.

## Verification

Use path-scoped isolated handoff for each implementation slice, focused package or
script tests for changed behavior, and `python3 Scripts/check-docs.py` after plan
metadata changes.

## Disposition

This plan supersedes the deferred portions of `ElegantSimplificationRound4` and
`SimplificationConsolidationRound2`; their outcomes are retained in the archived
plan ledger and their full detail remains in Git history.
