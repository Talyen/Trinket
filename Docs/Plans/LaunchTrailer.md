---
type: execution-plan
status: active
created: 2026-11-17
updated: 2026-11-17
expires: 2026-12-01
---

# Trinket boss combat showcase

Open in battle and stay there. Show each of Trinket’s seven distinct bosses against a new pair. Give the viewer enough time to recognize the enemy, follow a card from the hand to the target, and read the hit or response. Keep the full battlefield in fixed framing.

The [launch tracker](LaunchMarketing.md) owns distribution, approvals and spending. The earlier Blight Treant story cut remains with the November 17 release evidence.

## Matchups

| Boss | Hero | Companion | Encounter |
| --- | --- | --- | --- |
| The Blight Treant | Ranger | Wolf | Serpent Hollow |
| The Iron Bear | Rogue | Panther | Iron Vein |
| The Forge Golem | Wizard | Frost Whelp | Cinder Spire |
| The Frostwarden | Alchemist | Phoenix | Rime Vault |
| The Blood Countess | Warlock | Risen Skeleton | Sanguine Court |
| The Seraph | Knight | Library Owl | Aureate Choir |
| The Stone Titan | Druid | Shield Scarab | Resonance Hall |

Record floor 10 of each named Spire. This covers the seven boss identities in the [enemy manifest](../../ContentManifest/enemies.tsv). Campaign, Voyage and deeper floors can reuse those identities at other levels or with other modifiers.

## Direction

1. Start on the Treant already in motion. Put the boss name and pair in the space above the battlefield. The same typography and framing orient the viewer at every cut.
2. Give each boss a complete action. Start just before a card moves out of the hand and stay through the damage or status result. Add a second action or the boss response when it shows something a preceding fight did not.
3. Build the pace from familiar attacks into visually different effects. Look for frost against the Forge Golem, fire against the Frostwarden, the Countess’s Bleed, the Seraph’s light, and the Titan’s heaviest impact. The card drawn and its resolved effects decide the shot.
4. Let the Titan carry the last musical accent. Put the Trinket title over live combat. Use one music passage across the cuts and mix the game’s own combat sounds where the picture supports them.
5. Deliver a roughly 40–45 second 60 fps master and a roughly 26–29 second 30 fps iPhone preview with one action from each boss. Review once muted at phone size. All seven bosses and pairs should be recognizable, and the viewer should see a card move and land.

## Physical capture

The packaged Debug build accepts the Spire and two roster IDs through `-boss-capture`. It opens an in-memory save at the selected floor with an unlocked roster. The Spire coordinator launches the real encounter with its normal combat engine, cards, artwork, and modifiers. The capture argument is scoped to development builds. The runner verifies that the expected three combatants are visible before marking the hand plays.

Use the paired physical iPhone and keep the recorder running through the seven app launches. Cut the launches, approval UI and transitions between encounters from the picture.

~~~sh
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner "$THREAD_ID" --wait 900 --timeout 900 -- \
  ./Scripts/install-device.sh --device 'Ryan’s iPhone 14 Pro' --no-launch

python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner "$THREAD_ID" --wait 900 --timeout 600 -- \
  python3 Scripts/capture-launch-trailer.py --device 'Ryan’s iPhone 14 Pro' \
  --boss-showcase --output-dir "$TAKE"
~~~

Keep the iPhone original, monotonic-clock marks in `handles.json`, build identity, route log and the final edit timelines together. The gesture markers include the played card IDs. Use the actual picture to tighten each in and out point and to select synchronized sound cues.

Use the recorded game viewport at a fixed crop. An entry in the edit timeline can name a viewport-sized PNG in its `graphic` field. Use `--videotoolbox` for the 60 fps master and `--app-store` for the shorter 30 fps edit. Check the native cadence of moving cards and impacts in the source, then verify exported frame counts and stereo audio.

## Review and release

The review master is `boss-showcase/Trinket-Boss-Combat-Showcase-60.mp4` under `.DerivedData/Deliverables/Release/LaunchMarketing-Nov17/` in the primary checkout. It runs 44.30 seconds with `Battle 1` and synchronized game effects. The 28.00-second App Store preview retains two card plays per boss. The silent export has the same 2,658 picture frames as the master.

The 199.5-second iPhone 14 Pro original and route log are in `boss-showcase/take-01/`. The development build used an in-memory save for each encounter. The retained 20 manually played action windows measured 58.7–60.0 visibly changing frames/s. The edit ends on the Titan’s response from that same take. See `showcase-edit.json`, `store-edit.json`, and `verification.json` beside the exports.


- [x] Capture seven boss encounters with fourteen distinct player characters.
- [x] Review readable card plays and native impact cadence across the cut.
- [x] Verify the 60 fps master, silent creator copy and 30 fps preview.
- [ ] Review the trailer and promotional music rights before publication.
