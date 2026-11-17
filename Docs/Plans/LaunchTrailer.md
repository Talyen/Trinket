---
type: execution-plan
status: active
created: 2026-11-17
updated: 2026-11-17
expires: 2026-12-01
---

# Trinket launch trailer

**Make one 26-second portrait trailer from one continuous run on the physical iPhone over Wi-Fi.** A new player chooses two characters, sees what they can build and where they can take them, then watches that party fight the Forest boss. Preserve the order of events. Leave the recorder running through travel, scrolling, loading and exits. One edit removes those intervals.

The [launch tracker](LaunchMarketing.md) owns distribution, approvals and spending. Follow the [standing workflow](../../AGENTS.md#route-and-read) and [verification policy](../Platform/Verification.md).

## What to record

| Cut time | Subject | On-screen action and edit |
| --- | --- | --- |
| 0.0–2.9 | Choose the party | Enter on Knight sliding aside for Ranger. Match the carousel framing as Bear slides aside for Wolf. Keep the names settling with the portraits. |
| 2.9–4.3 | Choose an ability | Start with the ability grid. Follow Fire Arrow opening, then push in 13% and feather the surrounding UI down as the illustrated card arrives. The viewer will recognize it in the fight. |
| 4.3–5.6 | Inspect an item | Show the Forest merchant and the Sapphire Amulet rising from the offer grid. Follow the sheet with a small push. Keep the name and price readable. |
| 5.6–7.0 | Visit Homestead | Start on the village and its resource wallet. Follow the Farming tile into Wheat Field, Herb Garden, Chicken Coop and Pasture. |
| 7.0–9.1 | Campaign | Ride the illustrated Campaign entry into the Forest chapter. Scroll the stage card into view to introduce The Blight Treant by name. |
| 9.1–11.2 | Spires | Follow the Spires card into the tower list and the Cinder Spire artwork into its Fire Imp encounter. Cut the pause between selections. |
| 11.2–13.5 | Labyrinth | Briefly dim the neighboring mode cards. Follow the entry onto the map and keep the player's pan across the floor. |
| 13.5–15.8 | Contracts | Follow the illustrated board into its jobs. Keep the scroll from Goblin to Mud Elemental and the amulet reward. |
| 15.8–18.1 | Voyage | Light the compass artwork, enter Voyage, then show the Tundra sheet rising to reveal its encounters. Dip the last few frames before returning to the Forest. |
| 18.1–26.3 | Fight The Blight Treant | Match the Forest encounter to the battlefield. Follow Fire Arrow from the hand into its Burn hit, briefly shading the edges around the target. Keep Fangs, Astral Arrow, the damage response and the next deal. Resolve the picture and music together. |

Each mode gets two connected actions. Keep the native navigation pushes and sheet entrances at normal speed. Use the full frame for most gestures so the viewer can see what the player did. The [edit recipe](../../Scripts/LaunchTrailer/edit-recipe.json) specifies each gesture's cut offset and duration. Camera and light timings are local to the cut, with centers and radii expressed as fractions of the cropped game picture.

Use The Blight Treant in Stage 1-10 for the first run. It is an identifiable, animated Campaign boss reachable with the same Ranger and Wolf the viewer saw at onboarding. Fire Arrow also gives the editor a clearly illustrated ability to look for in combat. The hand is dealt by the real game. Check the footage before describing a particular card play. The Blood Countess on Sanguine Court floor 10 is a later option if a separate capture career can reach her during the same run. [Stages](../../ContentManifest/stages.tsv) · [Enemies](../../ContentManifest/enemies.tsv) · [Party abilities](../../ContentManifest/combatants.tsv)

## Recording one original on the iPhone

Use a physical iPhone running iOS 27 or later and Xcode 27. The phone renders and encodes the movie. Wi-Fi carries the UI test and transfers the finished file. This lets the director rehearse and retake without playing through a whole career. Professional game trailer editors use reproducible game states, clean footage and independent audio controls for this purpose. [GDC 2025 capture tooling, Matt Hackett](https://media.gdcvault.com/gdc2025/Slides/Hackett_Matt_Content-Ready_Game_Development.pdf) · [Derek Lieu’s capture toolkit](https://www.derek-lieu.com/blog/2018/5/1/the-best-debug-tools-for-game-trailer-capture)

1. Check the named device below. Enable a quiet Focus for the take and close iPhone Mirroring and Device Hub's live screen view. In Device Hub the physical iPhone supports screenshots. Its screen-record command returned CoreDevice error 1001 for the missing screen-recording capability. Apple's Device Hub video procedure applies to simulators. [Device Hub capture](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices) · [Wireless pairing](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
2. Use the capture command below. A standalone signed XCTest runner opens the installed game with a fresh named local career with cloud sync disabled. After the starter and ability shots, the game reloads that same career once to advance Forest stages 1–8 through its existing launch fixture. On build 13, preloading those stages before starter selection prevented Wolf confirmation. The recorder runs continuously through the reload; the edit removes it. Its companion development app uses Apple's ScreenCaptureKit picker and recording output to encode a single original MP4 on the iPhone. With the owner's authorization, the runner can press **Share Entire Screen**. Apple can require the owner to enter a passcode to enable UI automation. The helper records picture with the microphone off, writes into its own Documents folder, then finalizes the take. It stops automatically after six minutes if the test disconnects. [Apple's iOS capture sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios) · [Physical tour](../../Scripts/LaunchTrailer/PhysicalTour.swift) · [Recorder](../../Scripts/LaunchTrailer/Recorder.swift)
3. The test drives the same Ranger and Wolf through one continuous recording. It marks the gesture before sending input and saves generous source windows in `handles.json`. The capture command applies the edit recipe to write `keep.json`. The host retrieves the original and the timestamps over the paired connection. Keep the raw MP4, cue map, test log and build identity together. Compare the first mode transition and the last card impact against the cues to check alignment. Adjust keep boundaries in the edit list where the touch or action lands late. Every visible shot must come from this take.
4. If the capture helper is unavailable, use the iPhone's built-in Control Center recording with its microphone off, start the rehearsed route using `--rehearse`, then stop recording. In Photos, transfer just that recording by AirDrop using **Current** or export the **Unmodified Original** from Mac Photos after iCloud sync. Match the clock cues from `shots.json` to a visible starter confirmation and verify a second alignment point in combat. Apple documents the three-second countdown and Photos destination. Measure the transferred original before making a 60 fps delivery. [Apple's iPhone recording instructions](https://support.apple.com/en-us/102653) · [Sharing original photos and videos](https://support.apple.com/guide/iphone/share-photos-and-videos-iphf28f17237/ios)

~~~sh
python3 Scripts/capture-launch-trailer.py --device 'Ryan’s iPhone 14 Pro' --check

python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner "$THREAD_ID" --wait 900 --timeout 600 -- \
  python3 Scripts/capture-launch-trailer.py --device 'Ryan’s iPhone 14 Pro' \
  --output-dir "$TAKE"
~~~

Use a new `TAKE` directory under `.DerivedData/Deliverables/Release/`. Add `--rehearse` for a route check without recording. The signing team defaults to the game project's team. The helper and test runner are separate installs. Trinket does not need to be reinstalled.

## Checking that 60 fps is real

Use the original recording at normal speed. Frame-step the moving card or projectile and impact; inspect timing gaps and consecutive picture changes. An average across held art screens is misleading for turn-based gameplay. Choose at least 0.45 seconds of continuous visible motion in each of two retained boss actions. Use source seconds from the same take. Run `python3 Scripts/LaunchTrailer/cadence.py "$TAKE/continuous.mp4" START END` for each. The tool measures decoded presentation times and luma differences in the game area. The house screen for a 60 fps master is at least 54 materially changed frames/s in both samples and no hold over 50 ms. These thresholds are editorial choices. Low-contrast movement can undercount; inspect the frames and choose a clearly moving interval. No optical interpolation. If source animation itself updates at 30 fps, choose another authentic action or recapture after diagnosing its frame pacing. Archive each observation beside the master.

## Picture and sound

**Use one continuous passage of the game's soundtrack underneath the edited picture.** Start with The Blight Treant's own cue. For this cut start 13.85 seconds into the track. The accent at about 32.5 seconds lands as the Forest stage opens into battle. Carry the music across all cuts and fade it over the final deal. Check whether a vocal competes with the UI or suggests synchronization with lyrics that are absent from the footage. If it does, audition Battle 1. Confirm promotional rights before sharing. Record the selected master, hash and offset. [Music catalog](../../MusicManifest/music.tsv)

The default run disables audio for that launch. The editor uses a separately supplied music file after all picture cuts, so leaving a mode never interrupts the score. If a later take can capture app-only audio with in-game music off, retain the synchronous card and impact sounds and mix the soundtrack underneath using `--keep-source-audio`. Verify that the audio stream actually contains clean game effects. Keep the microphone off. The first physical Mirroring proof contained video only.

~~~sh
python3 Scripts/edit-launch-trailer.py \
  --source "$TAKE/continuous.mp4" --timeline "$TAKE/keep.json" \
  --soundtrack "$ASSET_ROOT/Sounds/Game Sources/Music/The Blight Treant.mp3" \
  --music-offset "$MUSIC_OFFSET" --crop 1180:2376:0:150 --videotoolbox \
  --output "$TAKE/trinket-press-60.mp4"
~~~

New takes can deal different cards. Confirm the card identifiers and damage type against the log and the picture before adding per-take sound cues. In the timeline each optional `sounds` entry supplies the bundled SFX `id`, its time `at` in seconds from the start of that shot and its `gain_db`. Use the game's bow, bite and matching Astral Arrow variant where the action warrants it. These cues enter only the scored export. The `--clean-picture` option bypasses camera and lighting while retaining every original cut for a motion review.

The editor checks the most active 0.85 seconds of each marked boss play and records the whole-play measurement. For an editor-selected sample, supply one `--motion-span START END` in source seconds per play. Set `MUSIC_OFFSET` to the chosen soundtrack start. The editor removes travel chronologically and produces a source-to-output cue sheet. Save a clean, music-free copy for creators using the same command without `--soundtrack` and a different output name. Read the opening and boss exchange with sound off, then listen for the score's entrance and ending. Leave room for card and impact sounds if the source contains isolated game effects. [Apple preview creative guidance](https://developer.apple.com/app-store/app-previews/) · [Professional trailer editing and creator assets](https://www.derek-lieu.com/blog/2023/2/4/how-to-make-game-trailers-for-influencers-and-content-creators)

For the U.S. iPhone App Store preview, replace `--videotoolbox` with `--app-store` and choose a separate output filename. Apple accepts 15–30 seconds, a maximum of 30 fps, and 886×1920 portrait for iPhone 14 Pro. The profile preserves the aspect ratio and encodes H.264 with stereo AAC. Use the 60 fps native-aspect master for the press kit and social distribution. [App Store Connect delivery specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)

## November 17 capture and release tracker

The review master is **`motion-v2/Trinket-Ranger-and-Wolf-60.mp4`** under `.DerivedData/Deliverables/Release/LaunchMarketing-Nov17/` in the primary checkout. The same directory contains the original 139.45-second on-device take, its gesture windows, the exact release edit, source-motion comparison, silent creator cut and 30 fps App Store version. The preceding 28.5-second cut is archived in the parent directory.

- [x] **Device and capture.** The paired iPhone 14 Pro recorded build 13 over Wi-Fi. A fresh named career took the party from onboarding to Stage 1-10 in one take. The test log identifies Fire Arrow, Fangs and Astral Arrow.
- [x] **Gameplay motion.** Across the 15 pre-combat shots, 53% of interior samples cleared the motion threshold, up from 0% in the first edit. This comparison uses the original game picture before any editorial effects. Sample at 15 Hz, omit the first frame in each shot, and count intervals where over 2% of the viewport changes luma by more than 10 of 255. This measures sizable movement; subtle idle effects can fall below the threshold.
- [x] **Combat cadence.** All three independently sampled 0.85-second attack intervals reached 60 visibly changing frames/s in the native take. The 60 fps master contains 1,580 frames, including the final deal.
- [x] **Picture and audio.** The 1180×2376 crop clears the system clock and recorder UI. Small pushes and feathered focus treatments guide attention through the menus and fight. The scored version mixes one passage of *The Blight Treant* with three synchronized game sound effects. Stereo loudness measured –16.4 LUFS integrated with a –2.4 dB true peak. The creator copy preserves the same picture with audio removed.
- [ ] **Publication approval.** Owner reviews the scored cut and promotional music rights before the press kit, App Store preview or featuring nomination goes public.
