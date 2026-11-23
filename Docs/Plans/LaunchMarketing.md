---
type: execution-plan
status: active
created: 2026-11-15
updated: 2026-11-23
expires: 2026-11-30
---

# Trinket launch marketing

Launch Trinket for iPhone and iPad in 173 App Store storefronts with a free
download and a one-time **Full Game** unlock (US$4.99 in the U.S.). Lead with
Apple editorial and targeted mobile game coverage at **$0 in promotion spend**.
Measure whether players
buy Full Game before paying to reach more of them.

Agents prepare assets, research recipients, draft outreach, verify the
storefront, and report results. The owner reviews the creative and outreach
in one batch, authorizes pre-order publication, and approves paid spend
if the evidence supports it. Group any required account or billing setup
with the relevant decision. The [standing workflow](../../AGENTS.md#workspace-and-workflow),
[shipping checklist](../Platform/Release.md#shipping), and
[verification policy](../Platform/Verification.md) govern repository and
release work.

## Launch calendar

**Monday, December 21, 2026** is the owner-approved launch date for the U.S. and all 172 eligible additional storefronts. Prepare review access, pitches, storefront checks and release-day copy before the owner’s trip the preceding week. The App Store Connect schedule uses the approved iOS 1.0.0 build 14. Local go-live times vary.

| Date | Work |
| --- | --- |
| November 25 target, November 30 latest for three weeks of lead time | Apple received the App Launch featuring nomination November 19. Apple’s nomination instructions recommend three weeks. Its general featuring page asks for at least two. Keep the earlier planning target. |
| November 23, morning Pacific | Sent three approved press batches. The first had ten emails at 8:00 a.m. The second had six emails and two editorial form submissions. The third had five creator and editorial emails at 10:44 a.m. One first-batch email bounced. |
| November 30, morning Pacific | Recheck replies, coverage and Press Preview signups. Review one follow-up for time-sensitive roundup desks that are still silent. Sending requires owner approval. |
| December 21–23 | Confirm owner availability for urgent purchase or crash issues. Verify downloads and the Full Game offer in the U.S. and representative international storefronts, then use the evergreen launch trailer and approved launch-day outreach. |

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

Use the shared-hand sentence below as the opening pitch. Target single-player strategy and fantasy card RPG readers. Keep outreach high-level. Describe the free download and one-time full-game unlock. Use US$4.99 for U.S. copy and verify the customer price before quoting any other storefront.

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

Give the recipient enough context to place the game in a short one-to-one
email. Put the press kit first on a standalone line, bold its linked label,
and name the assets it contains. Put the TestFlight preview and the appropriate
public App Store storefront link on the secondary line. For release lists, put the date and
platform in the subject or near the opener. For creators, include the silent
gameplay download. Keep named character combos and detailed rules in the
game and press materials. Each pitch should stand on its own without a
question, feedback request, or reply to arrange access.
[Muck Rack’s media pitching guide](https://muckrack.com/resources/guides/media-pitching)

For future copy reviews, ask independent readers to name the genre and describe a decision the player makes after reading just the opening. Then compare which accurate opening they remember. Use the outreach tracker for results. This small, targeted batch gives evidence about individual placements and reader interest. [Muck Rack’s 2026 journalist survey, p. 31](https://media.muckrack.com/documents/State_of_Journalism_2026_1.pdf)

## Press outreach tracker

| November 23 batch | Email dispatch | Editorial form receipts | Bounces | Editorial replies | Published coverage found |
| --- | ---: | ---: | ---: | ---: | ---: |
| First, 8:00 a.m. Pacific | 10 | 0 | 1 | 0 | 0 |
| Second, morning Pacific | 6 | 2 | 0 | 0 | 0 |
| Third, 10:44 a.m. Pacific | 5 | 0 | 0 | 0 | Pending check |
| Total | 21 | 2 | 1 | 0 | 0 found before the third batch |

Gmail Sent confirms dispatch. Its delivery notice says SNAPP Attack's server
rejected the message with `554 5.7.1 Relay access denied`. Hold that route until
a current editorial contact is verified. The two form receipts are Mobi.gg
and 4Gamer. The third batch went to Tekkan, MrMacRight, WithZack, Engadget
and TapSmart. Vandal and Retcon remain in Drafts.

The November 23 dispatch check included all 21 sent threads and the sending
mailbox for replies and delivery notices. Coverage was last checked before the
third batch. Recheck all three batches on November 30. Record each outlet's
reply date, disposition and next action, and each placement's URL and
publication date. The private ledger with thread references
and per-outlet status is at
`~/.local/share/trinket/press-outreach/2026-11-23/Tracker.txt`.

| Checked | TestFlight group | Enrolled | Change from pre-send baseline | Link capacity | Active press build |
| --- | --- | ---: | ---: | ---: | --- |
| November 23, after the third batch | Press Preview | 0 | 0 | 50 | 13, expires February 11, 2027 |

Read Press Preview enrollment in App Store Connect. Log each check date and
the change since the last check. The batches share an invite, so signups are
a group total. Attribute interest to an outlet only when the outlet identifies
itself. Keep enrollment, editorial replies and coverage as separate measures.

**Follow-up.** Review the list on Monday, November 30, one week after the
pitches and after U.S. Thanksgiving. If approved, use one short, same-thread
note for silent roundup desks with time-sensitive calendars, starting with
Pocket Gamer and Metro GameCentral. Leave bounced and held routes out. Use an
existing reply thread if an editor is already in touch. For form submissions
without a reply address, keep the receipt and skip repeat submissions. Use
December 21 as the alternative for suitable contacts that receive no advance
follow-up, after verifying their local listing offers downloads. Send only
one unsolicited follow-up per outlet across both dates.
[Journalist follow-up preferences](https://media.muckrack.com/documents/State_of_Journalism_2026_1.pdf#page=36)
· [U.S. Thanksgiving date](https://www.opm.gov/policy-data-oversight/pay-leave/federal-holidays/)

## Before launch

- [x] **Agents · still press kit.** Package five approved iPhone screenshots, icon artwork,
  game facts and a public contact. The November 17 release evidence contains the
  stills ZIP, eight individually drafted pitches, the App Launch nomination draft
  and the D7/D14/D30 reporting worksheet.
- [x] **Agents · prelaunch press kit.** The [press page](https://trinketrpg.com/press/) and downloadable offline ZIP are public. It includes eight captioned stills across iPhone and iPad layouts, artwork and the full-resolution transparent Ambush logo, a plain-text fact sheet, the Countess reel with a prelaunch ending, and silent creator footage. The launch cut with the App Store badge is separate. For interviews or review access, the kit points to the developer’s public contact.
- [x] **Agents · trailer.** Prepare one short fight clip for each of the seven bosses. Open on the first vocal passage with that boss’s theme and live lyrics. [Matchups, capture and edit plan](LaunchTrailer.md)
- [x] **Agents · Apple editorial.** Updated the submitted App Launch
  nomination on November 21 for all 173 launch storefronts. It leads with Hero
  and Companion combat, the solo developer story and the free download.
  It includes the December 21 date, current press kit and store links.
  [Apple featuring nominations](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)
- [x] **Agents · prepare outreach.** Rank 8–12 writers, outlets, and creators based on
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
  verified direct TestFlight link capped at 50 testers (raised from 20 on
  November 21). Include it in every
  approved direct press pitch alongside the public App Store URL and press
  kit. Check the build and capacity before dispatch. Keep the enrollment
  URL in direct correspondence and the private review packet. If a reviewer
  needs Full Game after release, prepare an authorized one-time offer code
  once Apple allows generation. Record
  redemptions separately from paid unlocks. [External TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) ·
  [In-App Purchase offer codes](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases)
- [x] **Owner · approve advance outreach.** Approved all three November 23
  batches. Record dispatch, delivery exceptions and coverage in the
  [press outreach tracker](#press-outreach-tracker).
- [x] **Agents · stage the launch review batch.** The private
  `Trinket-Launch-Review-Nov21/Review.md` packet in Release deliverables
  contains the first ten pitches with direct TestFlight access,
  launch-day posts, a press-page badge update, and the first-week reporting
  worksheet and collector. The launch-day press page and ZIP were built and
  checked privately for launch day. `Press-follow-up.md` has batch-specific
  Gmail searches and press reply snippets. The live tracker above owns the
  current follow-up dates.
  Run `ruby reporting/launch-check.rb` from the private packet for one
  read-only pass over the app and Full Game, sampled public pages, and
  first-week reporting. The pre-launch rehearsal verified 14 public
  pre-orders and 173 configured Full Game price points.

## Launch day and the first month

- [x] **Agents · publish the approved pre-order.** On November 21, confirmed
  iOS 1.0.0 build 14 and Full Game approval in App Store Connect, published
  for the United States, and verified the public product page shows
  “Coming Soon” and “Expected Dec 21, 2026.”
  [U.S. App Store listing](https://apps.apple.com/us/app/trinket/id6811284921)
- [x] **Agents · expand pre-order and Full Game availability.** On November 21,
  App Store Connect confirmed the December 21 pre-order and approved Full Game
  availability in the same 173 storefronts. Prices were already scheduled in
  each, and the U.S. date and build 14 were preserved. Mainland China and
  Vietnam remain out pending their required game licenses. Representative
  public pages confirmed the date and pre-order action, including the [UK](https://apps.apple.com/gb/app/trinket/id6811284921).
  [App availability](https://appstoreconnect.apple.com/apps/6811284921/distribution/pricing/availability)
- [x] **Agents · add pre-order links.** The [press kit](https://trinketrpg.com/press/)
  and advance drafts use the App Store link without a fixed country. Use the
  verified UK pre-order page for Pocket Gamer. The footage section also offers
  a 29-second narrated cut alongside the full feature reel and silent Blight
  Treant clip.
- [x] **Agents · set the approved App Store preview as the default.**
  Applied the corrected 29-second captioned preview to the English (U.S.)
  product page on November 23. The original preview test stopped on application
  and had zero recorded unique impressions in either arm at the last check.
  App Store Connect confirmed the approved video on version 1.0.0 and build
  14 in Pre-Order Ready for Sale. The public U.S. listing still showed the
  December 21 pre-order. Apple caps App Previews at 30 fps. The separate web
  press reel uses 60 fps.
  [Original preview test](https://appstoreconnect.apple.com/apps/6811284921/distribution/optimization/c3ddfdc8-90af-4e77-bd5c-73744600e89b)
  · [Apple's App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- [x] **Agents · submit the video-versus-screenshots comparison.**
  The English (U.S.) test splits eligible traffic 50/50. The original has the
  approved video and the treatment has zero previews. The ten iPhone and ten
  iPad screenshots match in both arms, including order. Optimization-only
  submission `3b5c3d7e-6681-4832-b38c-737d2a0b9ec7` was Waiting for Review
  on November 23.
  [App preview vs screenshots](https://appstoreconnect.apple.com/apps/6811284921/distribution/optimization/096be046-6cae-414b-9c6a-4e14eb1b65a8)
- [ ] **Agents · read the comparison after approval.** Confirm the test
  starts and record conversions, qualified impressions and confidence.
  Record when downloads become available so a mixed pre-order and live
  window is visible in the readout. Wait for a meaningful result before
  choosing a winner or starting the separate header experiment.
  [Apple test instructions](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/run-a-test/)
- [x] **Agents · submit the three selected product page headers.** On November
  21, App Store Connect validated all three as header-only PNGs. Standalone
  asset submission `a54e83a5-e5b7-4249-bf48-6058c5dc4531` is complete.
  Apple approved all three assets.
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
- [x] **Agents · stage community copy.** The private packet at
  `~/.local/share/trinket/launch-day/2026-12-21/Community-posts.txt` contains
  the December 21 social draft, a link to verified 60 fps gameplay, and a Developer
  Saturday comment for the first eligible thread after launch. The Reddit
  draft identifies the developer and discloses AI use in coding, illustrations,
  music and press trailer narration. Both drafts await owner review.
  [Current Developer Saturday example and rules](https://www.reddit.com/r/iosgaming/comments/1y1omln/megathread_developer_saturday_showcase_november/)
- [ ] **Agents · distribution.** Verify the posting rules for each selected
  community. Recheck the December Developer Saturday thread before posting.
  On launch day, after the
  store check passes, swap the press kit to the evergreen "Download on the App
  Store" trailer and download badge, push to `main` so GitHub Pages rebuilds
  both `Trinket-Press-Kit.zip` and `Trinket-images.zip`, and send approved
  launch messages and posts. Start with the ordinary App Store URL.
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
  Include U.S. and international totals and the strongest storefronts in each
  snapshot, with reporting dates, cohort age, and lag. Read the same cohort at
  the same age when comparing channels.
  [Apple cohort reporting](https://developer.apple.com/help/app-store-connect-analytics/monetization/cohorts/) ·
  [Analytics Reports API](https://developer.apple.com/help/app-store-connect-analytics/overview/analytics-reports-api)
- [ ] **Agents · respond to the funnel.** If qualified reach is low, revise
  the pitch or recipient list. If views are healthy and downloads lag,
  review the lead screenshot and store message. If people download but
  rarely buy after the cohort matures, inspect the free-to-paid path and
  actual player feedback before proposing a product change. Escalate
  confirmed purchase, restore, or save problems as soon as they are found.
- [ ] **Agents · localized galleries and 1.0.1 polish.** Add the approved
  localized iPhone and iPad screenshots, refreshed App Store keywords and
  description, direct `trinketrpg.com` support/privacy URLs, and a gentle
  milestone-triggered `requestReview()` prompt to the next editable version.
  Plan submission well before mid-December or in early January to avoid
  Apple's late-December holiday App Review slowdown. Verify each prioritized
  storefront before distributing market-specific links or local price claims.

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
| Global launch date | Confirmed by owner | December 21, 2026 in the U.S. and 172 eligible additional storefronts. The prelaunch film and press fact sheet carry the date. |
| Launch candidate | Build 14 submitted for App Review | On November 19 at 5:28 p.m. Pacific, Apple confirmed version 1.0.0 (14) was Waiting for Review with manual release after build 13 was withdrawn. Submission `9d37fa8c-814c-4cb7-bd94-d05d98057908`. TestFlight opened 1.0.0 (14) over Wi-Fi. Ranger and Wolf remained at chapter 1, stage 1, and the save database and write-ahead log matched the pre-update backup byte for byte. After restore and sign-in, Options showed Full Game — Unlocked. Reuse this result and the prior first-purchase evidence for unchanged commerce behavior. [Hosted release checks](https://github.com/Talyen/Trinket/actions/runs/44630048041) passed with one coverage gap for declined Ask to Buy. The build comparison and device evidence are in `LaunchReadiness-Nov19/Candidate.md`. |
| U.S. App Store pre-order | Public and verified November 21 | Version 1.0.0 build 14. Apple confirmed United States only and the public page shows the expected December 21, 2026 release, Free, and In-App Purchases. [U.S. listing](https://apps.apple.com/us/app/trinket/id6811284921) |
| International App Store pre-order | Confirmed November 21 | App Store Connect shows all 173 pre-orders available with the same date and Full Game lineup. Public spot checks passed in 14 storefronts. |
| Press access | Direct link verified November 21 | Build 13 is attached to Press Preview and expires February 11, 2027. The direct link was initially capped at 20 testers. The current cap and enrollment are in the press outreach tracker. Apple rejected build 14 for external TestFlight because version 1.0.0 is closed to new beta review submissions. Build 13 remains available to press, and the App Store uses build 14. |
| Featuring nomination | Submitted November 19, updated November 21 | Apple confirmed nomination `9a7f1d2d-b137-40ca-af15-432c455ae3ab` stayed submitted with the December 21 date, 173 storefronts, a gameplay-led pitch, the press kit, trailer, still and App Store link. |
| First-week reporting | Reporting access verified before launch | The active Analytics request and four standard report catalogs were readable on November 21 with no daily instances. The Sales and Trends check returned explicit no sales for November 17. Start with the D+7 snapshot, then refresh after data is complete through the seventh live day. |
| Editorial review | Shared-hand opener selected | The preceding editorial drafts are in the retained Release folder `LaunchPitch-Nov20/`. The press page and offline downloads share one set of captions and release facts. The owner accepted the existing trailer. The second editorial pass covers press copy, outreach and image assets. |
| Press outreach dispatched | All three November 23 batches sent | [Press outreach tracker](#press-outreach-tracker) records dispatch, the single bounce, reply and coverage checks, and TestFlight enrollment. |
| Launch-day rehearsal | Private preview verified November 21 | The launch-day badge and fact sheet switch apply cleanly. The assembled press ZIP and both corrected videos passed integrity checks. Analytics access and a historical Sales and Trends no-sales response were verified. |
| Verified public launch | Pending | Verify U.S. and prioritized international downloads and Full Game offers. |
| Day 7, 14, and 30 sales and conversion snapshots | Pending | |
| Paid pilot decision and result | Pending | |
| Repeat and reserve decisions | Pending | |
| Localized screenshot upload | Pending | Approved gallery is staged for the next editable App Store version. |

For each checkpoint, record the reporting window, source, first-time
downloads, paid unlocks, refunds, net proceeds, spend, and decision.
Record the reason when a stage is skipped. At closeout, link the final
launch and spending decisions in the handoff and retire this plan under
the [plan lifecycle](README.md).
