---
type: execution-plan
status: active
created: 2026-11-17
updated: 2026-11-17
expires: 2026-12-01
---

# Trinket launch trailer

**Tell one story in about 25 seconds. Ranger and Wolf hunt the Blight Treant.** The viewer meets the pair, sees the card Ranger will use, recognizes the beast in the Forest, then sees how the pair take turns against it.

The [launch tracker](LaunchMarketing.md) owns distribution, approvals and spending. Follow the [standing workflow](../../AGENTS.md#route-and-read) and [verification policy](../Platform/Verification.md).

## Director’s plan

| Beat | What the viewer should understand | Picture and sound |
| --- | --- | --- |
| Choose the party | These are the two characters I’ll play. | Start during the hero selection gesture. Let Ranger’s name settle and keep the native Continue transition into Wolf’s portrait. Hold long enough to read Wolf’s name. |
| Set up one card | Ranger has a fire attack I can recognize later. | Open Fire Arrow from the actual ability grid. Hold on the illustration and its Burn trait. The fire art will reappear in the battle hand. |
| Pick the fight | The Blight Treant is our target. | Read the Forest stage and its boss name. Keep the tap into combat. The same Treant art stays visible across the transition, then Ranger and Wolf appear below it. |
| Play the hand | I choose a card, it travels to the enemy, and something changes. | Show the full drag and hit of Fire Arrow, then Wolf’s Pack Tactics and Ranger’s Bounty Shot. Keep the actual damage and status feedback. Use short labels for who played which card, with the hand, enemy, and damage numbers fully visible. |
| End on the result | The Treant wins this encounter. | Mark the time jump within the fight, then show Wolf fall, Ranger take the last shot, and the actual defeat screen. Give the result a beat before the Trinket title. |

Offer the viewer a single objective, a recognizable card, and time to see each choice take effect. The asset list for other clips still includes the merchant, Homestead, Spires, Labyrinth, Contracts and Voyage. Those belong in standalone clips organized around a player action.

Keep the screen framing fixed. Use the game’s transitions, cuts between actions, and one score across the film. Cut on a matching character, illustration, or visible state. Give the fight and its result more than half the runtime. Favor a readable damage result over an extra card play. Watch the export muted at phone size and check whether a first-time viewer can name the party, the target, and the effect of the first play.

## Recording one original on the iPhone

Use a physical iPhone running iOS 27 or later and Xcode 27. The phone renders and encodes the movie. Wi-Fi carries the UI test and transfers the finished file. This lets the director rehearse and retake without playing through a whole career. Professional game trailer editors use reproducible game states, clean footage and independent audio controls for this purpose. [GDC 2025 capture tooling, Matt Hackett](https://media.gdcvault.com/gdc2025/Slides/Hackett_Matt_Content-Ready_Game_Development.pdf) · [Derek Lieu’s capture toolkit](https://www.derek-lieu.com/blog/2018/5/1/the-best-debug-tools-for-game-trailer-capture)

1. Check the named device below. Enable a quiet Focus for the take and close iPhone Mirroring and Device Hub's live screen view. In Device Hub the physical iPhone supports screenshots. Its screen-record command returned CoreDevice error 1001 for the missing screen-recording capability. Apple's Device Hub video procedure applies to simulators. [Device Hub capture](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices) · [Wireless pairing](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
2. Use the capture command below. A standalone signed XCTest runner opens the installed game with a fresh named local career with cloud sync disabled. After the starter and ability shots, the game reloads that same career once to advance Forest stages 1–8 through its existing launch fixture. On build 13, preloading those stages before starter selection prevented Wolf confirmation. The recorder runs continuously through the reload; the edit removes it. Its companion development app uses Apple's ScreenCaptureKit picker and recording output to encode a single original MP4 on the iPhone. With the owner's authorization, the runner can press **Share Entire Screen**. Apple can require the owner to enter a passcode to enable UI automation. The helper records picture with the microphone off, writes into its own Documents folder, then finalizes the take. It stops automatically after six minutes if the test disconnects. [Apple's iOS capture sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios) · [Physical tour](../../Scripts/LaunchTrailer/PhysicalTour.swift) · [Recorder](../../Scripts/LaunchTrailer/Recorder.swift)
3. The test drives the same Ranger and Wolf through one continuous recording. It marks the gesture before sending input and saves generous source windows in `handles.json`. The capture command applies the edit recipe to write a rough `keep.json`. Use the handles to keep the actual Ranger confirmation, the Treant’s entry, and the damage or result from this take. The recorder passes through the required Forest merchant on the route to the boss. Cut that stop out of the story. The host retrieves the original and the timestamps over the paired connection. Keep the raw MP4, cue map, test log and build identity together. Compare the first mode transition and the last card impact against the cues to check alignment. Adjust keep boundaries in the edit list where the touch or action lands late. Every visible shot must come from this take.
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

Use one continuous passage of *The Blight Treant* under the picture. Sync the musical lift to entering the boss encounter and add the game’s card sounds at the actual attacks. Resolve the score across the title. Confirm promotional music rights before sharing. [Music catalog](../../MusicManifest/music.tsv)

The default run disables audio for that launch. If an original later contains isolated in-game sound, mix it with `--keep-source-audio`. For the current cut, use score and the bundled attack sounds. Each optional timeline `sounds` entry supplies the bundled SFX `id`, its shot-relative time `at`, and `gain_db`. Check the current take for card IDs and damage types before reusing the cues.

~~~sh
python3 Scripts/edit-launch-trailer.py \
  --source "$TAKE/continuous.mp4" --timeline "$EDIT" \
  --soundtrack "$ASSET_ROOT/Sounds/Game Sources/Music/The Blight Treant.mp3" \
  --music-offset "$MUSIC_OFFSET" --crop 1180:2376:0:150 --videotoolbox \
  --output "$TAKE/trinket-press-60.mp4"
~~~

A shot can supply a viewport-sized PNG in `graphic` for a caption. The press timeline can add an `end_card` with a PNG and its dwell in `seconds`. Paths resolve beside the timeline. The App Store timeline ends on gameplay.

The editor checks the most active 0.85 seconds of each marked boss play and records the whole-play measurement. For an editor-selected sample, supply one `--motion-span START END` in source seconds per play. Use the 60 fps portrait master for press and social distribution. The App Store version uses the gameplay timeline, the same fixed framing and a 30 fps encode. Replace `--videotoolbox` with `--app-store` and choose a separate output filename. [App Store Connect delivery specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)

## Review and release

Use `story-v3/Trinket-The-Blight-Treant-Story-60.mp4` under `.DerivedData/Deliverables/Release/LaunchMarketing-Nov17/` in the primary checkout. `take-03/` contains the original Wi-Fi iPhone recording, clock, and gesture log. `story-edit.json` and `store-edit.json` give the exact source windows, graphics, and sound cues. Earlier cuts remain in their original folders.


- [ ] **Story edit.** Review the new cut at phone size in QuickTime. Watch once muted and once with the score and card sounds.
- [ ] **Deliverables.** Verify the 60 fps master, its silent creator copy, and the 30 fps App Store preview.
- [ ] **Publication approval.** Review the cut and promotional music rights before the press kit, App Store preview, or featuring nomination goes public.
