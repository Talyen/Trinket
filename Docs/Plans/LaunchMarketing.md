---
type: execution-plan
status: active
created: 2026-11-15
updated: 2026-11-19
expires: 2026-11-30
---

# Trinket launch marketing

Launch Trinket for iPhone and iPad in the U.S. with a free download and a
one-time **$4.99 Full Game** unlock. Lead with Apple editorial and targeted
mobile game coverage at **$0 in promotion spend**. Measure whether players
buy Full Game before paying to reach more of them.

Agents prepare assets, research recipients, draft outreach, verify the
storefront, and report results. The owner reviews the creative and outreach
in one batch, authorizes pre-order publication, and approves paid spend
if the evidence supports it. Group any required account or billing setup
with the relevant decision. The [standing workflow](../../AGENTS.md#route-and-read),
[shipping checklist](../Platform/Release.md#shipping), and
[verification policy](../Platform/Verification.md) govern repository and
release work.

## U.S. launch calendar

**Monday, December 21, 2026** is the owner-approved U.S. launch date. The owner is traveling the preceding week. Prepare review access, pitches, storefront checks and release-day copy before that trip. The owner authorized a U.S.-only pre-order for this date using iOS 1.0.0 build 14. Apple will release the game on the scheduled date after the pre-order goes live.

| Date | Work |
| --- | --- |
| November 25 target, November 30 latest for three weeks of lead time | Apple received the App Launch featuring nomination November 19. Apple’s nomination instructions recommend three weeks. Its general featuring page asks for at least two. Keep the earlier planning target. |
| December 7–11 | Give interested press time to play. Prepare or send the approved advance materials with the dated reel. Reserve the “available now” pitches for the verified public listing. |
| December 21–23 | Confirm owner availability for urgent purchase or crash issues. Verify the U.S. product page and Full Game purchase, then use the evergreen launch trailer and send approved launch-day outreach. |

A Christmas-week release gives press fewer ordinary workdays after launch, so prioritize advance review access. Give the public a date rather than an exact hour. Apple says a manually released version may take up to 24 hours to appear. [Featuring lead time](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/) · [Release timing](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)

## Starting point

- [x] Read **App Store Connect** on November 15, 2026. Version 1.0.0 build 13
  was **Waiting for Review**, **Full Game** was **Approved**, and the version
  used **Manual** release. The app and purchase were configured for the U.S.
  only. Apple's U.S. price point showed $4.99 customer price and $3.50
  estimated proceeds per unlock. Recheck the exact candidate and storefront
  before release. [App Store Connect](https://appstoreconnect.apple.com/apps/6811284921)
- [x] Locate the approved English iPhone and iPad galleries and the existing
  gameplay recordings in the primary checkout's
  `.DerivedData/Deliverables/Release/AppStoreLaunch-Nov7/` and
  `.DerivedData/Deliverables/Release/AppStoreLaunch-Nov8/`. The approved
  localized screenshot package is under
  `.DerivedData/Deliverables/Release/InternationalPrep/` for a later update.

## Positioning and audience

Use the shared-hand sentence below as the opening pitch. Target single-player strategy and fantasy card RPG readers. Keep outreach high-level and describe the free download and one-time US$4.99 full-game unlock in U.S. launch copy.

> *Trinket!* is a turn-based card RPG where your hero and companion share a hand of cards.

Italicize *Trinket!* in formatted prose, including the exclamation point. Use plain text in email subjects, paste-ready pitches, forms, metadata and credits.

Use `Trinket!` for the App Store listing name and the approved English
metadata when describing free content, offline play, iCloud sync, or the
purchase. [English store copy](../../Localization/Store/English.json) ·
[Monetization](../Product/Monetization.md)

*Pawnbarian* shipped with a free demo and a single $4.99 iOS purchase.
The developer of *Meteorfall: Krumit's Tale* reported two prominent App Store
placements at launch and $22,600 in first-week net revenue across iOS and
Android. Those results came from an established series sold upfront.
Use the examples to choose channels and position the game. Set sales
expectations from Trinket's own results. [Pawnbarian press kit](https://j4nw.com/pawnbarian/presskit) ·
[Krumit's Tale developer postmortem](https://www.gamedeveloper.com/business/ios-android-sales-deep-dive-meteorfall-krumit-s-tale-)

## Press materials

Team Alto presents facts, screenshots, video, logo and icon as distinct downloads. Pawnbarian specifies pricing per platform and explains its central mechanic in ordinary language. Trinket follows those examples with individual downloads and a full offline bundle. Once the U.S. listing opens to new players, update the press page, its share description and the fact sheet with the live store link and release wording. Verify both newly packaged ZIPs before distributing the launch pitch. Reserve a scannable end card for situations where the audience is watching a separate screen, such as an event booth. [Alto’s Odyssey press kit](https://altosodyssey.com/press/) · [Pawnbarian press kit](https://j4nw.com/pawnbarian/presskit) · [Apple promotion tools](https://developer.apple.com/app-store/promote/)

To rebuild on this Mac, run `python3 Scripts/PressKit/build.py <LaunchMarketing-Nov17> <fresh-output-directory>`. It renders the cleaned Ranger and Fox end card and packages the 6144 × 4096 transparent logo. Pass `--branded-trailers <folder>` to reuse the approved render from `Scripts/PressKit/brand.py`. It uses the “Coming to iOS” reel from `channel-edits/countess-press-2026-12-21/` and shares the curated screenshots and copy under `Website/press` with the public edition. The developer cleared the Countess soundtrack for press use on November 19. Add a live store URL only after verifying it opens the product page.

### Pitch selection

Give the recipient enough context to place the game, then link directly to the
playable TestFlight preview, editorial assets, and the public U.S. App Store
page. For release lists, put the date and platform in the subject or near the
opener. For creators, link the silent gameplay clip. Keep named character
combos and detailed rules in the game and press materials. Each pitch should
stand on its own without a question, feedback request, or reply to arrange access.

For future copy reviews, ask independent readers to name the genre and describe a decision the player makes after reading just the opening. Then compare which accurate opening they remember. After approved outreach, record published coverage and any replies by outlet and hook. Track TestFlight enrollment at the group level. With eight different desks, the results describe individual placements rather than measuring response-rate lift. [Muck Rack’s 2026 journalist survey, p. 31](https://media.muckrack.com/documents/State_of_Journalism_2026_1.pdf)

## Before launch

- [x] **Agents · still press kit.** Package five approved iPhone screenshots, icon artwork,
  game facts and a public contact. The November 17 release evidence contains the
  stills ZIP, eight individually drafted pitches, the App Launch nomination draft
  and the D7/D14/D30 reporting worksheet.
- [x] **Agents · prelaunch press kit.** The [press page](https://trinketrpg.com/press/) and downloadable offline ZIP are public. It includes eight captioned stills across iPhone and iPad layouts, artwork and the full-resolution transparent Ambush logo, a plain-text fact sheet, the Countess reel with a prelaunch ending, and silent creator footage. The launch cut with the App Store badge is separate. For interviews or review access, the kit points to the developer’s public contact.
- [x] **Agents · trailer.** Prepare one short fight clip for each of the seven bosses. Open on the first vocal passage with that boss’s theme and live lyrics. [Matchups, capture and edit plan](LaunchTrailer.md)
- [x] **Agents · Apple editorial.** Check for an existing nomination, then
  prepare the App Launch nomination for iPhone and iPad in the U.S. Include
  the solo developer story, Hero and Companion combat, the free start,
  the December 21 launch date, and the press kit. Aim to submit at least
  three weeks before the target window. If the owner chooses an earlier
  launch, pitch the first substantial update as the next editorial opportunity.
  [Apple featuring nominations](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)
- [ ] **Agents · outreach.** Rank 8–12 writers, outlets, and creators based on
  recent coverage of comparable mobile games, audience fit, and a published
  contact route. Start with Pocket Gamer's weekly launch coverage and its
  iPhone and iPad card-battler roundup. Consider MiniReview and creators
  whose recent work shows they play similar games. For each pitch, record
  the recipient, reason for fit, personalized draft, intended send date,
  reply if received, and coverage link. Write one pitch and at most one
  follow-up per recipient. Check current community rules before including any community
  post. [Pocket Gamer contact guidance](https://www.pocketgamer.com/pages/contact-us/) ·
  [Pocket Gamer card-battler roundup](https://www.pocketgamer.com/best-games/card-battler-games-for-iphone-ipad-ios/) ·
  [MiniReview's Dawncaster coverage](https://minireview.io/deck-building/dawncaster-deckbuilding-rpg)
- [x] **Agents · playable access.** The existing Press Preview group has a
  verified direct TestFlight link capped at 20 testers. Include it in every
  approved direct press pitch alongside the public App Store URL and press
  kit. Check the build and capacity before dispatch. Keep the enrollment
  URL in direct correspondence and the private review packet. If a reviewer
  needs Full Game after release, prepare an authorized one-time offer code
  once Apple allows generation. Record
  redemptions separately from paid unlocks. [External TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) ·
  [In-App Purchase offer codes](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases)
- [ ] **Owner · one review.** Review the clip, press kit,
  nomination, and recipient batch. Agents can send the approved outreach
  once the owner has authorized sending. Save dated artifact links and
  dispatch status in the tracker below.
- [x] **Agents · stage the launch review batch.** The private
  `Trinket-Launch-Review-Nov21/Review.md` packet in Release deliverables
  contains the advance and reserve drafts with direct TestFlight access,
  launch-day posts, a press-page badge update, and the first-week reporting
  worksheet and collector. External invitations and launch announcements
  await owner approval.

## Launch day and the first month

- [x] **Agents · publish the approved pre-order.** On November 21, confirmed
  iOS 1.0.0 build 14 and Full Game approval in App Store Connect, published
  for the United States, and verified the public product page shows
  “Coming Soon” and “Expected Dec 21, 2026.”
  [U.S. App Store listing](https://apps.apple.com/us/app/trinket/id6811284921)
- [x] **Agents · add pre-order links.** The [press kit](https://trinketrpg.com/press/)
  uses Apple's U.S. pre-order badge. The advance and launch drafts link to the
  same App Store listing. The gameplay footage section also offers a 29-second
  narrated cut alongside the full feature reel and the silent Blight Treant clip.
- [x] **Agents · submit the short App Store preview test.** On November 21,
  submitted one Product Page Optimization treatment for English (U.S.).
  The 29-second captioned iPhone preview is the only change, with half of
  eligible traffic assigned to the treatment. Submission
  `6ed661e7-bb92-4c7c-bf4f-0ee938dc3cab` is waiting for App Review.
  Build 14 and the December 21 U.S. pre-order were verified after submission.
  [App Store Connect test](https://appstoreconnect.apple.com/apps/6811284921/distribution/optimization/c3ddfdc8-90af-4e77-bd5c-73744600e89b)
- [ ] **Agents · check preview placement after approval.** Verify whether
  Apply Treatment is available for the current pre-order version. Applying it
  ends the 50/50 test, so record the option and get the owner's decision before
  switching the default page.
  [Apple's treatment instructions](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/apply-a-test-treatment-to-your-product-page/)
- [x] **Agents · submit the three selected product page headers.** On November
  21, App Store Connect validated all three as header-only PNGs. Standalone
  asset submission `a54e83a5-e5b7-4249-bf48-6058c5dc4531` is waiting for
  App Review.
  [App Store Connect Asset Library](https://appstoreconnect.apple.com/apps/6811284921/distribution/asset-library)
- [ ] **Agents · publish the approved default header and run the header test.**
  After the preview test concludes, use **01 Forest Ambush (Existing game
  artwork)** as the default. Compare it with **03 Into the Forge (Sunburst)**
  and **01 Forest Ambush (Sunburst)** in English (U.S.), allocating 34% to
  the default and 33% to each alternate. Keep the preview, screenshots, and
  search-result artwork consistent across the three pages. App Store Connect
  blocked creating the header test while the preview test was in review.
  [Apple's test setup](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/create-a-test)
- [ ] **Agents · public checks.** Confirm the U.S. listing, build, free
  download, iPhone and iPad galleries, support and privacy links, and
  Full Game offer. Use the release checklist for purchase and restore
  verification. Hold promotion while a listing, install, or purchase issue
  blocks players. Route confirmed defects to the release owner.
- [ ] **Agents · distribution.** Send approved launch messages and publish
  approved posts after the store check. Start with the ordinary App Store URL.
  As soon as Apple enables campaign links, use one link per channel group
  such as press, creators, and community. Pool small sources so the results
  have a chance to reach Apple's reporting thresholds. A campaign typically
  needs five first-time downloads to appear, and hidden metrics should be
  recorded as unavailable. [Apple campaign links](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links/)
- [ ] **Agents · baseline and follow-up.** Keep the first seven live days
  free of ad spend. On launch days 7, 14, and 30, pull App Store impressions,
  product page views, first-time downloads, download-to-paid cohorts,
  Full Game purchases and net proceeds, refunds, and material support
  issues. Use Sales and Trends to cross-check aggregate Full Game sales.
  Include the U.S. storefront, dates, cohort age, and reporting lag in each
  snapshot. Read the same cohort at the same age when comparing channels.
  [Apple cohort reporting](https://developer.apple.com/help/app-store-connect-analytics/monetization/cohorts/) ·
  [Analytics Reports API](https://developer.apple.com/help/app-store-connect-analytics/overview/analytics-reports-api)
- [ ] **Agents · respond to the funnel.** If qualified reach is low, revise
  the pitch or recipient list. If views are healthy and downloads lag,
  review the lead screenshot and store message. If people download but
  rarely buy after the cohort matures, inspect the free-to-paid path and
  actual player feedback before proposing a product change. Escalate
  confirmed purchase, restore, or save problems as soon as they are found.
- [ ] **Agents · later update.** Prepare a second earned-media push from the
  approved localized assets when the owner authorizes the international
  update. Verify app and Full Game availability and pricing match in each
  approved storefront before distributing market-specific links.

## Paid test and budget

| Stage | Proposed limit | What unlocks it |
| --- | ---: | --- |
| Editorial, press, and community launch | $0 | Approved assets and outreach |
| Apple Ads pilot | $100 | Organic baseline, working Full Game offer, approved measurement setup and spend |
| Repeat test | $150 | Mature pilot clears the proceeds and sample rules below |
| Reserve | $500 | Repeat clears the same rules and total U.S. proceeds also lift against comparable no-ad periods |
| Initial ceiling | **$750** | A separate owner decision is required to exceed it |

- [ ] **Agents · pilot setup.** Prepare one U.S. Apple Ads Advanced
  search-results campaign using Manage Bids, a few exact-match genre terms
  such as `card battler` and `offline card rpg`, and Search Match off.
  Create an approved custom product page for the ad using existing assets.
  Keep that page out of organic keyword targeting and public outreach so
  its Full Game proceeds can be tied to the ad traffic. Confirm the ad
  serves the intended page and check for fallback to the default ad.
  [Apple Ads controls](https://ads.apple.com/app-store/help/apple-ads-basic/0001-compare-apple-ads-solutions) ·
  [Ad variations](https://ads.apple.com/app-store/help/ads/0078-manage-ad-variations) ·
  [Custom product page analytics](https://developer.apple.com/help/app-store-connect-analytics/acquisition/custom-product-pages)
- [ ] **Owner · authorize the pilot.** Review the bid ceiling, dates, budget,
  and source of purchase data. Configure a fixed end date and a daily
  budget whose product with the run length stays within the approved cap.
  For example, seven days at $14 sets a $98 scheduled campaign budget.
  Apple can spend above the daily average on an individual day, so verify
  the dates and total before activation. [Apple Ads budget rules](https://ads.apple.com/app-store/help/bids-and-budget/0016-manage-budgets)
- [ ] **Agents · measure and decide.** Record search terms, spend, taps, and
  tap-through first-time downloads in Apple Ads. Use the dedicated custom
  page and download dates in App Store Connect to measure Full Game net
  proceeds for the paid cohort. Check early reads at days 7 and 14. Make
  the repeat decision after the last included download has had 30 days
  to convert and reporting has caught up. Treat missing, suppressed,
  contaminated, or low-volume data as inconclusive and hold further spend.
  [Apple Ads reporting](https://ads.apple.com/app-store/help/reporting/0023-reporting-options-and-definitions) ·
  [App Store Purchases report](https://developer.apple.com/documentation/analytics-reports/app-store-purchase)
- [ ] **Owner · repeat or stop.** Repeat only with at least 20 paid Full
  Game unlocks and at least **$1.50 in net proceeds per $1 of ad spend**.
  These are proposed decision rules. Use matured cohorts and exclude free
  codes. If the repeat also passes and U.S. proceeds rise against comparable
  no-ad periods, authorize reserve spend in steps. Note any featuring,
  coverage, or sale that overlaps the comparison. If the impact cannot be
  isolated, hold the reserve. Keep broader paid promotion out of the first
  round.

**Bid math.** At $3.50 per unlock, $100 needs 29 paid unlocks to break even.
A 5% download-to-paid rate implies about $0.18 in break-even cost per
first-time download. That conversion is illustrative. Use the measured
rate times actual net proceeds per unlock to estimate break-even cost per
download. Divide by 1.5 for the proposed proceeds target, then multiply by
the observed tap-to-first-time-download rate to estimate the corresponding
cost-per-tap ceiling. If the campaign delivers little volume at that bid,
record the result and retain the budget.

## Progress and handoff

Update this table when a decision, asset, or meaningful result changes.
Keep exports, clips, and review bundles under
`.DerivedData/Deliverables/Release/`. Record dates and aggregate results
here. Keep access codes, credentials, and private recipient details out of Git.

| Milestone | Status | Date or evidence |
| --- | --- | --- |
| Release state and source assets checked | Complete | November 15, 2026 |
| Stills, copy, eight pitches, nomination and reporting worksheet | Drafts prepared | Nov 17, retained Release evidence folder `LaunchMarketing-Nov17` |
| Trailer | Narrated feature reel cleared for press | Nov 19, Wizard and Frost Whelp face the Blood Countess. The cut includes three Homestead buildings, Bear recruitment, a skill and an ultimate, two Contract rewards, and a Desert Voyage. The revised 93-second master carries the Countess’s song across the end card. Prelaunch kit includes English captions. [Script and review master](LaunchTrailer.md#gameplay-feature-reel) |
| Prelaunch press kit | Public and checked on iPhone | Nov 19, retained Release folder `Trinket-Ambush-Launch/Press`. A full ZIP and an image-only ZIP accompany the press page. The public edition is live on [the press page](https://trinketrpg.com/press/) with silent creator footage, seven screenshots, original artwork, a fact sheet and offline downloads. The narrated trailer played in Safari on the iPhone 14 Pro. Anonymous requests retrieved all 26 linked assets. The downloaded press ZIP (27 entries) and image ZIP (11 entries) passed integrity checks. The developer cleared the Blood Countess soundtrack for press publication, download and editorial use. The full edition adds the 93-second narrated trailer and English captions. |
| Reporting access | Ongoing analytics enabled Nov 19 | Apple accepted the request. The download and purchase report catalogs are readable. Both had zero delivered instances before launch. Sales and Trends accepted the vendor number and returned its no-sales response for November 12 and 17. Verify the first delivered report after sales begin. First-month reporting and the $0 opening baseline are in Release evidence under `LaunchReadiness-Nov19/Reporting.md`. |
| U.S. launch date | Confirmed by owner | December 21, 2026. The prelaunch film and press fact sheet carry the date. |
| Launch candidate | Build 14 submitted for App Review | On November 19 at 5:28 p.m. Pacific, Apple confirmed version 1.0.0 (14) was Waiting for Review with manual release after build 13 was withdrawn. Submission `9d37fa8c-814c-4cb7-bd94-d05d98057908`. TestFlight opened 1.0.0 (14) over Wi-Fi. Ranger and Wolf remained at chapter 1, stage 1, and the save database and write-ahead log matched the pre-update backup byte for byte. After restore and sign-in, Options showed Full Game — Unlocked. Reuse this result and the prior first-purchase evidence for unchanged commerce behavior. [Hosted release checks](https://github.com/Talyen/Trinket/actions/runs/44630048041) passed with one coverage gap for declined Ask to Buy. The build comparison and device evidence are in `LaunchReadiness-Nov19/Candidate.md`. |
| U.S. App Store pre-order | Public and verified November 21 | Version 1.0.0 build 14. Apple confirmed United States only and the public page shows the expected December 21, 2026 release, Free, and In-App Purchases. No pitches sent. [U.S. listing](https://apps.apple.com/us/app/trinket/id6811284921) |
| Press access | Direct link verified November 21 | Build 13 is attached to Press Preview and expires February 11, 2027. The direct link has a 20-tester cap and zero testers at setup. The public press kit uses the App Store link. |
| Featuring nomination | Submitted November 19 | App Launch, December 21, U.S., iPhone and iPad. Apple confirmed nomination `9a7f1d2d-b137-40ca-af15-432c455ae3ab` with the public kit, narrated trailer and Blood Countess still. |
| Advance outreach | High-level pitches staged for one approval | Pocket Gamer news, MiniReview and Lunar Nebula Gaming are the December 7–9 batch. All eight advance and reserve pitches include playable access and editorial assets. Current drafts and the release-day update are in `Trinket-Launch-Review-Nov21/`. No dispatch yet. |
| First-week reporting | Reporting access verified before launch | The active Analytics request and four standard report catalogs were readable on November 21 with no daily instances. The Sales and Trends check returned explicit no sales for November 17. Start with the D+7 snapshot, then refresh after data is complete through the seventh live day. |
| Editorial review | Shared-hand opener selected; outreach remains unsent | The preceding editorial drafts are in the retained Release folder `LaunchPitch-Nov20/`. The press page and offline downloads share one set of captions and release facts. The owner accepted the existing trailer. The second editorial pass covers press copy, outreach and image assets. |
| Press outreach dispatched | Due December 7–11 | Check the public kit and external beta status before sending. |
| Verified public U.S. launch | Pending | |
| Day 7, 14, and 30 sales and conversion snapshots | Pending | |
| Paid pilot decision and result | Pending | |
| Repeat and reserve decisions | Pending | |
| International update handoff | Pending | |

For each checkpoint, record the reporting window, source, first-time
downloads, paid unlocks, refunds, net proceeds, spend, and decision.
Record the reason when a stage is skipped. At closeout, link the final
launch and spending decisions in the handoff and retire this plan under
the [plan lifecycle](README.md).
