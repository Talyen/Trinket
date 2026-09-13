# Game icon selections

Rendering and library policy are owned by the
[design system](../../Packages/TrinketDesignSystem/Documentation/VisualRoles.md#game-icons).
All symbolic game imagery uses SF Symbols; painted artwork remains primary.

## Keywords

`Keyword.visualStyle` owns the shared identity used by ordinary UI and floating
combat feedback. Thorns shares Physical's color, but has a distinct silhouette.

| Meaning | SF Symbol |
|---|---|
| Physical / Thorns | `burst.fill` / `asterisk` |
| Burn / Stun | `flame.fill` / `bolt.fill` |
| Block / Health | `shield.fill` / `heart.fill` |
| Holy / Mana | `sun.max.fill` / `moon.stars.fill` |
| Poison / Bleed / Leech | `flask.fill` / `drop.fill` / `eyedropper` |
| Freeze / Dodge | `snowflake` / `wind` |
| Purge / Cleanse | `shield.slash.fill` / `sparkles` |
| Death's Door | `hourglass.bottomhalf.filled` |
| Gold | `circle.circle.fill` |
| Beneficial / negative status | `arrowshape.up.fill` / `arrowshape.down.fill` |

Floating combat feedback uses the same identities, with dark outlines for contrast
over artwork. Numbers match their adjacent icon's keyword color. Size and motion
policy lives in the [floating combat feedback contract](../AgentContext/battle-presentation.md#floating-combat-feedback).

## Talents and Homestead nodes

The reviewable per-node mapping is the `icon_id` column beside each stable ID,
name, and description in [talents.tsv](../../ContentManifest/talents.tsv) and
[homestead_nodes.tsv](../../ContentManifest/homestead_nodes.tsv). The metadata
format is owned by the [manifest guide](../../ContentManifest/README.md).

Choose the named object when SF Symbols has a clear equivalent, then the described
action or keyword. Prefer reusing an accurate motif to introducing an unrelated
object just to distinguish talents. Pruning Touch uses `scissors`, Shared Roots
uses `tree.fill`, Skullcracker uses `hammer.fill`, and Full House uses
`rectangle.3.group.fill` for its set of three card types. Heat/cold combinations
use `sun.snow.fill`; flower talents use the flower-shaped `camera.macro`.

Bite, bone, skull, and spirit talents use their effects when no direct SF motif
fits: damage uses `burst.fill`, blood uses `drop.fill`, Leech uses `eyedropper`,
resistance uses `shield.fill`, and extended Death's Door uses the hourglass.
Fuel the Flames uses `flame.fill`; treasure and bargaining use the Gold symbol.
Spikes and direct Thorns motifs use `asterisk`; explosive impacts retain
`burst.fill`. Locked talent rows retain the native UI lock.

## Other game imagery

| Surface or meaning | SF Symbol |
|---|---|
| Battle / Boss / Shop / Mystery | `bolt.shield.fill` / `crown.fill` / `storefront.fill` / `sparkles` |
| Recruit Hero / Companion / Labyrinth entrance | `person.2.fill` / `pawprint.fill` / `door.left.hand.open` |
| Hero / Companion / Enemy placeholder | `person.fill` / `pawprint.fill` / `shield.slash.fill` |
| Item / Ability placeholder | `shippingbox.fill` / `wand.and.stars` |
| Campaign / Contract / Spire placeholder | `map.fill` / `scroll.fill` / `flag.fill` |
| Party selection / Recruit reward | `person.2.fill` / `person.badge.plus` |
| Wood / Stone / Iron fallback | `tree.fill` / `mountain.2.fill` / `hammer.fill` |
| Food / Herbs / Hide / Crystal / Gold fallback | `carrot.fill` / `leaf.fill` / `pawprint.fill` / `diamond.fill` / `circle.circle.fill` |
| Farming / Crafting / Alchemy / Training / Arcana category | `leaf.fill` / `hammer.fill` / `flask.fill` / `target` / `moon.stars.fill` |
| Collect | `gift.fill` |
| Corruption reward / Walk Away reward | `dice.fill` / `figure.walk` |
| Affix added / remade / empowered / weakened / rarity raised | `plus.circle.fill` / `shuffle` / `arrow.up.circle.fill` / `arrow.down.circle.fill` / `sparkles` |
| Full-game benefits: world / party / future content | `map.fill` / `person.2.fill` / `sparkles` |

Standalone XP rewards use the [two-book artwork](ArtworkStyleGuide.md#xp-rewards).
XP bars and character progress totals keep their existing text treatment.

Labyrinth modifiers reuse their associated keyword imagery; scholar, scavenger,
discount, and appraisal modifiers use `book.fill`, `shippingbox.fill`, `percent`,
and `eye.fill`. Native navigation, settings, filters, alerts, and other UI retain
their existing SF selections and symbol animations.

## Data compatibility

Authored content uses `sf:` strings; UI presentation carries `GameIcon`.
`TalentNode.iconID` retains the serialized `symbolName` key. Unqualified SF names
still resolve, and previously shipped `lucide:` values translate to SF Symbols
through the design system's legacy mapping. The legacy mapping is a context-free
fallback; current authored talent selections carry the more specific meanings.
Talent IDs, unlock progression, effect data, and saves are unchanged by icon selection.
