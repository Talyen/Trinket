---
type: execution-plan
status: active
created: 2026-11-17
updated: 2026-11-17
expires: 2026-12-01
---

# Trinket launch trailer

**Make one 28.5-second portrait trailer from one continuous run on the physical iPhone over Wi-Fi.** A new player chooses two characters, sees what they can build and where they can take them, then watches that party fight the Forest boss. Preserve the order of events. Leave the recorder running through travel, scrolling, loading and exits. One edit removes those intervals.

The [launch tracker](LaunchMarketing.md) owns distribution, approvals and spending. Follow the [standing workflow](../../AGENTS.md#route-and-read) and [verification policy](../Platform/Verification.md).

## What to record

| Final time | Subject | Action to keep and why it earns the time |
| --- | --- | --- |
| 0.0–1.5 | Hero selection | Open directly on the real onboarding carousel with Ranger framed and the name readable. Show the selection settling if that motion reads at phone size. |
| 1.5–3.0 | Companion selection | Match the framing on Wolf. Let the viewer recognize the second character before cutting. Both faces return in combat. |
| 3.0–4.5 | Abilities | Open Ranger's basic ability choices in Collection. Land on the enlarged Fire Arrow illustration and its name. Save a little motion at the start if the text remains legible. |
| 4.5–6.0 | Items | At the Forest merchant, open one actual offer. Fill the shot with the item art and its properties. Avoid implying that this item was earned or equipped. |
| 6.0–7.5 | Homestead | Land on the Homestead overview with the buildings and resource wallet visible. Let the viewer take in the change of scale. |
| 7.5–9.5 | Campaign | Keep 0.8s of the illustrated Campaign entry, then 1.2s of the Forest chapter with its stage path or active encounter. |
| 9.5–11.5 | Spires | Keep 0.8s of Spires artwork, then 1.2s on Cinder Spire's climb with its floors visible. |
| 11.5–13.5 | Labyrinth | Keep 0.8s of Labyrinth artwork, then 1.2s on the floor map where branching paths explain the mode. |
| 13.5–15.5 | Contracts | Keep 0.8s of Contracts artwork, then 1.2s on the illustrated jobs board. Frame the offers and their different difficulties. |
| 15.5–17.5 | Voyage | Keep 0.8s of Voyage artwork, then 1.2s on a destination's route preview. End on a region the viewer can recognize. |
| 17.5–26.5 | Boss combat | Reveal **The Blight Treant** for 1.5s, then keep two 3.75s action windows. The hand, the choice and the consequence should read together. Retain an enemy answer or visible status change. |
| 26.5–28.5 | Closing image | Hold on the real battlefield after the exchange, or on victory if the run earns it. Finish on the strongest settled frame. |

Use The Blight Treant in Stage 1-10 for the first run. It is an identifiable, animated Campaign boss reachable with the same Ranger and Wolf the viewer saw at onboarding. Fire Arrow also gives the editor a clearly illustrated ability to look for in combat. The hand is dealt by the real game. Check the footage before describing a particular card play. The Blood Countess on Sanguine Court floor 10 is a later option if a separate capture career can reach her during the same run. [Stages](../../ContentManifest/stages.tsv) · [Enemies](../../ContentManifest/enemies.tsv) · [Party abilities](../../ContentManifest/combatants.tsv)

## Recording one original on the iPhone

Use a physical iPhone running iOS 27 or later and Xcode 27. The phone renders and encodes the movie. Wi-Fi carries the UI test and transfers the finished file. This lets the director rehearse and retake without playing through a whole career. Professional game trailer editors use reproducible game states, clean footage and independent audio controls for this purpose. [GDC 2025 capture tooling, Matt Hackett](https://media.gdcvault.com/gdc2025/Slides/Hackett_Matt_Content-Ready_Game_Development.pdf) · [Derek Lieu’s capture toolkit](https://www.derek-lieu.com/blog/2018/5/1/the-best-debug-tools-for-game-trailer-capture)

1. Check the named device below. Enable a quiet Focus for the take and close iPhone Mirroring and Device Hub's live screen view. In Device Hub the physical iPhone supports screenshots. Its screen-record command returned CoreDevice error 1001 for the missing screen-recording capability. Apple's Device Hub video procedure applies to simulators. [Device Hub capture](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices) · [Wireless pairing](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
2. Use the capture command below. A standalone signed XCTest runner opens the installed game with a fresh named local career with cloud sync disabled. After the starter and ability shots, the game reloads that same career once to advance Forest stages 1–8 through its existing launch fixture. On build 13, preloading those stages before starter selection prevented Wolf confirmation. The recorder runs continuously through the reload; the edit removes it. Its companion development app uses Apple's ScreenCaptureKit picker and recording output to encode a single original MP4 on the iPhone. With the owner's authorization, the runner can press **Share Entire Screen**. Apple can require the owner to enter a passcode to enable UI automation. The helper records picture with the microphone off, writes into its own Documents folder, then finalizes the take. It stops automatically after six minutes if the test disconnects. [Apple's iOS capture sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios) · [Physical tour](../../Scripts/LaunchTrailer/PhysicalTour.swift) · [Recorder](../../Scripts/LaunchTrailer/Recorder.swift)
3. The test drives the same Ranger and Wolf through one uninterrupted app session. The host retrieves the original and the timestamps over the paired connection. Keep the raw MP4, cue map, test log and build identity together. Compare the first mode transition and the last card impact against the cues to check alignment. Adjust keep boundaries in the edit list where the touch or action lands late. Every visible shot must come from this take.
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

**Use one continuous passage of the game's soundtrack underneath the edited picture.** Start with The Blight Treant's own cue. Pick a 28.5-second passage that starts promptly, builds into the boss at 17.5s and resolves on the closing hold. Check whether a vocal competes with the UI or suggests synchronization with lyrics that are absent from the footage. If it does, audition Battle 1. Confirm promotional rights before sharing. Record the selected master, hash and offset. [Music catalog](../../MusicManifest/music.tsv)

The default run disables audio for that launch. The editor uses a separately supplied music file after all picture cuts, so leaving a mode never interrupts the score. If a later take can capture app-only audio with in-game music off, retain the synchronous card and impact sounds and mix the soundtrack underneath using `--keep-source-audio`. Verify that the audio stream actually contains clean game effects. Keep the microphone off. The first physical Mirroring proof contained video only.

~~~sh
python3 Scripts/edit-launch-trailer.py \
  --source "$TAKE/continuous.mp4" --timeline "$TAKE/keep.json" \
  --soundtrack "$ASSET_ROOT/Sounds/Game Sources/Music/The Blight Treant.mp3" \
  --music-offset "$MUSIC_OFFSET" \
  --output "$TAKE/trinket-press-60.mp4"
~~~

The editor checks the most active 0.85 seconds of each marked boss play and records the whole-play measurement. For an editor-selected sample, supply one `--motion-span START END` in source seconds per play. Set `MUSIC_OFFSET` to the chosen soundtrack start. The editor removes travel chronologically and produces a source-to-output cue sheet. Save a clean, music-free copy for creators using the same command without `--soundtrack` and a different output name. Read the opening and boss exchange with sound off, then listen for the score's entrance and ending. Leave room for card and impact sounds if the source contains isolated game effects. [Apple preview creative guidance](https://developer.apple.com/app-store/app-previews/) · [Professional trailer editing and creator assets](https://www.derek-lieu.com/blog/2023/2/4/how-to-make-game-trailers-for-influencers-and-content-creators)

For the U.S. iPhone App Store preview, run the same edit with `--app-store`, music, and a separate output filename. Apple accepts 15–30 seconds, a maximum of 30 fps, and 886×1920 portrait for iPhone 14 Pro. The profile preserves the aspect ratio and encodes H.264 with stereo AAC. Use the 60 fps native-aspect master for the press kit and social distribution. [App Store Connect delivery specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)

## November 17 capture and release tracker

The retained take is 184.57 seconds from a physical iPhone 14 Pro running Trinket 1.0.0 build 13. The timeline keeps 19 spans totaling 28.50 seconds. Ranger inspects Fire Arrow, the Forest merchant shows a Sapphire Ring, and the tour visits Homestead and all five modes. The Blight Treant fight includes **Astral Arrow** and **Fangs**. The two sampled attack animations measured 60.0 and 59.9 visibly changing frames/s. The raw movie uses variable frame timing and holds still artwork between interactions.

The press master uses a measured 1180×2376 crop that removes the iOS clock, return-to-recorder label and bottom margin. The App Store version fits that picture inside 886×1920 with its proportions intact. The soundtrack starts 15.01s into *The Blight Treant*, placing a musical accent at the boss reveal. Both edits preserve exactly the same shot order. The raw original and cue sheets live under `.DerivedData/Deliverables/Release/LaunchMarketing-Nov17/` in the primary checkout.

- [x] **Device connection.** Re-paired the physical phone wirelessly, enabled XCTest input, confirmed the named recording approval works unattended, and retrieved the native original.
- [x] **Native capture.** Two complete runs reached the boss. The second framed each illustrated mode card before selection. In-point, midpoint and out-point images showed the intended subject in all 19 shots. Use a constant-frame-rate review proxy when inspecting a held frame in the iPhone original.
- [x] **Earlier diagnostic.** A 74.99-second Mirroring rehearsal advanced the owner's normal career through Ranger and Wolf to Stage 1-1. A separate Xcode UI-test diagnostic video averaged 28.7 fps at 1178×2556. Subsequent trailer runs used named local careers.
- [x] **Picture cut.** Encoded a 60 fps press master and 30 fps App Store preview from one original. Both omit navigation, the checkpoint reload and the recording approval. The editor expands still-image holds before applying cuts so a static menu gets its full planned time.
- [x] **Sound mix.** A single stereo AAC music track measured –16.0 LUFS integrated and –2.4 dB true peak. The microphone was off. A music-free 60 fps cut uses the identical picture.
- [ ] **Publication approval.** Owner reviews the scored cut and promotional music rights in one pass. The music-free master is available to creators. Record approval before publishing the press kit, uploading an App Store preview or submitting the featuring nomination.
