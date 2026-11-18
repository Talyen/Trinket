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
| Press and creators | 59.0-second portrait reel. A Wizard takes a Frost Whelp up Cinder Spire. The final 17 seconds of gameplay follow their uninterrupted Forge Golem fight with its own song and visible lyrics. The release includes a caption track and a separate English SRT. |

### Press reel narration and edit

| Start | Picture | Spoken line |
| --- | --- | --- |
| 0.2s | Scroll right to Wizard | I'm taking the wizard up Cinder Spire. |
| 3.2s | Scroll right to Frost Whelp | Come on, little guy. You're with me. |
| 6.1s | Inspect Ray of Frost | Ray of Frost hits twice. I want both of those hits on the golem. |
| 11.0s | Inspect the Sapphire Amulet | More healing when he's frozen? I like that amulet. |
| 14.7s | Homestead and Farming | I keep meaning to get that herb garden going. |
| 18.4s | Campaign and Forest | There's the Treant. I'll come back for him. |
| 22.6s | Select the newly reachable Mystery room | I've cleared this room. What's over here? |
| 27.5s | Goblin contract | I could pick up a goblin contract on the way. |
| 31.8s | Tundra itinerary | A voyage to the Tundra can wait till tomorrow. |
| 36.3s | Enter Cinder Spire | There's Cinder Spire. Let's see how we do. |

At 40.3s, let the Forge Golem's singer take over. Keep the native Auto Battle card animations and let the last lyric resolve on screen before the title card. All section changes use a six-frame moving cross-dissolve at 30 fps. Out of Farming, dissolve directly to Play. The Forest belongs after the player opens Campaign.

**Recording.** Run `python3 Scripts/capture-launch-trailer.py --device <paired-iPhone-UDID> --press-pickups --output-dir <new-directory>` under the physical-device lane. The route taps the next card to the right in each carousel, opens the Wizard's Ray of Frost, then uses a disposable Labyrinth career to win the entrance fight. The retained shot starts on that partly explored floor and holds through the next reachable room's artwork opening. Select the gesture windows using the device-clock markers in `handles.json`.

**Review files.** Under `channel-edits/revision-two/`, `picture.json` records source windows, `render.py` assembles the reel, and `feature-reel-edit.json` records final frame and caption timing. The current mix uses Kokoro’s George. The `voice-audition/` folder contains George, Heart, Fenrir, and Emma reading the same opening three lines at matched loudness. Voice choice is open.

The narration introduces the player’s plan, then lets the player’s choices and the boss performance carry it through. The production references were Supergiant’s account of timing the *Bastion* trailer to its narrator, Valve’s *Panels* demonstration, and Sloclap’s *Sifu* combat overview. [Bastion production notes](https://www.supergiantgames.com/blog/presenting-the-bastion-launch-trailer/) · [Portal 2 — Panels](https://www.youtube.com/watch?v=0qcED35LL8I) · [Sifu combat overview](https://www.youtube.com/watch?v=tHaODlf6FIc)

The U.S. storefront lookup returned zero results on November 17. The social cuts are launch assets awaiting availability. App Store placement and the Apple Ads pilot remain tracked in the launch plan. [Apple preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) · [Apple badge guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
