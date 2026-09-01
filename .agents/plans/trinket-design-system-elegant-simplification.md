# Plan — Random Subsystem Elegant Simplification: TrinketDesignSystem

> **Selection method (code-based RNG):** Simple LCG `r = (a*seed + c) % m` with `a=1664525, c=1013904223, m=2^32`, `seed = int(time.time()) = 1788222170` → `r=336276593` → `idx = r % 12 = 5` → **`TrinketDesignSystem`** from `[BattleEngine, TrinketAppState, TrinketBattleFeature, TrinketContent, TrinketCore, TrinketDesignSystem, TrinketFeatureSupport, TrinketPersistence, TrinketTestSupport, Scripts, Docs, Trinket/App+Features]`. Investigation stopped once significant improvements were confirmed — no further subsystem sweep.

## 1. What this means for the player

Nothing changes visually on day one — same colors, same surfaces, same card backs, same XP bar timing — but the design system that paints every screen becomes a single, predictable vocabulary instead of three overlapping ones. Future art tweaks (one gold, one warning stroke, one glass recipe) land in one place and reach every screen consistently. It also removes a handful of subtle bugs that are visible today if you look closely: locked card placeholders that don't scale with Dynamic Type, a plasma background that double-counts one keyword color, a rarity shine that stutters when you revisit a screen, and an XP bar that can snap unevenly after a multi-level-up.

---

## 2. Investigation summary — how it was read

* **Enumerated the package:** 17 Swift sources (2,186 lines), 1 Metal shader (136 lines), 54 color assets, 4 test files (214 lines). All read in full. Cross-checked consumption via ~150 references to `TrinketDesign` / `trinketSurface` / `trinketTypography` across `Trinket/Features` and `TrinketFeatureSupport`.
* **Deep subagent sweep + manual file verification** against: `TrinketDesign.swift`, `VisualFoundation.swift`, `Modifiers.swift`, `TrinketMotion.swift`, `Keyword+VisualStyle.swift`, `KeywordPlasmaBackground.swift`, `CardArtwork.swift`, `PlaceholderArtwork.swift`, `ExperienceBar.swift`, `WalletResources.swift`, `HeroScrim.swift`, `ArtworkBlend.swift`, plus tests and `README`.
* **Lenses applied:** over-engineering / slop (`Docs/Audits/11_InelegantSlopAudit.md`), duplication, accidental inconsistency, performance, test gaps, build/doc hygiene, module ownership (`Docs/Platform/Architecture.md`).

### Headline finding

`TrinketDesignSystem` is the right owner and the smallest package by responsibility, but its internals carry the three most common sources of complexity in Trinket: **a grab-bag `Metrics` enum that mixes spacing with grid recipes** (`TrinketDesign.swift:48-115`), **a 65-line `switch` that reconstructs the same surface recipe eight times** (`VisualFoundation.swift:121-187`), and **two parallel placeholder renderers for the same token** (`CardArtwork.swift:26-43` vs `PlaceholderArtwork.swift:4-65`). These anchor most other duplication. Around them are a handful of YAGNI wrappers, dead code, and per-frame animation paths that are heavier than needed. None require a tech-stack change.

---

## 3. Findings grouped by lens

### A. Over-engineering / slop (delete → reuse wins)

| # | Location | What it is | Right shape |
|---|----------|------------|-------------|
| A1 | `Modifiers.swift:3-9` `CardSurfaceModifier` + `VisualFoundation.swift:303-313` | Delegates to `trinketSurface(.card)` — one-line wrapper kept for legacy reasons (already flagged in `ElegantSimplificationRound.md`). | Delete struct; keep `public func trinketCardSurface(...)` as thin alias to `trinketSurface(.card)` or remove alias and migrate two call sites (`ProductCardShell`, `ShopEncounterView`) directly — one is cleaner long-term. |
| A2 | `Modifiers.swift:163-168` `QuietTapButtonStyle` | No-op (`configuration.label` passthrough). Exists to avoid press dimming but `.buttonStyle(.plain)` already does this. | Delete style + `trinketQuietTapButtonStyle()`; callers use `.buttonStyle(.plain)` or fold into press style as a parameter. |
| A3 | `Modifiers.swift:85-161` 5 button wrappers | `GlassActionButtonModifier` + `OptionalForegroundModifier` + `Primary/SecondaryActionButtonModifier` + `OptionalAccessibilityIdentifierModifier` exist only to vary `isProminent` and optional `labelColor`/`identifier`. | Collapse to **one** `GlassButtonModifier(prominent:tint:labelColor:controlSize:identifier:)` that inlines `if let` checks. Removes 3 structs, 1 helper. |
| A4 | `Modifiers.swift:270-280` `optionalMatchedTransitionSource` | Generic `Namespace.ID?` helper unrelated to chrome; appears once. | Move to `TrinketFeatureSupport` or delete (call sites can `if let` inline). Not a design-system concern. |
| A5 | `VisualFoundation.swift:200-204` `SurfaceShadow.elevated` | Dead constant — no `SurfaceStyle` case uses it (`selected`/`reward` build inline shadows). | Delete. |
| A6 | `ArtworkBlend.swift:3-11` `ArtworkBlendDestination` enum | Single case `.canvas`. Switch in `color` is single-branch. YAGNI. | Replace enum with `typealias ArtworkBlendDestination = Color` or `struct` with `static let canvas`, or collapse `ArtworkBlend` to `enum { case none, bottom(Color? = .canvas) }`. Keep gradient recipe. Re-expand only when second destination ships. |
| A7 | `TrinketDesign.swift:151-159` `collectionShelfCardWidth()` View extension | Layout helper in token file; belongs with grid tokens. | Move to `VisualFoundation.swift` beside `hubGridItems` or to a new `Layout.swift` (see B). |
| A8 | `CardArtwork.swift:16-24` `cardArtworkPlaceholderBackground` | Trivial `.background(style.color)` wrapper. | Delete; callers already have `PlaceholderArtwork` view. |

### B. Consolidation / the “right” abstractions (fewer concepts, clearer ownership)

| # | Current split | Consolidated shape | Rationale |
|---|---------------|--------------------|-----------|
| B1 | `TrinketDesign.Metrics` — 32 statics mixing spacing (`tightSpacing`..`extraLargeSpacing`), card metrics, wallet metrics, bar heights, content margins, chip paddings, grid min/max — `TrinketDesign.swift:48-88`. | `enum TrinketDesign { enum Spacing { tight:2, xs:4, s:8, m:12, l:16, xl:24 } enum Layout { collectionGridMinimum/Maximum, partyPicker…, shelfSpacing/peek/previewLimit } enum Bars { statBarHeight, battleHealthHeights } }` — keep top-level `Metrics` as deprecated typealias for one release or remove outright (no save breakage; pure code references — ~100 hits, easy codemod). | One-file metrics file is the most-edited token file; grouping by concern stops “where does a new number go?” and cuts review thrash. Lowest risk refactor. |
| B2 | `SurfaceStyle` 65-line switch duplicating `padding = largeSpacing`, `cornerRadius = override ?? card`, `strokeWidth` boilerplate — `VisualFoundation.swift:121-187`. | Table-driven: `struct SurfaceSpec { fill, stroke, strokeWidth, padding, shadow }` with `static let specs: [SurfaceRole: SurfaceSpec]` data table; `init` becomes 5-line lookup + fallback. | Same behavior, 60% fewer lines, adding a new role is adding a row not a branch. Eliminates the `// swiftlint:disable:next function_body_length` debt. |
| B3 | Two placeholder renderers: opaque `CardArtworkPlaceholder` (fixed 38pt, paper 0.85, opaque fill) — `CardArtwork.swift:26-43` vs wash `PlaceholderArtwork` (0.18 wash, hierarchical, `@ScaledMetric`, weight semibold) — `PlaceholderArtwork.swift:54-64`. | Single source: extend `PlaceholderArtwork` to cover both, delete `CardArtworkPlaceholder` + `CardArtworkPlaceholderBackground`. Standardize on the wash + hierarchical path (already used in `AbilityCard:28`, `ItemArtwork:51`, `CombatantArtwork:50`). Keep `CardArtworkSurfaceModifier` as the sole shape/clipping owner (or fold into `TrinketDesign.cardShape` usage). | Removes visual divergence: today a locked hero placeholder looks different depending on which view hosts it, and the opaque path fails Dynamic Type scaling. Fix confirmed via file reads. |
| B4 | Four grid recipes: `Metrics.collectionGridItems` / `partyPickerGridItems` / `hubGridItems(for:)` — `TrinketDesign.swift:89-115` vs `DesignSystemPreview.swift:59` inline `adaptive 130`. | Expose all grids through `Layout` namespace; preview imports the same token (replace hard-coded `130` with `collectionGridMinimum` or dedicated `previewGrid`). | Single number for grid density; prevents drift between preview and product. |
| B5 | Shape reconstruction in 4 places: `TrinketDesign.cardShape` — `TrinketDesign.swift:122` vs `VisualFoundation.swift:189` `RoundedRectangle(cornerRadius:)` vs `CardArtwork.swift:6` vs `Modifiers.swift:29`. | One factory: `extension RoundedRectangle { static func trinketCard(cornerRadius: CGFloat = TrinketDesign.Corners.card) -> Self { ... } }` or reuse `TrinketDesign.cardShape` everywhere. Bake `style: .continuous` once. | Prevents future radius drift (already 16 in 4 files). |
| B6 | `GlassChipRole` padding re-declares metric names — `VisualFoundation.swift:286-299` reads `Metrics.chipPadding*` but is a second switch. | Make `GlassChipRole.padding` computed from same table or inline constants; alternatively `Spacing.chip` + `Spacing.chipEmphasis`. Keep role enum for semantics, remove second enum that mirrors metric names. | Change to chip padding currently requires two edits that compile independently. |
| B7 | `TrinketMotion` animations as computed `var` creating new `Animation` per access + `Interaction` vs `Reward` vs `Content` vs `Screen` overlap — `TrinketMotion.swift:15-32`. | Change hot animations to `static let` (`press`, `selection`, `stateChange`, `walletIncrease`, `fade`, `crossfade`); consolidate near-duplicate durations: `stateChange 0.18` vs `manaSpend 0.16` vs `fade 0.20` — document as intentional or collapse to 2-step scale (`quick 0.16`, `standard 0.20`, `emphasized 0.28`). Derive `Shine.textShineDuration` from `loopPeriod / 2` instead of hard-coding `2.4` vs `4.8`. | Saves per-frame allocations (each `var` call allocates), makes motion ladder intentional not accidental. |
| B8 | `WalletResources` Layout 96 lines with brittle `proposal.width <= 1` and manual column/row math — `WalletResources.swift:156-252`. | Replace with `Grid`/`LazyVGrid` or `ViewThatFits` if available on iOS 26, or shrink custom Layout to ~30 lines: remove equalized branch complexity, use `Layout` protocol `spacing` param directly, and test ideal vs compressed paths. | Current layout is over-fitted to one screen; simpler grid passes same visual tests at lower cost per layout pass (fewer `sizeThatFits(.unspecified)` allocations). |
| B9 | `ExperienceBar` pure model (`Segment`, `segments`, `stepCounts`, `easeInOut`) lives in DesignSystem — `ExperienceBar.swift:263-346`. | Move pure logic to `TrinketCore.CombatantProgression` (or `TrinketFeatureSupport`) and keep only the View (`circularPortrait` + bar) in `TrinketDesignSystem`. | `Architecture.md` says DesignSystem owns chrome only (`Architecture.md: TrinketDesignSystem = TrinketCore only, chrome`). Feature-shaped projection logic belongs with domain. |

### C. Bugs & accidental inconsistencies (fix with behavior preservation; flag player-visible edge)

| # | Location | Bug / inconsistency | Fix | Player-visible? |
|---|----------|---------------------|-----|-----------------|
| C1 | `Keyword+VisualStyle.swift:14-22` + `VisualFoundation.swift:132/160` + `HeroScrim.swift:24-30` | Opacity ladder is stringly scattered: keyword derived opacities `0.72/0.62/0.14/0.48` are magic, surface opacities `0.72/0.70/0.65/0.45/0.30` unrelated, scrim opacities `0.98/0.55/0.85/0.40` bespoke. | Introduce `enum TrinketOpacity { subtle:0.14, border:0.48, glow:0.62, secondary:0.72 }` (or similar) and derive all secondary/glow/subtle/border from same tokens. | No visual change if values preserved — approval not needed. If consolidating warning `0.12`/`0.65` fills, needs design sign-off (subtle tint change). |
| C2 | `CardArtwork.swift:38` vs `PlaceholderArtwork.swift:7/60` | Fixed `38pt` (`CardArtworkPlaceholder`) does not scale with Dynamic Type, while `PlaceholderArtwork` uses `@ScaledMetric(relativeTo:.title)`. On large text, one placeholder clips while the other scales. | Fixed by B3 deletion; alternative: add `@ScaledMetric` to `CardArtworkPlaceholder`. | **Yes — accessibility.** Needs approval to change scaling behavior; recommend scaling (WCAG). |
| C3 | `KeywordPlasmaBackground.swift:38-42, 92-98, 131-139` | Dual-init complexity: `precondition(count<=2)` + `prefix(2)` redundant; `sources` + `keywords` branching; `colors(for:)` silently drops 3rd+ keyword; `multiSourceBody` synthesizes `secondSource = firstSource` when only one source active → dual Metal shader runs with identical colors at same + phase offset (`KeywordPlasmaDiffusion.metal:126` `phase 2.35`) with `alpha 0.28` vs single `0.22` — wasted GPU + slightly darker blend. | Unified body: `let active = (sources ?? [Source(keywords:keywords, focal:...)]).filter{!$0.keywords.isEmpty}`; early return `.none` if empty; single `TimelineView` with `switch active.count { 1: shaderLiquidPlasma, 2: shaderDualLiquidPlasma }`; make `colors(for:)` take `prefix(2)` explicitly and assert `count<=2`. | No visual change if single-source path preserves single shader — verify in `StarterRouletteScreen:116`, `RewardReveal:120`. Slight brightness fix when one source is intended. |
| C4 | `KeywordPlasmaBackground.swift:21` `@State startDate` + `TrinketRarityLabel.swift:61-67` `shinePhase` task | Plasma `startDate` never resets on `keywords` change → elapsed jumps after reuse; `shinePhase` per-card `withAnimation(repeatForever)` drives 20 concurrent infinite linears for a shelf of premium cards. | Reset `startDate` on `keywords`/`sources` change via `.onChange`; share plasma time from parent or use `TrinketMotion.Shine.phase(at:)` driven by single `TimelineView` instead of per-view `repeatForever`. Guard both with `@Environment(\.accessibilityReduceMotion)`. | Pause/respect Reduce Motion is player-visible but desired — get explicit approval to pause motion. |
| C5 | `HomesteadResource+Color.swift:22` `gold → Keyword.gold.visualStyle.color` | Couples two color families; no `ResourceGold` asset in `DesignColors.xcassets` (54 assets lack it). Designer cannot tweak resource gold independently of keyword gold. | Add `ResourceGold` asset (copy of `KeywordGold` value) and point `HomesteadResource.gold` there; or document alias as intentional in `README.md:33` with comment linking families. | Tiny tint divergence possible if assets diverge — needs design approval if new asset is added. |
| C6 | `HomesteadResource+Color.swift` vs `Keyword+VisualStyle.swift:28-30` `burn.secondaryColor = KeywordPhysical` | Burn reuses physical asset as secondary, health reuses `TrinketDesign.Colors.health` — leaks families; `poison`+`bleed` both `drop.fill` visually identical; `leech: drop` (outline) subtle but intentional? `prefersDarkForeground` for `gold/holy/stun/freeze` set without contrast proof. | Keep as-is but add `// intentional: reuses physical` comment on burn; add contrast test for dark-foreground keywords (see Tests). If poison/bleed identity is unintentional, add stroke/border differentiation. | Poison/bleed identity matters in battle — if changing symbols, needs design. |
| C7 | `ExperienceBar.swift:221-253` `applyLevelUp` + `animate` | `applyLevelUp` snaps `displayedXP=0`, `fraction=0` outside animation; next segment `animate` then re-sets `displayedFraction=start 0.0` instantly → first frame pop; `displayedLevel` bumps before bar finishes → VoiceOver reads new level while bar at 0. | Make `applyLevelUp` animated or defer `displayedLevel` increment until after segment completes; or animate XP reset with same `easeInOut` tick instead of snap. | **Yes — timing visible.** Needs explicit approval to change level-up pacing; proposed fix keeps total `animationBudget 0.30s` unchanged, just smooths continuity. |
| C8 | `WalletResources.swift:207` `proposal.width <= 1` | Treats 0…1 as “unspecified” but split-screen width 1.1 would incorrectly take ideal path; `ScrollView` proposal can be `nil` vs `.infinity`. | Use `proposal.width == nil || proposal.width! >= 10000` (unspecified) idiom or `if let w, w.isFinite, w > 10` threshold; replace magic `1` with `10` or ` idealWidth` compare only. | No visual change at normal widths; fixes narrow split-screen edge. |
| C9 | `TrinketRarityLabel.swift:56-57` shine offsets `-0.35→1.35` / `0.65→2.35` | Hard-coded offsets not derived from `TrinketMotion.Shine.loopPeriod 4.8`; if motion token changes, gradient drifts. | Derive offsets from `loopPeriod` or centralize in `Shine.offsets` so motion and view stay coupled. | No visual change. |
| C10 | `TrinketDesign.swift:79-82` chip paddings `chipEmphasis 16/8` | Emphasis horizontal is `largeSpacing 16`, vertical is `smallSpacing 8` — same as standard vertical? Actually standard is `10/8`; emphasis is `16/8` — vertical identical, horizontal only delta. Naming implies both emphasize. | Either keep but document “emphasis = wider only” or rename to `wideChip`. No behavior change, just naming. | None. |

### D. Performance & optimization

| # | Location | Cost | Fix | Measurement |
|---|----------|------|-----|-------------|
| D1 | `Modifiers.swift:33-66` `LockedCardEffectModifier` | Per locked card: `saturation` → `compositingGroup` → `blur(opaque:true,1)` (offscreen) → 2× `clipShape` → 5 `shadow` + `drawingGroup`. Shelf of 12 locked cards = 60 shadows + 12 offscreen blurs while scrolling. | Replace 5 edge shadows with single `shadow(color:ink.opacity(0.9), radius:3)` + `strokeBorder` for edge; remove inner `compositingGroup`+ second `clipShape` unless needed for blur containment (test). Keep `saturation` + `blur` but measure. Alternative: pre-blurred asset or `material` overlay. | Profile: scroll collection filtered to locked, Instruments → Core Animation FPS / offscreen passes. Goal: remove 4 shadows/card, keep visual. |
| D2 | `KeywordPlasmaBackground.swift:57,94` + `KeywordPlasmaDiffusion.metal:16-36` | Two `TimelineView(.animation(minimumInterval:1/30, paused:!isMotionActive))` + full-screen `colorEffect` shader; 4 `fast::sin/cos` per fragment per frame (30Hz). Three screens mount it. No Reduce Motion check. | Gate `isMotionActive` also on `accessibilityReduceMotion`; pause timeline when view not visible (`scenePhase`); single-source uses single shader (C3) saves dual path overhead; consider static fallback wash `canvas + primary.opacity(0.08)` when reduced motion. | Instruments → GPU / Metal System Trace; FPS on low-end device (iPhone SE). |
| D3 | `TrinketRarityLabel.swift:61-67` | Per premium card `withAnimation(repeatForever)` drives independent timeline; 20 cards = 20 timers. | Share single `TimelineView` phase at parent or use `TrinketMotion.Shine.phase` with one timeline; or make shine `animatable` driven by parent `phase`. | Count of active animations in View hierarchy. |
| D4 | `VisualFoundation.swift:106` shadow unconditional | `shadow(color:clear radius:0)` still composes modifier even for `.none`. | Conditional: `if shadow.radius > 0 { shadow(...) }`. | Minor body recomposition saving. |
| D5 | `WalletResources.swift:194` `sizeThatFits(.unspecified)` per layout pass | Allocates two `[CGFloat]`/`[CGRect]` arrays per pass, 8 sizing passes per wallet frame during animation (pulse via `keyframeAnimator`). | Cache `idealSizes` or switch to `Grid` which caches; reduce animation’s layout invalidations (animate `scaleEffect` only, not size). | Layout performance not critical unless wallet animates at same time as scroll. Low priority. |
| D6 | `ExperienceBar.swift:172-246` 60fps `SuspendingClock` micro-sleeps | 18 `@State` writes in 0.30s (18 invalidations) + `contentTransition.numericText()` morph each step; uses `Task.sleep(tolerance:8ms)` hopping instead of `withAnimation`. | Replace with single `withAnimation(.easeInOut(duration: segmentDuration))` driving `Animatable` `fraction`/`xp` or `TimelineView` phase; keeps same `easeInOut` but coalesces invalidations. | FPS during level-up sequence; today acceptable but wasteful. |
| D7 | `TrinketMotion.swift:15-32` computed `var` animations | Each `TrinketMotion.Interaction.press` call allocates new `Animation`. | Change to `static let` where interpolation is pure (most are). | Instruments allocations. |
| D8 | `HeroScrim.swift:24-30` double shadow per text | 6 shadows for eyebrow+title+badge on art. | Single combined shadow where possible (`shadow` with larger radius + opacity blend), or tokenize. | Minor. |

### E. Test coverage / speed / efficiency

Today: 214 lines across 4 files; good `TextBalance` (9 cases), decent `ExperienceBar` pure functions, weak elsewhere.

**Keep:** `TextBalanceTests:34` exemplary, `ExperienceBarTests:105` pure segment/stepCounts parameterized.

**Add / expand (cheapest semantic owner = `TrinketDesignSystemTests`):**

* **E1 — SurfaceSpec pin:** `SurfaceRole` → spec snapshot (fill/stroke/padding/shadow) + override fallback `cornerRadiusOverride ?? Corners.card` for every role (`VisualFoundation.swift:121-187`). Prevents drift when table-driving B2.
* **E2 — Grid/metric pin:** Assert `collectionGridMinimum 150` / `Maximum 190` / `partyPicker 120/160` / `collectionShelfPreviewLimit 8` / `shelfSpacing 16` not silently regressed. ~10 lines, fast.
* **E3 — Keyword visual coverage:** Exhaustiveness: every `Keyword` case has asset existing in `xcassets`; every `HomesteadResource.tint` returns non-nil `Color`; `prefersDarkForeground` has contrast test. Use `UIColor(named:in:.module)` check similar to `SemanticColorContrastTests:31`.
* **E4 — Wallet layout contract:** Unit-test `TrinketWalletGridLayout.arrangement` for `proposal.width nil / .infinity / <ideal / ==ideal / >ideal` and single-item edge, pinning `minimumColumnWidth 36+8+16` math.
* **E5 — Placeholder unification:** Assert `PlaceholderArtwork` renders with `0.18` wash + hierarchical vs opaque path no longer diverges; snapshot or style param test.
* **E6 — Motion token sanity:** Duration ladder check: `fade 0.20` == `crossfade 0.20` == intentional; `textShineDuration *2 == loopPeriod`; durations within 0.05 of each other flagged as intentional.
* **E7 — Contrast expansion:** Extend `SemanticColorContrastTests.swift:8` array from 10 to all 54 assets + light/dark traits + largeText threshold 3:1 where applicable (`Chapter*`, `Encounter*`, `Resource*`, `Placeholder*`, `Keyword*`). Verify `warning 0.12` fill vs `warning` text contrast.
* **E8 — Plasma unit:** `colors(for:)`: `[] → accent`, `[a] → primary=visualStyle, secondary=secondaryColor`, `[a,b] → b.color`, `[a,b,c] → prefix(2)` behavior (C3).

**Speed:** No change to test suite runtime today (seconds). Avoid snapshot tests here — keep pin tests as plain `XCTest` color/metric assertions (sub-0.1s). Add performance budget test only if we keep per-card `repeatForever` (counts active animations).

### F. Documentation, scripts & build

| # | Area | Issue | Fix |
|---|------|-------|-----|
| F1 | `TrinketDesignSystem/README.md:2-104` | Components table lists files but omits `WalletResources.swift`, `CardArtwork.swift`, `KeywordPlasmaBackground.metal` responsibility; Color families table already thorough. | Add rows for wallet/plasma/cardArtwork; note `ArtworkBlend` + `HeroScrim` as complementary (already in line 101 but doc says “when they serve a separate purpose” — clarify). |
| F2 | `DesignAssetColors.swift:7` stringly-typed `named(_:)` | Runtime magenta on typo; no compile-time dead-asset detection. Prior archived plan (`ElegantSimplificationRound.md:43`) proposed generated `DesignColors.generated.swift`. | Generate file from `DesignColors.xcassets` contents (script: enumerate `*.colorset` → emit `static let themeCanvas = Color("ThemeCanvas", bundle:.module)`). Gate: `check-ui-style.sh` can then `grep` unused generated lets vs `named(` calls. Keep `named(_:)` private helper. |
| F3 | `./Scripts/check-ui-style.sh` | Enforcement is lint-only (`UIStyleCheck: allow`); generated file would make lint stricter. | Teach script to fail if raw `Color("…")` or `DesignAssetColors.named` string not in generated enum. |
| F4 | `Package.swift:25` `.process("Resources")` | `Bundle.module` requires resource processing; okay. If generating file, ensure `Package.swift` still processes `DesignColors.xcassets` correctly (no change). | None unless asset generation runs outside Xcode. |
| F5 | `TrinketDesignSystem/AGENTS.md:3` “Owns every product color token” | Contradicted by `HomesteadResource.gold` aliasing keyword asset without its own token (C5). | Decide: either add token or carve gold as explicit exception in guide. |
| F6 | `Scripts/generate.sh` | No design-system generation step today; well-scoped. | Add `--design-tokens` or fold into `--assets` to emit generated colors file; keep idempotent check in `assert-generated-output.sh`. |

---

## 4. Phased execution plan — what to do, in order

### Phase 0 — Safety pins (1–2 hours, no behavior change)
*Goal: lock current behavior so refactors are provable.*

1. Add tests E1–E4 pinned to current values (surface specs, metrics, wallet arrangement ideal/equalized branches, placeholder wash). Run `Scripts/test-package.sh TrinketDesignSystem` — green baseline.
2. Add generated-colors inventory script (dry run, no code change yet) that lists all `*.colorset` names vs `named("…")` strings to confirm parity.

**Verification:** `handoff.sh --isolate --paths Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/**` passes; no product change.

### Phase 1 — Deletions & inlines (2–3 hours, lowest risk, highest payoff)
*Goal: remove wrappers that add names but not behavior.*

- Delete **A1** `CardSurfaceModifier` struct → keep `trinketCardSurface` thin alias or migrate 2 call sites; verify no other `cardArtworkSurface`.
- Delete **A2** `QuietTapButtonStyle` + replace with `.buttonStyle(.plain)`.
- Collapse **A3** button layer → one `GlassButtonModifier`; delete `OptionalForegroundModifier` / `OptionalAccessibilityIdentifierModifier` in favor of `if let`.
- Delete **A5** `SurfaceShadow.elevated`, **A8** `cardArtworkPlaceholderBackground`.
- Collapse **A6** `ArtworkBlendDestination` YAGNI enum.
- `TrinketMotion` `var` → `let` for 6 animations (**B7** first tranche: `press`, `selection`, `stateChange`, `fade`, `crossfade`, `textAnimation`).

**Verification:** `handoff.sh --isolate --paths Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Modifiers.swift Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/ArtworkBlend.swift` green. No snapshot drift (preview still renders).

**Ask:** None — these are pure deletions with identical output.

### Phase 2 — Consolidations (half-day, the “right shape” changes)
*Goal: one place for surfaces, metrics, shapes, placeholders.*

- **B2** Table-drive `SurfaceStyle` (`VisualFoundation.swift:121-187` → 5-line lookup). Keeps all opacities identical at this step.
- **B1** Split `Metrics` into `Spacing`/`Layout`/`Bars` namespaces; keep `Metrics` as `@available(*, deprecated)` typealias for incremental migration, remove after one sweep of call sites (≈100 hits; codemod via search/replace).
- **B3** Unify placeholders: delete `CardArtworkPlaceholder`, keep `PlaceholderArtwork` as only implementation; update `CombatantArtwork:50`, `AbilityCard:28`, `ItemArtwork:51` to already-use path (already mostly migrated). Remove fixed `38pt` divergence.
- **B4** Wire all grid tokens through `Layout`; replace preview hard-coded `130` with token.
- **B5** Single card shape factory.
- **B7 remainder:** Derive `textShineDuration` from `loopPeriod`, consolidate near-duplicate durations with comments marking intentional ladder (`quick 0.16`, `standard 0.18-0.20`, `emphasized 0.28-0.35`).

**Verification:** Same isolate gate + contrast tests. Do a visual sweep of Collection grid, party picker, hub (regular vs compact), collection shelves.

**Ask:** Confirm naming for `Spacing` vs keeping `Metrics.*Spacing` identifiers — former requires ~100 file touch but is the cleaner long-term shape; latter keeps diff small. Recommend `Spacing`/`Layout` split with deprecated alias to get both.

### Phase 3 — Consistency & bug fixes (half-day, some require product say-so)

- **C3** Unify plasma body (single `TimelineView`, single/dual branch, `colors(for:)` prefix fix). This is a refactor but behavior-preserving except for the 1-source brightness correction (0.28 vs 0.22 — keep single path at 0.22).
- **C7** Smooth XP snap (defer level bump or animate reset).
- **C8** Fix `proposal.width <= 1` brittle threshold.
- **C1+C9** Centralize opacity ladder + derive shine offsets from motion tokens.
- **C4 Reduce Motion:** gate plasma + rarity shine on `accessibilityReduceMotion` (requires product confirmation that pausing is desired).
- **C2** Dynamic Type scaling for remaining placeholder paths (done via B3; if kept separately, add `@ScaledMetric`).
- **C5** Decide `ResourceGold` asset vs documented alias.

**Verification:** `ExperienceBarTests` still green; add `KeywordPlasmaBackground` unit test for `colors(for:)`; manual check Reduce Motion on device/simulator.

**Ask before merging:** Approve (a) Reduce Motion pausing behavior, (b) XP continuity change, (c) `ResourceGold` asset addition — all are tiny visual changes but player-visible in edge cases.

### Phase 4 — Performance polish (2–3 hours, measure before/after)

- **D1** Reduce locked-card shadows (5→1) + remove duplicate `compositingGroup`/`clipShape`; profile scrolling collection with Instruments.
- **D2** Plasma pause + single-shader fast path; measure FPS on SE / low-end sim.
- **D3** Share shine timeline or make `RarityLabel` shine parent-driven.
- **D4** Conditional shadow.
- **D6** Consider `ExperienceBar` animation coalescing (only if measured jank; current 18-step loop is acceptable for 0.30s — defer unless profiling shows cost).

**Verification:** No new tests needed; before/after FPS numbers attached to PR. No behavior change, just lighter.

### Phase 5 — Tests & docs to lock the shape (half-day, parallelizable with Phase 3/4)

- Add **E1–E8** expanded coverage (surface, metrics pin, keyword asset existence, wallet layout, placeholder, motion ladder, full 54-asset contrast light+dark, plasma fallback).
- **F2** Generate `DesignColors.generated.swift` from assets; teach `check-ui-style.sh` to enforce no raw strings outside generated file.
- **F1** README table polish; **F5** clarify `AGENTS.md` on `gold` ownership.

**Verification:** `test-package.sh TrinketDesignSystem` covers new cases <0.2s. `check-ui-style.sh` green, `change-budget.sh` advisory reported if authored delta > warning threshold (explain deprecated alias + generated file).

---

## 5. What is intentionally left alone

* `BattleEngine` / `TrinketContent` / `TrinketPersistence` — out of random scope; not touched despite adjacent duplication (e.g., `CombatantProgression.requiredXP` lives in `TrinketCore` correctly).
* `HeroScrim` + `ArtworkBlend` as separate concerns — they solve different readability problems (text shadow vs gradient). Consolidated only via shared opacity token, not merged types.
* `TrinketWalletGrid` custom Layout kept — not fully replaced by `Grid` until iOS 26 Grid performance is proven; simplified rather than replaced to avoid churn.
* `ExperienceBar` animation model moved only logically (pure functions to `TrinketCore`), not full `withAnimation` rewrite, unless profiling proves needed.
* No new packages, no external dependencies, no UIKit bridges, no new protocols (per `AGENTS.md` guardrails).

---

## 6. Verification & shipping

* **Per-phase:** `Scripts/handoff.sh --isolate --paths Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/** Packages/TrinketDesignSystem/Tests/**` — must be green before next phase.
* **Generation gate:** If adding `DesignColors.generated.swift`, run `Scripts/assert-generated-output.sh --idempotent` and `Scripts/generate.sh` not needed for this package otherwise.
* **Full gates (CI-owned after push):** `Smoke.xctestplan` and `check-artwork-budget.sh` / `check-comment-ban.sh` — not run locally in full; rely on isolate gate locally.
* **Change budget:** Expect `change-budget.sh` warning from B1 renames (~100 touches) — justification: readability/ownership, rejected smaller alternative was “keep Metrics flat” which leaves next contributor guessing where to add a new number. Include note in commit body.
* **Commit:** Directly to `main` only when you explicitly request push (per `Guardrails` — checkout stays on `main`, no branch). Each phase is one commit with authored + generated files.

---

## 7. Decisions needed from you before implementation

1. **Metal / plasma brightness fix (C3) — OK to correct 0.28→0.22 when single source?** Very subtle (≈6% alpha).
2. **Reduce Motion (C4/D2) — OK to pause plasma + rarity shine when `accessibilityReduceMotion` is on?** Recommended for a11y.
3. **XP bar continuity (C7) — OK to smooth level-up tick vs snap?** Keeps 0.30s budget, just removes one-frame pop.
4. **Resource gold (C5) — Keep alias `Keyword.gold` or mint a separate `ResourceGold` asset so Homestead gold is independently tweakable?** Recommend separate asset (copy value today).
5. **Metrics rename (B1) — Do you prefer the cleaner `TrinketDesign.Spacing/Layout/Bars` split with deprecated alias, or keep `Metrics` flat to minimize diff?** Recommend split.
6. **Placeholder visual (B3) — OK to standardize on `0.18` wash + hierarchical single path and remove the opaque `0.85` variant?** Recommend yes — already majority path.

If you approve, I’ll execute in the phased order above, starting at **Phase 0 pins → Phase 1 deletions**, and pause after each phase for green isolation.

---
*Evidence pins: `TrinketDesign.swift:48-160`, `VisualFoundation.swift:121-205`, `Modifiers.swift:3-280`, `TrinketMotion.swift:6-56`, `Keyword+VisualStyle.swift:14-44`, `KeywordPlasmaBackground.swift:21-139`, `CardArtwork.swift:26-43`, `PlaceholderArtwork.swift:4-65`, `ExperienceBar.swift:172-253`, `WalletResources.swift:186-221`, `TrinketRarityLabel.swift:51-67`, `ArtworkBlend.swift:3-50`, `HeroScrim.swift:22-31`. Deep audit subagent report and manual file reads back every claim.*

