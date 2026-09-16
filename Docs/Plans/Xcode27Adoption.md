---
type: execution-plan
status: active
created: 2026-09-16
updated: 2026-09-16
expires: 2026-10-14
---

# Xcode27Adoption

## Objective

Adopt Apple's recommended posture for the iOS 27 transition: build with the
latest stable Xcode / iOS 27 SDK once its hosted runner leaves preview, while
keeping a single binary that still supports the iOS 26 deployment minimum with
`#available` branches. No split-brain toolchain after the flip; no forced
player upgrade to iOS 27.

Durable policy stays in its owners; this plan owns only the migration steps.

- [Platform support](../Platform/ApplePlatformReference.md#platform-support) owns the OS window and beta/stable policy.
- [New iOS release readiness](../Platform/Verification.md#new-ios-release-readiness) owns the adoption checklist.
- [Toolchain ladder](../../Scripts/Reference.md#toolchain-ladder) owns how CI/local select Xcode.

## Baseline and constraints (verified 2026-09-16)

- Local: macOS 27.0 (26A428), Xcode 27.0 (27A266a), Swift 6.4. CI required gate runs `macos-26`, auto-selects Xcode 26.6 / Swift 6.3.3, which rejects `swift-tools-version: 6.4`.
- Repo: `swift-tools-version: 6.2` in all 9 packages, `.swiftformat 6.2`, `SWIFT_VERSION: "6.0"` language mode (valid on both toolchains), deployment target iOS 26.0 in `project.yml` and packages.
- Prior attempt `1799f5bf` (6.4 bump) failed CI on package resolution; reverted in `711da5be` (CI green on `35127439958`). That revert is the rollback template.
- GitHub `xcode-27` / `xcode-27-xlarge` image (arm64 only) is public preview as of the Sept 10 changelog; previously ran on macOS 26, now runs on macOS 27. Preview caveats: possible instability, queue/capacity balancing over coming weeks.
- Apple posture (authoritative docs): one binary across OS versions with conditional compilation and `#available` runtime checks; deployment target is the earliest supported OS, Base SDK is newest; target one or two older OS versions rather than requiring latest ([Running code on a specific version](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/)). Beta toolchains upload but only RC/stable submit; beta build-machine OS poisons the binary (ITMS-90111). Apple now accepts Xcode 27 RC submissions; from April 2027 submissions must build with the iOS 27 SDK.

## Plan

- [x] Phase 1 — Preview signal without destabilizing required CI.
  - Superseded by owner direction 2026-09-16 ("proceed with all", no split): prior evidence stands in for the advisory leg — local Xcode 27.0 (27A266a) iteration plus CI failure `1799f5bf` proving `macos-26`/Xcode 26.6 rejects `swift-tools 6.4`. Moving required CI directly to `xcode-27` preview instead of adding a separate advisory job.
  - Record Xcode build, SDK, simulator runtime, and macOS host per [readiness step 4](../Platform/Verification.md#new-ios-release-readiness) so beta evidence stays distinguishable.
  - Run existing focused journeys on the 27 runtime (Play, Collection, Homestead, Options, detail sheet, battle) for safe areas, chrome, legibility, hit targets, card input, dismissal, feedback; check icon appearances.
- [x] Phase 2 — Flip required toolchain (executed on preview per owner direction; GA re-verification still owed).
  - ~~Trigger: GitHub marks `xcode-27` GA/stable (not preview)~~ Waived: owner accepted preview-required risk for a unified toolchain.
  - Change 6 `runs-on: macos-26` lines to `xcode-27` in `tests.yml` (assets-gate, build, unit, smoke, exhaustive) and `gate.yml` (gate). No `macos-27` label exists under the per-Xcode image model.
  - Re-land version bumps: `swift-tools-version: 6.4` (9 packages), `--swiftversion 6.4`, `balance-sweep.sh` comment, `ApplePlatformReference.md` minimum, friction note. Keep `SWIFT_VERSION: "6.0"` (language mode `6`, not `6.4`).
  - Re-apply 6.4-only formatting (`CombatFeedbackRasterPool` trailing comma) via `format.sh`; confirm `format.sh --lint` clean.
- [ ] Phase 3 — Readiness verification on the new toolchain.
  - Generation idempotence (`generate.sh` + `assert-generated-output.sh`), app Release compile, routed package/smoke checks.
  - Save/relaunch, interrupted battle, purchase/restore via owning fixtures; physical audio/haptics on device only.
  - Exercise both runtimes: retained iOS 26 path plus newest 27 path, including both branches of every new availability check. Confirm leased simulator runtime explicitly; SDK alone is not coverage.
  - No new 27-only API without a 26 fallback (`withTaskCancellationShield`, `UniqueArray`/`Iterable`, non-copyable types already evaluated and excluded for the 26 minimum).
- [ ] Phase 4 — Close out.
  - Fold durable rules into `ApplePlatformReference.md#platform-support` and `Scripts/Reference.md#toolchain-ladder` only (link, don't duplicate).
  - Record outcome in `Archived/README.md`, delete this plan, report verification.

## Non-goals

- Bumping the deployment minimum to iOS 27. Early development does not override Apple's 1–2 older versions guidance or force player upgrades.
- Permanent dual full-matrix CI. Preview leg is advisory and temporary; post-flip, 26 coverage is retained-runtime checks, not a second full matrix.
- Device-matrix or snapshot-suite expansion merely to record the transition.

## Risks and rollback

- Preview queueing/instability blocking signal: mitigated by `continue-on-error` + nightly/dispatch scope in Phase 1; never a push gate until GA.
- Tool drift (SwiftFormat/SwiftLint/XcodeGen pins, cache keys, simulator boot): re-pin via `tool-versions.env`, compare restore/build/save durations together.
- Submission block (beta toolchain/OS stamp): never ship TestFlight/App Store builds from preview; required gate stays submittable until GA flip.
- Rollback: revert `runs-on` + version bumps exactly as `711da5be` did; `swift-tools 6.2` builds on both toolchains.

## Notes

Local Xcode 27 already provides new-toolchain iteration signal; CI main stays submittable. Four other active plans exist (`ArtworkPreparationHitches`, `CloudKitLaunchPreparation`, `PerformanceRemediation`, `SimplificationFollowup`); this plan touches only CI labels, toolchain pins, and platform docs, with no battle/content/persistence behavior change.
