# Monetization

Trinket is free to start, with one permanent **Full Game** purchase at a US base
price of **$4.99**. Use Apple's non-consumable In-App Purchase with Family Sharing.
No subscriptions, consumable currencies, paid power, reward boosts, or paid skips.

## Access

| Surface | Free edition | Full Game |
|---|---|---|
| Campaign | Forest, Dungeon, Desert | Every chapter |
| Voyage | Forest, Dungeon, Desert | All four locations |
| Contracts | Unlimited play with normal rewards | Same |
| Labyrinth | Floors 1–3 | Every floor |
| Spires | Floors 1–10 of every Spire | Every floor |
| Heroes | Knight, Ranger, Rogue, Wizard | Every hero |
| Companions | Wolf, Bear, Frost Whelp, Library Owl | Every companion |
| Talents and abilities | Complete progression for accessible, recruited characters | Same |
| Equipment and Homestead | All existing systems and progression | Same |

All future content released inside Trinket is included in Full Game. This does
not promise future releases, a roadmap, or any update cadence. New chapters after
the free three, additional characters, and new modes default to Full Game; every
Spire includes its first ten floors. Existing free characters retain their full
ability and talent progression when expanded.

Purchase grants access to normal recruitment and progression, not instant roster
completion, levels, talents, equipment, or rewards. Owners can choose a premium
character as their one starter per role. Free characters appear before premium
characters in Collection and starter selection. Normal recruitment and floor
progression remain separate from purchase access.

## Offer

[Original visual reference](FullGameOffer.png). This is a design mockup, not a
screenshot of the running app; the presentation and copy below supersede it.

Use a native art-led full-screen modal: the **Keep Exploring** heading overlays the
bottom-left of the triggering chapter, Spire, Labyrinth mode, hero, or companion
artwork, with a **FULL GAME** eyebrow. Use the current mountain artwork for Options
and when contextual artwork is unavailable. Prepare and pin the selected artwork
before presenting the offer, then release it on dismissal. Keep the square hero
header and use the artwork manifest's curated focal point to position the
aspect-fill crop using the prepared image's actual proportions. Preserve complete
heads, faces, and recognizable features, allowing lower-body cropping. Review
premium character crops with the heading, fade, display cutout, and sheet grabber
visible. Three icon rows use gold icons, primary-color text, and selective semibold
emphasis. Match the icons visually to the bullet text, give each icon the same scaled square
slot, align the text column, and use equal gaps between rows:

- All **chapters & modes**
- All **heroes & companions**
- All **future content**

Keep benefit rows on one line at standard text sizes, allowing natural wrapping
for enlarged text. The anchored primary button is **Unlock Full Game · {localized price}**;
keep its complete localized label and price visible, wrapping when needed.
**Restore Purchases · Privacy** and a small muted **Family Sharing** label sit
centered beneath the purchase button in the anchored footer. Restore and Privacy
stack when they cannot fit side by side; keep the footer controls reachable at
enlarged text sizes. Dismiss through the native sheet grabber or
swipe; omit the close button. No fixed content counts or named chapter claims,
additional one-time/subscription reassurance line, or secondary free-play CTA.

The offer opens from deliberate actions at premium campaign, Spire, Labyrinth,
character, or starter boundaries, and from Options. Never automatically interrupt
onboarding, defeat, victory, or a reward. Selecting a Full Game-only character
without access opens the offer directly with that character’s artwork, without
opening character details underneath. Accessible but unrecruited characters
remain inspectable with editing disabled. Combatant details have no recruitment
or purchase footer.

Options keeps a compact **Full Game** section with **Unlock Full Game** opening
the offer and **Restore Purchases** available while the game is locked. Verified
owners, including Family Sharing recipients, see **Full Game — Unlocked** instead
of both actions. Both purchase surfaces display concise inline outcomes for unavailable
pricing, pending approval, unsuccessful restoration, no purchase found,
unverified ownership, and failed purchases. Keep cancellation quiet and use the
existing successful purchase/dismissal behavior. General **Support** and **Privacy Policy** links
belong in a separate
**About** section after Full Game and before Game Data.

After verified purchase or restoration, return to the requesting screen without
automatically starting a battle, recruiting, or confirming a starter. Delayed
approval updates ownership without navigating away from current play.

## Preservation

Retain rewards for encounters legitimately begun with access. Refunds or removed
Family Sharing access prevent subsequent premium actions without deleting saves.
Keep character progress, equipment, talents, completed encounters, and maps for
restoration. Restore a usable free party when necessary without resetting other
progress. Gameplay reset never resets purchase ownership.

Every party can enter every [Spire](Spires.md), subject to floor progression and
purchase access.

Payment implementation and release prerequisites:
[Purchases.md](../Platform/Purchases.md).
