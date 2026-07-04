# Core Design Concepts

This document captures Trinket's core product vocabulary and design direction. `AGENTS.md` should stay focused on agent workflow and durable implementation constraints; concept-level product decisions can live here.

## When To Read This

Read this before changing gameplay concepts, card/detail patterns, Keywords, Items, Heroes, Pets, Enemies, Abilities, Homestead, rewards, or progression.

## Game Shape

Trinket is a portrait-first fantasy idle auto-battler. The core loop centers on collecting and improving heroes, pets, abilities, items, and homestead upgrades while battles provide the moment-to-moment dashboard for progress and next actions.

The current play path is:

```text
Play -> Chapter Journey -> Battle or Encounter
```

Combat is idle by default. A Hero and Pet alternate abilities against a single Enemy.

The persistent tab bar is:

```text
Play -> Heroes -> Inventory -> Homestead -> Options
```

`Heroes` is the shared collection area for both Heroes and Pets, with an in-page switch between the two collections. `Inventory` is a top-level collection surface because Items are expected to become a core reward and equipment loop.

## Chapters And Stages

The core journey is chapter-scoped vertical progression. Chapter 1 is `The Verdant Forest`. The Play tab shows one chapter at a time, starting with immersive full-bleed chapter art that collapses into a compact pinned chapter header while the player scrolls through that chapter's stages. All stages in the current chapter are visible. Completed stages compress into history rows, the active stage is a large inline card with the primary encounter action, and future stages remain visible with real art/details but locked actions. The next chapter appears as a locked teaser after the current chapter's final stage; completed chapters can be browsed later as history but are not replayable in the current loop.

Each stage has a predefined encounter type: Battle, Event, Shop, or Rest. Battle stages launch the authored enemy. Event, Shop, and Rest stages can appear in the path before their full systems exist, using a placeholder completion action so the chapter never dead-ends.

The active stage action launches from the inline card: Battle starts combat; Event, Shop, and Rest run their placeholder completion action. Active stage cards can include a compact Hero/Pet picker for party swapping.

Stage completion advances persistent journey progress, grants stub rewards once, and returns to the journey. The journey should scroll the newly active stage into a comfortable reading position so the next action is obvious. End-of-chapter stages should connect forward into a locked next-chapter destination even before that chapter has authored content.

## Heroes

Heroes are primary player combatants. They are represented as identity-first 3:4 full-art cards with exact health, abilities, effects, and formulas available through detail views rather than crowded onto card art.

Hero detail views use native pushed navigation from the Heroes tab. The overview should stay scannable: large art, name, level/experience, health, and focused detail sections.

## Pets

Pets are companion combatants that fight alongside Heroes. They should feel like meaningful partners rather than passive stat bonuses.

Pet detail views use the same native pushed collection-detail pattern as Heroes.

## Enemies

Enemies are the focal target in the first battle slice. Expose important enemy mechanics through enemy detail views and readable descriptions.

Enemy detail views use the shared combatant detail pattern and can show active combat effects during battle.

## Abilities

Abilities are the main source of combat actions and Keywords. Keep Abilities as rows inside combatant details for now. Do not create standalone Ability card detail screens until abilities need independent inspection, upgrades, or collection behavior.

Heroes, Pets, and Enemies have Basic, Skill, and Ultimate Abilities. Battles remain idle on a shared tick clock. Each **step** advances the clock once, runs passive effects, and resolves **at most one** combatant action. When multiple combatants are due, the one who has been ready longest acts first; on ties, slower intervals act before faster ones, then Hero, Pet, Enemy. Party members due on the same tick therefore act on consecutive steps, not in parallel. The selected Basic, Skill, or Ultimate fires automatically based on that combatant's own action count cadence.

Default action intervals: Hero and Pet every 2 ticks; Enemy every 6 ticks. First action occurs on the tick equal to the combatant's interval. Burn, Poison, and Bleed ticks can fire on steps where nobody acts.

Implemented ability rules span the full `Effect` model (direct damage, Burn/Poison/Bleed, control meters, shields, mitigation, healing, leech, gold, cleanse). Ability copy uses player-facing descriptions such as `Deal 3 Freeze damage and applies Frozen.` without tick or action language. Status aliases (`Frozen`, `Stunned`, `Burning`, `Poisoned`, `Bleeding`) share keyword color and emphasis in `KeywordDescriptionText`.

### Burn, Poison, and Bleed

These three keywords share a pattern: when an ability pairs direct damage with a matching DoT, the initial hit uses `directDamage` and the status tracks ongoing decay at step start without duplicating the first hit. When only a DoT effect is used, potency is dealt immediately on apply, then decays per the rules below.

| Keyword | On apply | Each step-start tick | Stacking | Block / Armor |
|---|---|---|---|---|
| `Burn` | Deal potency (unless paired direct hit already dealt it) | Deal `floor(potency / 2)`, then set potency to that value | Merge into one stack per target | Respected |
| `Poison` | Deal potency (unless paired direct hit already dealt it) | Deal `potency - max(1, floor(potency × 0.25))`, then set potency to that value | Merge into one stack per target | Respected |
| `Bleed` | Deal potency (unless paired direct hit already dealt it) | Deal the same potency again; expire after 3 post-apply ticks | Separate instances per application (UI may consolidate) | Respected |

`Nature`, `Freeze`, and `Stun` are direct damage types. `Freeze`/`Stun` also build toward `Frozen`/`Stunned` control effects via `.controlMeter`; a full meter always consumes exactly one scheduled action regardless of damage amount.

Stun and Freeze control-meter buildup uses damage after mitigation and item reduction, but **before** shield absorption. A fully blocked hit still adds buildup from that post-mitigation amount — shields protect health, not control meters.

`Cleanse` removes active Burn, Poison, Bleed, or control-meter instances matching the cleansed keyword (or all debuffs when unspecified).

### Battle simulation architecture

Combat rules live in `Packages/BattleEngine/`. `BattleState.advanceOneStep()` is the single simulation entry point and follows this contract:

1. Increment `tickCount` and run effect ticks for all living combatants in order: enemy, hero, pet.
2. If the battle ended during effect ticks, emit defeat milestones and return `.ended`.
3. Otherwise pick the next ready actor (at most one acts per step) using roster scheduling rules.
4. Execute that actor's turn (or consume a pending control effect), append defeat milestones if needed, and return `.acted`, `.effectsOnly`, or `.ended`.

Effect application is handler-driven (`EffectHandlers.all`); handlers mutate through `BattleEngineContext`, not `BattleState` directly. The combat log is derived from the append-only `events` stream via `BattleLogReducer` — handlers do not write log lines. UI uses `BattleRun` (`@Observable`) in `Trinket/BattleShell/` as the presentation shell over `BattleState`; restarting a battle replaces `ActiveBattleConfiguration` (new `id`), which recreates `BattleView` and resets `BattleRun`.

Regression coverage: `BattleGoldenPathTests` in `BattleEngineTests` pins deterministic outcomes for fixed matchups with RNG seed `0` via `BattleStateTestFactory`.

## Items

Items are the umbrella concept for inventory objects, gear-like rewards, affixes, and bonuses. Items live in the top-level Inventory tab and can also appear through equipment or reward flows.

Let players evaluate individual Items from clear item details. Avoid automatic "best for this hero" judgments unless later playtesting shows the inventory experience needs stronger guidance.

Item details should become a sibling detail pattern focused on affixes, bonuses, and readable tradeoffs.

Inventory Items have a base type, a shared slot (`Weapon`, `Armor`, or `Trinket`), item art, and up to four affix descriptions. Items are generated at reward time from base item type, rarity, slot-specific affix pools, and base item Keyword Affinities. Basic items roll one or two affixes, weighted toward one. Astral items roll three or four affixes, weighted toward three, and resolve the same affix pool into stronger values. Rarity does not change a base item's Keyword Affinities.

Affixes are eligible when their slot matches the base item slot and at least one affix Keyword matches the base item's Keyword Affinities. Items cannot roll duplicate affix IDs, but multiple affixes can share the same Keyword. Affixes are positive-only. Item names stay as the base item name to keep inventory grids readable.

Equipped items apply keyword-wide combat modifiers and flat primary-stat bonuses at battle entry. Affix descriptions use plain language such as "Increases Bleed damage dealt by 1" or "Increases Agility by 2". Modifiers stack across affixes and items; stats from gear merge into effective primary stats for the battle while keyword bonuses apply at each relevant combat resolution.

## Keywords

Keywords are the shared mechanic vocabulary across cards, abilities, enemies, items, affixes, and status effects. They are player-facing fantasy terms, styled distinctly inline in descriptions, and backed by concrete rules.

Every Keyword has one universal visual identity. Its color and symbol come from `Keyword.visualStyle` and are reused across inline descriptions, combat feedback, ability cards, item affixes, logs, and detail surfaces. Do not introduce one-off Keyword colors in feature views.

All Keywords are defined in `Packages/TrinketCore/Sources/TrinketCore/GameEnums.swift`. Keyword colors and SF Symbols live in `Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Keyword+VisualStyle.swift` (`Keyword.visualStyle`). Mechanics are wired through the unified `Effect` model (`Packages/TrinketContent/Sources/TrinketContent/Ability.swift`).

### Damage Types (Keyword.category = .damageType)

Used as `damageKeyword` on abilities. Direct damage is applied as the ability's `directDamage` value.

| Keyword | Color | SF Symbol | Rules |
|---|---|---|---|
| `Physical` | orange | `bolt.fill` | Direct weapon or body damage. |
| `Burn` | red | `flame.fill` | Deals potency immediately, then decays by halving each step-start tick. Stacks merge. |
| `Poison` | dark green | `drop.triangle.fill` | Deals potency immediately, then decays by 25% (minimum 1) each step-start tick. Stacks merge. |
| `Bleed` | dark red | `drop.fill` | Deals potency immediately, then repeats the same damage for 3 step-start ticks. Each application is tracked separately. |
| `Holy` | pale gold | `sun.max.fill` | Radiant holy damage type. |
| `Nature` | emerald | `leaf.fill` | Nature damage type. |
| `Freeze` | light blue | `snowflake` | Freeze damage type. Also builds toward `Frozen` (one skipped action). |
| `Stun` | yellow | `bolt.fill` | Stun damage type. Also builds toward `Stunned` (one skipped action). |

Status aliases share parent keyword styling: `Frozen` (Freeze), `Stunned` (Stun), `Burning` (Burn), `Poisoned` (Poison), `Bleeding` (Bleed).

### Mitigation (Keyword.category = .mitigation)

| Keyword | Color | SF Symbol | Rules |
|---|---|---|---|
| `Block` | blue | `shield.fill` | Damage absorption shield layered on top of health via `.shield`. Absorbs incoming damage until buffer expires. |
| `Armor` | gray | `shield.lefthalf.filled` | Damage mitigation via `.mitigation`. Reduces incoming damage by a percentage. |

### Restoration (Keyword.category = .restoration)

| Keyword | Color | SF Symbol | Rules |
|---|---|---|---|
| `Health` | red | `heart.fill` | Instant health restoration via `.instantHeal`. Clamped to max health. |
| `Leech` | magenta | `drop.fill` | Ongoing buff via `.leech`: restores 10% of damage dealt (any source, including DoTs) for 6 ticks. Standard value: `Effect.standardLeechBuff`. |

### Resource (Keyword.category = .resource)

| Keyword | Color | SF Symbol | Rules |
|---|---|---|---|
| `Gold` | amber | `dollarsign.circle.fill` | Currency gain via `.resourceGain`. Increments `BattleState.gold` during battle and persists to `PlayerRosterState.gold` on victory (combined with stage rewards). |
| `Mana` | indigo | `star.fill` | Magical energy used to power abilities. Tracked per-combatant via `CombatantRuntime.currentMana`. Restored via `.resourceGain(.mana, ...)`. |

### Effect Model

All keyword effects are represented by the `Effect` tagged union and applied through `TargetedEffect` (effect + target: ability target, actor, hero, pet, or enemy):

- `.burn(potency)` — deals potency immediately, then decays per Burn rules above
- `.poison(potency)` — deals potency immediately, then decays per Poison rules above
- `.bleed(potency)` — deals potency immediately, then ticks per Bleed rules above
- `.controlMeter(keyword, amount, threshold)` — tracks stun/freeze buildup; at threshold the target's next scheduled action is skipped; not reduced by passive tick decay
- `.shield(keyword, buffer, durationTicks)` — absorbs `buffer` damage before health
- `.mitigation(keyword, percent, durationTicks)` — reduces incoming damage by `percent`
- `.instantHeal(keyword, amount)` — immediately restores `amount` health (clamped to max)
- `.leech(keyword, percent, durationTicks)` — ongoing buff; restores `percent * damage dealt` to the source combatant for `durationTicks` (standard: 10% for 6 ticks)
- `.dealDamage(keyword, amount)` — typed direct damage hit
- `.cleanseRandom` — removes one random debuff (Burn, Poison, Bleed, Stun, Freeze)
- `.halveMitigation(keyword)` — halves existing mitigation % on the target
- `.resourceGain(keyword, amount)` — immediately adds `amount` of the resource identified by `keyword` (`.gold` → gold, `.mana` → mana)
- `.cleanse(keyword?, durationTicks)` — removes active effects matching `keyword` (or all if nil) for `durationTicks`

Abilities declare `targetedEffects: [TargetedEffect]` (or bare `effects` with default targeting). The `BattleState` applies instant effects immediately and tracks duration-based effects as `ActiveEffect` instances on the resolved target combatant.

## Cards And Details

3:4 full-art cards are the central representation for Heroes, Pets, Enemies, Abilities, and Items.

Keep cards identity-first. Avoid covering full-art cards with dense stats; put exact values and formulas in detail views.

Hero, Pet, and Enemy details should use an immersive hero header when curated art exists: the same 3:4 art becomes a full-bleed top background with overlaid identity content, while exact stats and choices remain in native detail sections below it. Focal points for this crop live in `ArtManifest/curated-assets.tsv` and are generated into `Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift`. Combatant art should only map to the matching game entity name, not a near-synonym or temporary stand-in.

Heroes and Pets use native pushed collection details. Enemies and battle-context combatant inspection can continue using sheets because those details are temporary battle-context views.

## Battle Screen

Treat Battle as the living moment-to-moment dashboard for combat, progress, goals, and useful next actions while preserving the top-level `TabView` as global navigation. The Battle screen should not replace or fight the app's core bottom-tab navigation.

Rare battle actions such as pause, battle details, and retreat should live in native Battle-screen chrome such as a trailing toolbar `Menu`, not in the persistent bottom tab bar.

Battle UI should stay focused on Enemy, Hero, and Pet cards with health bars. Names, HP text, abilities, effects, and logs can appear through native sheets.

Combat feedback should use a queued SwiftUI event overlay with stable event IDs, damage-type styling, icons, and Reduce Motion support.

Health bars should use custom animated SwiftUI bars for game combat so damage and healing can show smooth fill/trail feedback while exact HP remains available in accessibility and detail views.

## Homestead

Homestead is the base-building layer. Keep the presentation open-ended and prefer card-friendly, asset-light concepts until the game proves it needs a richer map or base visualization.

Eventually, Homestead should support long-lived upgrades and player goals that connect back to battles without overwhelming the first-session experience.

## Progression And Pacing

Eventually provide an opinionated next-action system that routes the player to the most useful current task instead of making them hunt through tabs.

Show simple fantasy explanations first, then formulas and exact mechanics on demand.

Reserve haptics and larger animations for meaningful milestones, combat outcomes, upgrades, unlocks, and important state changes.

Delay new systems until they improve the first-session experience; prefer elegance and clarity over early breadth.
