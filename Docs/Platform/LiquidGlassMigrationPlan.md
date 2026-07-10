# Liquid Glass Migration Plan

Detailed implementation plan for migrating Trinket's custom chrome to iOS 26 Liquid Glass. Complements [iOS26StackAudit.md](iOS26StackAudit.md) and [iOS26AppleReference.md](iOS26AppleReference.md).

**Status (July 2026):** Phases 0–3, 5–6 **complete**. Liquid Glass design-system migration is done. Toolbar background overrides on Battle / Play map / combatant detail are **retained intentionally** (art-forward chrome) and are not part of this plan. Remaining Apple-native follow-ups live in [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md).

**Scope:** `TrinketDesignSystem` modifiers, three primary CTA call sites, Homestead chrome, and `TrinketUITestCase.assertAccessibilityAudit`. Does **not** change combat rules, persistence, navigation structure, or art-forward toolbar visibility overrides.

**Principle:** Glass on **functional chrome** (chips, pills, primary actions, bottom bars over artwork). Solid themed surfaces on **dense content** (Collection grids, Inventory rows, Options forms) via `TrinketDesignSystem` / `VisualFoundation`.

---

## Goals

| Goal | Success criteria |
|------|------------------|
| Unified glass primitives | All custom translucent chrome routes through shared helpers with Reduce Transparency fallbacks |
| No raw glass in features | `check-ui-style.sh` passes; feature views call design-system modifiers only |
| Primary CTAs match iOS 26 | `trinketPrimaryActionButton()` uses `.glassProminent` |
| Clean UI test baseline | No `#available(iOS 17.0)` guards; accessibility audit runs on every smoke call site |
| Visual QA sign-off | Battle, Play, Homestead, and Collection smoke tests pass; manual check with Reduce Transparency / Reduce Motion |

---

## Current state

### Design system (`VisualFoundation.swift`)

| Modifier | Today | Target |
|----------|-------|--------|
| `GlassChipModifier` | `.glassEffect(.regular)` | Keep (reference implementation) |
| `StatusBadgeModifier` | `.background(.regularMaterial)` | `.glassEffect(.regular)` |
| `WalletPillModifier` | `.background(.thinMaterial)` | `.glassEffect(.regular)` |
| `MaterialRoleModifier` | `Material` by role | Role-specific: glass for chrome roles; solid for modal bodies |

### Feature call sites (grep-stable inventory)

| File | Modifier | Notes |
|------|----------|-------|
| `SkillCalloutView.swift:99` | `.trinketGlassChip()` | Already glass (battle feedback) |
| `HomesteadResourceViews.swift:53` | `.trinketWalletPill()` | Migrates with `WalletPillModifier` |
| `HomesteadProjectViews.swift:291` | `.trinketStatusBadge()` | Migrates with `StatusBadgeModifier` |
| `HomesteadDetailViews.swift:74` | `.trinketMaterial(.bottomBar)` | Phase 3 — bottom sticky bar |
| `CurrentStageCard.swift:48` | `.trinketPrimaryActionButton()` | Phase 2 |
| `HomesteadProjectViews.swift:237` | `.trinketPrimaryActionButton()` | Phase 2 |
| `BattleOutcomeComponents.swift:53` | `.trinketPrimaryActionButton()` | Phase 2 |

### Primary button (`Modifiers.swift`)

```swift
// Today
.buttonStyle(.borderedProminent)

// Target
.buttonStyle(.glassProminent)
```

### Toolbar background overrides (retained)

| File | Modifier | Notes |
|------|----------|-------|
| `BattleView.swift` | `.toolbarBackgroundVisibility(...)` | Art-forward combat chrome — keep |
| `ChapterStageSelectView.swift` | `.toolbarBackgroundVisibility(.hidden)` | Journey hero under nav — keep |
| `CombatantDetailPane.swift` | `.toolbarBackground(.clear)` + visibility hidden | Sheet over card art — keep |

These are product choices for full-bleed artwork, not outstanding Liquid Glass debt. Do not remove them as part of this migration. Optional iOS 26 scroll APIs (tab minimize, `backgroundExtensionEffect`, `scrollEdgeEffectStyle`) are tracked in [AppleNativeBestPracticesPlan.md](AppleNativeBestPracticesPlan.md) Phase D.

### UI test guard

```154:161:TrinketUITests/Support/TrinketUITestCase.swift
    func assertAccessibilityAudit(file: StaticString = #file, line: UInt = #line) {
        guard #available(iOS 17.0, *) else { return }
        do {
            try app.performAccessibilityAudit()
        } catch {
            fail("Accessibility audit failed: \(error)", file: file, line: line)
        }
    }
```

Called from `SmokePlayTests` and `SmokeCollectionTests`. Deployment target is iOS 26.0 — guard is dead code.

---

## Architecture: shared glass primitive

Before migrating individual modifiers, extract a single internal helper so fallbacks stay consistent.

### Proposed helper (in `VisualFoundation.swift`)

```swift
enum TrinketGlassShape {
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
}

struct TrinketGlassBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let glass: Glass
    let shape: TrinketGlassShape
    let solidFill: Color  // role-appropriate fallback

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(solidFill, in: resolvedShape)
                .overlay { resolvedShape.stroke(ThemePalette.apple.subtleStroke, lineWidth: 1) }
        } else {
            content
                .glassEffect(glass, in: resolvedShape)
        }
    }
}
```

**Why:** `GlassChipModifier`, `StatusBadgeModifier`, and `WalletPillModifier` today duplicate the same Reduce Transparency branch. One helper prevents drift.

**Public API unchanged:** `.trinketGlassChip()`, `.trinketStatusBadge()`, `.trinketWalletPill()` keep their names; only internal implementation changes.

### `GlassEffectContainer` usage

When multiple glass elements appear in one row (Homestead wallet + status badges), wrap siblings:

```swift
GlassEffectContainer {
    HStack {
        walletPill
        statusBadge
    }
}
```

Apply in `HomesteadResourceViews` or parent layout — not on every single chip globally. Apple warns against over-nesting containers ([Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)).

---

## Phased rollout

### Phase 0 — Prep (no visual change)

**Effort:** Small. **Risk:** None.

1. Add `TrinketGlassBackgroundModifier` (or equivalent private helper) in `VisualFoundation.swift`.
2. Refactor `GlassChipModifier` to use the helper — behavior should be pixel-identical.
3. Add unit tests in `VisualFoundationTests.swift`:
   - Helper resolves shapes for capsule and rounded-rectangle cases.
   - Document that Reduce Transparency paths use solid fills (compile-time structure; runtime a11y env not easily unit-tested).
4. Update `Packages/TrinketDesignSystem/README.md` if it lists modifier behavior.

**Verify:**

```sh
./Scripts/test-package.sh TrinketDesignSystem
./Scripts/check-ui-style.sh
```

---

### Phase 1 — Badge and wallet modifiers

**Effort:** Small. **Risk:** Low (2 Homestead call sites).

1. Migrate `StatusBadgeModifier` → shared glass helper, `.glassEffect(.regular)`, capsule shape. Solid fallback: `ThemePalette.apple.panelSurface` (unchanged).
2. Migrate `WalletPillModifier` → shared glass helper. Solid fallback: `ThemePalette.apple.secondaryBackground` (unchanged).
3. Wrap Homestead wallet row in `GlassEffectContainer` if multiple glass siblings are visible together.

**Manual QA:**

- Homestead tab: wallet pill and project status badges over scrolling content.
- Settings → Accessibility → **Increase Contrast** / **Reduce Transparency**: pills become solid, readable.

**Verify:**

```sh
./Scripts/test.sh ui SmokeHomesteadTests   # if exists; else SmokeCollectionTests + manual Homestead
./Scripts/test.sh smoke
```

---

### Phase 2 — Primary action buttons

**Effort:** Small. **Risk:** Medium (high-visibility CTAs).

1. Change `PrimaryActionButtonModifier` in `Modifiers.swift`:

   ```swift
   .buttonStyle(.glassProminent)
   .controlSize(.large)
   .buttonBorderShape(.roundedRectangle)
   ```

2. Review `check-ui-style.sh` allow-list comment on line 38–40 (“Debug / Battle Again intentionally use bordered”) — ensure it still matches any one-off bordered buttons after migration.

3. Visual QA on all three call sites:
   - Play → current stage card CTA (`CurrentStageCard.swift`)
   - Homestead → project build CTA (`HomesteadProjectViews.swift`)
   - Battle outcome → “Battle Again” / continue (`BattleOutcomeComponents.swift`)

**Accessibility:** Confirm button labels and contrast in Light, Dark, and Increase Contrast.

**Verify:**

```sh
./Scripts/test.sh ui SmokePlayTests
./Scripts/test.sh ui SmokeBattleTests   # or closest battle smoke class
./Scripts/check-ui-style.sh
```

---

### Phase 3 — `MaterialRoleModifier` role map

**Effort:** Medium. **Risk:** Medium (toolbar/bottom-bar semantics).

Define per-role behavior — not all roles should become glass:

| `MaterialRole` | Current | Proposed | Rationale |
|--------------|---------|----------|-----------|
| `.toolbar` | `.thinMaterial` | **No custom material** — remove modifier at call sites where system toolbar provides glass | System chrome |
| `.bottomBar` | `.thinMaterial` | `.glassEffect(.regular)` in rounded rect | Homestead sticky footer over content |
| `.modal` | `.regularMaterial` | Solid `panelSurface` or system sheet default | Sheets get iOS 26 glass automatically; avoid double material |
| `.popover` | `.thinMaterial` | `.glassEffect(.regular)` | Compact contextual chrome |
| `.rewardReveal` | `.regularMaterial` | `.glassEffect(.regular.tint(accent))` optional | Victory/reward moments |
| `.subtleOverlay` | `.ultraThinMaterial` | Keep material or very light glass | Battle scrims — test legibility |

**Call site today:** `HomesteadDetailViews.swift:74` — `.trinketMaterial(.bottomBar, cornerRadius: 0)`.

**Steps:**

1. Update `MaterialRoleModifier` implementation per table.
2. Grep for `.trinketMaterial(` — migrate or remove each call site.
3. If `.toolbar` call sites exist only for custom bars, switch to `.safeAreaBar` / system toolbar APIs per WWDC25-323.

**Verify:**

```sh
./Scripts/test.sh smoke
./Scripts/build.sh
```

---

### Phase 5 — Remove stale UI test guard

**Effort:** Trivial. **Risk:** Low.

**Change** `TrinketUITests/Support/TrinketUITestCase.swift`:

```swift
func assertAccessibilityAudit(file: StaticString = #file, line: UInt = #line) {
    do {
        try app.performAccessibilityAudit()
    } catch {
        fail("Accessibility audit failed: \(error)", file: file, line: line)
    }
}
```

**Why safe:** `performAccessibilityAudit()` is available on iOS 26; deployment target guarantees it.

**If audits fail after removal:** fix real accessibility issues surfaced by the audit (preferred) or narrow audit scope with `performAccessibilityAudit(for:)` if Apple API supports filtering — do not reintroduce OS version guards.

**Verify:**

```sh
./Scripts/test.sh ui SmokePlayTests
./Scripts/test.sh ui SmokeCollectionTests
```

---

### Phase 6 — Documentation and audit refresh

1. Update [iOS26StackAudit.md](iOS26StackAudit.md) — mark glass migration complete, refresh date.
2. Update `TrinketDesignSystem` / `VisualFoundation` material rules if role map changed.
3. Update `TrinketDesignSystem` README modifier table.
4. Add entry to `Docs/Platform/README.md` linking this plan (done when plan lands).

---

## Testing matrix

| Phase | Automated | Manual |
|-------|-----------|--------|
| 0 | `test-package.sh TrinketDesignSystem`, `check-ui-style.sh` | — |
| 1 | `test.sh smoke` | Homestead + Reduce Transparency |
| 2 | `SmokePlayTests`, battle smoke | Light/Dark/Increase Contrast on CTAs |
| 3 | `test.sh smoke`, `build.sh` | Homestead detail bottom bar, sheets |
| 5 | `SmokePlayTests`, `SmokeCollectionTests` | — |
| 6 | — | Doc review |

**Pre-merge gate for the full migration:**

```sh
./Scripts/ci-locally.sh
```

---

## PR strategy

Ship as **stacked PRs** or **sequential commits on main** to keep review focused:

| PR | Phases | Title |
|----|--------|-------|
| 1 | 0 + 1 | `refactor(design): extract glass helper; migrate badge/wallet` |
| 2 | 2 | `style(design): glassProminent primary action buttons` |
| 3 | 3 | `style(design): MaterialRole glass role map` |
| 4 | 5 | `test(ui): remove stale iOS 17 accessibility guard` |

Phase 5 (UI test guard) can land **independently at any time** — recommend doing it in PR 1 or as a standalone chore before visual changes so smoke tests exercise audits throughout migration.

---

## Out of scope

- Card surfaces (`.trinketSurface(.card)`) — stay solid; card art is the hero.
- Collection / Inventory / Options list rows — stay solid (`denseList` background mode).
- Toolbar background visibility on Battle / Play map / combatant detail — intentional art-forward chrome; not migrated.
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
