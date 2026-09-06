# Mystery events

Ordinary Mysteries are quick decisions between two item offers. Each choice grants
one item and one secondary reward: a material, shared XP, or Gold. Recruitment and
the Corruption Altar retain their distinct flows.

## Offers and presentation

Show both offers side by side with full-bleed 3:4 portrait artwork, the resolved item
label, one secondary reward, and a short action button. Use the Inventory label
component: centered rarity/type above the item name, with the standard shine
colors. Artwork opens the read-only
item detail sheet; only the action button commits. Do not add info icons, guaranteed
affix notes, recipient notes, or a separate Confirm button to ordinary Mysteries.
Allow names and actions to wrap and the screen to scroll on smaller devices.

Use the shared cinematic hero header, with the Mystery eyebrow and event title
at the bottom left of the artwork and the standard artwork blend and on-art text
treatment. Keep its artwork constrained to the viewport width. Narrative text below
the hero names the actual
offered items and connects each action to its rewards: physical sources for
materials and Gold, and learning or practice for XP. The authored catalog is
[MysteryEventPool.swift](../../Packages/TrinketContent/Sources/TrinketContent/Content/MysteryEventPool.swift).

## Reward rules

- Resolve offers before display. Basic/Astral gear uses the choice's fixed base;
  Trinkets and Uniques may only come from that choice's explicit thematic pool.
- Base probabilities per offer are 80% Basic, 8% Astral, 7% Trinket, and 5% Unique.
  Existing Astral bonuses apply. An unavailable special tier becomes Astral gear
  of the specified base, never an unrelated special item or an empty item reward.
- Keep the existing Manabound guarantee for the Mana Berries harvest, Crystal
  Geode gem collection, and Crystal Garden shard collection.
- Materials use the existing encounter-level quantity and applicable bonuses.
  Gold uses its authored base amount and existing bonuses. Quote only receivable
  Gold; when the wallet is full, substitute shared XP.
- XP uses the base battle XP curve at the resolved encounter level, applies the
  encounter's XP bonus, and is capped to the lower of both active characters'
  grant ceilings. Both receive the displayed amount, labeled simply “+N XP.”
- Ordinary Mystery completion does not add a separate Labyrinth Gold stipend.
  Other noncombat encounters retain their existing completion rewards.

## Stability and completion

Save both rolled items, including their affix powers, and secondary amounts with
the Journey stage or Labyrinth node before enabling choices. Reopening reuses
these offers. Existing saves without snapshots acquire them on first opening.

Revalidate ownership and grant capacity before claiming. If a special item has
become owned, or a secondary reward no longer fits, save and display the revised
offer and require a fresh action. Do not silently replace the player's selection.

Grant the selected offer and complete the encounter in one save transaction.
Failed saves preserve the displayed offers for retry; successful completion clears
the pending snapshot and cannot grant again. Keep the existing Mystery reward
reveal screen.

Engineering owners: [content](../AgentContext/content-and-manifests.md),
[persistence](../AgentContext/persistence.md), and
[SwiftUI features](../AgentContext/swiftui-features.md).
