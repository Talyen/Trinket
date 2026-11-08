---
type: execution-plan
status: blocked
reason: Seven iPhone screenshots approved; remaining gallery selection and signed-candidate device acceptance are pending; App Review remains on owner hold.
created: 2026-11-06
updated: 2026-11-08
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

## 1. Maintain the verified launch scope

The owner approved adapting the entire CI suite to the runner's available
toolchains, runtimes and working capabilities on November 7, including reduced
coverage. Prefer installed compatible environments over exact pins or mandatory
downloads. Record unavailable coverage explicitly; compiler errors, game assertions
and save/purchase defects remain failures. Never reuse unavailable scope as
passing test evidence. App Store compatibility remains at iOS and iPadOS 18.0;
automated coverage starts at 26 for both platforms.

- [x] Land and verify the iPad layout and CI repairs. Final hosted CI completed
  all seven package shards and six Smoke cases. The candidate also has an unsigned
  device Release compile, critical release proof and a FullUI assessment with
  23 passing cases. Retain exact source identities for these different runs.
- [x] Complete phone and tablet reward-return journeys and native-settings
  assessments. Each reward journey passed; each uncontrolled settings fallback
  passed five gameplay/navigation/merchant cases. Native text-size, Reduce Motion
  and native audits remain explicitly uncovered on the assessed runners.
- [x] Record installed runtime/model substitutions, English plus one rotating
  FullUI localization, deferred configurations and the known StoreKit denial-service
  gap. Keep complete localization and Duo rotation diagnostics available on demand.
  Live sandbox denial/retry and rendered language acceptance remain in sections 3–4.
- [x] Produce the signed candidate through [Release](../Platform/Release.md#produce-release-artifacts).
  The retained handoff identifies the candidate, executed scope, gaps, Xcode build,
  runtime and commit for each gate. Later CI-only repairs leave the candidate's
  game source unchanged. [CI policy](../Platform/VerificationInternals.md)
  · [Player coverage](../Platform/PlayerCoverage.md#ci-and-profiles)

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
- [x] Upload the Full Game review image. Apple processed the native English
  offer capture with a matching checksum and the purchase is Ready to Submit.
  The purchase remains unsubmitted.
- [x] Associate candidate build `1.0.0 (8)` with the draft store version. Readback
  confirms Prepare for Submission and manual release. The signed archive/export
  passed encryption, signature and Production entitlement checks with iCloud enabled.
- [x] Prepare 95 gallery candidates for owner review. Rate every original
  for composition, readability, game clarity, artwork and variety; replace the
  lowest 20 with new captures. Retain the App Store-style carousel, individual
  ratings, full-resolution originals and manifest. Add Homestead nodes and
  features, trinkets, Uniques, boss detail, Blood Countess combat with visible
  lyrics, and live combat frames with floating damage and attack motion.
- [ ] Upload only the owner's approved gallery selections. Keep the app and
  purchase out of App Review.
- [x] Verify the requested iPad sizing before store capture. The 13-inch iPad Pro
  simulator on iPadOS 27.0 showed the larger hand, the center card barely clipping
  the bottom edge, and combatants clear of the fan. Seven focused layout tests
  passed, including existing phone and Duo checks. Playing all three cards dealt
  the next hand with normal turn timing. The screenshot launch's sixty-second
  turn delay is intentional; it is not the shipping default. Hosted qualification
  passed after the layout changes landed.

## 3. Qualify the signed candidate on devices

Cloud-enabled TestFlight `1.0.0 (8)` from `64b9053db` is processed and assigned
to Personal Testing with Apple-confirmed symbols. The connected iPhone now has
`1.0.0 (8)` installed. The owner waived preservation of their personal beta save;
it is not an acceptance prerequisite. Use deliberate test saves for remaining
save checks. Identify the candidate by source commit, marketing version, build
number, and signed archive.

- [x] Use the [TestFlight workflow](../Platform/Release.md#local-testflight-deployment)
  for the exact candidate, with qualified hosted journey proof and the documented
  FullUI release gate. Use a shipping Xcode and SDK that satisfy
  [Apple's upload requirements](https://developer.apple.com/news/upcoming-requirements/).
  Verify the exported Production entitlements and cloud setting. Confirm Apple
  processing and internal availability, and retain the receipt, archive and matching dSYMs.
- [x] Confirm installation of candidate `1.0.0 (8)` on the connected iPhone.
- [ ] With deliberate test data, verify
  Campaign progress, party, equipment, Homestead, offline play, relaunch and recovery after interrupting a
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

- [x] Prepare 95 numbered portrait candidates across iPhone and iPad, covering
  combat, the Merchant, Play, Labyrinth, Collection, Homestead, character details,
  Mystery choices and equipment traits. The expanded pool has 80 phone and 15 tablet
  alternatives. All 40 originals, 24 replacement attempts and 23 requested feature
  captures have individual marketing ratings; four new tablet item sheets were
  rejected before retaining
  the final 20 replacements. The feature pass retained 21 additions, including
  Wheat Field, Blacksmith, Crucible, Wishing Well, crafting and wishing screens,
  three trinkets, two Uniques, the Blood Countess detail and her live lyrics.
  Two unmodified native video frames show floating combat text during attacks;
  the recordings and frame timestamps are retained. Two weaker feature captures
  were excluded. The preview preserves native aspect ratios without
  added image padding and keeps rejected captures out of the selection pool.
  The review gallery and manifest are retained with the AppStoreLaunch-Nov7 release
  deliverables. Capture source `7f7a02022` has the same game and UI source as
  candidate `64b9053db`; these are simulator captures from the hosted Debug product.
- [x] Capture the November 8 additions: eight random autoplay battle moments each
  against The Blight Treant (`89`–`96`) and Living Armor (`97`–`104`), plus the
  owner's current Explore screen on their physical iPhone 14 Pro (`88`). Native
  `devicectl` capture produced the unchanged 1179×2556 phone image; installed
  TestFlight version `1.0.0 (8)` was verified. The battle images are unchanged
  1206×2622 native simulator video frames. All 104 capture attempts are rated;
  retain all 16 requested random battle moments, including weaker transitions,
  for owner review. Recordings, sampling seeds and timestamps are retained in
  the AppStoreLaunch-Nov8 deliverables. The phone capture establishes the visible
  Explore layout; signed-candidate gameplay and purchase acceptance remain open.
- [x] Add Fox's expanded inspect pane (`105`) and 16 random Knight/Fox autoplay
  moments against The Blood Countess on Sanguine Court floor 10 (`106`–`121`).
  Boss Lyrics and Auto Battle were enabled; lyrics are visible in 15 frames,
  with one captured between phrases. All 17 images retain native 1206×2622
  pixels. Preserve the recording, sampling seed and timestamps with the
  Knight/Fox deliverables. All 121 marketing capture attempts have individual
  ratings; retain the requested random samples for owner review.
- [x] Retain the initial owner-approved iPhone selection from November 7:
  `01` Battle, `08` Ranger, `10` Rogue, `16` Wolf, `17` Bear,
  `72` Blacksmith, and `86` The Blood Countess detail. The selected originals and
  hashes are preserved in `selected-screenshots.json` and `selected-iphone/`
  within the release deliverables. Keep these seven selected when capture and
  review resume November 8; final ordering and the iPad selection remain open.
- [ ] Complete the owner's gallery selections, then upload the approved images in
  the required device slots. The separate Full Game review image is uploaded.
  Xcode's interaction tool currently lists only simulators, so physical interaction
  and purchase acceptance remain unverified.
  [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
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
