---
type: execution-plan
status: active
created: 2026-11-17
updated: 2026-11-17
expires: 2026-12-01
---

# Trinket boss lyric trailers

Make one portrait trailer per boss. Open in the fight just before that boss’s first lyric. Keep the original theme and the word-by-word lyric display in sync through a complete opening passage. Native Auto Battle keeps the cards moving while the lyrics develop.

The [launch tracker](LaunchMarketing.md) owns distribution and approvals. The earlier combined combat showcase remains with the November 17 release evidence.

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

1. Start just ahead of the first sung phrase. Frame the battlefield and preserve the lyric display inside the boss pane.
2. Keep one continuous shot per boss at game speed. Let Auto Battle drive the normal card-play animation and pacing.
3. Use that boss’s original theme. Check the first words and later lyric reveals against the timed lyrics for the corresponding track in [MusicManifest](../../MusicManifest/music.tsv).
4. End after a complete phrase while the fight is still readable. Allow the phrasing and combat to determine each runtime.

## Physical capture

The packaged Debug build accepts the Spire and two roster IDs through `-boss-capture`. It opens an in-memory save at the selected floor with an unlocked roster. The Spire coordinator launches the real encounter with its normal combat engine, cards, artwork, and modifiers. The capture argument is scoped to development builds. With `--boss-lyrics`, the fixture enables ordinary Auto Battle and live lyrics in isolated capture preferences. It uses the game’s existing music resume clock to cue each theme a few seconds before its first lyric. The runner verifies the three combatants and records the display and internal audio together. [ScreenCaptureKit audio configuration](https://developer.apple.com/documentation/ScreenCaptureKit/SCStreamConfiguration/capturesAudio)

Use the paired physical iPhone and keep the recorder running through the seven app launches. Cut the launches, approval UI and transitions between encounters from the picture.

~~~sh
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner "$THREAD_ID" --wait 900 --timeout 900 -- \
  ./Scripts/install-device.sh --device 'Ryan’s iPhone 14 Pro' --no-launch

python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner "$THREAD_ID" --wait 900 --timeout 600 -- \
  python3 Scripts/capture-launch-trailer.py --device 'Ryan’s iPhone 14 Pro' \
  --boss-lyrics --output-dir "$TAKE"
~~~

Keep the original, `handles.json`, and the route log. The November 17 capture shows the live lyrics and its audio track is silent. Match the first visible words and later reveals to the song’s timed lyrics. Use that alignment as `--music-offset` and pass the matching master as `--soundtrack` to `Scripts/edit-launch-trailer.py`. Use one interval per export, the fixed iPhone viewport and `--videotoolbox`. Review the first displayed words against the export clock and check the last frame for live battle.

## Review and release

- [x] Verify seven independently playable 60 fps clips against their corresponding songs.
- [x] Review the lyric lead-in and final phrase in each clip.
- [ ] Review the clips and promotional music rights before publication.

The seven November 17 iPhone 14 Pro exports are in
`.DerivedData/Deliverables/Release/LaunchMarketing-Nov17/boss-lyric-trailers/`.
Each runs 14–17 seconds in a single shot. The vocals start about 0.65 seconds
in, with a 0.19-second lead on The Blight Treant. The retained take, edit cue
maps and `verification.json` cover the source, 60 fps motion and soundtrack match.
