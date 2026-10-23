# Native input reference

Trinket's adaptation of Apple's Xcode 27.0 (`27A266a`) device-interaction export,
obtained October 2, 2026. [The skill](../SKILL.md) owns session lifecycle, exact
device targeting and tool selection; this reference covers observation and event
syntax only. Current tool metadata takes precedence over snapshot syntax.

## Reading hierarchy files

Capture before acting, read the hierarchy and inspect the screenshot. Use the
actual nested control, such as a Switch or Slider, rather than a nearby label.
A hierarchy entry reports its origin, size and calculated touch point:

```text
UIButton "Continue" {{110, 205}, {80, 30}}, hitPoint: {150.0, 220.0}
```

Prefer the latest `hitPoint`. After an ineffective hit-point tap, recapture before
using screenshot-estimated coordinates. `isRemoteLeafPlaceholder` entries omit
children and may require that fallback. Inspect the full-size image when a
thumbnail is insufficient. Current tool constraints still govern permitted input.

### Multiple applications

An `activationBundleId` annotation identifies a different application that must
be activated before interaction. Pass that identifier to the capture/input tool;
it can be supplied without an interaction command. Activate only when needed.
A screenshot of the wrong app or inactive display establishes no Trinket result.

## Interaction command syntax

Supply these strings through the managed terminal's `event` command, or the direct
session tool selected under the skill. This is the iOS subset of the Apple snapshot:

| Command | Description |
|---|---|
| `t <x> <y> [duration]` | Tap at coordinates with optional hold duration |
| `d <x> <y>` | Double tap |
| `t <x1> <y1> f <x2> <y2> [duration]` | Swipe from (x1,y1) to (x2,y2) |
| `drag <x1> <y1> <x2> <y2> [holdDuration] [moveDuration]` | Drag-and-drop: press-and-hold at (x1,y1) then slowly move to (x2,y2). Use for reordering lists or drag-and-drop targets |
| `mt [x1 y1, ...] dur [x1 y1, ...] dur ...` | Multi-touch sequence. Each `[...]` keyframe lists touch positions (`x y`). The duration after each block is the travel time to the next keyframe; for the last block it is the hold time before lifting. A finger ends when its slot is an empty comma entry (e.g. `[, x y]`) **or** when the frame has fewer entries than the finger's index — both are equivalent. A finger that reappears in a later keyframe after lifting starts a new tap. |
| `b h/p/u/d [duration]` | Hardware button: h=Home, p=Power, u=VolUp, d=VolDown |
| `sender keyboard kbd <text>` | Type text; **must be the last command in the chain** — all content after `kbd ` is taken verbatim (multiple spaces preserved). For special characters use `\u{XXXX}` Unicode escapes: `\u{000A}` (return/newline), `\u{0009}` (tab) |
| `w duration` | Wait for a duration without any work |
| `orientation faceDown/faceUp/landscapeLeft/landscapeRight/portrait/portraitUpsideDown` | Set device orientation (iOS only) |


For example, `t 200 600 f 200 200 0.3` scrolls upward;
`drag 100 300 100 100 0.5 1.5` holds for 0.5 seconds and moves over 1.5 seconds.
`mt [100 200] 0.5 [100 200] 1.0 [300 400] 0.2` holds, moves, then lifts.
`sender keyboard kbd submit\u{000A}` types and submits. These are syntax examples;
choose coordinates from the current observation.

## Observation and bounded recovery

After every action, capture again and verify its result before choosing another.
For a launch/loading transition, recapture once meaningful controls are available;
do not interact with controls still loading or add routine delays after every event.
If the app is absent or an action has no effect, refresh the observation and target,
then try one relevant retry/alternative. If it still fails, report the limitation
or use existing focused coverage under the skill's recovery rules.

Distinguish observed functional/layout defects and unexpected exits from expected
disabled/empty states, native permission dialogs and temporary loading/animation.
Retain the process identity and available runtime output for an unexpected exit.
Screenshots establish layout; interactions or recordings establish the behavior or
motion actually exercised. Report incomplete evidence without substituting a test
pass for visual review.
