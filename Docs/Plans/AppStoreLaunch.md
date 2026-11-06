---
type: execution-plan
status: active
created: 2026-11-06
updated: 2026-11-06
expires: 2026-11-20
---

# Trinket App Store launch plan

Ship the first public iPhone and iPad release with iCloud progress sync and the
one-time Full Game unlock. Freeze feature scope for the candidate. Accept fixes
that close a release gate, then refresh the affected evidence on the resulting
revision. Follow the [standing workflow](../../AGENTS.md#route-and-read) and
[verification policy](../Platform/Verification.md).

Engineering can start CI triage while the App Store Connect owner checks the
listing and account. The owner also needs two test devices, disposable saves,
and sandbox purchase accounts. Agree on the public version and launch territories
before preparing the release commit. TestFlight upload, App Review submission,
and release publication each require owner authorization.

## 1. Close the verification failures

The November 6 baseline is `19efbb435`. Push CI passed, and the nightly device
Release compile and Smoke passed. Start with these failures from the same revision.

| Failure | First diagnostic |
|---|---|
| FullUI battle lifecycle | Rerun `BattleLifecycleUITests/testBackgroundedTalentConfirmationsFinishAndLeaveTheNextStagePlayable` on the failing toolchain. Use the retained result and app state to determine why the app failed to enter the background before reactivation. [FullUI job](https://github.com/Talyen/Trinket/actions/runs/42235920702/job/127971984915) |
| Engine native parity | Inspect the native diagnostics and iOS comparator proof. Identify the mismatched evidence field and regenerate matching proof before drawing conclusions about engine behavior. [Parity job](https://github.com/Talyen/Trinket/actions/runs/42235920702/job/127977804209) |
| iOS 18 reward navigation | Reproduce `CriticalAccessibilityUITests/testRewardClaimRemainsReachableAndReturnsUnderRequestedSettings` on iOS 18. Compare the captured Play screen and stage state when the test cannot find the Stage 1-2 action. [Compatibility job](https://github.com/Talyen/Trinket/actions/runs/42245210926/job/127989567132) |
| Compact, Duo, and tablet coverage | Inspect each profile's failure. Compact exhausted simulator boot recovery. Rerun infrastructure failures on a healthy runner and require actual profile execution. [Player coverage run](https://github.com/Talyen/Trinket/actions/runs/42245210926) |

- [ ] Run the exact failed journeys first. Preserve their assertions and resolve
  confirmed game, test, and runner causes in their owning code.
- [ ] Prepare the formal version and release artifacts through
  [Release](../Platform/Release.md#produce-release-artifacts). On the resulting
  commit, collect green push CI, the unsigned device Release compile, FullUI,
  parity, and the required player coverage on iOS 18 and the current supported
  release. Use [Hosted CI and player acceptance](CIHostedVerification.md) for the
  detailed profile and localization work. Record the executed scope, Xcode build,
  runtime, and exact commit for each gate.

## 2. Confirm App Store Connect prerequisites in parallel

- [ ] Open the existing app `6811284921` and Full Game product `6811501717`.
  Inventory which fields, assets, and approvals are complete and which need
  owner action. Confirm the Paid Apps Agreement, banking and tax status, product
  availability, localized price, and Family Sharing against the
  [purchase checklist](../Platform/Purchases.md#before-release). Resolve account
  or product blockers before the device purchase pass.
- [ ] Confirm the listing and purchase localizations, review contact, age rating,
  content rights, export compliance, and applicable regional declarations.
  The support and privacy URLs were reachable on November 6. Reconcile their
  content and the App Privacy answers with the candidate's purchases, iCloud
  behavior, and diagnostics. Use the existing
  [submission draft](../Platform/AppStoreMetadata.md) for field ownership.

## 3. Qualify the signed candidate on devices

The local receipt for cloud-enabled TestFlight `0.1.0 (66)` records an upload from
`50139150e` with beta verification. Confirm its availability and suitability as
an upgrade source. Identify the new candidate by source commit, marketing version,
build number, and signed archive.

- [ ] Use the [TestFlight workflow](../Platform/Release.md#local-testflight-deployment)
  for the exact candidate, with qualified hosted journey proof and the documented
  FullUI release gate. Use a shipping Xcode and SDK that satisfy
  [Apple's upload requirements](https://developer.apple.com/news/upcoming-requirements/).
  Verify the exported Production entitlements and cloud setting. Confirm Apple
  processing and installation, and retain the receipt, archive, and matching dSYMs.
- [ ] Upgrade a populated beta save in place. Verify Campaign progress, party,
  equipment, Homestead, offline play, relaunch, and recovery after interrupting a
  battle or terminating after a reward claim. Review matching TestFlight feedback,
  crash reports, and physical-device artwork, frame, memory, and thermal evidence.
  Use [player coverage](../Platform/PlayerCoverage.md) for the device scope.
- [ ] Compare prior CloudKit results with the candidate and list the cases that
  need fresh evidence. Keep Development and Production observations separate.
  On two devices, verify import and merge of independently earned progress,
  offline reconnect, and preservation of accepted actions. Close applicable gaps
  around account changes, reset and offline rejoin, Homestead, and rollback with
  disposable saves. [CloudKit release checks](../Platform/CloudKitPreShipChecklist.md)
- [ ] On the signed candidate, load the real sandbox offer in **Options → Unlock
  Full Game**, purchase, relaunch, and restore. Confirm that the offer works from
  free play, access survives a progress reset, and restore works independently
  of iCloud. Verify eligible Family Sharing, pending approval and denial/retry,
  and refund or revocation using the applicable live sandbox paths.
  [StoreKit release checks](../Platform/Purchases.md#before-release)

## 4. Submit and release

- [ ] Capture representative portrait gameplay from the signed candidate. Start
  with battle, Campaign, and a progression screen on iPhone and iPad. Add the
  separate Full Game offer screenshot for review. Check localized text and upload
  the assets in the required device slots. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [ ] Review one candidate handoff with the owner. Record the commit and Apple
  build ID, linked CI runs, device and OS results, reused evidence, screenshots,
  and portal status. Hold submission for missing required coverage, unresolved
  save or purchase failures, or a portal blocker. If the build changes, recheck
  its identity and refresh the gates affected by the change.
- [ ] With submission authorized, select the verified build on the matching app
  version and include the first Full Game non-consumable in the same submission.
  Give App Review the Options path to the offer and explain offline play. Select
  manual release, then publish after approval and owner sign-off. Verify the live
  listing in the intended storefronts and triage reports against the shipped build.
  [Apple purchase submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
  · [Trinket release procedure](../Platform/Release.md#shipping)

Retain the candidate handoff with the release evidence. After launch verification,
move durable changes into their canonical owners and remove this plan.
