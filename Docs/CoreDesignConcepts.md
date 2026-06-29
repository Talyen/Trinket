# Core Design Concepts

This document captures Trinket's core product vocabulary and design direction. `AGENTS.md` should stay focused on agent workflow and durable implementation constraints; concept-level product decisions can live here.

## When To Read This

Read this before changing gameplay concepts, card/detail patterns, Keywords, Items, Heroes, Pets, Enemies, Abilities, Homestead, rewards, or progression.

## Game Shape

Trinket is a portrait-first fantasy idle auto-battler. The core loop centers on collecting and improving heroes, pets, abilities, items, and homestead upgrades while battles provide the moment-to-moment dashboard for progress and next actions.

The current battle path is:

```text
Play -> Battle -> Select Hero -> Select Pet -> Battle
```

Combat is idle by default. A Hero and Pet alternate abilities against a single Enemy.

The persistent tab bar is:

```text
Play -> Heroes -> Inventory -> Homestead -> Options
```

`Heroes` is the shared collection area for both Heroes and Pets, with an in-page switch between the two collections. `Inventory` is a top-level collection surface because Items are expected to become a core reward and equipment loop.

## Heroes

Heroes are primary player combatants. They are represented as identity-first 3:4 full-art cards with exact health, abilities, effects, and formulas available through detail views rather than crowded onto card art.

Hero detail views use native pushed navigation from the Heroes tab. The overview should stay scannable: large art, name, level/experience, health, and drill-ins for ability and item loadouts.

## Pets

Pets are companion combatants that fight alongside Heroes. They should feel like meaningful partners rather than passive stat bonuses.

Pet detail views use the same native pushed collection-detail pattern as Heroes.

## Enemies

Enemies are the focal target in the first battle slice. Expose important enemy mechanics through enemy detail views and readable descriptions instead of adding extra pre-battle steps before the strategy layer needs them.

Enemy detail views use the shared combatant detail pattern and can show active combat effects during battle.

## Abilities

Abilities are the main source of combat actions and Keywords. Keep Abilities as rows inside combatant details for now. Do not create standalone Ability card detail screens until abilities need independent inspection, upgrades, or collection behavior.

Heroes, Pets, and Enemies have Basic, Skill, and Ultimate Abilities. Hero and Pet collections can offer two choices per tier, with one Basic, one Skill, and one Ultimate selected into the active battle loadout before combat. Battles remain idle: Hero and Pet turns alternate, and the selected Basic, Skill, or Ultimate fires automatically based on that combatant's own turn cadence.

Implemented ability rules:

- `Physical`: direct damage.
- `Burn`: enemy damage-over-time.

## Items

Items are the umbrella concept for inventory objects, gear-like rewards, affixes, and bonuses. Items live in the top-level Inventory tab and can also appear through Hero/Pet item loadout flows.

Let players evaluate individual Items from clear item details. Avoid automatic "best for this hero" judgments unless later playtesting shows the inventory experience needs stronger guidance.

Item details should become a sibling detail pattern focused on affixes, bonuses, and readable tradeoffs.

Current item implementation is a visual-only stub. Inventory Items have a base type, a shared slot (`Weapon`, `Armor`, or `Trinket`), card-art placeholder styling, and up to four affix descriptions. Equipped Items do not affect combat stats or rules yet.

## Keywords

Keywords are the shared mechanic vocabulary across cards, abilities, enemies, items, affixes, and status effects. They should be player-facing fantasy terms, styled distinctly inline in descriptions, and backed by concrete rules only when those rules are implemented.

Every implemented Keyword has one universal visual identity. Its color and symbol should come from the centralized `Keyword.visualStyle` design token and be reused across inline descriptions, combat feedback, ability cards, item affixes, logs, and future detail surfaces. Do not introduce one-off Keyword colors in feature views.

Current Keywords:

- `Physical`: baseline weapon or body damage. Implemented as direct damage.
- `Burn`: fire damage over time. Implemented as independently stacking, enemy-only damage-over-time.

Early candidate Keywords:

- `Freeze`: action prevention or delay.
- `Stun`: short interruption or skipped action.
- `Block`: temporary damage prevention.
- `Armor`: durable physical mitigation.
- `Health`: survivability and restoration.
- `Gold`: currency for shops or upgrades.
- `Holy`: radiant or restorative power.
- `Poison`: toxic damage over time or weakening.
- `Bleed`: physical damage over time.
- `Leech`: damage that restores the user.
- `Nature`: growth, beasts, healing, roots, or wild magic.

Do not implement all Keywords at once. Introduce them through actual abilities, enemies, items, and affixes as the battle loop needs them.

## Cards And Details

3:4 full-art cards are the central representation for Heroes, Pets, Enemies, Abilities, and Items.

Keep cards identity-first. Avoid covering full-art cards with dense stats; put exact values and formulas in detail views.

Hero, Pet, and Enemy details should use an immersive hero header when curated art exists: the same 3:4 art becomes a full-bleed top background with overlaid identity content, while exact stats and choices remain in native detail sections below it. Focal points for this crop live in `Art/curated-assets.tsv` and are generated into `Trinket/Generated/ArtCatalog.generated.swift`. Combatant art should only map to the matching game entity name, not a near-synonym or temporary stand-in.

Heroes and Pets use native pushed collection details with drill-in Ability Loadout and Item Loadout screens. Enemies and battle-context combatant inspection can continue using sheets because those details are temporary battle-context views.

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
