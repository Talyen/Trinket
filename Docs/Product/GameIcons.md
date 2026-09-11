# Game icon selections

Rendering and library policy are owned by the
[design system](../../Packages/TrinketDesignSystem/Documentation/VisualRoles.md#game-icons).
These mappings cover symbolic game imagery; existing painted art remains primary.

## Keywords

The executable owner is `Keyword.visualStyle` in the design system. All colors
are unchanged except Thorns, which shares Physical's color.

| Meaning | Icon |
|---|---|
| Physical | Lucide `sword` |
| Thorns | SF `burst.fill` — spikes; no equally direct Lucide silhouette |
| Burn / Stun | Lucide `flame` / `zap` |
| Block / Health | Lucide `shield` / `heart` |
| Holy / Mana | Lucide `sun` / `moon-star` |
| Poison / Bleed / Leech | Lucide `flask-conical` / `droplet` / `pipette` |
| Freeze / Dodge | Lucide `snowflake` / `wind` |
| Purge / Cleanse | Lucide `shield-off` / `sparkles` |
| Death's Door | Lucide `hourglass` |
| Gold | Lucide `coins` |
| Beneficial / negative status | Lucide `arrow-big-up` / `arrow-big-down` |

Floating combat feedback has a separate SF Symbol mapping in
`CombatFeedbackChipPresentation.Style.feedbackIcon`, including a symbolic Gold
glyph. Filled silhouettes and dark outlines improve contrast over artwork;
numbers match their adjacent icon's keyword color. Its size and motion policy lives in
[BattleFeature](../../Packages/TrinketBattleFeature/README.md#uikit-feedback-island).

## Talents and Homestead nodes

The reviewable per-node mapping is the `icon_id` column beside each stable ID,
name, and description in [talents.tsv](../../ContentManifest/talents.tsv) and
[homestead_nodes.tsv](../../ContentManifest/homestead_nodes.tsv). The metadata
format is owned by the [manifest guide](../../ContentManifest/README.md).

Talent choices follow the named object first, then the described action, then
the keyword when no more specific motif fits. Pruning Touch uses `scissors`,
Shared Roots uses `trees`, Skullcracker uses `skull`, and Bounty Blade uses `sword`.
Heat/cold combinations use `sun-snow`. Druid branches use their named flora rather
than repeating a generic damage icon.

Talent icons may reuse a direct Lucide silhouette across multiple talents:
`bone` for bites/fangs/feeding, `droplet` for blood, `heart-pulse` for Leech
healing, `hammer` for crushing impacts, and `dog` for canine identity. Retained
SF talent selections are explicit `sf:` entries in the manifest: `burst.fill` for
spikes and explosive impacts, `figure.fall` for hamstring effects,
`theatermasks.fill` for feints/decoys, and `lock.shield.fill` for Sealed
Sarcophagus. These exceptions convey shapes or combinations absent from the
selected Lucide set. Locked talent rows still show the native UI lock.

## Other game imagery

| Surface or meaning | Lucide selection |
|---|---|
| Battle / Boss / Shop / Mystery | `swords` / `crown` / `store` / `sparkles` |
| Recruit Hero / Companion / Labyrinth entrance | `users-round` / `paw-print` / `door-open` |
| Hero / Companion / Enemy placeholder | `user-round` / `paw-print` / `skull` |
| Item / Ability placeholder | `package` / `wand-sparkles` |
| Campaign / Contract / Spire placeholder | `map` / `scroll-text` / `flag` |
| Party selection / Recruit reward | `users-round` / `user-round-plus` |
| Wood / Stone / Iron fallback | `trees` / `mountain` / `anvil` |
| Food / Herbs / Hide / Crystal / Gold fallback | `carrot` / `leaf` / `paw-print` / `gem` / `coins` |
| Farming / Crafting / Alchemy / Training / Arcana category | `wheat` / `anvil` / `flask-conical` / `target` / `moon-star` |
| Collect / Experience | `gift` / `star` |
| Corruption reward / Walk Away reward | `skull` / `footprints` |
| Affix added / remade / empowered / weakened / rarity raised | `circle-plus` / `shuffle` / `circle-arrow-up` / `circle-arrow-down` / `sparkles` |
| Full-game benefits: world / party / future content | `map` / `users-round` / `sparkles` |

Labyrinth modifiers reuse their associated keyword imagery; scholar, scavenger,
discount, and appraisal modifiers use `book-open`, `package`, `percent`, and `eye`.
The native Resources toolbar button remains an SF bag, and the battle menu's
Retreat action retains its SF running figure. Tabs, alerts, empty-state views,
filters, navigation arrows, Family Sharing, and animated settings symbols remain
native UI imagery.

## Data compatibility

Content carries provider-qualified strings; UI presentation carries `GameIcon`.
`TalentNode.iconID` retains the serialized `symbolName` key, and legacy unqualified
values still resolve as SF Symbols. Talent IDs, unlock progression, effect data,
and saves are unchanged by icon selection.
