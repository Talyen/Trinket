# Battle commit presentation migration

**Status:** Active agent execution plan (handoff).  
**Order:** #1 → #4 → #5 → #2 → #3  
**Owner surface:** Battle play-commit / impact frame only.  
**Out of scope:** App-wide engine rewrite, SpriteKit/Metal for non-battle UI, Homestead/Play/Collection migrations.

This plan turns the stacked `real-card-play` hitch into a game-style presentation path without changing player-visible timings, motion curves, multimodal sync, or hand fan settle.

---

## 0. Non-negotiable UX / product guardrails

Another agent **must not** ship any of the following without an explicit human UX approval in the conversation:

1. **No multimodal frame-splitting** — chips, SFX, hit reactions, and keyword bursts stay on the same impact frame as today (`recordFeedbackEvents` → bridge publish + `applyImmediatePresentation`).
2. **No deferred cast** — cast still starts on the successful play commit frame (same ordering relative to engine resolve as today).
3. **No deferred / delayed attack swing** relative to play commit.
4. **No sibling hand-reflow suppression** to win the commit frame (reverted once already; do not reintroduce). Fan settle when `cardIDs` change must keep per-slot behavior: only the held/forced card skips `handReflow`; siblings still spring.
5. **No Metal chip renderer** as a substitute for fixing commit stacking.
6. **No full-app SpriteKit / custom game loop** for tabs, navigation, or non-battle screens.
7. **Do not hand-edit** generated code, `.DerivedData/`, `.tools/`, or the Xcode project; use routed generation scripts.
8. **Work on `main`**; no branch/commit/PR unless the human asks.

### Visual / timing parity definition

A change is **UX-safe** only if all of the following remain true versus pre-change production:

- Same commit order as today (see §1.2 current order).
- Same cast duration, dissolve look, particle motion, and handoff pose (center / scale / tilt / rotation / perspective from the releasing card).
- Same chip labels, stagger, lifetime, and host motion recipes.
- Same attack wind-up → swing feel and timing constants from `TrinketMotion.Battle`.
- Same haptics triggers and SFX clip selection on impact.
- Hand fan reflow springs still run for non-held siblings on play.

If a phase cannot prove parity, **stop and report** — do not “fix” hitch by changing motion.

---

## 0.1 Evidence baseline (why this plan exists)

Isolation (warm paths) showed pieces alone can sit near **60 FPS / ~16.7 ms**, while `real-card-play` stacks them into a large hitch. Dominant **couplings** (not only additive cost):

| Coupling | Probe signal |
|---|---|
| Forced-drag release ⊕ feedback host apply | `play-real-no-cast` bad; `play-real-no-feedback` much better |
| Hand reflow ⊕ cast mount | `play-stack-no-feedback` bad; pieces alone clean |

Gate scenarios for regression (prefer `TRINKET_PERFORMANCE_QUICK=1` for iteration; omit quick for formal compares):

```sh
TRINKET_PERFORMANCE_QUICK=1 TRINKET_ISOLATE=1 ./Scripts/test.sh performance \
  BattlePerformanceUITests/test03bRealCardPlay \
  BattlePerformanceUITests/test03gPlayStackDirect \
  BattlePerformanceUITests/test03hPlayRealNoCast \
  BattlePerformanceUITests/test03h2PlayRealNoFeedback \
  BattlePerformanceUITests/test03g2PlayStackNoFeedback \
  BattlePerformanceUITests/test03g3PlayStackNoCast \
  BattlePerformanceUITests/test03ePlayCastOnly \
  BattlePerformanceUITests/test03dPlayFeedbackOnly \
  BattlePerformanceUITests/test03cPlayEngineHand \
  BattlePerformanceUITests/test03fPlaySwingOnly
```

For stabler signal on `real-card-play`, use `TRINKET_PERFORMANCE_REPETITIONS=3` (or 5) and compare **median** max-frame / 1% low — single quick runs are noisy.

Formal gate: `./Scripts/performance.sh` (no quick mode).

---

## 0.2 Working rules for executing agents

1. Run `./Scripts/agent-context.sh --paths <files…>` before editing; follow nested `AGENTS.md` + selected cards.
2. Verify with `./Scripts/verify-changed.sh --isolate --paths <files…>`.
3. After Battle SwiftUI / presentation changes: style + `SmokeBattleTests` (or narrower smoke if one method owns the behavior).
4. After any commit-path or cast/chip change: run the gate scenario list in §0.1 and paste median metrics in the handoff notes.
5. Preserve existing unrelated dirty work; do not revert or “clean up” peers’ changes.
6. Prefer extending existing seams (`CombatFeedbackChipBridge`, `BattlePresentationState`, `BattleCastPresentationState`, signposts) over inventing parallel systems.

---

## Phase #1 — Single commit owner (frame budget)

### Goal

One authoritative API owns the successful card-play **presentation commit** so ordering, signposts, and future retained-layer work have a single choke point. Engine resolve stays in `BattleSession.playCard`; UI must not keep scattering append/swing/feedback side effects across view methods without going through the owner.

### Current order (must preserve)

Today in `BattleView.playCard(_:request:)` / `playCard(cardID:)` roughly:

1. `BattleSession.playCard` → `installBattleState` + `presentResolvedEvents` → `recordFeedbackEvents` (chip bridge publish + multimodal)  
2. `commitAttackSwing` (if owner resolved)  
3. `castPresentation.append(request)`

Finger / forced-drag path builds `CardActivationRequest` in `BattleAbilityCardView.beginPlay()` then calls `onPlay`.

### Deliverables

1. **Introduce** something like `BattlePlayCommit` / `BattleCommitPresenter` (name bikeshed OK; keep it in app target near Battle):

   Suggested location: `Trinket/Features/Battle/Commit/BattlePlayCommit.swift` (new folder OK).

2. **API shape** (illustrative — match project style):

   ```swift
   struct BattlePlayCommitRequest: Equatable {
     let card: BattleCard
     let cast: CardActivationRequest
     // optional flags only for DEBUG perf scenarios already used by BattleView
   }

   enum BattlePlayCommit {
     @MainActor
     static func perform(
       _ request: BattlePlayCommitRequest,
       session: BattleSession,
       journey: JourneyProgressState,
       homestead: PlayerHomesteadState,
       castPresentation: BattleCastPresentationState
     ) -> Bool
   }
   ```

3. **Move** the body of `BattleView.playCard(_:request:)` into that owner so BattleView becomes a thin caller.

4. **Signposts:** wrap the whole commit in one interval, e.g. `BattleFramePacingSignposts.Name.cardCommit` (or add `PlayCommit` if needed), with nested existing intervals (chip publish/flush, cast) unchanged.

5. **DEBUG scenario hooks** currently inlined in `BattleView` (`playRealNoCast` / `playRealNoSwing`) must move into the commit owner so production and harness share one path. Do not break:

   - `play-real-no-cast`
   - `play-real-no-swing`
   - `play-real-no-feedback` (session flag `performanceSuppressFeedbackPresentation`)

6. **Document** the owner in a short section of `Docs/Platform/PerformanceInvestigationPlaybook.md` (“Play commit owner”) and one sentence in `Docs/Platform/Architecture.md` under Battle presentation.

### Explicit non-goals for #1

- No retained layers yet.
- No pooling changes yet.
- No reordering of feedback / swing / cast.
- No `withTransaction(disablesAnimations)` around the stack (already tried; noisy / regressive).

### Acceptance

- [ ] All production plays go through the commit owner (grep: no stray `castPresentation.append` + `commitAttackSwing` pairs outside it / DEBUG labs).
- [ ] `SmokeBattleTests` pass.
- [ ] Gate scenarios still runnable; `real-card-play` not regressed beyond noise (compare medians).
- [ ] Style / boundaries clean.

### Verify

```sh
./Scripts/verify-changed.sh --isolate --paths Trinket/Features/Battle/Commit Trinket/Features/Battle/BattleView.swift
TRINKET_PERFORMANCE_QUICK=1 TRINKET_ISOLATE=1 ./Scripts/test.sh performance \
  BattlePerformanceUITests/test03bRealCardPlay
```

---

## Phase #4 — Pooling + atlases (expand what chips already do)

### Goal

Make each commit ingredient **cheap when stacked**, not merely “60 alone,” by ensuring warm caches and avoiding first-use baking/decoding on the impact frame.

### Already done (do not undo)

- `CombatFeedbackRasterPool` + closed catalog prewarm via `BattlePresentationWarmup`
- `CardDissolveTexture` threshold bake cache + launch/battle prewarm
- `CardCastEffectsPrewarmView` with real `BattleAbilityCardFace` (not paper-only)
- Battle hand art pin via `PreparedArtworkCache.prepareAndPin`
- Optional invisible hand-lead cast prewarm in `BattleView`

### Deliverables

1. **Cast face snapshot pool (preferred next pooling win)**  
   - On hand appear / prewarm, rasterize each distinct hand ability face at cast size into a bounded `CGImage`/`UIImage` pool keyed by `(artworkName, width, height, displayScale, dynamicTypeSize)` as needed for parity.  
   - Cast dissolve path uses the snapshot **when present**, falling back to live `BattleAbilityCardFace` if missing (must look identical).  
   - Snapshot must include the same clip + card surface treatment players see (parity).  
   - Use `ImageRenderer` / UIGraphics carefully: bake **off the impact frame** (prewarm / hand appear), never sync-bake inside `BattlePlayCommit.perform`.

2. **Particle path**  
   - Keep particle **count / motion constants** from `TrinketMotion.Battle` / `CardCastEffectConfiguration`.  
   - Optionally pre-create `CardActivationParticle` templates per keyword set; do not change seed/noise look.  
   - Do not raise particle counts.

3. **Chip path**  
   - Audit cold `prepare` on commit (`CombatFeedbackChipBridge` miss compose).  
   - Extend catalog / pin set only for labels that appear on common Stage 1 plays if gaps remain.  
   - Do not shrink pool capacity without measuring eviction during `real-card-play`.

4. **Dissolve masks**  
   - Keep step-stable masks + face-only `compositingGroup` (particles outside).  
   - Ensure default noise key is fully `prepare()`’d before first non-cold-cast play.

5. **Prewarm orchestration**  
   - Centralize “imminent battle resources” in `BattlePresentationWarmup` (or commit-adjacent helper) so Stage Select → Battle and launch paths share one checklist: dissolve textures, chip catalog, cast face snapshots for expected hand art, chip host motion clock.

### Explicit non-goals for #4

- No lowering visual quality (mask resolution, particle count, chip font).
- No removing hand SwiftUI cards in favor of snapshots for the **hand** (snapshots are for cast overlay only unless parity is proven).

### Acceptance

- [ ] `play-cast-only` stays clean when warm.  
- [ ] `first-card-cast-cold` still measures cold texture policy (do not accidentally warm that scenario).  
- [ ] `real-card-play` median max-frame improves or holds; no UX change.  
- [ ] Unit coverage for pool keying / hit-miss if new pool types are added (mirror `CardDissolveTextureTests` / raster tests).

### Verify

```sh
TRINKET_PERFORMANCE_QUICK=1 TRINKET_ISOLATE=1 ./Scripts/test.sh performance \
  BattlePerformanceUITests/test03ePlayCastOnly \
  BattlePerformanceUITests/test03FirstCardCastCold \
  BattlePerformanceUITests/test03bRealCardPlay \
  BattlePerformanceUITests/test03dPlayFeedbackOnly
```

---

## Phase #5 — Sim vs present vs decorate (tighten seams)

### Goal

Keep `BattleEngine` / `BattleSession` authoritative for rules and outcomes, while **decoration** (chips, cast, swing, bursts, SFX) is explicitly “present” work invoked from the commit owner — not accidental side effects deep in unrelated session APIs.

### Current good patterns to extend

- `BattlePresentationState` projections for hand/combatants (fine-grained install).  
- `CombatFeedbackChipBridge` as incremental UIKit decoration.  
- `performanceSuppressFeedbackPresentation` for diagnostic isolation.

### Deliverables

1. **Classify APIs** in a short comment block or `Docs/Platform` note:

   | Layer | Examples | Rule |
   |---|---|---|
   | Sim | `BattleState.playCard`, session install | No SwiftUI, no chips/cast |
   | Present | `BattlePresentationState.install`, hand projections | State for UI; still no Canvas/Timeline |
   | Decorate | chips, cast, swing, bursts, SFX, haptics | Only via commit owner / explicit presenters |

2. **Ensure** `installBattleState` does not itself trigger cast/chip/swing. Feedback today is via `presentResolvedEvents` — keep that, but call graph should be: commit owner → session.playCard (sim+present+feedback decorate) → swing decorate → cast decorate.

3. **Avoid new observation bridges** from decorate back into sim.

4. **Harness / DEBUG** stack probes (`play-stack-*`) should call the same commit owner with flags, not fork a second stacking order.

5. **Boundary lint:** State must not import feature views (existing rule). Commit owner may live under Features/Battle and take session + cast state as inputs.

### Explicit non-goals for #5

- No rewriting `BattleEngine`.  
- No moving chip UIKit hosts into the package layer.

### Acceptance

- [ ] Grep shows cast append + swing only from commit owner (plus labs/playgrounds).  
- [ ] Stack diagnostic scenarios still match production ordering when all flags enabled.  
- [ ] Module boundary check passes.

---

## Phase #2 — Retained combat presentation island (Battle only)

### Goal

Move **impact-frame decoration** (cast dissolve + particles, and eventually attack telegraph if needed) onto a **retained** layer tree updated by property changes, while the rest of Battle chrome (toolbars, detail sheets, victory) stays SwiftUI.

Chips already use always-mounted UIKit hosts — treat that as the template.

### Architecture

```text
SwiftUI BattleView
  ├─ Battlefield / Hand / overlays (SwiftUI) — keep
  ├─ CombatFeedbackRasterUIView hosts — keep / extend
  └─ BattleCombatEffectsHost (new UIView/CALayer island)
        ├─ Cast layer(s): face texture + mask + particles
        └─ (optional later) attack telegraph layers
```

### Deliverables

1. **`BattleCombatEffectsHost`** (UIView) always mounted in the battle field coordinate space (same space as today’s cast lane).

2. **Cast migration (first slice):**  
   - Input: existing `CardActivationRequest` (or commit DTO).  
   - Drive dissolve progress from a display link / `CADisplayLink` owned by the host (or shared battle effects clock), matching `TrinketMotion.Battle.cardActivationDuration` and dissolve fraction.  
   - Face: prefer Phase #4 snapshot; mask: existing `CardDissolveTexture` images; particles: draw into a dedicated layer/`CALayer` or `UIView` backed by Core Animation — **same counts and curves**.  
   - Remove or bypass SwiftUI `CardCastEffectsLayer` TimelineView for production once parity is proven; keep SwiftUI path behind DEBUG or as fallback until then.

3. **Handoff parity:** cast still uses release center / tilt / scale / perspective from the request. No “spawn at hand resting pose.”

4. **Concurrency:** max concurrent casts remains `TrinketMotion.Battle.maxConcurrentCardCasts`.

5. **Do not** move the hand itself into the island in this phase.

6. **Perf harness:** `play-cast-only`, `play-cast-*` isolation, and `real-card-play` must exercise the production host path (launch args must not silently keep SwiftUI cast).

### Explicit non-goals for #2

- No SpriteKit scene for the whole battle.  
- No Metal required (Core Animation / CoreGraphics is enough unless proven otherwise).  
- No changing Ultimate cinematic pipeline.

### Acceptance

- [ ] Side-by-side visual check (or screenshot diff in DEBUG lab) vs pre-migration cast.  
- [ ] `play-cast-only` clean when warm.  
- [ ] `real-card-play` median hitch improved vs Phase #1/#4 baseline recorded in handoff notes.  
- [ ] Smoke battle + cast-related unit tests green.

### Rollback

Feature flag or compile-time DEBUG toggle to restore SwiftUI `CardCastPresentationLane` if parity fails.

---

## Phase #3 — Animation as property tracks (commit path only)

### Goal

Replace remaining **SwiftUI-driven** commit animations that still invalidate large subtrees with **explicit tracks** on the retained island / UIView hosts — without changing curves or durations.

### Scope (only after #2 cast island is stable)

1. **Cast progress track** — already a progress scalar in #2; ensure no SwiftUI `animation(_:value:)` on cast.  
2. **Attack wind-up / swing** — migrate combatant attack telegraph to the effects host or existing UIKit-friendly mechanism **only if** still on the impact-frame critical path after #2/#4. Preserve `TrinketMotion` timings.  
3. **Chip motion** — already CADisplayLink-ish via raster host; do not regress to SwiftUI chips.  
4. **Hand drag / reflow** — **out of scope** for property-track migration in this plan (SwiftUI hand stays; do not suppress sibling reflow).

### Deliverables

- Document which animations are tracks vs SwiftUI in the playbook.  
- Any migrated animation must have a before/after constant table (`TrinketMotion.Battle` values unchanged).

### Acceptance

- [ ] No intentional timing constant edits.  
- [ ] Gate scenarios + `SmokeBattleTests`.  
- [ ] Human visual pass on wind-up → play → swing → chips → dissolve.

---

## Cross-phase testing checklist

Copy into each phase PR / handoff:

### Functional

- [ ] Play a card from drag-armed pose (production gesture).  
- [ ] Play with forced-drag harness (`real-card-play`).  
- [ ] Unplayable drag deny still works.  
- [ ] Enemy/hero/companion chips appear on impact with SFX.  
- [ ] Attack wind-up during drag; swing on play; cancel on return.  
- [ ] Hand fan reflow still animates for siblings on play.  
- [ ] Ultimate / callout / victory paths untouched.

### Performance

- [ ] Record medians for `real-card-play`, `play-real-no-cast`, `play-real-no-feedback`, `play-stack-direct`, `play-cast-only`, `play-feedback-only`.  
- [ ] Cold cast scenario still honest (`first-card-cast-cold`).  
- [ ] Optional: `TRINKET_PERFORMANCE_REPETITIONS=5` before claiming a win.

### Commands

```sh
./Scripts/agent-context.sh --paths <touched files>
./Scripts/verify-changed.sh --isolate --paths <touched files>
TRINKET_ISOLATE=1 SKIP_GENERATE=1 ./Scripts/test.sh smoke SmokeBattleTests
# + performance gate list in §0.1
```

---

## Suggested sequencing calendar (guidance only)

| Phase | Relative effort | Depends on |
|---|---|---|
| #1 Commit owner | Small (1–2 focused sessions) | — |
| #4 Pooling | Medium | #1 helpful but not required |
| #5 Seam tightening | Small | #1 |
| #2 Retained cast island | Large | #1, #4 strongly recommended |
| #3 Property tracks | Medium | #2 |

Do **not** start #2 until #1 exists and #4 has cast-face snapshots warm on the battle path.

---

## Done definition for the whole migration

The migration is complete when:

1. Production play commit goes through one owner.  
2. Impact-frame cast (+ chips as today) run on retained hosts with warm pools.  
3. `real-card-play` median max-frame is consistently near other warm isolation scenarios (directionally toward single-frame budget), **without** UX guardrail violations.  
4. Playbook + Architecture docs describe the island and commit owner.  
5. SwiftUI remains the shell for Battle layout/chrome; no app-wide game engine.

---

## References (read before coding)

- `Docs/Platform/PerformanceInvestigationPlaybook.md` — matrix, guardrails, stacked-commit notes  
- `Docs/Platform/Architecture.md` — module ownership  
- `Trinket/Features/Battle/BattleView.swift` — current play commit  
- `Trinket/Features/Battle/Feedback/CombatFeedbackChipBridge.swift` — retained chip pattern to copy  
- `Trinket/Features/Battle/Effects/CardCastOverlay.swift` — cast/dissolve  
- `Trinket/Features/Battle/Effects/CardDissolveTexture.swift` — mask cache  
- `Trinket/Features/Battle/BattlePerformanceScenarioDriver*.swift` — isolation probes  
- `Packages/TrinketDesignSystem/.../TrinketMotion.swift` — timing constants (do not “tune” to cheat FPS)
