# Liquid Glass Migration Plan

Detailed implementation plan for migrating Trinket's custom chrome to iOS 26 Liquid Glass. Complements [iOS26StackAudit.md](iOS26StackAudit.md) and [iOS26AppleReference.md](iOS26AppleReference.md).

**Status (July 2026):** Phases 0–3, 5–6 **complete**. Liquid Glass design-system migration is done. Toolbar background overrides on Battle and combatant detail are **retained intentionally** (art-forward chrome) and are not part of this plan. Remaining Apple-native follow-ups live in [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md).

**Scope:** `TrinketDesignSystem` modifiers, primary CTA styling, and chrome that sits over artwork. Accessibility audit removal and the visual-first baseline are documented in PD-007; this plan does not reintroduce accessibility audits.

**Principle:** Glass on **functional chrome** (chips, pills, primary actions, bottom bars over artwork). Solid themed surfaces on **dense content** (Collection grids, Inventory rows, Options forms) via `TrinketDesignSystem` / `VisualFoundation`.

---

## Goals

| Goal | Success criteria |
|------|------------------|
| Unified glass primitives | All custom translucent chrome routes through shared helpers with one consistent material policy |
| No raw glass in features | `check-ui-style.sh` passes; feature views call design-system modifiers only |
| Primary CTAs match iOS 26 | `trinketPrimaryActionButton()` uses `.glassProminent` |
| Clean UI test baseline | Stable UI-test selectors and visible-state assertions; no accessibility audit execution path |
| Visual QA sign-off | Battle, Play, Homestead, and Collection smoke tests pass |

---

## As shipped (current state)

### Design system (`VisualFoundation.swift` / `Modifiers.swift`)

| Modifier | Shipped behavior |
|----------|------------------|
| `TrinketGlassBackgroundModifier` | Shared helper: `.glassEffect(glass, in: shape)` |
| `GlassChipModifier` | Capsule glass via shared helper (`.trinketGlassChip()`) |
| `StatusBadgeModifier` | Capsule glass via shared helper (`.trinketStatusBadge()`); API retained, no feature call sites today |
| `WalletPillModifier` | Capsule glass via shared helper (`.trinketWalletPill()`); used by Shop gold chip |
| `MaterialRoleModifier` | Role map via `MaterialRoleStyle` (see below) |
| `PrimaryActionButtonModifier` | `.buttonStyle(.glassProminent)` |

### `MaterialRole` map (`MaterialRoleStyle`)

| `MaterialRole` | Shipped | Rationale |
|----------------|---------|-----------|
| `.toolbar` | No custom material | System chrome |
| `.bottomBar` | Glass (`.regular`) over `panelSurface` fallback color | Sticky footer / reward chrome over content |
| `.modal` | Solid `panelSurface` | Avoid double material on sheets |
| `.popover` | Glass (`.regular`) over `elevatedBackground` | Compact contextual chrome |
| `.rewardReveal` | Glass (`.regular.tint(accent)`) | Victory/reward moments |
| `.subtleOverlay` | `.ultraThinMaterial` | Battle scrims |
| `.homesteadFooter` | Glass (`.regular`) over `panelSurface` | Homestead wallet grid chrome |

### Representative feature call sites

| File | Modifier | Notes |
|------|----------|-------|
| `SkillCalloutView.swift:73` | `.trinketGlassChip(.utility)` | Battle feedback chip |
| `ShopEncounterView.swift:135` | `.trinketWalletPill()` | Shop gold chip |
| `WalletResources.swift:27` | `.trinketMaterial(.homesteadFooter)` | Homestead resource wallet grid |
| `RewardRevealShell.swift:66` | `.trinketMaterial(.bottomBar, cornerRadius: 0)` | Bottom-pinned reward CTA bar |
| `CurrentStageCard.swift:99` | `.trinketPrimaryActionButton(...)` | Play stage CTA |
| `BattleOutcomeComponents.swift:52` | `.trinketPrimaryActionButton()` | Battle outcome CTA |

Discover additional `.trinketGlassChip()` / `.trinketPrimaryActionButton()` call sites with a repo grep; do not treat the table above as exhaustive.

### Toolbar background overrides (retained)

| File | Modifier | Notes |
|------|----------|-------|
| `BattleView.swift` | `.toolbarBackgroundVisibility(.hidden, ...)` | Art-forward combat chrome — keep |
| `DetailHeroScrollShell.swift` | `.toolbarBackground(.clear)` + visibility hidden | Combatant / detail hero under nav — keep |

These are product choices for full-bleed artwork, not outstanding Liquid Glass debt. Do not remove them as part of chrome cleanup. Optional iOS 26 scroll APIs (tab minimize, `backgroundExtensionEffect`, `scrollEdgeEffectStyle`) are tracked in [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) Phase D (tab minimize deliberately omitted; journey `backgroundExtensionEffect` already shipped).

### UI test baseline

UI tests retain stable `AccessibilityID` selectors and assert visible state or interaction outcomes. Accessibility audits are intentionally removed; comprehensive accessibility permutations are outside the product scope defined by PD-007.

---

## Architecture: shared glass primitive

Shipped helper in `VisualFoundation.swift` (shape is a generic `Shape`, not a custom enum):

```swift
struct TrinketGlassBackgroundModifier<S: Shape>: ViewModifier {
    let glass: Glass
    let shape: S
    let solidFill: Color

    func body(content: Content) -> some View {
        content
            .glassEffect(glass, in: shape)
    }
}
```

**Why:** `GlassChipModifier`, `StatusBadgeModifier`, and `WalletPillModifier` share one material policy so chrome does not drift.

**Public API:** `.trinketGlassChip()`, `.trinketStatusBadge()`, `.trinketWalletPill()`, and `.trinketMaterial(_:)` keep their names; feature code must not call raw `.glassEffect` / `.buttonStyle(.glass*)`.

Palette tokens use `ThemePalette.trinket` (there is no `ThemePalette.apple`).

### `GlassEffectContainer` usage

When multiple glass elements appear in one row, wrap siblings:

```swift
GlassEffectContainer {
    HStack {
        walletPill
        statusBadge
    }
}
```

Apply only where sibling glass chips are visible together — not on every chip globally. Apple warns against over-nesting containers ([Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)). Homestead wallet chrome now uses `TrinketWalletGrid` + `.homesteadFooter` rather than sibling wallet/status glass pills.

---

## Completed rollout (historical)

Phases below are finished. Keep them as the migration record; do not re-open unless product revisits chrome policy.

### Phase 0 — Prep ✅

1. Added `TrinketGlassBackgroundModifier` in `VisualFoundation.swift`.
2. Refactored `GlassChipModifier` onto the helper.
3. Covered shared policy in `VisualFoundationTests.swift`.
4. Documented modifier behavior in `Packages/TrinketDesignSystem/README.md`.

**Verify (then):** `./Scripts/test-package.sh TrinketDesignSystem`, `./Scripts/check-ui-style.sh`

### Phase 1 — Badge and wallet modifiers ✅

1. Migrated `StatusBadgeModifier` / `WalletPillModifier` onto the shared glass helper with `ThemePalette.trinket` solid-fill tokens.
2. Homestead wallet chrome later consolidated into `TrinketWalletGrid` (`.homesteadFooter`); Shop retains `.trinketWalletPill()`.

**Verify (then):** `./Scripts/test.sh smoke SmokeHomesteadTests` (or closest Homestead smoke), `./Scripts/test.sh smoke`

### Phase 2 — Primary action buttons ✅

1. `PrimaryActionButtonModifier` uses `.glassProminent` / `.buttonBorderShape(.roundedRectangle)`.
2. `check-ui-style.sh` still allow-lists legacy `.bordered*` only for Debug / “Battle Again” contexts; production CTAs go through `.trinketPrimaryActionButton()`.
3. Representative CTAs: Play stage card, battle outcome, plus other feature primary actions discovered by grep.

**Verify (then):** `./Scripts/test.sh smoke SmokePlayTests`, `./Scripts/test.sh smoke SmokeBattleTests`, `./Scripts/check-ui-style.sh`

### Phase 3 — `MaterialRoleModifier` role map ✅

Role map shipped as in the **As shipped** table above (including `.homesteadFooter`). Bottom-bar chrome for pinned primary actions lives in `RewardRevealShell.swift`.

**Verify (then):** `./Scripts/test.sh smoke`, `./Scripts/build.sh`

### Phase 5 — Accessibility scope alignment ✅

Accessibility audit helper / nightly path removed. Native SwiftUI controls and stable UI-test identifiers remain; do not add custom semantics or accessibility-setting branches without revisiting PD-007.

### Phase 6 — Documentation and audit refresh ✅

[iOS26StackAudit.md](iOS26StackAudit.md), design-system README, and [Docs/Platform/README.md](README.md) record the migration as complete.

---

## Testing matrix (historical)

| Phase | Automated | Manual |
|-------|-----------|--------|
| 0 | `test-package.sh TrinketDesignSystem`, `check-ui-style.sh` | — |
| 1 | `test.sh smoke SmokeHomesteadTests` | Homestead visual flow |
| 2 | `SmokePlayTests`, `SmokeBattleTests` | Visible CTA state and interaction |
| 3 | `test.sh smoke`, `build.sh` | Reward bottom bar, sheets |
| 5 | `SmokePlayTests`, `SmokeCollectionTests` | — |
| 6 | — | Doc review |

**Pre-merge gate used for the full migration:**

```sh
./Scripts/ci-locally.sh
```

---

## PR strategy (historical)

Shipped as stacked PRs / sequential commits:

| PR | Phases | Title |
|----|--------|-------|
| 1 | 0 + 1 | `refactor(design): extract glass helper; migrate badge/wallet` |
| 2 | 2 | `style(design): glassProminent primary action buttons` |
| 3 | 3 | `style(design): MaterialRole glass role map` |
| 4 | 5 | `refactor(tests): remove accessibility audit path` |

Phase 5 landed alongside the visual-first accessibility decision; smoke tests cover gameplay/UI flows without running platform accessibility audits.

---

## Out of scope

- Card surfaces (`.trinketSurface(.card)`) — stay solid; card art is the hero.
- Collection / Inventory / Options list rows — stay solid (`denseList` background mode).
- Toolbar background visibility on Battle / detail hero chrome — intentional art-forward chrome; not migrated.
- `LockedCardEffectModifier` fixed font sizes — Dynamic Type pass in [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) Phase C.
- StoreKit, GameKit, RealityKit — not applicable today.
- App icon layer composition for Liquid Glass — track via App Store prep checklist.

---

## References

- [iOS26AppleReference.md](iOS26AppleReference.md) — WWDC links and API table
- [iOS26StackAudit.md](iOS26StackAudit.md) — point-in-time findings
- [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) — follow-up Apple-native migrations
- [TrinketDesignSystem/README.md](../../Packages/TrinketDesignSystem/README.md) — dense vs glass surfaces, chrome inventory
- [Apple Design skill](../Skills/apple-design/SKILL.md) — fluid motion via SwiftUI / `TrinketMotion`
- `Scripts/check-ui-style.sh` — enforcement rules
