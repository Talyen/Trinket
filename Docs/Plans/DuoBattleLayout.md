---
type: execution-plan
status: active
created: 2026-11-03
updated: 2026-11-03
expires: 2026-11-17
---

# Duo battle layout: larger combatants without changing working phone layouts

## Objective and boundaries

Improve the expanded portrait Duo battle composition in the user's screenshot:
larger enemy, hero, and companion frames at their existing aspect ratios, with a
less dominant hand. Preserve normal iPhone composition and other layouts already
judged correct. Investigation and this plan are complete; gameplay/layout changes
have not been implemented or authorized by this planning request.

Follow the [standing workflow](../../AGENTS.md#route-and-read) and
[verification policy](../Platform/Verification.md). Keep this plan active for
implementation, then fold accepted requirements into the package owner and delete
it. Retain it intentionally with `--keep-plan` for the planning-only handoff.

Non-negotiable constraints:

- Preserve the enemy-above-party arrangement, native safe areas, combatant artwork
  crops, prepared artwork, and feedback. Enemy frames remain 4:3; party frames
  and ability cards remain 3:4. Never stretch artwork or frames.
- Preserve compact phone metrics, hand position, and interaction exactly; do not
  globally remove the combatant scale or reduce hand cards across expanded layouts.
- Ability cards remain artwork-only. The user explicitly approved bottom cropping
  of the resting hand in the affected Duo layout, using the same amount as normal
  iPhone layouts. Reuse the existing phone positioning calculation: lower cards
  by `cardHeight * 0.20` with the existing 30-point bottom rise and fan offsets.
  Do not invent a Duo crop percentage or flatten card proportions. Keep horizontal
  bounds, inspection, and held/cast artwork usable; normal iPhone framing stays
  unchanged. This approval supersedes this plan's earlier full-hand constraint.
- Follow [PD-033](../Product/Decisions.md) and the
  [battle package contract](../../Packages/TrinketBattleFeature/README.md): adapt
  to actual available geometry rather than introducing a device-name layout.
- Preserve manual play, inspection, Auto Battle, automatic casts, and resize
  cancellation. No battle rules, saves, new dependencies, or new panels.

## Evidence and findings

Investigated local main `9958f546d9c57809f9a5c3a8e2b08ef58fde101e` on
2026-11-03. Evidence consists of the attached 2007×2853-pixel screenshot, source
review, and a Python arithmetic model of the current formulas. This is not an
executed Swift test or a fresh simulator capture. No current Duo safe-area/window
measurement or rendered comparison has been obtained.

### Why this composition is small

1. [BattleFieldLane](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/BattleView.swift)
   passes its available canvas into separate hand and grid calculations.
   [BattlefieldView](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Battlefield/BattlefieldView.swift)
   top-aligns one landscape enemy above two portrait party members.
2. [BattleCardGridLayout](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Layout/BattleCardGridLayout.swift)
   makes the enemy width equal the combined party-row width. With 12-point gaps,
   a row of width R needs approximately `17R/12 + 4` points of total height.
   The screenshot is consistent with height limiting the group; unused side
   space cannot be filled without reclaiming height or changing the arrangement.
3. After fitting the entire group, the grid multiplies row width by 0.90.
   On height-limited expanded canvases this also leaves approximately 10% of
   field height as clearance above the hand. Setting it to 1 globally is unsafe:
   the fully fitted party would reach the earliest resting card top when that
   bound controls the field. Replace implicit clearance explicitly only in the
   affected layout, rather than spending it all.
4. [BattleHandLayout](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/Layout/BattleHandLayout.swift)
   already has a distinct `width <= 500` compact path. Expanded canvases cap hand
   cards at 220 points wide and reserve up to 42% of portrait height or 36% of
   landscape height, subject to the cap. The field is then bounded by the actual
   rotated three-card fan top. Reducing only the reserved percentage has no effect
   where the card cap still controls sizing; the reserved frame and fitted card
   size must agree.
5. The difference from normal iPhone is explicit, not an artwork limitation.
   `BattleHandLayout.restingCenter` and
   [BattleAbilityCardView.restingTranslation](../../Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Features/BattleAbilityCardView.swift)
   both add `cardHeight * restingPhoneYFraction` only at widths <= 500, where
   `restingPhoneYFraction` is 0.20. Expanded canvases omit it. Commit
   `2222fe41b89956195afbbc8e93d10237cccf8889` restored the old phone framing behind
   this condition while retaining the expanded full-fan fit. Reuse that phone
   calculation in the affected composition, not the phone's fixed 224-point frame
   or its entire sizing branch. The actual visible crop depends on rotation, the
   30-point bottom rise, and native insets; the 20% value is a lowering offset,
   not a claim that exactly 20% of the image is hidden.
6. The existing hand fit already calculates rotated bounds. Reuse it; do not
   duplicate an approximate fan rectangle or add an independent positioning layer.

### Numerical exploration, not a promised result

Dividing the screenshot by an assumed 3× display scale yields 669×951 points for
the full image, not the battle canvas. An inferred 669×869-point canvas produces
an enemy approximately 342 points wide, consistent with the visible approximately
1024-pixel frame. This supports the hypothesis but does not establish the true
display scale, native insets, or current app revision. Measure them before tuning.

| Input canvas | Current enemy width | Current party width each | Current hand-card width | Party-to-fan gap |
| --- | ---: | ---: | ---: | ---: |
| 393×740, archived compact fixture | 353.70 | 170.85 | 176.85 | 15.36 |
| 430×839, additional compact sample | 387.00 | 187.50 | 193.50 | 48.39 |
| 669×869, inferred screenshot canvas | 341.83 | 164.92 | 220.00 | 53.81 |
| 669×951, existing expanded fixture | 393.93 | 190.96 | 220.00 | 62.01 |
| 618×422, existing wide Duo fixture | 167.77 | 77.88 | 92.94 | 26.41 |
| 744×1000, existing expanded fixture | 425.06 | 206.53 | 220.00 | 66.91 |

At the inferred canvas, retaining 220-point-wide hand cards and applying the
existing phone lowering rule adds 58.67 points to the resting hand's Y position.
This makes room without making the artwork smaller. The revised candidates are:

| Candidate | Enemy width | Party width each | Gain in enemy width | Party-to-fan gap |
| --- | ---: | ---: | ---: | ---: |
| Existing composition | 341.83 | 164.92 | — | 53.81 |
| Phone lowering, original 0.90 scale | 379.10 | 183.55 | 10.9% | 59.67 |
| Phone lowering, fitted with explicit clearance | 409.93 | 198.97 | 19.9% | 16.00 |

The user selected the existing phone lowering amount; the 16-point clearance is
still only a prototype value. First inspect phone lowering with the original
combatant scale, then compare explicit clearance if more combatant space is useful.
Keep hand card size unchanged in these candidates. Do not shrink cards as the
default solution. The modeled 10.9–19.9% gains are not rendered results or promises.

The task retains `user-baseline.png`, `model.py`, and `model-results.json` under
`.DerivedData/Deliverables/duo-battle-layout/`. Local landing preserves these in
Git's shared `trinket-evidence/codex/duo-battle-layout-plan/` snapshots with the
task report. The model records source hashes and cross-checks the three archived
393×740 size values; its results remain arithmetic evidence only. The subsequent
crop calculation and source hashes are retained as `crop-model.py` and
`crop-model-results.json` in this follow-up task's
`.DerivedData/Deliverables/duo-hand-crop-plan/`, preserved under shared evidence
for `codex/duo-hand-crop-plan`. The earlier model predates crop approval.

### Existing protection and gaps

[BattleHandLayoutTests](../../Packages/TrinketBattleFeature/Tests/TrinketBattleFeatureTests/BattleHandLayoutTests.swift)
locks the 393×740 phone composition, expanded resource-bar separation, bounded
rotated artwork, aspect ratio, and held-card release bounds beside either sidebar.
It does not assert that already-correct expanded frame sizes remain unchanged,
nor distinguish full screen dimensions from the actual safe-area battle canvas.
Its full-bottom-containment expectation currently applies to every expanded
fixture. Keep that expectation for protected unchanged layouts; add an explicit
allowed bottom overflow for the affected composition using the existing phone
positioning rule. Preserve horizontal containment and party resource-bar clearance.
The compact-to-expanded branch also changes sharply around width 500; retain
boundary coverage rather than moving that threshold to solve this screenshot.

[DuoRotationUITests](../../TrinketUITests/Profiles/DuoRotationUITests.swift)
checks actual app orientation, retained hand identities, usable controls, and card
play. It does not assert combatant size or aesthetic acceptance. The
[Duo qualification owner](../Platform/PlayerCoverage.md#duo-visual-qualification)
requires active-display captures and actual window dimensions; an orientation
command alone is insufficient evidence.

## Implementation plan

- [x] Trace layout ownership, current compact protection, expanded sizing, and
  consumers; quantify candidate changes without editing runtime code.
- [ ] Establish matching shipping baselines. On the active Duo display, record
  full app-window size, BattleFieldLane's usable size and origin, safe-area insets,
  display scale, OS/build revision, pose, hand count, and actual frame bounds.
  Record correct normal iPhone and iPad/wide-window comparisons in the same battle
  state. Use temporary diagnostics, without introducing permanent runtime logging.
- [ ] Define a narrow geometry eligibility rule from those captures: the affected
  mid-width portrait canvas must be height-limited with excessive fan/field
  imbalance. Keep `width <= 500`, landscape, and protected expanded baselines on
  their original formulas. Do not use `width > 500` alone or a hard-coded Duo
  device/screen size. Sweep the proposed boundaries for jumps and bars moving sides.
  If an already-correct protected window has identical geometry, geometry cannot
  distinguish it: document the conflict and obtain a product decision before
  broadening the affected set. No final predicate is established by this plan.
- [ ] Prototype the existing phone lowering rule at unchanged hand-card size and
  original combatant scale, then compare explicit clearance for larger combatants.
  Keep the shared enemy/party-row width and original aspect ratios. Compare actual
  renders at normal display size, including the normal phone reference; inspect hand
  recognition, hero/companion framing, health/mana visibility, boss lyrics, and busy
  hit/status feedback. Do not shrink the enemy independently in this pass.
- [ ] Implement the selected result inside the existing private layout owners.
  Keep the legacy path unchanged for every noneligible canvas. Pass resolved
  geometry consistently to grid fitting and the hand; use one result for manual
  drawing, held/release projection, automatic casts, and diagnostic previews.
  Resolve the existing 0.20 lowering fraction once for the layout and use it in
  both `restingCenter` and `restingTranslation`, rather than changing only the drawn
  offset. Recalculate the available field from the lowered fan top; check whether
  the older reserved-frame ceiling becomes the limiting bound. Clip only at the
  intended lower viewport edge, without cutting off lifted/cast overlays or
  introducing invisible interactive artwork beneath native controls.
  Avoid introducing a public layout API or persistent state for pure arithmetic.
- [ ] Extend consequential coverage in the existing layout tests: exact preserved
  compact values, unchanged protected expanded values, larger target frames at
  fixed ratios, phone-equivalent lowering, explicit resting clearance, horizontal
  rotated bounds, and permitted bottom overflow for supported hand counts. Keep
  full containment assertions for unchanged expanded layouts. Check eligibility
  edges and manual/automatic cast-origin agreement. Include actual measured canvas
  dimensions rather than only whole-screen sizes. Retain the current held-card
  constraints and rotate/resize journey; do not add a broad snapshot framework.
- [ ] Review shipping callers and diagnostics: `BattleFieldLane`, `BattleHandView`,
  `CardActivationRequest.restingRequest`, `AutomaticCardCastView`,
  `BattlePerformanceScenarioDriver`, and `BattleTransitionLabCanvas`. Update only
  consumers whose geometry contract changes. Preserve the existing resize path
  that cancels held input and hides stale cast coordinates.
- [ ] Verify the entire change under the standing policy. Use static handoff and
  existing hosted package/UI obligations. If a focused local compiled diagnostic
  is useful, select only `BattleHandLayoutTests` under the one-worker deadline and
  shared host admission. Use bounded shipping-UI inspection for matched images and
  tap, drag, inspection, Auto/automatic cast, and resize checks. Pending hosted
  results or unavailable display routing remain explicit evidence gaps.
- [ ] Update the battle package contract's blanket full-hand visibility clause
  with the approved phone-equivalent resting crop for the affected geometry,
  remove this temporary plan after implementation acceptance, review the complete
  diff, and follow protected local integration. Push/publication is separate.

## Acceptance and open evidence

- At the confirmed target canvas, all combatants become larger in both dimensions
  at their existing ratios, with a visible improvement over the matching baseline.
  Choose the actual gain from inspected candidates, not an arbitrary percentage.
- Normal iPhone metrics, hand position, artwork crops, and play behavior remain
  unchanged. Other protected correct layouts also retain their baseline metrics.
- The affected resting fan uses exactly the existing phone lowering calculation,
  including its 0.20 card-height fraction, bottom rise, and fan offsets. Only the
  bottom may crop at the viewport; horizontal artwork stays bounded. Inspection
  and lifted/cast artwork remain usable. Health/mana remain unobscured, and the
  explicit gap leaves room for existing feedback and reactions in real battle.
- Manual drawing and cast origins agree; folding/rotation/resizing cancels stale
  held input without duplicate plays or loss of battle/Auto state. Native actions
  remain usable and foreground respects the live safe area.
- Exact target safe-area geometry, the complete set of already-correct expanded
  baselines, the eligibility boundary, and the preferred rendered candidate remain
  open. These are implementation prerequisites, not grounds to change all devices.
