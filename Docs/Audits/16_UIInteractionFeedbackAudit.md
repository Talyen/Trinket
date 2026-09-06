# 16. UI Interaction Audit

**Goal:** Repair interaction and feedback defects that prevent players from completing
or understanding a flow.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
[PD-014](../Product/Decisions.md) owns basic accessibility semantics;
[SwiftUI guidance](../AgentContext/swiftui-features.md) owns feature integration.

## What to investigate

Unusable navigation/dismissal, competing gestures, unclear action feedback,
incoherent enabled/loading/error/retry states, hidden required actions, and flows
that fail to recover from interruption. Review consequential flows by risk; expand
a confirmed component defect to its affected callers.

Controls should communicate action and state. Native buttons are preferred, while
intentional game gestures can be valid. Image labeling/hiding and stable test
identifiers follow existing product and testing contracts. Preserve portrait-first
game interaction and existing accommodations; do not add bespoke accessibility
modes, setting-specific layouts/tests, or iPad-only interaction work.

## Evidence

Trace the complete interaction before declaring a missing safeguard. Native dismissal,
a shared control, store-level idempotency, or a lifecycle owner may already satisfy
the requirement. Missing local debounce, `scenePhase`, `Button`, or progress-indicator
syntax is not proof of wrong behavior. Confirm whether repeat input, cancellation,
or interruption actually violates the flow's contract.

Source can prove unreachable dismissal, missing required semantics/identifiers,
or a reachable incorrect transition. Gesture conflicts, feedback feel, obscured
controls, and progress timing usually need runtime observation. Without it, report
unverified candidates and the missing check rather than shipping speculative changes.

## Remedy and success

Restore a usable flow with coherent feedback and preserve its product contract.
Apply confirmation only where the destructive-action policy requires it; do not
add friction to intentional immediate actions such as Homestead upgrades.
Verify affected entry, action, completion, and recovery conditions as appropriate.
Reuse coverage under [Testing](../Platform/Testing.md), including its identifier
change requirements; do not create UI tests merely to inventory controls.

Layout/typography migrations belong to [01](01_AppleNativeUIAudit.md); test-harness
quality belongs to [10](10_E2ETestQualityAudit.md). Use the shared table for durable
transaction failures and other overlaps.
