# Battle Spectacle Plan — Skill Callouts & Ultimate Cinematics

Implementation plan for battle cast presentation. Design lock: Skill caster-anchored ability art + Hero/Pet Ultimate full-screen cinematics. Roadmap anchors: **R-008**, **R-011** (Ultimate-only). Complements `AppVisualFoundation.md` §Battle Feedback And Motion.

**Status:** planned — awaiting implementation kickoff  
**Out of scope:** Skill full-screen cinematics, enemy Ultimate full-screen, keyword particles / card lunge (R-006), battle SFX (R-007), idle portrait loops (R-010)

---

## Product contract (locked)

| Cast | Who | Presentation | Battle clock | Hit feedback |
|------|-----|--------------|--------------|--------------|
| Basic | Anyone | Existing target floating chips | Continues | Immediate on target |
| Skill | Anyone | Ability art over **caster** card | Soft-hold **~0.5s** | On target (during/after callout) |
| Ultimate | **Hero & Pet only** | Full-screen cinematic | **Hard hold** until dismiss | **Deferred** until cinematic ends, then immediate |
| Enemy Ultimate | Enemy | No full-screen; Skill-style caster callout (or Basic chips) | Soft-hold if callout | On target |

**Ultimate media:** Prefer preloaded video; fall back to ability card art until videos exist. Display crop **9:16** (source aspect may vary). Typical length ~4–6s; not a hard engine cap. Audio optional later (schema + volume hook reserved).

**Options:** Ultimate skip preference — Always / Never / After first view.

**Reduce Motion:** Skill = fade only; Ultimate = static art fallback + short fade (no video).

---

## Motion research → Trinket choices

Trinket already uses `KeyframeAnimator` + `SpringKeyframe` / `CubicKeyframe` for combat chips (`CombatFeedbackEventView`), `.snappy` springs in Homestead, and Liquid Glass morph IDs (`.glassEffectID` + `@Namespace`). Battle spectacle should extend that vocabulary — not invent one-off curves in feature views.

### API selection matrix

| Moment | Prefer | Why | Avoid |
|--------|--------|-----|-------|
| Skill art appear / settle / exit | `KeyframeAnimator` (multi-track scale, opacity, offset) | Same family as floating chips; precise ~0.5s budget; independent tracks | Long `withAnimation` chains that fight the soft-hold timer |
| Skill soft-hold clock | `SuspendingClock` + session gate (like Reduce Motion chip path) | Deterministic hold; testable; does not depend on animation completion callbacks | Sleeping inside view body; `Task.sleep` for production multi-second delays |
| Ultimate enter (art → full screen) | `@Namespace` + `matchedGeometryEffect` from caster ability art (or combatant card) → full-screen frame, driven by `withAnimation(.spring(…))` / `.smooth` | Continuity: cast “comes from” the fighter; buttery hero morph in one hierarchy | `navigationTransition(.zoom)` — battle is an overlay on Play, not a NavigationStack push; known iOS 26 swipe-back quirks irrelevant but wrong layer |
| Ultimate scrim / chrome dim | Implicit `.animation(.easeOut(duration:), value:)` on opacity | Simple property; keep off the matched-geometry path | Animating layout of the whole battlefield |
| Ultimate video reveal | Crossfade video over fallback art once `AVPlayerItem.status == .readyToPlay` **and** preroll complete | Never show a black/loading frame; art is always the first paint | Mounting `VideoPlayer` cold on cast; recreating `AVPlayer` per frame |
| Ultimate exit → resume | Spring collapse via matched geometry **or** fast opacity+scale out if skip/Reduce Motion; then flush deferred chips with existing `KeyframeAnimator` | Hit numbers should feel like the cinematic “lands” | Dropping chips mid-transition; hard-cut with no exit |
| Skip affordance | Opacity fade-in after lockout; `.symbolEffect` optional | Low distraction | Blocking glass buttons that fight art-forward battle chrome |
| Glass chips on Skill callout | Existing `.trinketGlassChip()`; optional `.glassEffectID` if morphing chip→cinematic later | Design-system compliant | Raw `.glass` / materials in feature views |

### Shared motion tokens (implement with R-001 slice)

Add a small battle-facing preset surface in `TrinketDesignSystem` (names illustrative):

| Token | Suggested feel | Use |
|-------|----------------|-----|
| `TrinketMotion.battle.skillCallout` | Keyframe recipe ~0.55s total (in 0.12 / hold / out 0.18) | Skill art |
| `TrinketMotion.battle.ultimateExpand` | Spring `response ≈ 0.38–0.45`, `dampingFraction ≈ 0.86–0.92` (almost no bounce) | Matched-geometry expand |
| `TrinketMotion.battle.ultimateCollapse` | Slightly snappier spring or `easeIn` ~0.28s | Exit / skip |
| `TrinketMotion.battle.scrim` | `easeOut` ~0.2s | Dim battlefield |
| `TrinketMotion.battle.reduceMotionFade` | `easeOut` ~0.15–0.2s | Accessibility path |

Centralizing these advances **R-001** for the battle slice without boiling the ocean app-wide.

### Buttery-smooth rules (non-negotiable)

1. **One owner for timing** — `BattleSession` owns soft-hold / cinematic hold / deferred feedback flush. Views animate; they do not advance the battle clock.
2. **No layout thrash** — Ultimate overlay is a `ZStack` sibling above `BattlefieldView`, not a rebuild of the card grid.
3. **Matched geometry stays in-tree** — Source and destination must share an ancestor during the morph (overlay pattern, not navigation push).
4. **Transaction hygiene** — Use explicit `withAnimation` / `KeyframeAnimator` triggers; avoid accidental implicit animations on health bars during cinematic hold.
5. **Reduce Motion first-class** — Branch before starting springs/video; never “play then cancel.”
6. **60fps budget** — Prefer HEIC ability art + one video layer; no particle systems in this plan.

### Video hitch-free strategy

Bundle clips as local assets (not streaming). Pipeline goals:

| Technique | Detail |
|-----------|--------|
| Persistent player cache | `BattleCinematicPlayer` (or session-scoped store) keyed by `abilityID`; **do not** recreate `AVPlayer` when the overlay appears |
| Warm on battle start | After `ActiveBattleConfiguration` is set, preload Hero + Pet Ultimate assets (fallback image always; video if catalog has one) |
| Preroll before first frame | `AVPlayer.preroll(atRate:)` / wait until `readyToPlay` + `playbackLikelyToKeepUp` before swapping art→video |
| Instant start | For local files, `automaticallyWaitsToMinimizeStalling = false` once prerolled so play does not invent a wait; if not ready, keep art fallback visible |
| Display crop | `scaledToFill` in a 9:16 container (or full-bleed portrait with 9:16 content mode); letterboxing only if product later asks |
| Audio | Player respects `OptionsStore.effectsVolume`; default mute or silent assets until audio is authored; schema flag `hasAudio` |
| Memory | Release non-active items on battle end; keep only current + next likely Ultimate warm |
| SwiftUI surface | Prefer thin `AVPlayerLayer` / `UIViewRepresentable` or controlled `VideoPlayer` **without** system chrome; hide playback controls |

---

## Architecture

```text
BattleEngine
  ActionEvent (+ actorID, abilityID, abilityTier)
       │
BattleSession
  softHoldUntil / cinematic / deferredFeedback[]
  pause gates (overlay + cinematic + soft-hold)
       │
BattleView
  BattlefieldView          // cards + existing chips
  SkillCalloutLayer        // caster-anchored art (matched geo source)
  UltimateCinematicOverlay // full-screen morph + video/art
```

### Engine

Enrich `.ability` events at `BattleTurnEngine` emit site:

- `actorID: String`
- `abilityID: String`
- `abilityTier: AbilityTier`

Update `ActionEvent` init call sites, formatters/log (ignore new fields for prose), and BattleEngine tests. No cast/hit phase split in v1.

### Session presentation state

Extend `BattleSession` (names illustrative):

- `softHoldUntil: Date?` — blocks `canAutoAdvanceTick` until elapsed
- `activeSkillCallout: SkillCallout?` — actorID, abilityID, expiresAt
- `activeCinematic: BattleCinematic?` — abilityID, actorID, phase (`expanding` / `playing` / `collapsing`)
- `deferredFeedbackEvents: [ActionEvent]` — Ultimate step’s chips held until cinematic ends
- `cinematicPauseDepth` or reuse `pauseForOverlay` with a distinct reason so manual pause + cinematic compose correctly

**Ultimate step flow:**

1. `advanceOneStep` emits Ultimate `.ability` (+ effect events).
2. If actor is Hero/Pet → start cinematic; **do not** record those events into live feedback yet; stash in `deferredFeedbackEvents`.
3. Hard-hold ticks while cinematic active.
4. On finish/skip → collapse animation → `recordFeedbackEvents(deferred)` → clear cinematic → resume ticks.

**Skill step flow:**

1. On Skill `.ability` → set callout + `softHoldUntil = now + 0.5s`.
2. Record feedback to targets as today (chips can overlap callout).
3. `canAutoAdvanceTick` false until soft-hold elapses (and not otherwise paused).

### UI layers

- **SkillCalloutView** on `BattleCombatantPane` (or overlay aligned to pane frame): 3:4 ability art, name optional, keyword rim; `KeyframeAnimator` lifecycle; Reduce Motion fade.
- **UltimateCinematicOverlay**: scrim + matched-geometry destination; art fallback always; video layer when ready; tap-to-skip per Options; accessibility announcement.

### Options

`OptionsStore` + `OptionsView` section **Battle**:

```swift
enum UltimateCinematicSkipPolicy: String, CaseIterable {
    case always
    case never
    case afterFirstView
}
```

Persist with `@AppStorage` key `options.ultimateCinematicSkipPolicy`. For `afterFirstView`, store seen ability IDs in `UserDefaults` (device-local, not CloudKit). Reset-progress keeps settings (existing behavior).

Clear new keys in `clearResetStateDefaults` only if product wants settings wiped on reset — **default: keep** (match appearance/haptics).

### Assets / catalog

1. Manifest kind for Ultimate cinematics (e.g. `ability_cinematic` in art/video manifest) keyed by ability `id`.
2. Generated `UltimateCinematicReference`: `abilityID`, optional `videoName`, `fallbackImageName` (ability art), optional `hasAudio`, display aspect hint (always present as 9:16 for battle).
3. Until videos exist: references resolve to fallback only; overlay path identical.
4. `./Scripts/generate.sh --assets` prepares bundles; never hand-edit `Generated/`.

---

## Phased implementation

### Phase 0 — Motion tokens + docs already landed

- [x] Design lock in Roadmap / AppVisualFoundation / this plan
- [ ] Add `TrinketMotion.battle.*` presets in `TrinketDesignSystem` (+ focused tests for token existence / Reduce Motion helpers if pure data)

### Phase 1 — Event enrichment

- [ ] Extend `ActionEvent` + emit site
- [ ] BattleEngine unit tests for tier/id/actor on ability events
- [ ] Fix any app/test compile breakages from new fields

### Phase 2 — Session timing gates

- [ ] Soft-hold + cinematic hold in `canAutoAdvanceTick`
- [ ] Deferred feedback queue for Ultimates
- [ ] `TrinketTests` / session tests: Skill holds ~0.5s; Ultimate blocks ticks until dismissed; deferred chips flush once

### Phase 3 — Skill callout UI (R-008)

- [ ] Caster-anchored art using `ability.artReference`
- [ ] Keyframe recipe from motion tokens; Reduce Motion path
- [ ] `accessibilityIdentifier` for smoke
- [ ] Smoke: battle still stable (`SmokeBattleTests`); optional assert callout appears when forced Skill (may need test hook / seed)

### Phase 4 — Ultimate overlay + art fallback (R-011 groundwork)

- [ ] Full-screen overlay + matched-geometry expand/collapse
- [ ] Hero/Pet only; enemy Ultimate → Skill-style callout
- [ ] Hold combat; flush damage on dismiss
- [ ] Options skip policy wired (tap skip respects policy)
- [ ] Reduce Motion: static art, short fade, no morph required

### Phase 5 — Video pipeline + preload

- [ ] Manifest + generated catalog stubs
- [ ] `BattleCinematicPlayer` cache, warm on battle start, preroll, 9:16 crop
- [ ] Crossfade art → video only when ready; never blank
- [ ] effectsVolume / hasAudio hook (can stay silent)
- [ ] Memory teardown on `endBattle`

### Phase 6 — Polish & verification

- [ ] `./Scripts/check-ui-style.sh`
- [ ] `./Scripts/check-module-boundaries.sh`
- [ ] Package + app unit tests for new logic
- [ ] `SmokeBattleTests` (+ Options smoke if skip control added)
- [ ] Manual: Reduce Motion, skip policies, no hitch on art fallback path

---

## Module & style constraints

- Rules stay in `BattleEngine`; presentation in `Trinket/Features/Battle` + `BattleSession`.
- Reusable motion/chrome in `TrinketDesignSystem` only (`TrinketCore` dependency — no BattleEngine import).
- No raw materials / `.buttonStyle(.glass*)` in feature views — route through design system.
- iOS 26 only; no `#available` for older OS.
- Do not unit-test styling aesthetics; do test session gates and event fields.

---

## Test plan (summary)

| Layer | What |
|-------|------|
| BattleEngine | Ability events include id/tier/actor; cadence unchanged |
| BattleSession | Soft-hold; cinematic hold; deferred flush; skip does not leak pause |
| OptionsStore | Skip policy persistence; afterFirstView seen-set |
| UI smoke | Battle enter/pause/log/retreat still green; new a11y ids if asserted |
| Manual | Buttery expand/collapse; zero blank frames; Reduce Motion; 9:16 crop |

---

## Open implementation details (defaults if unspecified at kickoff)

1. **`afterFirstView` scope:** per `abilityID` lifetime on device (recommended).
2. **Enemy Ultimate:** Skill-style caster callout (recommended) vs Basic-only chips.
3. **Skill callout size:** ~40–55% of caster card width, top-trailing or center-over-card — tune in Phase 3.
4. **Matched-geometry source:** ability art thumbnail on caster if already visible, else combatant card bounds.
5. **Skip lockout:** ~0.45s after expand starts before taps count.

---

## Approval

Approve this plan (or note deltas) before coding Phases 0–5. Design decisions above are locked; motion/video sections are the implementation contract for “buttery smooth.”
