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

## Channel exports

The November 17 `channel-edits/` folder next to the boss masters contains four review exports.

| Placement | Export and use |
| --- | --- |
| App Store and Apple Ads search results | The Forge Golem, 17 seconds, 886 × 1920 at 30 fps. Use the poster frame at 0.30 seconds and finish on combat. Use this preview on the listing and the planned combat custom product page. |
| Organic social and off-store ads | Forge Golem and Blight Treant, 1080 × 1920 at 60 fps. Each ends with the game title and Apple’s download badge for 1.8 seconds. Use the launch cuts once the U.S. listing is live. Compare store visits from equivalent organic posts before considering spend. |
| Press and creators | A 54.6-second portrait feature reel with English narration and optional captions. Kokoro generated the narration locally using its stock British English voice, George. The narrator hands the last 9.5 seconds of combat to the Blight Treant’s singer. |

### Narration script

| Start | Picture | Spoken line |
| --- | --- | --- |
| 0.3s | Ranger selection | We need a ranger. |
| 3.2s | Wolf selection | A wolf. |
| 4.3s | Party to ability selection | And something that sets trees on fire. |
| 6.9s | Fire Arrow | Fire Arrow. Equip an ability and it goes into your deck. |
| 11.6s | Sapphire Amulet | An amulet for the road. |
| 14.7s | Homestead farming | Back at the Homestead, build upgrades and gather supplies. |
| 18.8s | Campaign and Forest | The Campaign takes us into the Forest. |
| 22.2s | Spire floors | Feeling ambitious? Climb a Spire, one floor at a time. |
| 27.0s | Labyrinth route | Pick your way through the Labyrinth. |
| 31.3s | Contract offers | Take a Contract for a quick fight. |
| 35.6s | Voyage route | Or chart a Voyage. |
| 38.0s | Return to the party | In battle, the pair shares one hand. |
| 40.9s | Blight Treant reveal | And the Blight Treant? It sings. |

The opening names a problem the final boss can answer. Supergiant’s account of building *Bastion* around a recorded narration track informed the timing. Valve’s *Panels* trailer lets the demonstration deliver the joke, and Sloclap’s *Sifu* overview pairs each mechanic with its visible result. For Trinket, that means showing the amulet as it is named, letting mode navigation unfold, and leaving the boss enough space to sing. [Bastion production notes](https://www.supergiantgames.com/blog/presenting-the-bastion-launch-trailer/) · [Portal 2 — Panels](https://www.youtube.com/watch?v=0qcED35LL8I) · [Sifu combat overview](https://www.youtube.com/watch?v=tHaODlf6FIc)

The U.S. storefront lookup returned zero results on November 17. The social cuts are launch assets awaiting availability. App Store placement and the Apple Ads pilot remain tracked in the launch plan. [Apple preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) · [Apple badge guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
