# Memory and Energy Investigation

Use measured device evidence for memory, battery, thermal, and lifecycle regressions.
Simulator-only observations can identify leads but cannot establish a shipping
budget or improvement.

## Memory workflow

1. Reproduce on a named device/OS/build configuration from a cold launch.
2. Record process footprint at launch, after visiting the affected surfaces, after
   returning to Play, and after a representative extended session.
3. Use Instruments Allocations and Leaks plus Xcode Memory Graph to distinguish live
   caches, retained view/session graphs, leaked objects, and transient decode peaks.
4. Repeat the same journey after the change and compare peaks and settled footprint.
5. Verify cache eviction and scene background/foreground behavior; a lower peak that
   produces repeated decode churn is not automatically an improvement. Launch and
   imminent-destination artwork pins are hitch prevention — do not release the
   first-interactive working set after warmup to lower the peak.

For art inputs, `./Scripts/report-art-memory.sh` estimates full-catalog RGBA decode
cost. It is a catalog-sizing signal, not expected simultaneous residency. Current
investigation thresholds:

| Signal | Threshold | Status |
|---|---:|---|
| Full generated art catalog estimate | 1024 MiB | Enforced only when `report-art-memory.sh --enforce` is requested |
| Resident prepared artwork | 240 MiB | Diagnostic target; validate on device before enforcing |
| Total process footprint | 400 MiB | Diagnostic target; validate on representative devices before enforcing |

Change a threshold only with a recorded device class, scenario, before/after
evidence, and the user-visible tradeoff.

## Energy and thermal workflow

1. Reproduce on device with Low Power Mode and thermal state recorded.
2. Capture Instruments Energy Log and Time Profiler for the same fixed-duration
   journey.
3. Inspect idle clocks, timers, display-link work, audio/video playback, background
   tasks, persistence churn, and repeated image decode.
4. Confirm that backgrounding parks or cancels work and foregrounding restores one
   owner without duplicate timers or playback.
5. Compare CPU, wakeups, network, GPU activity, and thermal behavior before and after.

## Reporting

Report revision/dirty state, device and OS, build settings, scenario/duration,
thermal and Low Power Mode state, instruments used, peak and settled memory,
energy/CPU/wakeup observations, retained-owner evidence, and functional verification.
Do not claim a production improvement when device evidence is missing.
