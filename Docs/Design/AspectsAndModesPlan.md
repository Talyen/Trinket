# Aspects & Play Modes Plan

Design and implementation plan for the **Play Modes** destination chooser and the first alternate mode, **Aspects** (Keyword-constrained floor climbs). Expands roadmap **R-022**. Complements `CoreDesignConcepts.md` (journey + Keywords), `AppVisualFoundation.md` (chrome + motion), and `AppleNativeGuidelines.md` (SwiftUI / iOS 26 patterns).

**Status:** implementing — Phases 1–4 landed; follow-up fixes cover attunement coverage, Aspect battle resume, unlock guards, Warden item rolls, Modes Chapter-1 gate, climb UX. Content uses existing enemy roster; TSV codegen deferred.  
**Out of scope for Aspects v1:** PvP, guild modes, Easy/Hard difficulty tiers, Reliquary Gauntlet / Astral Hunt (teasers only). **The Labyrinth** (infinite delve) is specified and implemented per `Docs/Design/DelveModePlan.md` (**R-022c**).

---

## Product contract (locked)

| Surface | Role |
|---------|------|
| **Chapter Journey** | Primary narrative progress. Remains the default Play destination. |
| **Play Modes** | Secondary destinations for variety and alt-progression. Not difficulty variants of the journey. |
| **Aspects** | First Mode. Climb floors under one **Aspect** affinity. Same Hero / Pet / Enemy / Ability / Item / `BattleEngine` stack. |
| **Player-facing language** | Never say “Keyword” in Modes/Aspects UI. Use **Aspect**, affinity color/symbol, and poetic place names. |

**Combat contract:** Aspects battles are normal idle auto-battles (`BattleState.advanceOneStep`, Hero+Pet vs one Enemy). Mode rules are **eligibility + encounter selection + rewards**, not a new combat UI.

**Progression contract:** Aspects grant XP, gold, Homestead materials, and Aspect-biased item rolls so alternate Heroes/Pets can progress without replaying chapters. Journey completion is never required to *finish* an Aspect floor set, but Modes unlock from journey milestones.

---

## Naming

### Mode umbrella

| Layer | Name | Notes |
|-------|------|-------|
| Play destination list | **Modes** | Short tab/row label |
| Screen title | **Modes** | One word; subtitle explains |
| First mode | **Aspects** | Collection of affinity climbs |
| One climb | an **Aspect** | e.g. “Cinder Spire” |
| Floor | **Floor N** | Not “Stage” — Stages belong to Chapters |

### Aspect roster (all Keywords)

Each Aspect has a **poetic title** (primary UI), a short **epithet**, and a hidden `Keyword` binding for rules/content. Titles must not be the Keyword string alone.

#### Damage Aspects (v1 climb set — ship these first)

| Keyword | Aspect title | Epithet | Symbol (existing) |
|---------|--------------|---------|-------------------|
| Physical | **Iron Vein** | Strike without ornament | `bolt.fill` |
| Burn | **Cinder Spire** | Heat that refuses to die | `flame.fill` |
| Poison | **Serpent Hollow** | Slow certainty | `drop.triangle.fill` |
| Bleed | **Scar Gallery** | Every cut remembers | `drop.fill` |
| Holy | **Aureate Choir** | Light that judges | `sun.max.fill` |
| Nature | **Wildroot Grove** | Growth as weapon | `leaf.fill` |
| Freeze | **Rime Vault** | Stillness that binds | `snowflake` |
| Stun | **Storm Anvil** | One blow that stops the world | `bolt.fill` |

#### Mitigation Aspects (v1.1 — unlock after damage set exists)

| Keyword | Aspect title | Epithet |
|---------|--------------|---------|
| Block | **Aegis Bastion** | Hold the line |
| Armor | **Plate Crypt** | Endure the storm |
| Dodge | **Whisper Gallery** | Never where they strike |
| Purge | **Unmaking Altar** | Strip the gifted |

#### Restoration Aspects (v1.1)

| Keyword | Aspect title | Epithet |
|---------|--------------|---------|
| Health | **Heartwell** | Mend and stand |
| Leech | **Thirsting Shrine** | Take what you deal |
| Death's Door | **Threshold Chapel** | One breath from the end |

#### Resource Aspects (optional / later — economy flavor, not combat climbs)

| Keyword | Aspect title | Epithet | Notes |
|---------|--------------|---------|-------|
| Gold | **Gilded Vault** | Fortune favors the bold | Prefer Homestead Expedition rewards over a climb |
| Mana | **Starwell** | Power drawn from quiet | Prefer Magical delve / Labyrinth boons |

**v1 ship set:** the eight **Damage Aspects** only. Mitigation/Restoration Aspects reuse the same UX once content exists.

---

## Player fantasy & rules

### What an Aspect is

An Aspect is a **vertical climb** of authored floors. Entering an Aspect means the party must **attune** to that Aspect:

1. **Hero** must have at least one Ability whose `damageKeyword` (or primary effect Keyword) matches the Aspect’s Keyword — *or* be tagged with that affinity in content (see Content model).
2. **Pet** same rule.
3. **Equipped Items** should contribute: at least one equipped item’s `keywordAffinities` intersects the Aspect Keyword **or** the party already qualifies via abilities. Soft rule for v1: **require Hero+Pet ability affinity**; items are recommended (UI hint) but not hard-gated until inventory depth is high enough.
4. Enemies on that Aspect favor the opposing fantasy (Burn Aspect enemies lean into Burn threats / Burn-resistant patterns via authored catalog, not a global “hard mode” multiplier).

### Floor structure

| Floor band | Count (v1) | Encounter | Reward emphasis |
|------------|------------|-----------|-----------------|
| 1–9 | 9 | Standard Aspect enemies | Gold, XP, materials |
| 10 | 1 | Aspect Warden (boss) | Aspect-biased item roll + milestone |

Progress is **persistent per Aspect** (`highestClearedFloor`). Floors are sequential; no skipping. Clearing Floor N unlocks N+1. Replays of cleared floors are allowed for farming (same rewards at reduced rate *or* full rate with a daily soft cap — pick in Phase 2 economy pass; default **full rate, no stamina** for v1 simplicity).

### Why play Aspects (vs Journey)

| Journey | Aspects |
|---------|---------|
| Story, chapter art, mixed encounter types | Pure combat climb, affinity fantasy |
| Advances world progress | Advances **roster depth** + **affinity gear** |
| One active path | Eight parallel paths (v1) |
| Locked once completed (current loop) | Replayable floors |

---

## UI/UX flow

### Information architecture

```text
Play tab (NavigationStack)
├─ PlayHomeView                    ← NEW root (Modes + Journey entry)
│   ├─ push → ChapterStageSelectView   (existing journey)
│   └─ push → ModesView
│         └─ push → AspectsHubView
│               └─ push → AspectClimbView(aspect)
│                     └─ fullScreenCover / existing battle overlay → BattleView
└─ (active battle still replaces Play content via AppState.battle — unchanged)
```

**Important:** Keep battle presentation as today (`PlayView` swaps to `BattleView` when `activeBattle != nil`). Modes/Aspects only change *how* `ActiveBattleConfiguration` is created (Aspect floor encounter instead of journey stage).

### Screen 1 — Play Home

**Composition (one viewport, brand/journey first):**

1. Full-bleed **current chapter art** (reuse `ChapterJourneyHero` crop / `backgroundExtensionEffect`).
2. Chapter title + one line (“Continue the Verdant Forest”).
3. Primary CTA: **Continue Journey** → push journey.
4. Below fold / secondary: **Modes** row (art-forward, not a dashboard).

Optional compact chips on the Modes row: one progress teaser (“Cinder Spire · Floor 4”) — never a grid of timers/stats.

**Empty / early unlock:** If no Modes unlocked, hide the Modes row or show a single locked teaser after a journey milestone (e.g. clear Chapter 1 Stage 5 or Chapter 1 finale — product pick in Phase 0).

### Screen 2 — Modes

**Title:** Modes  
**Subtitle:** Other paths. Same battles. Different reasons to fight.

Vertical list of mode cards (v1: Aspects only; others locked teasers):

| Mode | State | Card content |
|------|-------|--------------|
| Aspects | Unlocked | Symbol mosaic of Aspect colors, “Climb by affinity”, highest Aspect progress |
| Reliquary Gauntlet | Locked | Epithet + “Opens later” |
| Astral Hunt | Locked | Epithet + “Opens later” |
| The Labyrinth | Locked | Epithet + “Opens later” |

Tap Aspects → push `AspectsHubView`. Locked cards are non-interactive (or show a one-line unlock hint sheet — prefer non-interactive for v1).

### Screen 3 — Aspects Hub

**Title:** Aspects  
**Hero:** Quiet full-bleed abstract / collage using Keyword visual colors (no busy dashboard). One line: “Attune a Hero and Pet. Climb one Aspect at a time.”

**Body:** Scrollable list (or 2-column grid if art tiles read well at 3:4 — prefer **list of art-forward rows** first to match journey density).

Each Aspect row:

- Leading: Keyword-colored symbol in glass chip
- Title: poetic name (`Cinder Spire`)
- Epithet (secondary)
- Trailing: `Floor N` or `Warden` / `Cleared`
- Locked Aspects: silhouette + unlock condition (“Clear Iron Vein Floor 5” or journey gate)

Tap → push `AspectClimbView`.

### Screen 4 — Aspect Climb

Mirrors journey readability without copying chapter chrome:

1. **Pinned Aspect header** — title, epithet, Keyword-tinted atmosphere (semantic background + subtle Keyword glow accents per `AppVisualFoundation`; not wallpaper noise).
2. **Party attunement strip** — Hero + Pet cards; invalid party shows clear reason (“Needs a Burn ability”) and disables Start.
3. **Floor list** — completed floors compress; active floor is large card with enemy preview + **Begin Floor**; future floors visible but locked.
4. Primary action on active floor → starts Aspect battle (same party picker patterns as journey).

Enemy art tap → existing combatant detail sheet.

### Screen 5 — Battle & return

- Identical `BattleView` chrome.
- On victory: grant Aspect rewards, advance floor progress, dismiss to Aspect Climb with scroll-to-next (same comfort scroll idea as journey).
- On defeat: return to Aspect Climb; floor unchanged.
- Toolbar retreat/abandon: same as journey battles.

### Navigation & deep links

| Launch / restore | Behavior |
|------------------|----------|
| Default Play | Play Home (or jump straight to Journey if product prefers zero friction — **recommend Play Home once Modes exist**, with Continue Journey as primary) |
| `-launch-screen play` | Play Home |
| Future `-launch-screen aspects` | Aspects Hub |
| Mid-Aspect battle restore | Resume card on Play Home / Aspect Climb (extend existing resume battle card) |
| Tab switch during battle | Unchanged (`selectedTab != .play` pauses) |

### Accessibility

- All interactive controls get `AccessibilityID` entries under `AccessibilityID.Modes` / `.Aspects`.
- Aspect titles and epithets are VoiceOver labels; Keyword color is not the only signal (symbol + text).
- Dynamic Type via `trinketTypography`; no fixed icon font sizes.
- Reduce Motion: see Motion section.
- Reduce Transparency: glass chips / materials resolve via design-system fallbacks.

---

## Motion, transitions, SwiftUI best practices

Align with `BattleSpectaclePlan.md` motion vocabulary and iOS 26 APIs already in the app.

### API selection matrix

| Moment | Prefer | Why | Avoid |
|--------|--------|-----|-------|
| Play Home → Journey / Modes | `NavigationStack` + `navigationDestination` | Standard Play stack; swipe-back | Presenting Modes as sheet over journey |
| Modes → Aspects → Climb | Same stack pushes | Continuous hierarchy | Nested `NavigationStack`s |
| Aspect color accents on appear | Implicit `.animation(.smooth, value:)` on tint opacity | Cheap, interruptible | Per-frame `TimelineView` for static hubs |
| Floor row appear in climb list | Existing `JourneyScrollTransition`-style modifier gated by Reduce Motion | Familiar Play language | Random spring on every row forever |
| Aspect Hub symbol mosaic | Staggered opacity via `PhaseAnimator` **or** simple `ForEach` + delay only if Reduce Motion off | Presence without noise | Continuous particle loops on hub |
| Begin Floor → Battle | Existing battle presentation path | One battle shell | Custom zoom that fights battle overlay |
| Victory → next floor focus | `scrollPosition` + `withAnimation(.smooth)` (journey pattern) | Consistency | Manual `ScrollViewReader` unless needed |
| Attunement fail feedback | `.trinketSensoryFeedback` gated by Options + symbol bounce via `.symbolEffect(.bounce)` | Native, accessible | Custom shake hacks |
| Matched hero art (optional polish) | `@Namespace` + `matchedGeometryEffect` from Aspect row symbol → Climb header symbol | Continuity | `navigationTransition(.zoom)` until proven on art-forward hidden toolbars |
| Tab bar | Existing `.tabBarMinimizeBehavior(.onScrollDown)` | Already on `ContentView` | Re-implementing minimize per screen |

### Motion tokens (add to `TrinketDesignSystem` when implementing)

| Token | Feel | Use |
|-------|------|-----|
| `TrinketMotion.modes.push` | System default / `.smooth` | Hub pushes |
| `TrinketMotion.aspects.tintIn` | `easeOut` ~0.25s | Aspect header tint |
| `TrinketMotion.aspects.floorFocus` | `.smooth` | Scroll to active floor |
| `TrinketMotion.aspects.reduceMotion` | `easeOut` ~0.15s opacity only | Accessibility path |

### Buttery-smooth rules

1. Animate **opacity, transform, scroll position** — not layout thrash of large art assets.
2. One intentional motion per transition; max **2–3** on Aspects Hub first paint (tint in, mosaic fade, row settle).
3. Never block battle clock on hub animations.
4. Prefer `@Observable` mode/progress state; no `ObservableObject` / `@Published`.
5. Chrome through `TrinketDesign` / `.trinketSurface` / `.trinketGlassChip` / `.trinketPrimaryActionButton` only.
6. Hidden toolbar on art-forward Aspect Climb header is OK (same rationale as journey); Modes list can show standard nav bar title.

---

## Content & data model

### Domain types (`TrinketCore` / `TrinketContent`)

```text
AspectID          // stable id, e.g. cinderSpire
AspectDefinition  // id, title, epithet, keyword, unlock, floorCount, artRef
AspectFloor       // aspectID, floorIndex, enemyID, rewards
AspectProgress    // aspectID → highestClearedFloor (persistence)
```

Do **not** hand-edit `Generated/`. Prefer:

- `ContentManifest/aspects.tsv` + `aspect_floors.tsv` (or single TSV with floor rows)
- `./Scripts/generate.sh` → `AspectCatalog.generated.swift`

### Persistence (`TrinketPersistence`)

New slice (keep hub thin):

- `PlayerAspectsState` value type: `[AspectID: AspectProgress]`
- SwiftData models under `PlayerSaveGraph/` (e.g. `AspectsModel` + per-aspect progress rows)
- Access via `PlayerSaveStore` property `aspects` (mirror `journey` / `roster`)
- Sanitizer: drop unknown Aspect IDs; clamp floors to catalog

### Battle entry

Extend configuration (illustrative):

```text
ActiveBattleConfiguration
  source: .journey(stageID) | .aspect(aspectID, floor)
```

Victory handler branches on source for rewards + progress write-through. Engine stays unaware of Modes.

### Eligibility helper

Pure function in content/rules layer (unit-tested):

```text
AspectAttunement.evaluate(hero, pet, loadout, aspect) -> .ready | .missingHeroAffinity | .missingPetAffinity | ...
```

---

## Rewards (v1 proposal)

On floor clear:

| Reward | Rule |
|--------|------|
| XP | Both active Hero and Pet (same grant path as journey) |
| Gold | Scaled by floor index |
| Homestead materials | Small amounts; Aspect Keyword can bias material type if a mapping exists |
| Items | On Warden (floor 10) and optionally every 5th floor: `ItemGenerator` with `keywordBias: [aspect.keyword]` |

No separate “Aspect currency” in v1 unless economy needs a sink later.

---

## Unlock pacing (v1 proposal)

| Gate | Unlocks |
|------|---------|
| Clear Journey Chapter 1 Stage 5 *(or finale — confirm in Phase 0)* | Modes screen + **Iron Vein** |
| Clear Iron Vein Floor 5 | **Cinder Spire** + **Serpent Hollow** |
| Clear Iron Vein Floor 10 | Remaining damage Aspects |
| Clear any Aspect Floor 10 | Mitigation Aspects hub section (v1.1) |

Locked teasers for Gauntlet / Hunt / Labyrinth appear on Modes with no unlock yet.

---

## Implementation plan

### Phase 0 — Design lock & scaffolding docs

**Deliverables**

- [ ] This plan reviewed; Aspect titles locked
- [ ] Unlock milestone chosen (Stage 5 vs Chapter 1 clear)
- [ ] Soft item gate decision (hint-only vs hard gate)
- [ ] Update `Docs/Roadmap.md` **R-022** to point here; optionally split **R-022a Modes shell** / **R-022b Aspects**
- [ ] One paragraph in `CoreDesignConcepts.md` under Play path: Modes + Aspects vocabulary (no Keyword in player copy)

**Verify:** doc-only; `./Scripts/ci-gate.sh` if manifests untouched

### Phase 1 — Play Home + Modes shell (UI only)

**Touch**

- `Trinket/Features/Play/PlayHomeView.swift` (new root)
- Refactor `PlayView` to host home vs battle; journey becomes pushed destination
- `ModesView`, locked mode teaser rows
- `AccessibilityID.Modes`
- Navigation path model on `AppState` or local `@State` path enum (prefer local path + explicit `AppState` for battle/resume only)

**Motion**

- Standard navigation transitions; Play Home hero reuses journey overscroll/`backgroundExtensionEffect` patterns

**Tests**

- `SmokePlayTests`: Play Home visible; Continuable Journey; Modes opens
- Unit: navigation path helpers if any

**Verify:** `./Scripts/check-ui-style.sh`; `./Scripts/test.sh ui SmokePlayTests` (toolchain permitting)

### Phase 2 — Aspects domain + persistence

**Touch**

- Manifests + generate Aspect catalog
- `PlayerAspectsState` + save graph + sanitizer + store API
- `AspectAttunement` pure evaluator
- Package tests: catalog invariants, attunement cases, persistence write-through

**Verify:** `./Scripts/generate.sh`; `./Scripts/test-package.sh TrinketContent`; `./Scripts/test-package.sh TrinketPersistence`; `./Scripts/test-package.sh TrinketCore` as needed

### Phase 3 — Aspects Hub + Climb UI

**Touch**

- `AspectsHubView`, `AspectClimbView`, floor rows (reuse journey row patterns where possible without importing journey types into a tangle — shared “climb row” primitives in Play folder OK)
- Party attunement strip + disabled Begin states
- Keyword tint via `Keyword.visualStyle` (internal); player copy uses Aspect title only
- Motion tokens + Reduce Motion paths
- `AccessibilityID.Aspects`

**Tests**

- Smoke: open Aspects, open one Aspect, see floors
- UI identifiers stable for exhaustive later

**Verify:** UI style check + smoke

### Phase 4 — Battle wiring + rewards

**Touch**

- `ActiveBattleConfiguration` Aspect source
- `AppState` start/complete/fail Aspect floor
- Reward grant + progress advance + scroll focus
- Resume/abandon parity with journey battles
- Music preview hooks if chapter music pattern extends (Aspect-specific tracks optional later)

**Tests**

- `TrinketTests` orchestration: start floor, win advances, lose does not, rewards once
- BattleEngine unchanged except using existing factory with Aspect enemies

**Verify:** `./Scripts/test.sh unit` (filtered then full when possible)

### Phase 5 — Content fill (eight damage Aspects)

**Touch**

- Author floors 1–10 enemies/rewards per Aspect (can start with 3 Aspects fully authored, stubs for rest)
- Art: symbol-forward first; full-bleed Aspect art via ArtManifest when available (`generate.sh --assets`)
- Economy pass: gold/XP curves vs journey

**Verify:** content catalog tests; smoke happy path on one full Aspect

### Phase 6 — Polish & ship gate

- Haptics on attunement failure / floor clear milestone
- Matched-geometry symbol continuity (optional)
- Locked mode teasers copy final
- `ci-gate.sh`; unit; smoke; note Xcode 26 requirement in PR if cloud agent skipped simulator

---

## File / module map (expected)

| Area | Location |
|------|----------|
| Play Home / Modes / Aspects UI | `Trinket/Features/Play/Modes/`, `…/Aspects/` |
| Journey (existing) | `Trinket/Features/Play/PlayMap/` |
| Orchestration | `Trinket/State/AppState+Aspects.swift` (new), battle config helpers |
| Domain | `Packages/TrinketCore` (IDs/progress value types if shared), `TrinketContent` catalogs |
| Persistence | `Packages/TrinketPersistence` aspects slice |
| Chrome / motion | `Packages/TrinketDesignSystem` |
| A11y | `Trinket/Shared/AccessibilityID.swift` |
| Smoke | `TrinketUITests/Smoke/SmokePlayTests.swift` (+ Modes helpers) |

**Boundaries:** Packages must not import the app. DesignSystem stays on `TrinketCore` only. Aspects UI may read catalogs + `AppState`; no `BattleEngine` imports in pure layout views if avoidable (prefer configuration built in `AppState`).

---

## Future Modes (teasers only on Modes screen)

| Mode | One-line fantasy | Reuses |
|------|------------------|--------|
| Reliquary Gauntlet | Multi-fight run; wounds persist | Encounter types, carry HP between battles |
| Astral Hunt | Rotating Warden; score damage | Boss enemy, event scoring from battle log |
| **The Labyrinth** | Persistent infinite descent; biome clusters + named modifiers | Mystery/Shop/Rest/Craft + map modifiers; Event collapsed into Mystery; see `DelveModePlan.md` |

Do not implement Gauntlet/Hunt/Labyrinth in Aspects phases. Labyrinth Phase 0 preferences are locked in `DelveModePlan.md` §12.

---

## Open decisions (resolved)

1. Play default root: Journey remains root with a Modes entry chip on the chapter hero (Play Home deferred until more Modes ship).
2. Unlock beat: **Chapter 1 complete** unlocks Modes.
3. Item affinity: **hint-only** on Aspect Climb.
4. Replay rewards: **full rate**, no stamina.
5. Resource Keywords: economy-only for v1 (no Gold/Mana climbs).

---

## Definition of done (Aspects v1)

1. Player can open Modes → Aspects → an unlocked Aspect → clear Floor 1 with an attuned party.
2. Progress persists across launch.
3. No player-facing “Keyword” copy on these screens.
4. Battle UI unchanged; engine rules unchanged.
5. Smoke covers Modes + one Aspect entry; package tests cover attunement + persistence.
6. UI style + module boundary gates clean.
