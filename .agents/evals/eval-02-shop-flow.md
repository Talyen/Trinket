# Eval 02 — Shop flow affordance

Tests whether `apple-design` + `swiftui-features` guidance helps an agent ship a minimal player-facing shop change with correct accessibility and smoke ownership.

## Goal
Add or adjust a Shop affordance in `Trinket/Features/Play/Shop/` (or `Trinket/Features/Collection` → Shop entry) with correct DesignSystem routing and stable test hooks.

## Setup
- Touch: `Trinket/Features/Play/Shop/*` or `TrinketUITests/Play/ShopFlowUITests.swift`
- Read: `Trinket/Features/AGENTS.md`, `Docs/AgentContext/swiftui-features.md`, `.agents/skills/apple-design/SKILL.md`, `Docs/Platform/Testing.md` (keep/drop rubric)
- Route: `./Scripts/agent-context.sh --agent --paths <touched>` confirms smoke target `SmokeShopTests`

## Steps
1. Implement the affordance using `TrinketDesignSystem` primitives (no one-off color literals, no `DesignAssetColors`).
2. Assign a stable `AccessibilityID` constant (queried by `AccessibilityID.*` in UITests per `check-accessibility-ids.sh`).
3. Add smoke coverage only if it meets the keep/drop rubric (state-changing journey or safety invariant); otherwise rely on package tests.

## Pass criteria
- `SKIP_GENERATE=1 ./Scripts/test.sh smoke SmokeShopTests` canary passes (or `handoff.sh` routes it).
- `./Scripts/check-ui-style.sh` and `check-accessibility-ids.sh` pass (no `check-ui-style` product-color bypass without allow comment).
- `./Scripts/test.sh style <touched-swift>` passes.
- No unnecessary animation/material polish beyond request (change-discipline priority in apple-design skill).

## Anti-goals
Do not copy display strings into tests; assert `AccessibilityID` + one visible outcome. Do not add nav-path pushes under launch cover.

## Handoff gate
`./Scripts/handoff.sh --isolate --paths Trinket/Features/Play/Shop/<touched> TrinketUITests/Play/ShopFlowUITests.swift`
