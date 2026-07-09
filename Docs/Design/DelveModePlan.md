# Delve Mode — Product Spec & UI/UX Plan

Design and product plan for an infinite, procedurally generated dungeon Mode inspired by Path of Exile’s Delve: cluster biomes, stacked affixes, target farming, and special finds. Expands roadmap **R-022** (Modes) and replaces the locked **Wanderer's Labyrinth** teaser with a concrete Mode fantasy.

**Status:** design lock / preference pass — no implementation yet.  
**Complements:** `AspectsAndModesPlan.md` (Modes shell), `CoreDesignConcepts.md` (journey + Keywords + Items), `AppVisualFoundation.md`, `AppleNativeGuidelines.md`.  
**Out of scope for this doc:** combat rule changes, PvP, real-time multiplayer, hand-authored full maps.

---

## 0. Executive recommendation (read first)

| Decision | Recommendation | Why |
|----------|----------------|-----|
| **Ship name** | **The Undercroft** (player-facing); internal id `undercroft` | Fantasy-native, not “Delve”/PoE-coded; fits Trinket’s poetic Mode naming (Aspects, Reliquary Gauntlet). |
| **Modes slot** | Replace **Wanderer's Labyrinth** teaser with this Mode | Same fantasy (branching rooms + run modifiers); avoid two labyrinth Modes. |
| **Fantasy vs Aspects** | Aspects = *vertical affinity climb*; Undercroft = *horizontal infinite map with biome affixes* | Clear product differentiation; both reuse idle battles. |
| **Run model** | **Session runs** with optional **persistent depth record** + **biome atlas** unlocks | Infinite feel without permanent map sprawl on disk; atlas gives long-term collection goals. |
| **Map UX** | Portrait **node graph** (clusters of 3–7 nodes), not a free-pan dig grid | Matches portrait-first idle game; readable one-handed; Apple-native list/graph hybrid. |
| **Combat** | Same Hero+Pet vs one Enemy idle battles | Mode rules = map gen + affixes + rewards; `BattleEngine` stays unaware of Modes. |
| **Affix language** | Player-facing **Veins** / **Echoes** (biome modifiers); never “Keyword” | Mirror Aspects copy rules. |
| **Stamina** | **No stamina in v1**; soft daily milestone bonuses only | Matches Aspects v1 simplicity; economy can add sinks later. |
| **Death** | **Run ends on defeat**; keep gold/items earned that run; lose unfinished path | Clear risk; still rewarding for idle sessions. |

Open preference questions (with defaults) are collected in **§12**. Answer those to lock Phase 0.

---

## 1. Player fantasy

> You descend into a living undercroft. The path is never the same. Biomes gather into **clusters**—pockets of stone, root, frost, or gold—each stamped with **Echoes** that change what you fight and what you find. Push deeper for power and loot, or steer toward the Echoes that feed your build.

### Why this Mode exists

| Need | How Undercroft answers it |
|------|---------------------------|
| Infinite / replayable content after journey | Procedural map + rising depth |
| Target farming (gear Keywords, materials) | Biome Echoes bias drops and XP |
| Variety beyond Aspects’ linear floors | Branching clusters, shops, mysteries, bosses |
| Alt-progression without chapter replay | Same reward families as Aspects/journey, depth-scaled |
| “Something special might be ahead” | Rare nodes: Wardens, Shrines, Merchants, Mysteries |

### Differentiation matrix

| | Chapter Journey | Aspects | **Undercroft (this Mode)** |
|--|-----------------|---------|----------------------------|
| Structure | Authored stages | Authored floors per Aspect | Procedural node map |
| Length | Finite chapter | 10 floors + Warden | Infinite depth (run-based) |
| Theme | Story / place | One affinity climb | Multi-biome clusters + Echoes |
| Encounters | Battle / Shop / Rest / Event / Mystery | Mostly battle | All journey types + special finds |
| Persistence | Stage clear | Highest floor | Depth record + atlas + run state |
| Player goal | Advance story | Attune & climb | Farm, explore, chase rare finds |

---

## 2. Naming options

Pick one **Mode title** (Modes list + nav) and keep short **vocabulary** consistent in UI.

### Recommended shortlist

| Rank | Name | Tone | Notes |
|------|------|------|-------|
| **1 (rec)** | **The Undercroft** | Quiet gothic fantasy | Distinct from PoE; works as place-name; “Enter the Undercroft”. |
| 2 | **Deepways** | Exploratory, soft | Good for path/node language (“a Deepways run”). |
| 3 | **Rootvault** | Nature-stone hybrid | Ties to Verdant Forest chapter fantasy. |
| 4 | **Echo Depths** | Affix-forward | Highlights Echoes; slightly abstract. |
| 5 | **Wanderer's Labyrinth** | Already on Modes teaser | Familiar in-repo; more maze than delve; keep if you want zero rename churn. |
| 6 | **Veinrun** | Punchy, modern | Short Modes row; less poetic than Aspects peers. |
| 7 | **Ashen Descent** | Dramatic | Strong; may feel Burn-biased. |
| 8 | **The Hollow Road** | Journey-like | Soft; less “infinite dungeon”. |
| 9 | **Night Delve** | Literal homage | Avoid unless you want PoE echo on purpose. |
| 10 | **Astral Undercroft** | Ties to Astral rarity | Risks colliding with **Astral Hunt** Mode teaser. |

### Vocabulary (recommended)

| Concept | Player term | Internal / rules |
|---------|-------------|------------------|
| Mode | **The Undercroft** | `PlayMode.undercroft` |
| One attempt | **Run** | `UndercroftRun` |
| Progress measure | **Depth** (Depth 1, 12, …) | `depth` |
| Map region | **Cluster** | `BiomeCluster` |
| Cluster theme | **Biome** (poetic title) | `BiomeID` + hidden Keyword bias |
| Cluster / node modifiers | **Echoes** | `UndercroftAffix` |
| Map cell | **Node** | `UndercroftNode` |
| Boss find | **Warden** | special node |
| Collection of seen biomes | **Atlas** | `UndercroftAtlas` |
| Affinity (rules) | never say Keyword | bind to `Keyword` under the hood |

**Alternate Echo synonyms to choose from:** Echoes (rec), Veins, Marks, Seals, Whispers.

---

## 3. Product contract

| Surface | Role |
|---------|------|
| **Chapter Journey** | Primary narrative progress (unchanged). |
| **Modes** | Secondary destinations; Undercroft is Mode #2 after Aspects. |
| **Aspects** | Affinity floor climbs (unchanged). |
| **Undercroft** | Infinite procedural delve with biome clusters and Echoes. |
| **Player-facing language** | No “Keyword”, no “proc gen”, no “seed” in UI. Use Biome titles, Echoes, Depth, Run. |

**Combat contract:** Normal idle auto-battles. Echoes modify *encounter selection, enemy scaling, and rewards* before battle entry—not a new battle UI.

**Progression contract:** Runs grant XP, gold, Homestead materials, and Echo-biased items. Journey completion gates unlock; Aspects and Undercroft are parallel alt-progression.

**Economy contract (v1):** No unique Undercroft currency. Optional later: **Glimmer** / **Undercroft Dust** for atlas upgrades or shop rerolls.

---

## 4. Core loop

```text
Modes → Undercroft Hub
  → Start Run (party + optional intent)
  → Map: choose next reachable node
  → Resolve node (Battle / Shop / Rest / Mystery / Event / Warden)
  → Collect rewards; Echoes on current cluster apply
  → Branch deeper or sideways into new clusters
  → Defeat ends run (keep loot) OR Retreat (keep loot, end run)
  → Hub: Depth record, Atlas, last-run summary
```

### Session shapes

| Shape | Description | Rec for v1 |
|-------|-------------|------------|
| **Short delve** | 5–12 nodes, one or two clusters | Primary expected session |
| **Deep push** | 20+ nodes until defeat | Supported; depth scaling handles it |
| **Target farm** | Steer toward Echoes matching desired Keyword / drop type | Supported via readable Echo chips + path choice |
| **Idle-friendly** | Start battle, leave app, return | Same as journey/Aspects battle restore |

---

## 5. Map & generation

### 5.1 Mental model (not a dig grid)

PoE Delve’s continuous cartograph is a poor fit for portrait idle play. **Recommendation:** a **directed acyclic node graph** laid out top→bottom (descent), grouped into **clusters**.

```text
        [Entrance]
            |
      ┌─────┴─────┐
   Cluster A    (side spur)
   (3–5 nodes)     |
      │         rare shop
      └────┬──────┘
        Cluster B
        (Echoes: …)
            |
         Depth gate
            |
        Cluster C …
```

- Player always sees **current cluster** fully, plus a **peek** at adjacent cluster entrances.
- Deeper clusters fog until the gate node is cleared.
- No free camera pan; vertical scroll + optional horizontal cluster switcher.

### 5.2 Clusters & biomes

Each **Cluster** has:

| Field | Purpose |
|-------|---------|
| `biomeID` | Poetic place (e.g. **Cinder Galleries**, **Verdant Sump**) |
| `keywordBias` | Hidden Keyword(s) for enemy/loot weighting |
| `echoes` | 1–3 Echoes rolled for this cluster |
| `depthBand` | Controls difficulty + reward tier |
| `nodes` | 3–7 nodes with typed encounters |

**v1 biome set (illustrative — poetic titles, Keyword under the hood):**

| Biome title | Bias | Fantasy |
|-------------|------|---------|
| Iron Galleries | Physical | Struck stone, brute foes |
| Cinder Galleries | Burn | Heat veins, ash wardens |
| Serpent Sump | Poison | Dripping roots |
| Scar Catacombs | Bleed | Old cuts in the rock |
| Aureate Crypt | Holy | Judging light |
| Wildroot Hollow | Nature | Living walls |
| Rime Descent | Freeze | Still cold |
| Storm Culvert | Stun | Sudden violence |
| Gilded Fault | Gold (resource) | Merchant-heavy, gold Echoes |
| Heartwell Grotto | Health / Rest-leaning | More Rest / heal finds |

Ship **6–8 combat biomes** in v1; add resource/rest biomes as spice.

### 5.3 Echoes (affixes)

Echoes are the Mode’s signature. They modify **power, rewards, and finds**.

#### Categories

| Category | Player promise | Examples (rules-facing) |
|----------|----------------|-------------------------|
| **Threat** | Harder fights, better payout | Enemy HP/damage +X%; elite chance up |
| **Bounty** | More loot/XP | Gold +%, XP +%, item drop chance +% |
| **Affinity** | Target farm | “Gear leans Burn”; “Bleed affixes more common” |
| **Encounter** | Map composition | +Shop chance; +Mystery; +Rest; suppress Rest |
| **Special** | Unique finds | Guaranteed Warden in cluster; Mystery guaranteed; Merchant with Astral bias |
| **Curse-lite** (optional v1.1) | Risk/reward | “No Rest in this cluster”; “Defeat loses 25% gold this run” |

**v1 recommendation:** Threat + Bounty + Affinity + Encounter + Special. Defer true curses until players understand Echoes.

#### Example Echo cards (player copy)

| Title | Epithet | Effects (summary) |
|-------|---------|-------------------|
| **Ash Tithe** | Heat takes its cut | Burn-biased enemies; Burn-affinity item rolls +; gold +10% |
| **Blood Market** | Every wound pays | Bleed threat up; Bleed gear bias; XP +15% |
| **Gilded Whisper** | Fortune in the dark | +Shop node in cluster; gold drops +25% |
| **Warden’s Mark** | Something waits below | Guarantees a Warden at cluster exit |
| **Quiet Altar** | A choice in the stone | Guarantees a Mystery node |
| **Rootbound Hoard** | Nature keeps its gifts | Nature gear bias; materials + |
| **Iron Pressure** | The stone pushes back | Enemy power +20%; all rewards +20% |
| **Astral Seam** | Rarity cracks open | Astral item chance up on rewards |

Echo UI: glass chip + title + one-line epithet; tap → detail sheet with plain-language bullets (no formula walls on the map).

### 5.4 Node types

Reuse journey encounter vocabulary where possible:

| Node | Behavior | Notes |
|------|----------|-------|
| **Battle** | Standard idle battle | Enemy picked from biome pool + depth |
| **Elite** | Tougher battle | Higher rewards; Threat Echoes increase rate |
| **Warden** | Boss battle | Cluster or depth-gate boss; big item roll |
| **Shop** | Merchant visit | Existing shop flow; Echoes can bias shelf |
| **Rest** | Heal / small boon | Run-scoped HP/mana restore if run wounds exist; else gold/XP crumb |
| **Mystery** | Narrative encounter | Existing mystery pipeline; recruit locked if already owned |
| **Event** | Light choice encounter | Can start as journey-style placeholder → expand |
| **Gate** | Depth transition | Short battle or automatic; reveals next cluster |

### 5.5 Generation rules (v1)

| Rule | Value |
|------|-------|
| Seed | Per-run `UInt64`; deterministic regenerate for resume |
| Cluster size | 3–7 nodes |
| Branching | 2–3 exits from most non-boss nodes; no cycles |
| Depth | +1 per Gate cleared (or per cluster — **rec: per Gate**) |
| Echo count | Depth 1–5: 1 Echo; 6–15: 1–2; 16+: 2–3 |
| Special find rate | ~8–12% clusters get Special Echo |
| Biome repeat | Avoid same biome twice in a row |
| Party power check | Soft: show “Deadly” badge when depth ≫ roster level; no hard gate |

**Algorithm sketch:** depth band → pick biome → roll Echo set from weighted tables → place mandatory Gate/Warden → fill remaining nodes from encounter weights modified by Encounter Echoes → connect as layered DAG.

---

## 6. Run rules & progression

### 6.1 Party

- Same Hero + Pet loadout as journey/Aspects.
- **No Aspect-style hard attunement** for v1 (Undercroft is the “any build” infinite Mode).
- Optional **Intent** at run start (soft bias, not a lock):

| Intent | Effect |
|--------|--------|
| **Explore** | Slightly more Mystery/Event |
| **Fortune** | Slightly more Shop / Gold Echoes |
| **Conquest** | Slightly more Elite/Warden |
| **Harvest** | Slightly more Affinity/Bounty Echoes |

**Recommendation:** Include Intent as a single segmented control on Start Run; default **Explore**.

### 6.2 Failure & retreat

| Outcome | Progress | Loot |
|---------|----------|------|
| Victory on node | Advance map | Grant node rewards |
| Defeat | **Run ends** | **Keep** gold/items/XP already granted |
| Retreat (toolbar) | Run ends | Keep earned; no penalty beyond ending path |
| Force-quit mid-battle | Resume battle (existing) | — |
| Force-quit on map | Resume run map | Persist `UndercroftRun` |

**Recommendation:** Do **not** wipe inventory on death. Risk is “lost depth / lost path”, not deleted gear—better for idle and CloudKit sync sanity.

### 6.3 Persistent meta (outside a run)

| Meta | Purpose |
|------|---------|
| **Deepest Depth** | Personal record (hub hero stat) |
| **Atlas** | Biomes discovered; Echoes seen; optional milestones |
| **Milestones** | One-time rewards at depth 5/10/25/50 |
| **Last run summary** | Depth reached, Echoes seen, best drop |

No permanent shared world map in v1 (avoids save bloat and UI complexity).

### 6.4 Unlock pacing (proposal)

| Gate | Unlocks |
|------|---------|
| Clear Journey Chapter 1 | Modes (existing) |
| Clear any Aspect Floor 5 **or** Journey Chapter 1 complete | **Undercroft** entry |
| Reach Undercroft Depth 10 | Atlas panel |
| Reach Depth 25 | Intent: Harvest / Conquest (if gated) |

**Recommendation:** Unlock Undercroft after **Chapter 1 complete** *or* **first Aspect Floor 5**—whichever comes first—so Modes players who skip Aspects still get it, and Aspects players get an early alternate.

---

## 7. Rewards & farming

### 7.1 Per-node rewards

| Reward | Rule |
|--------|------|
| XP | Hero + Pet; scaled by depth + Bounty Echoes |
| Gold | Scaled by depth + Echoes |
| Materials | Small; biome can bias type |
| Items | Elites / Wardens / some Mysteries; Affinity Echoes pass `keywordBias` into `ItemGenerator` |

### 7.2 Target farming (design goal)

Players should be able to say: “I need Burn gear” and **steer**:

1. Spot clusters with Burn-leaning biome art + Affinity Echo chips.
2. Prefer paths into those clusters.
3. Read Echo detail: “Burn-affinity item rolls increased”.
4. Optional Intent **Harvest** nudges Affinity Echo frequency.

Do **not** require a separate “farm filter” modal in v1—the map itself is the filter.

### 7.3 Special finds

| Find | Presentation | Reward fantasy |
|------|--------------|----------------|
| Warden | Full-bleed boss node card | Astral-leaning item + milestone FX |
| Mystery | Existing mystery sheet | Recruit / item / gold narrative |
| Merchant | Shop visit | Echo-biased shelf |
| Shrine (Rest+) | Short boon picker | Run buff (v1.1) or instant heal/gold (v1) |
| Astral Seam Echo | Cluster banner | Higher rarity odds |

---

## 8. UI/UX design

### 8.1 Information architecture

```text
Play tab (NavigationStack)
├─ Journey / Play entry (existing)
└─ ModesView
      ├─ AspectsHubView (existing)
      └─ UndercroftHubView                    ← NEW
            ├─ Start Run sheet / push
            ├─ UndercroftMapView (active run)
            │     ├─ Node detail (sheet)
            │     ├─ Echo detail (sheet)
            │     └─ Battle / Shop / Mystery (existing presentations)
            └─ AtlasView (push)
```

Battle presentation stays the existing Play ↔ `BattleView` swap via `ActiveBattleConfiguration` with a new source:

```text
source: .journey(...) | .aspect(...) | .undercroft(runID, nodeID)
```

### 8.2 Screen-by-screen

#### Screen A — Modes row

Replace locked **Wanderer's Labyrinth** with:

- Title: **The Undercroft** (or chosen name)
- Subtitle: **Descend forever. Biomes. Echoes. Finds.**
- Trailing: `Depth 14` record if any
- Symbol: `point.bottomleft.forward.to.point.topright.scurvepath` or `arrow.down.to.line.compact` (final pick in implementation)

#### Screen B — Undercroft Hub (one composition)

**First viewport (hero, not dashboard):**

1. Full-bleed undercroft atmosphere art (dark stone / root veins; Keyword accents only as particles, not chrome).
2. Mode title as hero signal.
3. One line: “Choose a path. Follow the Echoes.”
4. Primary CTA: **Enter** / **Continue Run** (if active).
5. Secondary text button: **Atlas**.

Below fold (scroll): Deepest Depth, last-run summary, short “How it works” disclosure—not a stat strip of six metrics.

**Avoid:** pill clusters of currencies, schedule snippets, multi-mode dashboards.

#### Screen C — Start Run

Sheet or push with:

1. Party strip (Hero/Pet) — reuse journey/Aspects picker patterns.
2. Intent segmented control (Explore / Fortune / Conquest / Harvest).
3. One sentence explaining Intent.
4. **Begin Descent** primary button.

#### Screen D — Map (core UX)

**Pinned header:**

- Depth N
- Current biome title + epithet
- Horizontal **Echo chips** (scroll if 3); tap → Echo detail

**Body:**

- Vertical scroll of **node cards** in layers (not a minimap grid).
- Completed nodes compress to history rows (journey pattern).
- Reachable next nodes are large actionable cards (enemy/shop art preview).
- Locked/fogged deeper nodes show silhouette + “Clear a path to reveal”.
- Cluster boundaries marked by a quiet section header (“Cinder Galleries”) + Echo chips repeated once.

**Node card content:**

- Leading art / SF symbol for type
- Title (enemy name or “Merchant’s Shop”)
- One reward teaser (“Burn-leaning spoils” if Affinity Echo active)
- Primary: **Enter** / **Fight** / **Visit**

**Toolbar:**

- Menu: Retreat from run, Atlas (disabled mid-run or read-only), Help
- No persistent skill bar; idle battle rules unchanged

#### Screen E — Node resolve & return

- Battle/Shop/Mystery use existing shells.
- On success: reward toast/sheet → map focuses next reachable nodes (`scrollPosition` + `.smooth`).
- On defeat: **Run Complete** summary → Hub.

#### Screen F — Atlas

Collection-like quiet list:

- Biomes discovered (art + epithet)
- Echoes catalogued (title + epithet)
- Depth milestones
- Empty state: “Echoes you meet are recorded here.”

### 8.3 Motion (2–3 intentional moments)

Align with Aspects motion vocabulary + Reduce Motion.

| Moment | Prefer | Avoid |
|--------|--------|-------|
| Hub → Map | `NavigationStack` push | Sheet-over-sheet stacks |
| Cluster reveal | Opacity + slight vertical settle | Particle storms |
| Echo chip appear | Staggered fade (max 3) | Infinite shimmer |
| Depth gate clear | Brief header Depth number count-up | Full-screen noise |
| Begin battle | Existing battle path | Custom zoom fighting battle overlay |

Tokens (when implementing): `TrinketMotion.undercroft.clusterReveal`, `.echoIn`, `.depthFocus`, `.reduceMotion`.

### 8.4 Visual language

- Chrome: `TrinketDesign` / `.trinketSurface` / `.trinketGlassChip` / `.trinketPrimaryActionButton`.
- Background mode: extend `playJourney` or add `playUndercroft` semantic background (neutral stone atmosphere; biomes carry hue).
- Echo chips: glass chip + biome/Keyword tint from `Keyword.visualStyle` **without** saying Keyword.
- Cards: identity-first; details in sheets.
- Appearance: respect System/Light/Dark; no forced dark-only Mode.

### 8.5 Accessibility

- `AccessibilityID.Undercroft.*` for hub, map, nodes, echoes, atlas, start CTA.
- Echo meaning never color-only (title + epithet + symbol).
- Dynamic Type via `trinketTypography`.
- Reduce Transparency / Reduce Motion via design-system fallbacks.
- VoiceOver order: Depth → Biome → Echoes → reachable nodes.

### 8.6 Deep links / UI tests

| Arg / id | Behavior |
|----------|----------|
| `-launch-screen undercroft` | Hub |
| `-launch-screen undercroft-map` | Active run map (seeded) |
| Smoke | Modes → Undercroft → Enter → see map node |

Prefer deep links over scrolling Play map.

---

## 9. Content & data model

### Domain (illustrative)

```text
BiomeID / BiomeDefinition          // title, epithet, keywordBias, artRef
UndercroftAffixID / AffixDef       // Echo catalog: category, weights, modifiers
UndercroftNodeType                 // battle, elite, warden, shop, rest, mystery, event, gate
UndercroftNode                     // id, type, enemyID?, rewards, edges
BiomeCluster                       // biome, echoes, nodes, depthBand
UndercroftRun                      // seed, depth, party snapshot, clusters, cursor, status
UndercroftAtlas                    // discovered biomes/echoes, deepestDepth, milestones
```

### Persistence

- New slice: `PlayerUndercroftState` (active run optional + atlas + records).
- SwiftData under `PlayerSaveGraph/`; access via `PlayerSaveStore` property `undercroft`.
- Sanitizer: drop unknown biome/affix IDs; clamp depth; invalidate corrupt graphs by clearing active run (keep atlas).

### Content pipeline

- Prefer `ContentManifest/undercroft_biomes.tsv`, `undercroft_echoes.tsv` (+ weights).
- `./Scripts/generate.sh` → generated catalogs.
- Do **not** hand-edit `Generated/`.

### Battle entry

- Build enemy + reward modifiers in `AppState` / run engine **before** creating `ActiveBattleConfiguration`.
- `BattleEngine` remains Mode-agnostic.

### Pure logic ownership

| Concern | Owner |
|---------|-------|
| Map generation | Package rules type (e.g. `UndercroftGenerator` in `TrinketContent` or small `TrinketCore` helper) |
| Echo application | Pure functions + unit tests |
| UI | `Trinket/Features/Play/Modes/Undercroft/` |
| Orchestration | `AppState+Undercroft.swift` |

---

## 10. Phased implementation

### Phase 0 — Design lock (this doc)

- [ ] Lock Mode name + Echo vocabulary
- [ ] Resolve §12 preference questions
- [ ] Update `Docs/Roadmap.md` R-022 / add R-022c
- [ ] Point Modes teaser copy at locked name
- [ ] One paragraph in `CoreDesignConcepts.md` Modes path

### Phase 1 — Shell UI

- Undercroft Hub + Modes row unlock/teaser swap
- Atlas empty state
- Accessibility IDs + smoke entry
- No real generator yet (static sample map fixture)

### Phase 2 — Generator + persistence

- Seeded DAG generator, Echo tables, run save/resume
- Package tests for determinism and sanitizer

### Phase 3 — Node wiring

- Battle/Shop/Mystery/Rest through existing pipelines
- Rewards + depth advance + defeat summary

### Phase 4 — Echo depth

- Affinity item bias, Threat scaling, Special finds
- Intent weights
- Economy pass vs Aspects/journey

### Phase 5 — Polish

- Art via ArtManifest, motion tokens, milestones, hub atmosphere
- `ci-gate.sh`; unit; smoke (toolchain permitting)

---

## 11. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Map UI feels like a strategy game | Node cards + journey compression; no free-pan grid |
| Affix soup overwhelms | Max 3 Echoes; chips + one-line epithets; details on demand |
| Overlaps Aspects | Different structure (graph vs climb); no hard attunement |
| Save size / CloudKit | Run graph capped (e.g. keep last N clusters); atlas is IDs only |
| Idle players hate run-ending deaths | Keep all earned loot; clear summary; easy restart |
| PoE clone perception | Poetic naming; Trinket encounter types; portrait node UX |
| Scope creep (curses, run buffs, currency) | Explicitly v1.1+ |

---

## 12. Preference questions (please answer)

Each item lists **options**, then **recommendation**. Reply with choices (e.g. `1B, 2A, 3C…`) or overrides.

### Q1 — Mode name
- **A.** The Undercroft *(rec)*
- **B.** Deepways
- **C.** Rootvault
- **D.** Echo Depths
- **E.** Keep **Wanderer's Labyrinth**
- **F.** Other: ___

### Q2 — Affix vocabulary
- **A.** Echoes *(rec)*
- **B.** Veins
- **C.** Marks
- **D.** Whispers

### Q3 — Map metaphor
- **A.** Vertical node descent (layered cards) *(rec)*
- **B.** Cluster hub wheel (pick next cluster, then linear nodes)
- **C.** Closer to PoE: panable grid (not recommended for portrait idle)

### Q4 — Run failure
- **A.** Defeat ends run; keep all earned loot *(rec)*
- **B.** Defeat ends run; lose gold earned this run only
- **C.** Roguelike wounds: HP carries between battles; defeat at 0
- **D.** Can retry the same node once per run

### Q5 — Persistence fantasy
- **A.** Session runs + Depth record + Atlas *(rec)*
- **B.** One persistent infinite map that grows forever
- **C.** Daily seeded map shared for all players (no online req—just date seed)

### Q6 — Relationship to Aspects
- **A.** Fully independent party (any Hero/Pet) *(rec)*
- **B.** Soft bonus if party matches cluster bias
- **C.** Hard attunement like Aspects for Affinity clusters only

### Q7 — Unlock
- **A.** Chapter 1 complete OR Aspect Floor 5 *(rec)*
- **B.** Chapter 1 complete only
- **C.** Aspect Floor 10 only
- **D.** Earlier (e.g. Journey Stage 5)

### Q8 — Stamina / limits
- **A.** None in v1 *(rec)*
- **B.** Soft daily bonus chest at Depth milestones
- **C.** Entry cost in gold/materials
- **D.** Limited “torch” resource that depletes with nodes

### Q9 — Special finds priority for v1
Rank or pick top 3:
- Warden bosses *(rec include)*
- Merchant shops *(rec include)*
- Mysteries *(rec include)*
- Rest/Shrines
- Events/choices
- Crafting altar (R-020 adjacent—defer)

### Q10 — Threat vs bounty coupling
- **A.** Threat Echoes always pair with bounty bump *(rec — PoE-like clarity)*
- **B.** Independent rolls (can get hard+poor or easy+rich)
- **C.** Player chooses to “empower” a cluster for more risk/reward

### Q11 — Intent at run start
- **A.** Yes, 4 intents *(rec)*
- **B.** No intents; pure map reading
- **C.** Intents unlock later via Atlas

### Q12 — Modes list treatment
- **A.** Replace Wanderer's Labyrinth teaser with this Mode *(rec)*
- **B.** Keep Labyrinth as separate future Mode; add Undercroft as fifth row
- **C.** Rename Labyrinth in place and implement this spec under that name

### Q13 — Tone
- **A.** Quiet dread / gothic undercroft *(rec)*
- **B.** Wonder / luminous caves
- **C.** Aggressive conquest / war tunnels

### Q14 — Depth scaling feel
- **A.** Steady ramp (readable power) *(rec)*
- **B.** Spiky difficulty with safe biomes mixed in
- **C.** Player-selected difficulty tier at run start

### Q15 — Should Echoes ever be negative-only curses in v1?
- **A.** No—threat is framed as risk/reward, not pure curse *(rec)*
- **B.** Yes—some clusters are nasty on purpose
- **C.** Opt-in “Fractured” runs with curses for bonus loot

---

## 13. Definition of done (v1)

1. Player can Modes → Undercroft → start a run → clear multiple nodes across ≥2 clusters.
2. Echoes are visible, readable, and affect rewards and/or encounter mix.
3. Defeat ends the run but keeps earned rewards; progress (depth/atlas) persists.
4. Battle UI/engine unchanged in rules; configuration source extended.
5. No player-facing “Keyword” / “proc gen” copy.
6. Smoke covers entry + one node; package tests cover generator determinism + persistence.
7. UI style + module boundary gates clean.

---

## 14. Open implementation notes (post–preference lock)

- Wire Modes teaser in `ModesView` to locked name/subtitle.
- Extend `ActiveBattleConfiguration` with `.undercroft`.
- Prefer local `NavigationPath` for hub/map; `AppState` owns active run + battle.
- Reuse Shop / Mystery / reward appliers; do not fork economy pipelines.
- When Xcode 26 toolchain is present: `check-ui-style.sh`, focused unit, `SmokePlayTests` expansion.
