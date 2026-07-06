# Roadmap

Loose product and polish ideas for iteration. **Not committed scope.**

Agents: read this for context and brainstorming. Do not implement items here unless the user explicitly asks to explore or build a specific entry (cite the `R-###` id). When an idea graduates into a durable decision, move the prose to `Docs/Design/CoreDesignConcepts.md` or `Docs/Architecture.md` and mark the item `shipped` or `parked` here.

**Status key:** `scratch` (unrefined) · `exploring` (active discussion) · `planned` (direction agreed) · `shipped` · `parked`

---

## Presentation & Motion

### R-001 — SwiftUI animation vocabulary
- **Area:** Cross-cutting
- **Status:** scratch
- **Idea:** Establish a shared motion language across the app: easing curves (accel/decel/duration), spring parameters (stiffness, damping, mass), named preset styles (e.g. bouncy), and scroll/drag friction with inertia. Centralize in `TrinketDesignSystem` so screens feel cohesive.
- **Touches:** `TrinketDesignSystem`, feature transitions, collection grids

### R-002 — Haptic feedback
- **Area:** Cross-cutting
- **Status:** scratch
- **Idea:** Add tactile feedback for high-signal moments — battle hits, stage completion, unlocks, homestead upgrades — using `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` with Reduce Motion respect.
- **Touches:** `TrinketDesignSystem`, battle UI, Play flow

### R-003 — Staggered content entrance
- **Area:** Cross-cutting
- **Status:** scratch
- **Idea:** Fade or slide lists and grids in with a short staggered delay (collection cards, stage rows, reward reveals) so screens feel alive without slowing navigation.
- **Touches:** `Trinket/Shared`, collection and Play map views

### R-004 — Metal shader effects on art
- **Area:** Cross-cutting
- **Status:** scratch
- **Idea:** Apply lightweight Metal/SwiftUI shader treatments to portrait art — shimmer on rare items, elemental tint pulses on keywords, subtle idle breathing — without replacing the underlying HEIC assets.
- **Touches:** `Trinket/Shared` card views, `ArtPipeline`

### R-005 — Parallax and device motion
- **Area:** Play, Battle
- **Status:** scratch
- **Idea:** Subtle parallax on chapter backgrounds and battle backdrops driven by device attitude (Core Motion), disabled when Reduce Motion is on.
- **Touches:** Play map, battle presentation layer

---

## Battle Presentation

### R-006 — Battle VFX layer
- **Area:** Battle
- **Status:** scratch
- **Idea:** Add a dedicated visual-effects pass for combat: keyword-colored particles (Burn, Freeze, etc.), card portrait motion on hit, attack lunge/recoil, and impact flashes. Keyword color should match existing `KeywordDescriptionText` / homestead tint vocabulary.
- **Touches:** `Trinket/Features/Battle`, `Trinket/BattleShell`, `SoundManifest`

### R-007 — Battle SFX layer
- **Area:** Battle
- **Status:** scratch
- **Idea:** Layer combat sound effects on top of the existing music director — ability casts, hits, blocks, status applies — keyed by damage type or keyword where practical.
- **Touches:** `SoundManifest`, `Trinket/Audio`, battle UI event hooks

### R-008 — Ability art callout in combat
- **Area:** Battle
- **Status:** scratch
- **Idea:** Briefly surface the casting combatant's ability art when an action fires so the player can see *which* ability triggered and *who* used it, without pausing the idle tick loop.
- **Touches:** battle action presentation, ability catalog art refs

### R-009 — Combined Hero + Pet portrait frame
- **Area:** Battle
- **Status:** scratch
- **Idea:** For team moments (e.g. paired ultimates), dynamically compose Hero and Pet portrait art into one double-width frame with a diagonal split — anime "team attack" framing — rather than two separate cards.
- **Touches:** battle layout, art composition pipeline

### R-010 — Looping idle combatant animations
- **Area:** Battle, Art
- **Status:** scratch
- **Idea:** Replace static battle portraits with short looping idle clips per Hero, Pet, and Enemy. Pipeline: generate with Veo (or similar), crop to combatant aspect ratio, loop on an end-frame hold. One loop per catalog entry.
- **Touches:** `ArtPipeline`, `Raw Assets/`, battle card views

### R-011 — Skill and Ultimate cinematics
- **Area:** Battle, Art
- **Status:** scratch
- **Idea:** Full-screen or flash-frame cinematics for Skills and Ultimates on Heroes and Pets (Omni Flash–style), plus shorter Skill animations for Enemies. Distinct from idle loops (R-010) — these play once per cast.
- **Touches:** `ArtPipeline`, battle presentation, ability event timing

---

## Progression & Game Modes

### R-012 — Chapter 2 content
- **Area:** Play, Content
- **Status:** scratch
- **Idea:** Author Chapter 2 with stages `2-1` through `2-10` — encounters, enemies, art, and chapter header — following the Chapter 1 journey pattern in `CoreDesignConcepts`.
- **Touches:** `ContentManifest/stages.tsv`, chapter art, Play map

### R-013 — Post-battle reward flow
- **Area:** Play, Battle
- **Status:** scratch
- **Idea:** Design and polish the victory moment: gold grant, item drop reveal, and return-to-map transition. Today rewards are stubbed; this item covers UX and persistence wiring for the full loop.
- **Touches:** `BattleVictorySummary`, `PlayFlowCoordinator`, inventory grants

### R-014 — Hero and Pet unlock flow
- **Area:** Heroes, Play
- **Status:** scratch
- **Idea:** Define how new Heroes and Pets enter the roster — stage milestones, shop purchases, event choices — including collection reveal UI and "new" badges.
- **Touches:** `PlayerCollectionState`, collection UI, stage rewards

### R-015 — Shop encounters
- **Area:** Play
- **Status:** scratch
- **Idea:** Replace Shop stage placeholders with a real shopping UI: browse authored offers, spend gold, leave with items or upgrades. Stage type already exists in the journey model.
- **Touches:** Play encounter routing, economy, `ContentManifest`

### R-016 — Mystery Events
- **Area:** Play
- **Status:** scratch
- **Idea:** Replace Event stage placeholders with branching mystery encounters — short narrative choices with varied outcomes (gold, items, buffs, risks).
- **Touches:** Play encounter routing, event content manifests

### R-017 — Homestead material drops
- **Area:** Homestead, Play
- **Status:** scratch
- **Idea:** Grant homestead crafting materials from battles and events, not only from homestead actions. Tie material types to chapter/theme and feed the existing homestead upgrade loop.
- **Touches:** `PlayerHomesteadState`, stage rewards, `adjustedMaterialRewards`

### R-018 — Talents system
- **Area:** Heroes, Pets
- **Status:** scratch
- **Idea:** Explore a talent tree or passive perk layer per Hero and possibly per Pet — choices that modify stats or ability behavior without new ability slots. Open question: shared tree shape vs. unique trees per combatant.
- **Touches:** `TrinketCore` progression, collection detail UI, battle stat resolution

### R-019 — Campfire Stage encounter
- **Area:** Play
- **Status:** scratch
- **Idea:** Design a rest-and-prepare encounter where the player can camp between battles. Mechanics TBD — could involve pet interactions, cooking food for buffs, crafting gear from gathered materials, or spending resources to restore the party. A low-stakes breather between harder stages.
- **Touches:** Play encounter routing, `ContentManifest`, inventory/crafting systems

### R-020 — Corruption Altar Stage encounter
- **Area:** Play
- **Status:** scratch
- **Idea:** An encounter centered on risk/reward item crafting. Players offer gear or materials at an altar to receive corrupted or upgraded versions — higher stats, random affixes, or tradeoffs (e.g. huge power with a curse). Mechanics TBD around pool, rarity shifts, and curse/boon balance.
- **Touches:** Play encounter routing, `ContentManifest`, item model, `PlayerCollectionState`

### R-021 — Alchemist's Shop & Potion Crafting
- **Area:** Play
- **Status:** scratch
- **Idea:** A shopping encounter variant focused on consumables. Players browse or mix potions from ingredient inventories — healing, temporary buffs, maybe one-use combat effects. Potion-mixing mechanics TBD (combine reagents for different outcomes, discover recipes, etc.).
- **Touches:** Play encounter routing, `ContentManifest`, consumable item model, economy

### R-022 — Alternate Game Modes
- **Area:** Play, Cross-cutting
- **Status:** scratch
- **Idea:** Expand beyond the chapter journey with secondary modes for variety and alt-progression. Candidates: a dungeon-crawl gauntlet (multi-stage run with persistent damage), a boss-rush mode, or a roguelite mode (procedural picks, permadeath, stacking buffs). Goal: give players a way to level or gear alternate heroes/pets without replaying the same chapters.
- **Touches:** `PlayFlowCoordinator`, `BattleSession`, mode selection UI, `TrinketCore` progression

---

## Art & Branding

### R-023 — App icon
- **Area:** Platform
- **Status:** shipped
- **Idea:** Design and ship a production app icon, exploring Icon Composer and/or external image tools (e.g. Nano Banana Pro). Must read at small sizes on the Home Screen.
- **Touches:** `Trinket/Assets.xcassets/AppIcon`, `Scripts/prepare-app-icon.sh`

### R-024 — Chapter art aspect ratio
- **Area:** Play, Art
- **Status:** scratch
- **Idea:** Evaluate cropping chapter hero art to 3:4 for consistency with combatant portrait cards and simpler layout math on the Play map header.
- **Touches:** chapter art in `ArtManifest`, Play map header

---

## Agent Workflows

### R-025 — Imagegen design spike workflow
- **Area:** Cross-cutting
- **Status:** scratch
- **Idea:** Document a repeatable agent workflow: generate a visual mock with imagegen, review with the user, then implement in SwiftUI against `TrinketDesign` — useful for screen-level redesign experiments without committing to the roadmap item list.
- **Touches:** `Docs/`, feature views under `Trinket/Features`
