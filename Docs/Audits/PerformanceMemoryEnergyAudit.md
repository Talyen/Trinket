# Performance, Memory & Energy Audit

Goal: Catch static performance/memory/energy hazards agents can fix; leave Instruments deep-dives as optional human follow-up.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Run static probes, fix up to **3** high-confidence issues (retain cycles, `AnyView`, background tick not pausing). Do **not** relocate battle simulation off `@MainActor` unless architecture docs already require it — easy to introduce races.

## Hard stops

- No speculative MainActor offloading of `BattleEngine` / session ticks.
- No broad `[weak self]` rewrites without a proven cycle (see [BugHuntingAudit.md](BugHuntingAudit.md)).
- Instruments recipes are optional and may be unavailable in cloud agents — skip without failing the audit.

## Part A — Static probes (required)

```bash
rg -n '\bAnyView\b' --type swift -g '!*Tests*' -g '!**/Generated/*'
rg -n 'var\s+\w+Delegate\s*:' --type swift -g '!*Tests*'
rg -n 'NotificationCenter\.default\.addObserver|notifications\(named:\)' --type swift -g '!*Tests*'
rg -n 'Timer\.scheduledTimer|Timer\.publish' --type swift -g '!*Tests*'
rg -n 'scenePhase|ScenePhase|\.background' --type swift -g '!*Tests*' Trinket/
rg -n 'TimelineView' --type swift -g '!*Tests*'
```

### Checks

- Prefer `@ViewBuilder` / generics over `AnyView`
- Delegates: `weak` when `AnyObject`
- Observers / notification streams cancelled or removed
- Prefer `ContinuousClock` / `SuspendingClock` + `Task.sleep(tolerance:)` over repeating `Timer` for app logic
- Battle / animation work pauses or throttles on `ScenePhase.background`
- Do not drive business logic solely from `TimelineView` frames

## Part B — Instruments (optional human)

Only when Xcode + device/Simulator profiling is available:

1. **Leaks** — tab switch + battle start/end; watch retain cycles
2. **Time Profiler** — battle + fast tab switches; watch main-thread save I/O
3. **Energy** — start battle, background app; energy should drop (loop paused)

Document optional findings in the PR body — not in this file.

## Fixes

- Replace `AnyView` with typed builders
- Weak delegates; cancel tasks/observers on teardown
- Pause battle ticks on background
- Add tolerance to periodic sleeps where appropriate

## Verification

```sh
./Scripts/lint.sh
./Scripts/build.sh
./Scripts/test.sh unit <FocusedClass>   # if session/tick logic changed
```

## Commit

```
perf(<scope>): <imperative fix>

- <static probe addressed>
- <verification>

User-Facing: no
```
