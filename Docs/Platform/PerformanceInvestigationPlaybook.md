# Performance Investigation Playbook

Use this only for a reported or measured performance, memory, battery, or lifecycle regression. It is deliberately not an autonomous coding audit: static grep cannot prove that a view is slow, memory leaks, or energy use is excessive.

## Intake

Capture the affected device/OS, exact flow, player-visible symptom, frequency, and comparison point. Establish a baseline before editing. Simulator behavior is useful for reproduction, but real-device evidence decides perceived smoothness and energy conclusions.

## Investigation

1. Reproduce the specific flow with a release-like build where practical.
2. Measure the relevant signal: Time Profiler for stalls, Allocations/Leaks for growth, or Energy Log for background/tick behavior.
3. Identify the responsible call stack or retained object. A static pattern such as `AnyView`, `Task`, `Timer`, or `GeometryReader` is only a lead.
4. Make one hypothesis-driven change that preserves BattleEngine isolation and player-visible behavior.
5. Re-run the same scenario and compare the measurement with the baseline.

## Guardrails

- Do not move battle simulation off `@MainActor`, add weak captures, erase views, or rewrite layout merely because a grep probe found a pattern.
- Verify scene-background behavior through the actual battle/session lifecycle.
- Prefer a focused correctness regression test when the fix changes lifecycle or state semantics; profiling itself is not a unit-test substitute.
- If hardware, Instruments, or a reproducible symptom is unavailable, report the limitation and make no speculative performance change.

## Report

Record the device/OS, flow, baseline, measured cause, changed files, after result, and verification. If the evidence does not identify a cause, close the investigation without a code change.
