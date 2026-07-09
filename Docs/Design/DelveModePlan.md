# Wanderer's Labyrinth — Product Spec & UI/UX Plan

Design and product plan for an infinite, procedurally generated dungeon Mode inspired by Path of Exile’s Delve: cluster biomes, stacked cluster modifiers, target farming, and special finds. Expands roadmap **R-022** / **R-022c**. Implements the Modes teaser **Wanderer's Labyrinth** (does not invent a second labyrinth Mode).

**Status:** Phase 0 preferences **locked** (see §12). Design only — no implementation yet.  
**Complements:** `AspectsAndModesPlan.md` (Modes shell), `CoreDesignConcepts.md`, `AppVisualFoundation.md`, `AppleNativeGuidelines.md`.  
**Out of scope for this doc:** combat rule changes, PvP, real-time multiplayer, hand-authored full maps.

---

## 0. Locked decisions

| Decision | Locked choice | Notes |
|----------|---------------|-------|
| **Ship name** | **Wanderer's Labyrinth** | Modes row title; internal id `labyrinth` |
| **Modes slot** | Replace the locked Labyrinth teaser with this Mode | Same row; unlock when gated |
| **Fantasy vs Aspects** | Aspects = vertical affinity climb; Labyrinth = persistent infinite map with biome clusters + modifiers | Both reuse idle battles |
| **Map persistence** | **One persistent infinite map that grows forever** | Not session runs; save must chunk/stream clusters |
| **Map UX** | Portrait **vertical node graph** (clusters of 3–7 nodes) | Not a free-pan dig grid |
| **Combat** | Same Hero+Pet vs one Enemy idle battles | Mode = map gen + modifiers + rewards |
| **Modifier language** | **No umbrella player term** (no Echoes/Veins/Marks) | Show each modifier by its own title, like Item affixes |
| **Stamina** | **None in v1** | |
| **Failure** | **Endless retries** — defeat returns to map; retry the node or go elsewhere | PoE Delve-like; map never wiped by death |
| **Party** | Any Hero/Pet; no attunement gate | |
| **Unlock** | Chapter 1 complete **OR** Aspect Floor 5 (whichever first) | |
| **Threat ↔ bounty** | Threat modifiers always pair with a bounty bump | |
| **Special finds (v1)** | Wardens, Shops, Mysteries, Rest/Shrines, Events, Crafting altar | Full set |
| **Tone** | Quiet dread / gothic undercroft | |
| **Scaling** | Steady readable ramp | |
| **Curses** | No pure negative-only curses in v1 | Threat is risk/reward framed |
| **Intent (Q11)** | **Dropped for v1** | See §6.1 — does not fit a persistent map |

---

## 1. Player fantasy

> The Wanderer's Labyrinth does not reset when you fall. Stone corridors gather into **clusters**—pockets of heat, root, frost, or gold—each carrying named modifiers that change what you fight and what you find. Push deeper, farm the paths that feed your build, and return whenever you like. The map remembers.

### Why this Mode exists

| Need | How Labyrinth answers it |
|------|--------------------------|
| Infinite / replayable content after journey | Persistent procedural map + rising depth |
| Target farming (gear Keywords, materials) | Cluster modifiers + biome bias on drops/XP |
| Variety beyond Aspects’ linear floors | Branching clusters; shops, mysteries, bosses, shrines, events, craft altar |
| Alt-progression without chapter replay | Same reward families as Aspects/journey, depth-scaled |
| “Something special might be ahead” | Rare nodes and special modifiers |

### Differentiation matrix

| | Chapter Journey | Aspects | **Wanderer's Labyrinth** |
|--|-----------------|---------|--------------------------|
| Structure | Authored stages | Authored floors per Aspect | Procedural node map |
| Length | Finite chapter | 10 floors + Warden | Infinite depth (persistent) |
| Theme | Story / place | One affinity climb | Multi-biome clusters + named modifiers |
| Encounters | Battle / Shop / Rest / Event / Mystery | Mostly battle | All journey types + craft altar + special finds |
| Persistence | Stage clear | Highest floor | **Growing map** + deepest depth + discovery log |
| On defeat | Stage unchanged | Floor unchanged | **Retry node or leave**; map stays |
| Player goal | Advance story | Attune & climb | Explore, farm, chase rare finds |

---

## 2. Naming & vocabulary

### Mode title (locked)

**Wanderer's Labyrinth** — Modes list, nav title, hub hero.

### Vocabulary (locked)

| Concept | Player term | Internal / rules |
|---------|-------------|------------------|
| Mode | **Wanderer's Labyrinth** | `PlayMode.labyrinth` |
| Progress measure | **Depth** (Depth 1, 12, …) | `depth` |
| Map region | **Cluster** (optional in UI; biome title is primary) | `BiomeCluster` |
| Cluster theme | **Biome** poetic title (e.g. Cinder Galleries) | `BiomeID` + hidden Keyword bias |
| Cluster modifiers | **No umbrella word** — each shows its **title** only | `LabyrinthModifier` / catalog id |
| Map cell | **Node** (mostly invisible; cards use encounter names) | `LabyrinthNode` |
| Boss find | **Warden** | special node |
| Discovery log | **Atlas** (biomes + modifiers you've seen) | `LabyrinthAtlas` |
| Affinity (rules) | never say Keyword | bind to `Keyword` under the hood |
| Attempt / session | — | No “Run” in player copy; you **enter** / **continue** the Labyrinth |

### Modifier copy rule (important)

Mirror **Item affixes**: players never need a category noun.

- **Do:** glass chips labeled `Ash Tithe`, `Iron Pressure`, `Astral Seam`
- **Do:** detail sheet with the modifier’s title, epithet, and plain-language bullets
- **Don’t:** “This cluster has 3 Echoes” / “Veins active” / “Affix: …”
- **Don’t:** say Keyword in Modes UI (same rule as Aspects)

Header can simply list the chips under the biome title with no section label, or a quiet label like **Modifiers** only if layout needs a VoiceOver grouping — prefer **no label** when chips read clearly.

---

## 3. Product contract

| Surface | Role |
|---------|------|
| **Chapter Journey** | Primary narrative progress (unchanged). |
| **Modes** | Secondary destinations; Labyrinth is Mode #2 after Aspects. |
| **Aspects** | Affinity floor climbs (unchanged). |
| **Wanderer's Labyrinth** | Persistent infinite procedural delve. |
| **Player-facing language** | No “Keyword”, no “proc gen”, no “seed”, no umbrella modifier noun. Biome titles, modifier titles, Depth. |

**Combat contract:** Normal idle auto-battles. Cluster modifiers change encounter selection, enemy scaling, and rewards before battle entry—not a new battle UI.

**Progression contract:** Clearing nodes grants XP, gold, Homestead materials, and modifier-biased items. Map state persists across launches.

**Economy contract (v1):** No unique Labyrinth currency. Optional later sink if atlas upgrades or shop rerolls need one.

---

## 4. Core loop

```text
Modes → Labyrinth Hub
  → Enter / Continue (party check)
  → Persistent map: choose a reachable node
  → Resolve (Battle / Elite / Warden / Shop / Rest / Mystery / Event / Craft / Gate)
  → On victory: rewards; reveal edges; map grows at the frontier
  → On defeat: back to map; same node still available; explore elsewhere
  → Leave anytime; map + progress saved
  → Hub / Atlas: deepest depth, discoveries
```

### Session shapes

| Shape | Description |
|-------|-------------|
| **Short visit** | Clear a few nodes, leave |
| **Deep push** | Follow gates downward; map extends |
| **Target farm** | Steer toward biomes/modifiers that match desired drops |
| **Retry wall** | Fail a hard node, gear up in Collection/Homestead, return and retry |
| **Idle-friendly** | Mid-battle restore unchanged |

---

## 5. Map & generation

### 5.1 Mental model

Portrait-first **directed node graph**, top→bottom descent, grouped into **clusters**. Not a panable PoE dig grid.

```text
        [Entrance]
            |
      ┌─────┴─────┐
   Cluster A    (side spur)
   (3–5 nodes)     |
      │         rare shop
      └────┬──────┘
        Cluster B
        (Ash Tithe · Iron Pressure)
            |
         Depth gate
            |
        Cluster C …   ← generated as frontier expands
```

- Show **current cluster** fully + peek at adjacent entrances.
- Fog deeper clusters until a Gate (or connecting path) is cleared.
- Vertical scroll; optional horizontal switcher between sibling branches.
- **Persistent:** cleared nodes, fog state, and unexplored frontier remain across sessions.

### 5.2 Clusters & biomes

| Field | Purpose |
|-------|---------|
| `biomeID` | Poetic place (e.g. **Cinder Galleries**) |
| `keywordBias` | Hidden Keyword(s) for enemy/loot weighting |
| `modifiers` | 1–3 named modifiers rolled for this cluster |
| `depthBand` | Difficulty + reward tier |
| `nodes` | 3–7 typed encounters |

**v1 biome set (illustrative):**

| Biome title | Bias | Fantasy |
|-------------|------|---------|
| Iron Galleries | Physical | Struck stone, brute foes |
| Cinder Galleries | Burn | Heat, ash wardens |
| Serpent Sump | Poison | Dripping roots |
| Scar Catacombs | Bleed | Old cuts in the rock |
| Aureate Crypt | Holy | Judging light |
| Wildroot Hollow | Nature | Living walls |
| Rime Descent | Freeze | Still cold |
| Storm Culvert | Stun | Sudden violence |
| Gilded Fault | Gold | Merchant-heavy; gold-leaning modifiers |
| Heartwell Grotto | Health / Rest-leaning | More Rest / heal finds |

Ship **6–8 combat biomes** in v1; resource/rest biomes as spice.

### 5.3 Cluster modifiers (no umbrella noun)

Modifiers are the Mode’s signature. They change **power, rewards, and finds**. Player sees **titles only**.

#### Categories (internal / design only — not player labels)

| Category | Promise | Examples |
|----------|---------|----------|
| **Threat** | Harder fights | Enemy HP/damage +X%; elite chance up |
| **Bounty** | More loot/XP | Gold +%, XP +%, item drop +% |
| **Affinity** | Target farm | Burn-leaning gear; Bleed affixes more common |
| **Encounter** | Map mix | +Shop / +Mystery / +Rest; suppress Rest |
| **Special** | Unique finds | Guaranteed Warden; Mystery; Astral-biased Merchant; Craft altar |

**Locked:** Threat always ships **paired** with a bounty bump (Q10A). No pure curses in v1 (Q15A).

#### Example modifier cards (player copy)

| Title | Epithet | Effects (summary) |
|-------|---------|-------------------|
| **Ash Tithe** | Heat takes its cut | Burn-biased enemies; Burn-affinity item rolls +; gold +10% |
| **Blood Market** | Every wound pays | Bleed threat up; Bleed gear bias; XP +15% |
| **Gilded Whisper** | Fortune in the dark | +Shop in cluster; gold drops +25% |
| **Warden’s Mark** | Something waits below | Guarantees a Warden at cluster exit |
| **Quiet Altar** | A choice in the stone | Guarantees a Mystery node |
| **Rootbound Hoard** | Nature keeps its gifts | Nature gear bias; materials + |
| **Iron Pressure** | The stone pushes back | Enemy power +20%; all rewards +20% |
| **Astral Seam** | Rarity cracks open | Astral item chance up on rewards |
| **Forge Vein** | The anvil answers | Guarantees or biases a Crafting Altar node |

UI: glass chips with **title only**; tap → detail (title, epithet, bullets). Max 3 per cluster.

### 5.4 Node types (v1 — all included)

| Node | Behavior | Notes |
|------|----------|-------|
| **Battle** | Standard idle battle | Biome pool + depth |
| **Elite** | Tougher battle | Higher rewards; Threat increases rate |
| **Warden** | Boss battle | Big item roll |
| **Shop** | Merchant visit | Existing shop; modifiers can bias shelf |
| **Rest / Shrine** | Heal / small boon | Instant heal crumb and/or minor gold/XP; shrine picker can expand later |
| **Mystery** | Narrative encounter | Existing pipeline |
| **Event** | Light choice | Placeholder → expand |
| **Crafting Altar** | Risk/reward craft beat | Align with roadmap R-020 fantasy; v1 can be a focused sheet that consumes/offers an item for a reroll or guaranteed affix — exact craft rules in a follow-on economy pass, but **node type ships in v1 map mix** |
| **Gate** | Depth transition | Reveals / generates next cluster band |

### 5.5 Generation rules (v1)

| Rule | Value |
|------|-------|
| World seed | Stable per-save `UInt64` (or derived from player id + salt); **deterministic** expansion |
| Expansion | Generate next cluster band when frontier Gate is cleared (or when player approaches fog) |
| Cluster size | 3–7 nodes |
| Branching | 2–3 exits from most non-terminal nodes; prefer DAG (no cycles) for clarity |
| Depth | +1 per Gate cleared |
| Modifier count | Depth 1–5: 1; 6–15: 1–2; 16+: 2–3 |
| Special rate | ~8–12% clusters get a Special modifier |
| Biome repeat | Avoid same biome twice in a row on a path |
| Power check | Soft “Deadly” badge when depth ≫ roster; no hard gate |

**Algorithm sketch:** depth band → biome → roll modifiers (Threat always with bounty) → place Gate / specials → fill nodes from weights → connect as layered DAG → **persist** new cluster into save.

### 5.6 Persistent map & save hygiene

Growing forever is the fantasy; unbounded graphs are the risk.

| Policy | Rule |
|--------|------|
| Canonical state | All generated clusters + node clear/fog flags in `PlayerLabyrinthState` |
| Chunking | Store by depth band / cluster id; load visible ±1 band in UI |
| CloudKit | Compact wire: ids, flags, seed, depth — not full enemy snapshots |
| Soft cap (engineering) | If graph exceeds N clusters, keep full frontier + summarize deep history as compressed “cleared depth” **without deleting reachable uncleared branches** the player can still path to |
| Corruption | Sanitizer drops unknown biome/modifier ids; never wipe the whole labyrinth for one bad row |

---

## 6. Party, failure, meta

### 6.1 Party

- Same Hero + Pet loadout as journey/Aspects.
- **No hard attunement** (locked).

### 6.1b What “Intent” was (Q11) — and why it’s dropped

**Intent** meant: at the start of a *session run*, pick a soft bias (Explore / Fortune / Conquest / Harvest) so the generator rolled more Mysteries, Shops, Elites, or affinity modifiers.

That fitted **disposable runs**. With a **persistent map**, the player already steers by choosing paths and reading modifier chips. A start-of-run Intent UI would be confusing (“intent for what?”) and fight the Delve fantasy.

**Locked for v1:** no Intent control. Farming = read the map and walk toward the right biomes/modifiers. Revisit later only if discovery feels too random.

### 6.2 Failure & leaving (locked — endless retries)

| Outcome | Map | Loot |
|---------|-----|------|
| Victory | Node cleared; edges open; rewards granted | Keep |
| Defeat | **Return to map**; node **remains uncleared** and retryable | No node reward; prior loot kept |
| Leave Labyrinth | Map saved as-is | Keep |
| Force-quit mid-battle | Resume battle | — |
| Force-quit on map | Resume map | — |

No run-end screen. No loot wipe. Optional light feedback: “The path holds. Try again or take another way.”

**First-clear rewards:** grant full rewards on first victory per node. **Retries after defeat** before first clear: full rewards on eventual clear. **Re-clearing an already cleared node:** not required in v1 (cleared nodes compress to history; no farm-by-spam). Side branches and deeper gates are the farm surface.

### 6.3 Persistent meta

| Meta | Purpose |
|------|---------|
| **Labyrinth map** | The growing graph itself |
| **Deepest Depth** | Hub record |
| **Atlas** | Biomes discovered; modifier titles seen; milestones |
| **Milestones** | One-time rewards at depth 5/10/25/50 |

### 6.4 Unlock pacing (locked)

| Gate | Unlocks |
|------|---------|
| Clear Journey Chapter 1 | Modes (existing) |
| Chapter 1 complete **OR** Aspect Floor 5 | **Wanderer's Labyrinth** |
| Reach Depth 10 | Atlas emphasis / badge (Atlas can exist earlier as empty) |

---

## 7. Rewards & farming

### 7.1 Per-node rewards

| Reward | Rule |
|--------|------|
| XP | Hero + Pet; depth + bounty modifiers |
| Gold | Depth + modifiers |
| Materials | Small; biome may bias type |
| Items | Elites / Wardens / some Mysteries / craft outcomes; Affinity modifiers pass `keywordBias` into `ItemGenerator` |

### 7.2 Target farming

1. Spot biome art + modifier chips that match the goal (e.g. Burn-leaning).
2. Path into those clusters.
3. Open modifier detail for plain-language confirmation.
4. On a wall: leave, upgrade party/gear, return and retry.

No separate farm-filter modal in v1.

### 7.3 Special finds (all in v1 mix)

| Find | Presentation |
|------|----------------|
| Warden | Boss node card |
| Mystery | Existing mystery sheet |
| Merchant | Shop visit |
| Rest / Shrine | Heal / boon sheet |
| Event | Choice sheet |
| Crafting Altar | Craft sheet (rules pass with R-020; node present in generator) |
| Astral Seam (modifier) | Higher rarity odds on cluster rewards |

---

## 8. UI/UX design

### 8.1 Information architecture

```text
Play tab (NavigationStack)
├─ Journey / Play entry (existing)
└─ ModesView
      ├─ AspectsHubView (existing)
      └─ LabyrinthHubView                 ← NEW (or map-first if active)
            ├─ LabyrinthMapView           ← primary persistent surface
            │     ├─ Node detail (sheet)
            │     ├─ Modifier detail (sheet)
            │     └─ Battle / Shop / Mystery / Rest / Event / Craft
            └─ AtlasView (push)
```

Battle source:

```text
source: .journey(...) | .aspect(...) | .labyrinth(nodeID)
```

### 8.2 Screen-by-screen

#### Screen A — Modes row

Unlock the existing Labyrinth row (no rename):

- Title: **Wanderer's Labyrinth**
- Subtitle: **An endless descent. Biomes, modifiers, finds.**
- Trailing: `Depth 14` if any
- Symbol: keep current labyrinth SF Symbol unless art pass says otherwise

#### Screen B — Hub (optional thin)

If the map is the product, Hub can be minimal:

1. Full-bleed quiet gothic atmosphere.
2. Title **Wanderer's Labyrinth**.
3. One line: “The path remembers. Descend when you are ready.”
4. Primary: **Enter** / **Continue**.
5. Secondary: **Atlas**.

Or **skip Hub** and open the map directly from Modes once unlocked — **recommendation: map-first after first enter**; Hub only for first-time orientation.

#### Screen C — Party gate (not “Start Run”)

Before map (or from map toolbar): party strip to confirm Hero/Pet. No Intent control. CTA: **Continue**.

#### Screen D — Map (core UX)

**Pinned header:**

- Depth N
- Current biome title + epithet
- Up to 3 **modifier title chips** (no section noun)

**Body:**

- Vertical layered **node cards**
- Cleared nodes compress to history rows
- Reachable uncleared nodes are large actionable cards
- Fogged deeper nodes: silhouette + “Clear a path to reveal”
- Cluster section headers use biome title; chips may repeat once at section start

**Node card:**

- Art / type symbol
- Encounter title
- Optional teaser (“Burn-leaning spoils”) when an affinity modifier is active
- **Enter** / **Fight** / **Visit** / **Retry** (if previously failed)

**Toolbar:** Leave Labyrinth, Atlas, Help. No run-abandon.

#### Screen E — Resolve & return

- Existing battle/shop/mystery shells; new craft sheet as needed.
- Victory → rewards → focus next reachable nodes.
- Defeat → map with failed node still actionable (subtle failed state, not locked).

#### Screen F — Atlas

- Biomes discovered
- Modifier titles discovered (listed by name — still no umbrella noun in chrome)
- Depth milestones
- Empty: “Places and powers you meet are recorded here.”

### 8.3 Motion

| Moment | Prefer | Avoid |
|--------|--------|-------|
| Modes → Map | `NavigationStack` push | Sheet stacks |
| Cluster reveal | Opacity + slight settle | Particle storms |
| Modifier chips | Staggered fade (≤3) | Infinite shimmer |
| Depth gate | Brief Depth count-up | Full-screen noise |
| Defeat return | Quiet settle to map | Game-over interstitial |

Tokens: `TrinketMotion.labyrinth.clusterReveal`, `.modifierIn`, `.depthFocus`, `.reduceMotion`.

### 8.4 Visual language

- Chrome via `TrinketDesign` only.
- Semantic background: `playJourney` or new `playLabyrinth` (neutral stone; biomes carry hue).
- Modifier chips: glass + Keyword tint from rules bias **without** saying Keyword.
- Quiet gothic tone; respect System/Light/Dark.

### 8.5 Accessibility

- `AccessibilityID.Labyrinth.*`
- Modifier meaning never color-only
- VoiceOver: Depth → Biome → modifier titles → reachable nodes

### 8.6 Deep links / tests

| Arg | Behavior |
|-----|----------|
| `-launch-screen labyrinth` | Hub or map |
| `-launch-screen labyrinth-map` | Seeded/persisted map |
| Smoke | Modes → Labyrinth → see reachable node |

---

## 9. Content & data model

```text
BiomeID / BiomeDefinition
LabyrinthModifierID / ModifierDef     // catalog; player sees title/epithet only
LabyrinthNodeType                     // battle, elite, warden, shop, rest, mystery, event, craft, gate
LabyrinthNode                         // id, type, enemyID?, rewards, edges, cleared, failCount?
BiomeCluster                          // biome, modifiers, nodes, depthBand
LabyrinthMapState                     // seed, deepestDepth, clusters[], frontier
LabyrinthAtlas                        // discovered biomes/modifiers, milestones
```

**Persistence:** `PlayerLabyrinthState` on `PlayerSaveStore` (e.g. `labyrinth`). Chunked clusters; sanitizer tolerant.

**Content:** `ContentManifest/labyrinth_biomes.tsv`, `labyrinth_modifiers.tsv` → `./Scripts/generate.sh`. Never hand-edit `Generated/`.

**Logic owners:** generator + modifier pure functions in packages; UI under `Trinket/Features/Play/Modes/Labyrinth/`; `AppState+Labyrinth.swift` orchestration.

---

## 10. Phased implementation

### Phase 0 — Design lock

- [x] Preferences answered (§12)
- [x] Name locked: Wanderer's Labyrinth
- [x] No umbrella modifier noun
- [x] Persistent map + endless retries
- [ ] Keep Roadmap / CoreDesignConcepts / Aspects plan wording aligned with locks
- [ ] Crafting Altar v1 rules spike (can be thin: consume gold → minor item bump) before Phase 3 ships craft nodes

### Phase 1 — Shell UI

- Unlock Modes row; Labyrinth map fixture; Atlas empty; a11y + smoke

### Phase 2 — Generator + persistence

- Seeded expanding DAG; modifier tables; map save/resume; chunking tests

### Phase 3 — Node wiring

- Battle/Shop/Mystery/Rest/Event/Craft/Gate; defeat→retry; first-clear rewards

### Phase 4 — Modifier depth

- Affinity bias, Threat+bounty pairing, special finds rates; economy vs Aspects

### Phase 5 — Polish

- Art, motion, milestones; gates/tests (toolchain permitting)

---

## 11. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Persistent map save bloat | Chunk by depth band; compact CloudKit wire; history compression policy |
| Affix soup | Max 3 chips; titles only; details on demand |
| Overlaps Aspects | Graph vs climb; no attunement |
| Craft altar scope | Ship node + thin v1 action; full R-020 later |
| Players stuck on Deadly nodes | Endless retry + leave to gear up; soft badge only |
| “Run” mental model leftover | Copy audit: Enter/Continue/Leave — never Run/Abandon |

---

## 12. Preference log (answered)

| # | Topic | Answer |
|---|-------|--------|
| Q1 | Name | **E — Wanderer's Labyrinth** |
| Q2 | Affix umbrella word | **None** — titles only, like Item affixes |
| Q3 | Map metaphor | **A — Vertical node descent** |
| Q4 | Failure | **Endless retries** (PoE Delve-like); not run-ending |
| Q5 | Persistence | **B — One persistent infinite map** |
| Q6 | vs Aspects | **A — Any party** |
| Q7 | Unlock | **A — Ch1 complete OR Aspect Floor 5** |
| Q8 | Stamina | **A — None** |
| Q9 | Special finds | **All** (Warden, Shop, Mystery, Rest/Shrine, Event, Craft altar) |
| Q10 | Threat↔bounty | **A — Always paired** |
| Q11 | Intent | **Clarified & dropped** — was a soft generator bias for session runs; irrelevant with persistent map steering |
| Q12 | Modes list | **A — Replace Labyrinth teaser with this Mode** (same name) |
| Q13 | Tone | **A — Quiet gothic** |
| Q14 | Scaling | **A — Steady ramp** |
| Q15 | Curses | **A — No pure curses in v1** |

---

## 13. Definition of done (v1)

1. Modes → Wanderer's Labyrinth → persistent map with ≥2 clusters over play.
2. Named modifiers visible (titles only) and affect rewards and/or encounter mix.
3. Defeat returns to map; node retryable; map not wiped.
4. Battle rules/UI unchanged; configuration source extended.
5. No player-facing “Keyword”, “proc gen”, or umbrella modifier noun.
6. Smoke: entry + one node; package tests: deterministic expand + persistence/chunking.
7. UI style + module boundary gates clean.

---

## 14. Implementation notes

- `ModesView`: unlock Labyrinth row; subtitle per §8.2A.
- `ActiveBattleConfiguration` source `.labyrinth(nodeID)`.
- `AppState` owns map + battle; local `NavigationPath` for atlas.
- Reuse Shop / Mystery / reward appliers; thin Craft altar until R-020 deepens.
- Toolchain: `check-ui-style.sh`; unit; smoke when Xcode 26 available.
