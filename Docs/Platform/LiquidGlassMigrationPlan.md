# Liquid Glass Migration Plan

Detailed implementation plan for migrating Trinket's custom chrome to iOS 26 Liquid Glass and removing the stale UI test availability guard. Complements [iOS26StackAudit.md](iOS26StackAudit.md) and [iOS26AppleReference.md](iOS26AppleReference.md).

**Scope:** `TrinketDesignSystem` modifiers, three primary CTA call sites, Homestead chrome, toolbar background audit, and `TrinketUITestCase.assertAccessibilityAudit`. Does **not** change combat rules, persistence, or navigation structure.

**Principle:** Glass on **functional chrome** (chips, pills, primary actions, bottom bars over artwork). Solid themed surfaces on **dense content** (Collection grids, Inventory rows, Search, Options forms) per `AppVisualFoundation.md`.

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
| `CombatFeedbackEventView.swift:78` | `.trinketGlassChip()` | Already glass |
| `HomesteadResourceViews.swift:53` | `.trinketWalletPill()` | Migrates with `WalletPillModifier` |
| `HomesteadProjectViews.swift:322` | `.trinketStatusBadge()` | Migrates with `StatusBadgeModifier` |
| `HomesteadDetailViews.swift:74` | `.trinketMaterial(.bottomBar)` | Phase 3 — bottom sticky bar |
| `ActiveStageCard.swift:43` | `.trinketPrimaryActionButton()` | Phase 2 |
| `HomesteadProjectViews.swift:266` | `.trinketPrimaryActionButton()` | Phase 2 |
| `BattleOutcomeComponents.swift:52` | `.trinketPrimaryActionButton()` | Phase 2 |

### Primary button (`Modifiers.swift`)

```swift
// Today
.buttonStyle(.borderedProminent)

// Target
.buttonStyle(.glassProminent)
```

### Toolbar background overrides (visual QA required)

| File | Modifier | Risk |
|------|----------|------|
| `BattleView.swift:30` | `.toolbarBackgroundVisibility(...)` | May fight system scroll-edge effect |
| `ChapterStageSelectView.swift:77` | `.toolbarBackgroundVisibility(.hidden)` | Play map hero under nav |
| `CombatantDetailPane.swift:168-169` | `.toolbarBackground(.hidden)` + visibility | Sheet detail |

Apple guidance ([Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)): remove custom backgrounds behind bars when they interfere with the system scroll-edge effect. Audit in Phase 4 — do not delete blindly.

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
   - Play → active stage card CTA (`ActiveStageCard.swift`)
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

### Phase 4 — Toolbar background audit (Play + Battle)

**Effort:** Medium. **Risk:** Medium (art-forward screens).

**Do not implement blindly.** This phase is an audit + targeted edits after simulator review.

1. Run app on iOS 26 simulator with Play map, Battle, and combatant detail sheet.
2. For each `toolbarBackgroundVisibility(.hidden)` site, check:
   - Does content scroll under the bar?
   - Is text/icon legibility worse with system scroll-edge effect vs hidden background?
3. **If system effect suffices:** remove `.toolbarBackground(.hidden)` and `.toolbarBackgroundVisibility(.hidden)`.
4. **If custom art requires hidden bar:** keep hidden visibility but add `.scrollEdgeEffectStyle(...)` if content scrolls beneath (WWDC25-323).

Files to review:

- `BattleView.swift`
- `ChapterStageSelectView.swift`
- `CombatantDetailPane.swift`

**Optional (product decision, separate PR):**

- `.tabBarMinimizeBehavior(.onScrollDown)` on `ContentView` TabView for Play/Collection long scroll.
- `.backgroundExtensionEffect()` on `ChapterJourneyHero` for edge-to-edge journey art.

Document decisions in a short comment at each retained override: `// UIStyleCheck: allow - hero art requires hidden nav chrome`.

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
2. Update `AppVisualFoundation.md` Material Rules if role map changed.
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
| 4 | `test.sh smoke` | Play map scroll, Battle toolbar legibility |
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
| 4 | 4 | `style(play): toolbar background audit for Liquid Glass` |
| 5 | 5 | `test(ui): remove stale iOS 17 accessibility guard` |

Phase 5 (UI test guard) can land **independently at any time** — recommend doing it in PR 1 or as a standalone chore before visual changes so smoke tests exercise audits throughout migration.

---

## Out of scope

- Card surfaces (`.trinketSurface(.card)`) — stay solid; card art is the hero.
- Collection / Inventory / Search / Options list rows — stay solid (`denseList` background mode).
- `LockedCardEffectModifier` fixed font sizes — separate Dynamic Type pass (see audit § decorative icons).
- StoreKit, GameKit, RealityKit — not applicable today.
- App icon layer composition for Liquid Glass — track via App Store prep checklist.

---

## References

- [iOS26AppleReference.md](iOS26AppleReference.md) — WWDC links and API table
- [iOS26StackAudit.md](iOS26StackAudit.md) — point-in-time findings
- [AppVisualFoundation.md](../Design/StyleGuide/AppVisualFoundation.md) — dense vs glass surfaces
- [AppleNativeGuidelines.md](../Design/AppleNativeGuidelines.md) — repo patterns and deprecated APIs
- `Scripts/check-ui-style.sh` — enforcement rules
