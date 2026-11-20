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
in one batch, gives the manual release decision, and authorizes paid spend
if the evidence supports it. Group any required account or billing setup
with the relevant decision. The [standing workflow](../../AGENTS.md#route-and-read),
[shipping checklist](../Platform/Release.md#shipping), and
[verification policy](../Platform/Verification.md) govern repository and
release work.

## U.S. launch calendar

**Monday, December 21, 2026** is the owner-approved U.S. launch date. The owner is traveling the preceding week. Prepare review access, pitches, storefront checks and release-day copy before that trip. Agents can monitor the listing and report issues, while the owner retains the manual release decision.

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

Lead with the Hero and Companion pairing, show a turn where their abilities
work together, then show how earned gear or talents change the next fight.
Target players who already seek single-player strategy games and fantasy card
battlers on mobile. Use the free Campaign chapters as the invitation to play
and put the one-time unlock price next to it.

> Pair a Hero with a Companion in turn-based fantasy card battles. Play the
> first three Campaign chapters free. Unlock the rest with a one-time $4.99
> Full Game purchase in the U.S.

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

Team Alto presents facts, screenshots, video, logo and icon as distinct downloads. Pawnbarian specifies pricing per platform and explains its central mechanic in ordinary language. Trinket follows those examples with individual downloads and a full offline bundle. For journalists, place the live store link beside the trailer when the listing opens. Reserve a scannable end card for situations where the audience is watching a separate screen, such as an event booth. [Alto’s Odyssey press kit](https://altosodyssey.com/press/) · [Pawnbarian press kit](https://j4nw.com/pawnbarian/presskit) · [Apple promotion tools](https://developer.apple.com/app-store/promote/)

To rebuild on this Mac, run `python3 Scripts/PressKit/build.py <LaunchMarketing-Nov17> <fresh-output-directory>`. It renders the cleaned Ranger and Fox end card and packages the 6144 × 4096 transparent logo. Pass `--branded-trailers <folder>` to reuse the approved render from `Scripts/PressKit/brand.py`. It takes the “Coming to iOS” reel from `channel-edits/countess-press-2026-12-21/`, the selected stills archive and the two iPhone takes. The developer cleared the Countess soundtrack for press use on November 19. Add a live store URL only after verifying it opens the product page.

## Before launch

- [x] **Agents · still press kit.** Package five approved iPhone screenshots, icon artwork,
  game facts and a public contact. The November 17 release evidence contains the
  stills ZIP, eight individually drafted pitches, the App Launch nomination draft
  and the D7/D14/D30 reporting worksheet.
- [x] **Agents · prelaunch press kit.** The [press page](https://talyen.github.io/Trinket/press/) and downloadable offline ZIP are public. It includes seven captioned stills, artwork and the full-resolution transparent Ambush logo, a plain-text fact sheet, the Countess reel with a prelaunch ending, and silent creator footage. The launch cut with the App Store badge is separate. For interviews or review access, the kit points to the developer’s public contact.
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
  reply, and coverage link. Write one pitch and at most one follow-up per
  recipient. Check current community rules before including any community
  post. [Pocket Gamer contact guidance](https://www.pocketgamer.com/pages/contact-us/) ·
  [Pocket Gamer card-battler roundup](https://www.pocketgamer.com/best-games/card-battler-games-for-iphone-ipad-ios/) ·
  [MiniReview's Dawncaster coverage](https://minireview.io/deck-building/dawncaster-deckbuilding-rpg)
- [ ] **Agents · playable access.** Offer early gameplay access only if an
  approved external TestFlight build is ready and access is authorized.
  Otherwise, preview with the clip and share the live App Store link on
  launch day. If a reviewer needs Full Game after release, prepare an
  authorized one-time offer code once Apple allows generation. Record
  redemptions separately from paid unlocks. [External TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) ·
  [In-App Purchase offer codes](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases)
- [ ] **Owner · one review.** Review the clip, press kit,
  nomination, and recipient batch. Agents can send the approved outreach
  once the owner has authorized sending. Save dated artifact links and
  dispatch status in the tracker below.

## Launch day and the first month

- [ ] **Owner · release decision.** After App Review approves the exact
  candidate, confirm the manual release. Use the technical release
  checklist for readiness and post-release checks. Begin the public push
  when the listing is verified live. Apple says storefront propagation can
  take up to 24 hours. [Shipping checklist](../Platform/Release.md#shipping) ·
  [Apple manual release](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)
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
| Prelaunch press kit | Public and checked on iPhone | Nov 19, retained Release folder `Trinket-Ambush-Launch/Press`. A full ZIP and an image-only ZIP accompany the press page. The public edition is live on [the press page](https://talyen.github.io/Trinket/press/) with silent creator footage, seven screenshots, original artwork, a fact sheet and offline downloads. The narrated trailer played in Safari on the iPhone 14 Pro. Anonymous requests retrieved all 26 linked assets. The downloaded press ZIP (27 entries) and image ZIP (11 entries) passed integrity checks. The developer cleared the Blood Countess soundtrack for press publication, download and editorial use. The full edition adds the 93-second narrated trailer and English captions. |
| Reporting access | Ongoing analytics enabled Nov 19 | Apple accepted the request. The download and purchase report catalogs are readable. Both had zero delivered instances before launch. Sales and Trends accepted the vendor number and returned its no-sales response for November 12 and 17. Verify the first delivered report after sales begin. First-month reporting and the $0 opening baseline are in Release evidence under `LaunchReadiness-Nov19/Reporting.md`. |
| U.S. launch date | Confirmed by owner | December 21, 2026. The prelaunch film and press fact sheet carry the date. |
| Launch candidate | Build 14 verified on iPhone 14 Pro | Build 13 is in App Review with manual release. TestFlight opened 1.0.0 (14) over Wi-Fi. Ranger and Wolf remained at chapter 1, stage 1, and the save database and write-ahead log matched the pre-update backup byte for byte. After restore and sign-in, Options showed Full Game — Unlocked. Reuse this result and the prior first-purchase evidence for unchanged commerce behavior. [Hosted release checks](https://github.com/Talyen/Trinket/actions/runs/44630048041) passed with one coverage gap for declined Ask to Buy. The build comparison and device evidence are in `LaunchReadiness-Nov19/Candidate.md`. |
| Press access | External Beta App Review requested Nov 19 | Build 13 is attached to the invite-only Press Preview group. Apple returned Waiting for Review. Send private invitations after external approval. |
| Featuring nomination | Submitted November 19 | App Launch, December 21, U.S., iPhone and iPad. Apple confirmed nomination `9a7f1d2d-b137-40ca-af15-432c455ae3ab` with the public kit, narrated trailer and Blood Countess still. |
| Advance outreach | Three December 7–9 pitches prepared | Pocket Gamer news, MiniReview and Lunar Nebula Gaming. Send-day copy and sources are in `LaunchReadiness-Nov19/Advance-outreach.md`. No dispatch yet. |
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
