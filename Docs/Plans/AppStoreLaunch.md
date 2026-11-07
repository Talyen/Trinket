---
type: execution-plan
status: active
created: 2026-11-06
updated: 2026-11-07
expires: 2026-11-20
---

# Trinket App Store launch plan

Ship the first public iPhone and iPad release with iCloud progress sync and the
one-time Full Game unlock. Freeze feature scope for the candidate. Accept fixes
that close a release gate, then refresh the affected evidence on the resulting
revision. Follow the [standing workflow](../../AGENTS.md#route-and-read) and
[verification policy](../Platform/Verification.md).

Engineering and App Store Connect preparation are authorized, including TestFlight
distribution. App Review submission remains pending at the owner's request.
Use the existing iCloud test results and deliberate test saves for candidate checks.
A second physical device is not a release gate. The existing storefront
territories guide candidate preparation.

## 1. Close the verification failures

The November 7 baseline is `0e554659c`. Push CI passed. The latest nightly
passed the device Release compile, Smoke, all package suites and engine native
parity. Close the remaining failures below before qualifying the public candidate.

| Failure | First diagnostic |
|---|---|
| Script gate | The stalled-boot fixture failed its five-second wall-time assertion after the watchdog correctly returned a timeout. Retain the one-second boot deadline and bound the fixture independently. [Gate job](https://github.com/Talyen/Trinket/actions/runs/42377855957/job/128419073576) |
| Full Game refund and repurchase | The test confirmed revoked access and preserved progress, then exhausted its eight-second product-lookup wait after relaunch. The offer attachment shows loading. Verify the complete journey with a StoreKit service deadline. [FullUI job](https://github.com/Talyen/Trinket/actions/runs/42377855957/job/128424861387) |
| Reward return and native profiles | Compact reward return passed; tablet reward return and native settings profiles stopped on simulator prerequisites. Require actual execution on iOS/iPadOS 26 and 27. Retry a confirmed prerequisite failure once on a fresh runner. [Player coverage run](https://github.com/Talyen/Trinket/actions/runs/42382791768) |
| Duo rotation | The requested orientation changed while the app window stayed portrait. Establish actual geometry through the supported simulator controls; preserve the window-resize assertion. [Rotation job](https://github.com/Talyen/Trinket/actions/runs/42382791768/job/128433767903) |

Keep App Store compatibility at iOS and iPadOS 18.0. Automated launch coverage
starts at 26 for both platforms.

- [ ] Run the exact failed journeys in the launch matrix first. Preserve their
  assertions and resolve confirmed game, test, and runner causes in their owning code.
- [ ] Prepare the formal version and release artifacts through
  [Release](../Platform/Release.md#produce-release-artifacts). On the resulting
  commit, collect green push CI, the unsigned device Release compile, FullUI,
  parity, and player coverage on iOS and iPadOS 26 and 27. Use
  [Hosted CI and player acceptance](CIHostedVerification.md) for the detailed
  profile and localization work. Record the executed scope, Xcode build,
  runtime, and exact commit for each gate.

## 2. Confirm App Store Connect prerequisites in parallel

- [x] Audit app `6811284921` and Full Game product `6811501717`. The Paid Apps
  Agreement, banking, tax and trader status are active. The owner accepted the
  updated Developer Program License Agreement on November 7. Full Game is $4.99
  in the U.S., with Family Sharing enabled. The draft app is free and available
  in the U.S. on release, matching the existing purchase storefront.
- [x] Prepare version `1.0.0` with manual release, all nine listing and purchase
  localizations, review contact and cloud-enabled review notes. The owner
  confirmed content rights; the portal declaration is saved. Age-rating answers
  are complete. App Privacy reports Data Not Collected, consistent with local
  data, private iCloud sync and Apple-managed purchases/diagnostics. Support and
  privacy URLs are configured. [Field ownership](../Platform/AppStoreMetadata.md)
- [ ] Finish screenshots, the Full Game review image and candidate build
  association. Recheck exported encryption and Production entitlements with the
  signed archive. Keep the app and purchase out of App Review.
- [x] Verify the requested iPad sizing before store capture. The 13-inch iPad Pro
  simulator on iPadOS 27.0 showed the larger hand, the center card barely clipping
  the bottom edge, and combatants clear of the fan. Seven focused layout tests
  passed, including existing phone and Duo checks. Playing all three cards dealt
  the next hand with normal turn timing. The screenshot launch's sixty-second
  turn delay is intentional; it is not the shipping default. Refresh hosted
  qualification after landing these layout changes.

## 3. Qualify the signed candidate on devices

Cloud-enabled TestFlight `0.1.0 (66)` from `50139150e` is processed and assigned
to Personal Testing. The connected iPhone currently has `0.1.0 (6)` installed;
preserve its existing save as the upgrade source. Identify the new candidate by
source commit, marketing version, build number, and signed archive.

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
- [x] Reuse the existing iCloud test results, confirmed by the owner on November 7.
  Source review found no sync, schema or merge behavior changes since build 66.
  Keep Development and Production observations identifiable in the handoff;
  investigate affected save-preservation behavior if candidate changes invalidate it.
  [CloudKit release checks](../Platform/CloudKitPreShipChecklist.md)
- [ ] On the signed candidate, load the real sandbox offer in **Options → Unlock
  Full Game**, purchase, relaunch, and restore. Confirm that the offer works from
  free play, access survives a progress reset, and restore works independently
  of iCloud. Verify eligible Family Sharing, pending approval and denial/retry,
  and refund or revocation using the applicable live sandbox paths.
  [StoreKit release checks](../Platform/Purchases.md#before-release)

## 4. Prepare the handoff; hold submission

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
