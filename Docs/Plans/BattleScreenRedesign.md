# Revised Cinematic Triptych Battle Layout

## Summary

Rebalance the screen so the five-card hand is the primary interaction surface while all combatants remain continuously visible. Preserve existing full-art `3:4` ability cards, use a shorter `4:3` enemy viewport, and remove all unneeded resource or pause chrome.

## Layout and Interaction

- Render existing square enemy art in a full-width `4:3` landscape viewport using centered fill-cropping; do not create new enemy assets.
- Keep Hero and Pet side-by-side beneath it using their existing `3:4` art.
- Anchor enemy health to the enemy region’s bottom edge and party health to each party region’s top edge.
- Show mana only when live `maxMana > 0`, as a thinner second bar directly below health. Knight and Bear show health only, with no empty mana track.
- Preserve the existing battle tab bar and status safe area. Add no pause control, global crystals, resource strip, or other top chrome.

## Card Hand

- Change the gameplay hand cap from eight to five; retain the four-card opening hand.
- At the cap, prioritize drawing for the owner with fewer cards; alternate the tie-break by round.
- Use the existing card ratio exactly: `3:4` width-to-height with full-bleed ability art and no name, cost, description, owner badge, or other face text.
- Size cards to approximately 43% of the available screen width—about `168×224` points on a 390-point-wide phone.
- Fan five cards at approximately `−12°, −6°, 0°, 6°, 12°`, with the center card highest and the outer cards slightly lower.
- Clip roughly the bottom 25% of the resting hand at the bottom of the battle content above the tab bar. Only minimal resting overlap with party art is allowed.
- On touch, immediately raise and straighten the selected card. Track upward dragging 1:1; play when released inside the battlefield and spring back when canceled. A tap without a committed drag continues to open ability details.

## Interfaces and Implementation Notes

- Update `BattleHand.softCap` to `5` and make simultaneous automatic draws owner-balanced.
- Replace the square-enemy grid contract with a `4:3` enemy viewport while retaining `3:4` party and ability-card ratios.
- Keep the existing optional mana-bar interface; this redesign does not implement mana gameplay or invent temporary mana state.
- Add no new art-manifest fields or processed assets.

## Verification

- Unit-test enemy `4:3`, party/card `3:4`, five-card fan bounds, rotations, clipping, and responsive behavior at 375-, 390-, and 430-point widths.
- Package-test the five-card cap, four-card opening hand, owner-balanced final-slot drawing, and targeted draw effects at capacity.
- Smoke-test one non-mana party and, once live mana exists, mixed and dual-mana parties.
- Verify all five cards remain individually tappable, tap opens details, battlefield drag plays, canceled drag restores the exact resting fan, and the tab bar remains usable.
- Confirm no pause button, crystals, card-face text, fake costs, or empty mana tracks appear.
