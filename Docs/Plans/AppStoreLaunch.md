---
type: execution-plan
status: blocked
reason: Ten iPhone and ten iPad screenshots approved; final ordering and signed-candidate device acceptance remain pending; App Review remains on owner hold.
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
- [x] Finalize the owner's ten iPhone screenshots, including Mud Elemental moment
  `146`. Remove all remaining unapproved alternatives. Rate all 156 capture attempts for
  composition, readability, game clarity, artwork and variety. Remove older
  unapproved images at the owner's request; preserve the ten approved originals,
  App Store-style carousel, current review package and audit metadata.
- [x] Prepare ten iPhone upload assets. Remove fully opaque alpha channels from
  `88`, `105` and `139`, preserving every decoded RGB pixel and the native dimensions.
  Keep byte-identical originals separately. The selected 1179×2556 and 1206×2622
  images match Apple's Dynamic Island medium-display category.
  [Current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [x] Capture and obtain owner approval for ten native portrait iPad counterparts.
  Prepare the 2064×2752 originals for Apple's required 13-inch display category.
- [ ] Finalize screenshot ordering for both device families. Preserve the owner's
  supplied selection order until a final App Store order is approved.
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

- [x] Lock the owner's updated November 8 iPhone selection:
  `08` Ranger, `10` Rogue, `16` Wolf, `72` Blacksmith,
  `86` The Blood Countess detail, `88` Explore on Ryan's iPhone,
  `98` Living Armor moment 02, `105` Fox inspect,
  `139` Blackfletch Unique detail, and `146` Knight/Bear versus Mud Elemental moment 06.
  Remove Slime Battle (`01`), Bear (`17`), Crucible (`77`) and Ranger talent categories (`133`).
  Preserve byte-identical originals and selected copies in the release
  deliverables, with hashes in `selected-screenshots.json`. Final ordering and
  the iPad set remain open. The ten-image iPhone selection is complete.
- [x] Replace the incorrect Wishing Well previews (`122`–`129`) with exactly two
  standard Collection Unique details: `139` Blackfletch and `140` Kingbreaker.
  Correct Collection's existing item launch route to resolve the Unique catalog.
  Verify both pages without a Wish action in the updated local Debug build.
  Blackfletch (`139`) is in the final set. Kingbreaker (`140`) and all talent
  alternatives were removed when the owner finalized the ten images. Preserve
  their ratings and deletion records as historical evidence.
- [x] Prune older unapproved gallery images and superseded review archives, as
  authorized by the owner. Rebuild the approved package and gallery around the
  ten approved originals and no older unapproved alternatives. Preserve audit metadata for all
  156 earlier attempts, including the 146 removed images. Retain the separate
  purchase review image, recordings, release artifacts and CI diagnostics.
- [x] Preserve capture provenance. Most retained images use hosted Debug source
  `7f7a02022`, whose game and UI source match signed candidate `64b9053db`.
  Explore (`88`) is an unchanged native 1179×2556 capture from the owner's iPhone
  14 Pro, with installed TestFlight `1.0.0 (8)` verified. It establishes the
  visible Explore layout; signed-candidate gameplay and purchase acceptance
  remain open. The two corrected Unique captures use a local build from `7007e47e6`
  plus the Collection launch-route fix; their source patch and build metadata are
  retained separately. This route correction is not in signed candidate build 8.
  The new battle frames use local source `b83553691`, whose app source matches
  `586eb15f5`: hosted app compilation, all seven package shards and six Smoke cases
  passed. Keep that source identity separate from the signed candidate.
  The carousel preserves native aspect ratios without image padding.
- [x] Capture sixteen mid-battle autoplay moments: eight Knight/Bear versus
  Mud Elemental frames (`141`–`148`) and eight Wizard/Library Owl versus
  Plague Doctor frames (`149`–`156`). Use Campaign Stage 1-3 and Serpent Hollow
  Floor 4, respectively, with native party selection and Auto Battle enabled.
  The owner selected `146`; remove the other fifteen marketing frames and the
  obsolete batch package. Retain the recordings, sampling windows and seeds,
  individual ratings, and the selected native frame in the final package.
- [x] Recreate the same ten scenes on iPad in portrait, as chosen by the owner.
  Retain 24 refreshed native 2064×2752 candidates (`181`–`204`): eight static counterparts,
  eight Ranger/Wolf versus Living Armor autoplay variants, and eight Knight/Bear
  versus Mud Elemental autoplay variants. Individually inspect and rate every
  image; preserve random sampling windows, seeds and native recordings.
  The 13-inch iPad Pro simulator runs iPadOS 27.0 with local Debug source
  `71b00f851`. Hosted run `42527753265` passed app compilation, all seven package
  groups and Smoke, with successful executed-coverage markers. Preserve native
  page inspections and card animations. The ten approved iPhone originals remain
  byte-identical. There are now 204 historical ratings, 20 approved current gallery
  images, 38 inactive iPad originals retained as evidence, and 146 historical
  deletions.
- [x] Record the owner's approval of static iPad counterparts `181`, `182`, `183`,
  `187`, `188`, `184`, `186`, `185`, Living Armor variant `191` and Mud Elemental
  variant `197`. Preserve this supplied selection order; final store ordering
  remains open. Each device family now has ten approved images.
- [x] Prepare the ten approved iPad upload assets. Remove fully opaque alpha
  channels from the eight static PNG copies, preserving every decoded RGB pixel
  and native 2064×2752 dimensions. Keep both battle PNGs and all selected originals
  byte-identical. Rebuild the twenty-image approved-original package and separate
  upload packages; remove unselected battle variants from the active gallery.
- [x] Correct the iPad layout issues exposed during screenshot review. Replace
  fixed inspection detents with native `.page` sizing; the 13-inch simulator now
  presents a 928×1312-point detail page instead of a 580×660-point form.
  Expand Explore with 40-point side margins and extra vertical padding while
  fitting Spires and Labyrinth above the tab bar. Scale floating combat feedback
  up to 2× with actual portrait dimensions while retaining peak-footprint fitting
  and stable, prewarmed 2× raster resolution.
  Verify the Ranger inspection, both Explore cards, native drag dismissal and
  live Living Armor autoplay feedback on iPadOS 27.0. Preserve before/after
  examples and the recording separately from owner-approved marketing images.
- [x] Refresh all 24 iPad marketing candidates after these layout corrections.
  Review every image and retain individual ratings, native recordings and random
  sampling provenance. The earlier `157`–`180` batch remains comparison evidence
  and must not be treated as captures of the corrected UI.
- [ ] Include the Collection route and iPad layout corrections in the signed
  release candidate before final device and purchase acceptance. Existing signed
  build 8 predates these source changes.
- [ ] Upload the final approved gallery in
  the required device slots. Use the native portrait 2064×2752 iPad originals in
  Apple's required 13-inch set and let smaller iPad display sets inherit Apple's
  automatic scaling. Preserve aspect ratios and full pixels; do not stretch,
  crop, pad or create unnecessary resized alternatives. Check the inherited
  previews in App Store Connect after upload; this scaling strategy is prepared,
  not yet configured in the portal. The separate Full Game review image is uploaded.
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
