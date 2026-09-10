# Contracts

Contracts is a renewable, one-battle mode for developing any Hero and Companion
and earning regular battle loot. It is available in Play → Explore immediately
after starter selection, on both new and existing saves.

## Board

Three offers appear in Easy, Standard, Hard order. Every ordinary enemy is
eligible for Easy and Standard; every boss is eligible for Hard, independent of
discovery or completion elsewhere. The two ordinary targets are distinct.

Let P be the active Hero and Companion's average level, rounded down:

| Offer | Target | Level |
|-------|--------|-------|
| Easy | Ordinary enemy | max(1, P − 3) |
| Standard | Ordinary enemy | P |
| Hard | Boss | P + 3 |

Use the existing enemy curves, shared
[progression-based loot policy](../../Packages/TrinketContent/README.md#random-item-rewards)
at the resolved encounter level, catch-up XP,
level-difference XP reductions, reward ownership, and applicable Homestead
effects. There are no Contracts-specific stat or reward multipliers. Difficulty
labels describe level and enemy category, not a guaranteed matchup outcome.

Use the shared Stage screen, list, and active-card layout from Campaign and Spires.
All three offers are available Stage cards, showing difficulty (Easy, Standard,
Hard), enemy artwork/name, and Battle. Cards use the same 16-point gap as Game
Mode cards; Campaign and Spires retain their compact stage spacing. Enemy artwork
opens standard catalog enemy details without a party-scaled encounter preview.
Each card has a Party control beside Battle that opens the existing party picker
for the shared active Hero and Companion. Rewards appear only on victory: no XP, item, currency, or reward-category
previews are shown on the board. Reuse Explore art and existing enemy portraits.

## Lifecycle

Refresh is free, immediate, unlimited, and replaces all offers. Victory replaces
only the completed offer; avoid immediately repeating its target when possible.
Defeat and retreat retain the offer for free retries and award nothing. Each
attempt starts with the existing fresh-battle state.

The board persists between visits and app launches. Party changes and level-ups
retain targets. Encounter levels and loot are resolved only when Battle is pressed,
using the active party at that moment. Each attempt fixes its party, level, and
loot at launch; victory pays those rewards using
the normal victory and talent-choice flow before returning to Contracts.

Claiming rewards and replacing the offer is one saved operation. A duplicate or
stale offer claim cannot pay again; failed writes retain the board and pending
victory for retry. App interruption follows the existing battle lifecycle: an
interrupted, unclaimed offer remains available rather than adding mid-battle
save/resume. Missing or unreadable board data can regenerate independently of
all other saved progress.

Contracts has no entry cost, timers, separate statistics, ranks, bonus
objectives, or overall completion percentage. Its lasting rewards are roster
progression, equipment, gold, and materials.
