---
type: execution-plan
status: active
created: 2026-11-17
updated: 2026-11-21
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
| Press and creators | 93.1-second portrait reel. Follow the Wizard and Frost Whelp to the Blood Countess in Sanguine Court. The Countess fight runs 26.8 seconds in one physical iPhone shot. Her song carries across the dissolve to the launch card. The distribution cuts include burned-in English captions with gold highlights timed to the narration. Optional captions and a separate SRT are also available. |

### Gameplay feature reel

George narrates in the voice of the original Wizard reel. The new master plays his speech at 1.25× with pitch preserved. The game animations, boss music and sung lyrics run at their original speed. Time each line to the visible card or building.

| Start | Picture | Spoken line |
| --- | --- | --- |
| 0.2s | Select the Wizard | I'm taking the Wizard to the Sanguine Court. |
| 2.9s | Select the Frost Whelp | Come on, little guy. You're with me. |
| 5.3s | Open Ray of Frost | Ray of Frost. Two hits for one card. |
| 7.9s | Twin Casting staff | Empower Ray of Frost with this staff and you draw a Burn card. |
| 11.7s | Frozen Pocketwatch held still | And this little watch can keep them frozen for another turn. |
| 15.9s | Open the Herb Garden | I keep meaning to get that herb garden going. |
| 20.5s | Open the Wheat Field | A wheat field gives the hero more health. |
| 23.5s | Open the Chicken Coop | The chicken coop does the same for your companion. |
| 26.6s | Forest Campaign | There's the Treant. I'll come back for him. |
| 30.3s | Recruit the Bear | A Recruit event. That bear can join the party. |
| 35.1s | Bear’s Sunder skill | The Bear’s Sunder halves the enemy’s Block before it hits. |
| 39.7s | Knight’s Blessed Aegis ultimate | The Knight’s ultimate, Blessed Aegis, gives her Block, heals an ally, and deals Holy damage. |
| 45.4s | Goblin contract | The goblin pays extra hide. |
| 48.1s | Mud Elemental on the same board | The Mud Elemental drops an amulet. |
| 50.6s | Desert Voyage itinerary | A voyage through the Desert. You can check the route before you embark. |
| 55.0s | Enter Sanguine Court | Sanguine Court. Let's go meet the Countess. |

At 57.8s the Wizard and Frost Whelp meet the Blood Countess. Enter just before the first lyric. At 1:24, as “I have dressed myself for you” resolves, dissolve to the launch card over 0.6s. The same recording continues through the question “Does it beat so fast for me?” Fade the music in the instrumental breath before the chorus. The end card stays visible for 9.1s including the dissolve. The cleaned Ambush logo shows the Ranger and Fox on charcoal. Center “Start playing for free”, “Unlock the full game with one purchase.” and the App Store badge together in the bottom third.

**Recording.** Use `Scripts/capture-launch-trailer.py --device <paired-iPhone-UDID> --press-pickups <route> --output-dir <new-directory>` under the physical-device lane. The `countess` route holds the Pocketwatch still, opens the three farming buildings, visits Sanguine Court, then records the boss with the original party. The `roster` route recruits Bear, inspects a Voyage, then opens the Bear and Knight ability details. Match Voyage copy to the destination actually recorded. For Contracts, the original motion take contains one uninterrupted scroll from Goblin’s bonus Hide to Mud Elemental’s amulet.

The prelaunch press reel uses the same musical ending and centers “Coming to iOS” above “December 21, 2026”, followed by the free start and one-purchase copy. The branded master is `Trinket-Ambush-Launch/Trailers/Trinket-Press-Feature-Reel.mp4` in Release deliverables. The captioned 60 fps download-badge cut is staged at `~/.local/share/trinket/launch-day/2026-12-21/Trinket-Launch-Feature-Reel-60fps-Captioned.mp4`. Use it for the website press kit once the listing is live.

The press kit’s 952 × 1920 feature reel runs at 60 fps. Its 17 gameplay shots come from the original variable-rate iPhone recordings. The edit list uses 30 fps frame numbers for timing. The press exporter converts those numbers to timestamps and copies the approved narration, music and subtitle streams from the reviewed master. The feature export sets a continuous AAC packet clock. The November 21 audit removed timestamp gaps at 0:55 and 1:30 in both feature cuts and at 0:11.9 in the short press reel. The corrected clips retain the original encoded picture, audio frames and captions. Review evidence is in `Feature-Reel-Audio-Nov21/`.

**Branded exports.** Run `python3 Scripts/PressKit/brand.py <LaunchMarketing-Nov17> <new-output-directory>` to render both 60 fps web feature reels, their end cards, and all seven boss social cuts. The App Store preview ends on gameplay. To record the real loading screen, use `Scripts/capture-launch-trailer.py --loading-screen --device <iPhone-UDID> --output-dir <fresh-take>` over Wi-Fi.

**Review files.** Use the staged 60 fps launch cut for the website. Open `Trinket-Ambush-Launch/Trinket-iPhone-14-Pro-Launch.mp4` in Release deliverables for the Wi-Fi iPhone recording. The November 17 evidence folder retains the original layout, picture windows and English SRT in `channel-edits/countess-launch-card/`. The November 19 extended iPhone take, music alignment and narration are in `channel-edits/countess-ending/`. George retains the 1.25× delivery. On the contract board, end on the Mud Elemental’s amulet reward before the native Back transition begins.

The production references were Supergiant’s account of timing the *Bastion* trailer to its narrator, Valve’s *Panels* demonstration, and Sloclap’s *Sifu* combat overview. [Bastion production notes](https://www.supergiantgames.com/blog/presenting-the-bastion-launch-trailer/) · [Portal 2 — Panels](https://www.youtube.com/watch?v=0qcED35LL8I) · [Sifu combat overview](https://www.youtube.com/watch?v=tHaODlf6FIc)

The U.S. storefront lookup returned zero results on November 17. The social cuts are launch assets awaiting availability. App Store placement and the Apple Ads pilot remain tracked in the launch plan. [Apple preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) · [Apple badge guidelines](https://developer.apple.com/app-store/marketing/guidelines/)

## Feature stories for launch

The owner reports Apple approved a build. The U.S. launch is planned for December 21, 2026. These off-store drafts carry launch copy intended for use after the game is downloadable. The end card uses the cleaned Ranger and Fox logo, **Start playing for free**, and Apple’s official black **Download on the App Store** badge. Hold the card for three seconds. Use “Start for free. Unlock the full game with one purchase.” in the post or ad description. The free opening and the permanent unlock are in the same download. [Apple marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/) · [Product model](../Product/Monetization.md)

| Reel | Player story | Voice |
| --- | --- | --- |
| **Cinder Spire** | Wizard picks a Frost Whelp, checks Ray of Frost and a Sapphire Amulet, visits the farm, then weighs five routes before climbing Cinder Spire. Leave the Forge Golem’s lyric sequence to the singer. | Qwen Aiden |
| **Choir Practice** | Knight needs a partner who can get through a Spire. Scroll right to Library Owl, inspect how Shield Bash turns Block into damage, then follow the sound to the Seraph. Let the boss answer “Do you hear singing?” | Qwen Ryan |
| **One More Room** | “One room. Then I’m going home.” An Inquisitor guards the entrance. The win earns an Emerald Amulet and opens a Mystery room. Hold on the newly selected room as the narrator reconsiders going home. | Qwen Aiden |
| **Who’s Paying?** | Leave the merchant’s amulet on the shelf. A Plague Doctor contract offers an Astral item. Ranger and Wolf win, keep their gold and collect an Astral Longsword. | Qwen Serena |

The four November 17 drafts use physical iPhone footage, a continuous shot for each fight, six-frame dissolves between locations, and optional English captions. The two boss films feature the boss’s own recording and in-game lyrics. The other two show the actual victory and reward in the same take. The owner declined these drafts. Hold the narrated press kit and keep the files as edit references. The separate App Store preview finishes on gameplay.

### Reproduce and review

- Keep the named masters and SRTs in `channel-edits/feature-stories/` under the November 17 release evidence. `studio/render_stories.py` and each film’s JSON record the exact input windows, narration cues and duration. Use `--press-pickups knight` to record the Knight, Library Owl, Shield Bash and the entrance to Aureate Choir on the paired iPhone. Use `--contract` to capture the board, play the easy offer and hold on the victory loot. The board can roll different enemies and rewards on a new take, so match the script to the recorded offer.
- Generate a full thought at a time and direct the delivery for the shot. Save the clean reads so changing the music or end card costs no additional inference. The four films use Qwen3-TTS 1.7B CustomVoice on this Mac via MLX. The upstream model is Apache-2.0 and supports written performance direction with preset voices. [Model card](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice)
- Listen to `Trinket-Open-Voice-Audition.m4a` for the same line from Aiden, Ryan, Serena and Chatterbox Turbo. Chatterbox offers a second local English engine with expressive cues. Kyutai Pocket TTS is a CPU-friendly third candidate. Its model card lists CC BY 4.0 and access conditions. The audition contains the first two engines. [Chatterbox](https://github.com/resemble-ai/chatterbox) · [Pocket TTS](https://huggingface.co/kyutai/pocket-tts)

- [x] Record both new physical routes and export the four launch editions.
- [x] Restore George and render the Wizard and Frost Whelp gameplay overview.
- [ ] Release the launch assets when the App Store download is live.

### Earlier narrator and opening auditions

These were private casting and story tests. The owner selected George and the gameplay overview above.

Review files are under `channel-edits/direction-auditions/` in the November 17 release evidence. Play `Female-commercial-reads.m4a` to compare three readings of “If you’re going to pick a fight with the Iron Bear, bring a very big cat.” A starts at 0.0s with a dry smile, B at 4.3s with a brighter delivery, and C at 8.4s with a matter-of-fact read. All three were generated locally with VoxCPM2 from written direction. [VoxCPM2 model card](https://huggingface.co/openbmb/VoxCPM2)

| Opening | What to watch for |
| --- | --- |
| `Ask-the-Countess.mp4` · B | “What did you wear to meet the king?” Leave a beat. The Countess sings “I wore black for every king” as the words appear in the fight. |
| `Bring-a-Big-Cat.mp4` · A | Enter the Iron Bear fight mid-attack. The narrator lands “very big cat” over the Rogue and Panther’s uninterrupted fight. |
| `Two-Amulets.mp4` · C | The merchant wants ten gold for the sapphire. Follow the fight through victory and time “The emerald cost us a fight” to the loot. |

- [x] Export three short openings from physical iPhone footage and the matched dry voice comparison.
- [ ] Review the full reel with music and captions before replacing the narrated press kit.
