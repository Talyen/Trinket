# Release process

Trinket generates a developer changelog and player-facing App Store notes at a
release boundary. Agents do not edit `CHANGELOG.md` or `ReleaseNotes/en-US.txt`
for ordinary commits. Commit format, task checkouts, integration, and Git hooks
follow [Development](Development.md).

## Sources of truth

- `project.yml`: `MARKETING_VERSION` and the baseline `CURRENT_PROJECT_VERSION`
- Local TestFlight receipt: allocated upload build number and source commit;
  TestFlight overrides the baseline at archive time without editing the project
- `cliff.toml`: developer changelog categories
- `ReleaseNotes/en-US.txt`: generated App Store/TestFlight notes

Run `generate.sh` after changing a version so the generated Xcode project stays
in sync.

## Shipping

Before adopting a new major iOS release, complete the
[platform readiness checks](Verification.md#new-ios-release-readiness). Release
artifacts use an explicitly selected, Apple-supported Xcode; [toolchain selection](../../Scripts/Reference.md#toolchain-ladder)
owns command setup and bisection. The
[platform support policy](ApplePlatformReference.md#platform-support) owns the
supported OS window; verify the minimum supported runtime and current release,
plus the affected availability branches, before claiming readiness.

Before App Store submission, complete the
[purchase release prerequisites](Purchases.md#before-release), including the
public support contact and published support/privacy pages. When enabling iCloud
progress sync, also complete the [CloudKit checklist](CloudKitPreShipChecklist.md).
Local-only releases do not require CloudKit enablement. The commands below
produce verified release artifacts; they do not provision these external services.

### Prepare while the beta is running

Use the existing App Store Connect record for TestFlight (provisioning:
[CloudKit setup baseline](CloudKitPreShipChecklist.md#setup-baseline)).
Complete its public listing using the [metadata draft](AppStoreMetadata.md);
do not create another app or change the bundle ID to match the display name.

1. In **Apps → the existing Trinket app → App Information**, prepare the
   subtitle, Games category/subcategories, content rights, and age-rating answers
   based on actual game content. Use Apple's
   [age-rating questionnaire](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
2. Prepare the first iOS version's description, keywords, copyright, support URL,
   review contact, and review notes. Capture representative portrait gameplay
   screenshots from the intended release build using Apple's current
   [screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
   Explain offline play and where reviewers can find Options → Full Game.
3. Publish and check the [support](../../Website/index.html) and
   [privacy](../../Website/privacy.html) pages without authentication. Their expected
   URLs are `https://talyen.github.io/Trinket/` and
   `https://talyen.github.io/Trinket/privacy.html`. Page source in Git is not proof
   that hosting is enabled. In **App Privacy**, enter the public privacy-policy URL
   and review [Apple's privacy questions](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
   against the shipped app, including purchases and diagnostics. Revisit the answers
   when iCloud behavior changes; the privacy manifest alone does not fill them in.
4. Complete the [purchase prerequisites](Purchases.md#before-release): agreements,
   banking/tax, the Full Game non-consumable, pricing/territories, and real sandbox
   purchase/restore testing. Set up paid access independently of progress sync.
5. In App Store Connect, review pricing/availability, the applicable regional
   business requirements, export-compliance questions, and the release method.
   Prefer manual release when the launch date is not yet settled. Recheck Apple's
   submission requirements near release rather than freezing today's requirements.
6. Use beta updates to test preservation of the existing save, offline play,
   interrupted battles, restart, and purchase restoration. Record build IDs and
   observed outcomes. Run CloudKit's Development and TestFlight stages separately;
   a successful local-only TestFlight launch does not verify iCloud sync.

### Triage a player report

Record the app version and build, device and iOS version, approximate time, and
the player's steps and visible result. Ask for only the information needed to
reproduce; do not ask a player to reset or reinstall before preserving progress.
Review available TestFlight feedback and Apple's crash and performance reports for
the matching build. Apple diagnostics depend on availability and the player's
sharing settings; absence of a report is not proof of an absence of crashes.

Match a crash's binary UUID to the retained build archive and dSYM before
interpreting symbols. Use the release receipt and symbol procedure below; a
different build's symbols cannot establish a diagnosis. MetricKit's local log
summaries supplement those reports; they do not create a developer-operated
upload service. Keep shared reports and support messages under the published
privacy policy and avoid including save contents unless needed and provided by
the player.

### Produce release artifacts

Prepare the release in its isolated task worktree. Defer tagging until after
integration because integration may rebase the release commit:

```sh
./Scripts/release.sh --dry-run
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/release.sh --no-tag
node Scripts/agent-worktree.mjs integrate --keep-worktree
```

Review the integrated release commit. If integration incorporated changes beyond
the source already covered by deploy verification, rerun the required deploy and
unsigned device Release checks on that combined revision. Lightweight integration
handoff does not replace release verification.

When publication is requested, tag the verified integrated commit explicitly and
push that release tag together with its commit on `main`. From the retained,
clean task worktree at that commit (substitute the actual version and commit below):

```sh
git tag -a vX.Y.Z <integrated-release-commit> -m 'Release vX.Y.Z'
git push --atomic origin HEAD:refs/heads/main refs/tags/vX.Y.Z
```

Every outgoing source ref must resolve to the checked-out commit for pre-push
validation. A non-fast-forward rejection requires reconciling newer main and
reverifying before publication; the atomic push keeps the tag unpublished when
the main update fails. Inspect any existing unpushed tag before preparing a
replacement, and never move a published release tag or force the push. Do not use
`--tags`, which also selects unrelated local tags. Keep the release worktree while its requested
publication and hosted verification remain in flight; cleanup follows the
[isolated workflow](Development.md#isolated-chat-workflow).

The local opt-in is for an expressly requested release run because this command
invokes the full deploy suites. Dry-run needs no opt-in. See the
[execution limits](Verification.md#execution-limits); ordinary commits and pushes
still use lightweight handoff and hosted CI.

The release command runs deploy verification, chooses or accepts a semantic
version, increments the build number, generates changelog and store notes,
checks unsigned device Release compilation after updating the version, commits
release artifacts, and creates a tag unless `--no-tag` is supplied as above.
This compile check does not validate signing or App Store distribution. Use
`--version X.Y.Z` to select a version explicitly; `--skip-tests` remains emergency-only.

A pushed `v*` tag triggers the GitHub release workflow. It confirms that the
tagged commit is on `main` with green push CI for that exact commit, then creates
a GitHub Release whose body is `ReleaseNotes/en-US.txt` plus a pointer to
`CHANGELOG.md` and uploads that file as an artifact. It does
not repeat the full suite already run by the release command and main CI.

Apple's What's New field is required for updates after the first version, is
plain text and localizable, and permits up to 4,000 characters. See
[Apple's platform version reference](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).
`release-notes-user.py` infers player-facing commits and writes
`ReleaseNotes/en-US.txt`. Paste that file into App Store Connect when submitting.

## Local TestFlight deployment

After one-time setup, deploy a committed, clean checkout with:

```sh
./Scripts/testflight.sh
```

This is the canonical agent entry point for TestFlight. Routine internal betas
require green exact-commit CI, hosted Smoke, and qualified hosted critical UI
journeys. The Mac archives and exports the signed Release build, uploads it, and
waits for the exact build to be available to the configured internal testing group.
Fastlane is [free, MIT-licensed local tooling](https://github.com/fastlane/fastlane).
The default beta path requires no local simulator runtime, test build, simulator
boot, or heavy-local override. Doctor checks Apple access and signing prerequisites.

The deployment command dispatches `release-verification.yml` on the pushed default
branch commit when no run exists. That workflow installs the qualified iPhone 17
Pro / iOS 26.2 (23C54) runtime if needed, reuses compatible products or the shared warm
build cache, and runs qualified Smoke plus purchase denial/retry, durable rewards, battle/background
lifecycle, navigation, and real audio recovery. Changed functional UI classes
since the preceding commit and previously failed classes are selected alongside Smoke. The authored
Smoke/FullUI registry bounds selection; Profiles and Soak are excluded. A selected
full class covers its critical methods once. These checks protect a critical
subset, not every FullUI scenario.

Upload requires matching exact-commit CI and qualified journey proof. Missing,
failed, cancelled, expired or incompatible evidence blocks upload; resume retains
signed artifacts while awaiting CI. Signing credentials remain on the Mac.
[Verification internals](VerificationInternals.md#testflight-evidence-and-reuse)
owns proof identity, selector checkpoints and cache mechanics.

FullUI runs nightly and on demand. Use `--full-ui` before an App Store/release
candidate or for a deliberate complete local UI pass. A known relevant FullUI
failure still needs triage and resolution before a beta; moving the suite nightly
does not authorize ignoring a known regression. No UI assertion is relaxed by
the beta policy.

The command preserves the marketing version and allocates a build number above
Apple's existing builds for that version, the project baseline, and retained
local reservations. It passes the number to Xcode without modifying tracked
files. Linked worktrees share the deployment lock and new run receipts in the
primary checkout's `.DerivedData/testflight`; existing receipts in registered
worktrees also reserve their build numbers. A live or ambiguous checkout-local
deployment lock from an older script version blocks new deployments until that run
finishes. Concurrent uploads from another Mac
can still collide and require a fresh run. Failed reservations are not reused.
It never commits, tags, pushes, or stashes. `release.sh` remains the separate
formal version/changelog/tag workflow and does not upload to Apple.

Only the configured internal group is assigned by this command. Existing Apple
group auto-distribution rules still apply; review them during setup. Builds remain
eligible for later App Store submission, but this command never submits beta or
App Store review or invites testers. Availability is verified from Apple; it is
not proof of installation or a successful device test.

### One-time TestFlight setup

1. An agent runs `./Scripts/setup-testflight.sh`. It uses installed Homebrew to
   obtain Ruby 3.4 if needed, installs Bundler 4.0.15 beneath `.tools/testflight/`,
   and installs the locked Fastlane dependencies from `Gemfile.lock`. It does not
   use system Ruby, `sudo`, or change shell profiles. Homebrew is the prerequisite
   if the Mac does not already have it; see [Homebrew](https://brew.sh).
2. In App Store Connect, use app record `6811284921` (`com.ryanmcintire.Trinket`;
   named **Trinket!** in the [October 12 portal baseline](AppStoreMetadata.md#candidate-evidence))
   and select an existing internal group with its intended testers. Obtain a team API key through **Users and Access →
   Integrations → App Store Connect API**, with an App Manager or Admin role
   for upload and beta distribution. Signing additionally requires permission
   to access the team's certificates and profiles; the key is not itself a
   signing certificate. Account Holder/Admin assistance may be needed once.
   See [Apple's API setup](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
   and [Fastlane authentication](https://docs.fastlane.tools/app-store-connect-api/).
3. Keep the downloaded `.p8` key outside the repository, with permissions `600`.
   Create `~/.config/trinket/testflight.json` from the
   [configuration template](../../Scripts/config/testflight.example.json), also
   with permissions `600`, under a directory with permissions `700`. Fill in
   the key ID, issuer ID, absolute key-file path, and internal group ID.
   Never put key contents in chat, Git, or command arguments.
4. Run `./Scripts/testflight.sh --doctor`. If the group is not yet configured,
   doctor lists the internal groups available to that app so an agent can save
   the chosen ID. It checks the configured Xcode/SDK, API access, group, local
   signing identities, and clean source state. It performs no provisioning,
   archive, or upload. Listed identities do not prove distribution permission;
   the first successful signed export does.

Use `--config /absolute/path.json` for another local configuration. Authentication
uses the API key throughout; agents should fix a failed prerequisite rather than
falling back to interactive Apple ID login. Signing/provisioning updates occur
only during an actual deployment, through Xcode automatic signing.

### Options and recovery

```sh
./Scripts/testflight.sh --dry-run
./Scripts/testflight.sh --notes /absolute/path/beta-notes.txt
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/testflight.sh --full-ui
./Scripts/testflight.sh --resume /absolute/path/to/.DerivedData/testflight/RUN
```

Dry-run is offline and makes no writes, installs, or Apple calls. Optional notes
populate English **What to Test**; the default is a neutral version/build/commit
description. Existing App Store release notes are not assumed current.

Cloud sync inherits `project.yml`. Only request `--cloud-sync YES` after the
[CloudKit activation gates](CloudKitPreShipChecklist.md#prepared-testflight-activation)
have been satisfied; `--cloud-sync NO` makes an explicit local-only build. The
export checks the effective flag, existing app identity, build/version, signature,
Production iCloud/push entitlements, and export-compliance declaration.

Each new run retains its receipt, archive, IPA, symbols, and logs under the primary
checkout's `.DerivedData/testflight/`. Legacy receipts in the invoking checkout
remain resumable. The receipt links command logs and records the source
commit, Xcode, build number, cloud setting, IPA checksum, and Apple build ID.

Release builds explicitly generate `dwarf-with-dsym` without disabling optimization.
Before upload, `Scripts/build-symbols.py` validates every bundled app/framework
executable against the archive's dSYMs, checks that the exported IPA contains the
same binary UUIDs and nonempty Apple symbol payloads, and makes a hash-verified
copy of the complete archive, IPA, and receipt outside disposable build storage.
The default is `~/Library/Developer/Trinket/BuildArtifacts/releases/`; set
`TRINKET_SYMBOL_BACKUP_ROOT` to use another durable location, such as a backed-up
volume. The default is a local safety copy, not an off-machine backup. Existing
copies are verified and never overwritten with different artifact contents.
The receipt's `symbol_artifacts` records this copy and its manifest; later receipt
updates are mirrored there. Keep release copies for as long as those builds need
diagnosis. If restoring a deleted deployment, restore its original run directory
and paths from these artifacts before resuming.
Already-uploaded legacy receipts without surviving local archives remain
reconcilable using Apple's symbol status; the receipt records that local retention
could not be verified. This cannot recreate a lost archive or dSYM.

After Apple processes the exact uploaded build, deployment requires its app build
bundle's `includesSymbols` to be true before requesting tester distribution or
reporting ready. Missing symbols fail; an unknown state remains pending, with no
automatic re-upload. Check an existing build of the current marketing version
without uploading or distributing anything:

```sh
./Scripts/testflight.sh --verify-symbols 39
```

Backfill a retained archive using its original receipt and exported IPA. `--link`
verifies the recovery copy and writes each receipt atomically under the
deployment lock; it does not upload or change the deployment stage. If the
working files are gone, omit `--archive` and `--ipa` to find exactly one matching
existing backup; missing, ambiguous or damaged backups remain untouched:

```sh
python3 Scripts/build-symbols.py --link --archive /absolute/path/Trinket.xcarchive --ipa /absolute/path/Trinket.ipa --receipt /absolute/path/receipt.json
```

Resume keeps passed phases only while their source and build identity remain
compatible; missing products are rebuilt. See the linked
[checkpoint contract](VerificationInternals.md#testflight-evidence-and-reuse).
New beta receipts record their verification mode and source baseline. Legacy
receipts retain their original FullUI requirement. After qualified hosted UI passes, signed
archive/export runs while standard hosted CI finishes; upload waits for CI and Smoke.
An interrupted CI wait retains the signed IPA and focused results for resume.
Release archives use a retained DerivedData cache keyed by checkout and Xcode.
The process-local `IDEBuildLocationStyle=Unique` override keeps the complete Xcode
archive arena there without changing the Mac's preferences. Leave `SYMROOT`,
`OBJROOT`, and precompiled-header paths under Xcode's control: overriding them
individually can separate compiled products and dSYMs from archive assembly.
Signed archives, exported IPAs, and checksums remain separate
per deployment; a build number or binary is never relabeled for reuse.
[Output retention](../../Scripts/Reference.md#output-retention) owns authoritative
release lifetimes, inspection scratch and duplicate-copy eligibility. Successful
IPA inspection retains compact identity/signature proof before its scoped
extraction is removed.

`cleanup-outputs.py --dry-run --resources --primary` audits duplicate release
working copies. Apply with `--apply --resources --primary` only after reviewing
the inventory. The retention window begins after preservation and completion;
legacy receipts use their last write as a conservative bound.
Each deletion revalidates the authoritative manifest, all archive hashes, matching
native UUIDs/dSYMs and IPA checksum/resources. Working copies must also match;
unknown/mismatched outputs, live owners/open files, locks, recent writes and keeps
are preserved. Cleanup shares the deployment lock. Resume/validation resolves
missing local paths through the authoritative copy. Unfinished or uncertain
deployments never qualify; old receipts need not be rewritten to recover.

The default processing/distribution timeout is 1800 seconds; change it with
`--timeout SECONDS`. Exit `0` means internally available, `2` means pending or
uncertain, and `1` means a failed prerequisite/stage. Doctor and dry-run also use
`0` when their own checks succeed; they never claim a deployed build.

Resume reuses the receipt's notes, target group, cloud setting, and build number.
Before upload it requires the original clean commit and Xcode; after an upload
attempt it reconciles with Apple and does not rebuild or re-upload. An interrupted
transport can have succeeded remotely: do not start repeated uploads just because
the local command was interrupted. If Apple still has no record after the normal
processing window, inspect the upload log and App Store Connect before deciding
to start a new deployment, which allocates a new number.

### TestFlight troubleshooting

| Failure | Agent action |
|---|---|
| Missing Ruby, Bundler, or locked gems | Run `setup-testflight.sh`; do not install gems into system Ruby or update the lockfile to bypass a failure. |
| Missing configuration/key, 401, or 403 | Run doctor; check key path/permissions, revocation, issuer, team, and role. An account owner may need to grant access. |
| Missing/wrong internal group | Doctor lists existing internal groups. Save the intended group ID; do not invent a new app/group or add testers. |
| Dirty checkout or generated drift | Resolve with the owner of the changes; do not commit or stash automatically. Retry from a clean commit. |
| Verification fails | Follow [verification failure handling](Verification.md#failures-and-reporting); resume retains passed phases. Routine beta and `--full-ui` requirements are explicit; there is no skip-verification switch. |
| Certificate, private-key, provisioning, or keychain error | Read archive/export logs, check signing permissions and the local keychain. API access alone does not establish signing access. Do not revoke unrelated certificates. |
| Unsupported Xcode/SDK | Check [Apple's upload requirements](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), select an accepted installation with `DEVELOPER_DIR`, and start a new run. Do not change global `xcode-select`. |
| Agreements or export compliance | Report Apple's exact error; the account owner resolves legal/account answers in App Store Connect. Never guess new compliance answers. |
| Duplicate build number | Check the existing build and its source; start a new run for a new binary. Never relabel or overwrite a retained IPA. |
| Upload interrupted, processing delayed, or distribution pending | Use `--resume RUN`. Do not equate upload acceptance with tester availability. |
| Apple rejects processing or build expires | Inspect the exact Apple build, fix the cause, and start a new run with a new number. |

Local StoreKit qualification currently requires **iOS 26.2 (23C54)**. Probes with
Xcode 27.0 (`27A266a`) and 27.1 RC (`27A9275`) exposed declined Ask to Buy
transactions as verified, unrevoked current entitlements on iOS 27 runtimes, while
iOS 26.2 passed denial/retry. This is local StoreKit-test evidence, not a production
App Store defect. Preserve valid signed entitlements and the denial/retry assertions;
Apple's [Ask to Buy contract](https://developer.apple.com/documentation/storekit/testing-ask-to-buy-in-xcode)
says denial delivers no transaction to the app.

Until requalified, hosted beta proof must record that exact runtime. Bounded local
diagnostics may select it with an explicit managed runtime/type pair; a newer runtime
is not automatically qualified. Retain the selected beta/full-release gate.
Legacy `SKTestTransaction.state` can remain deferred after a correctly resolved denial.
Detailed qualification runs remain in Git history.

On iOS 26.2, `setSimulatedError(nil, forAPI: .purchase)` can report nil while the
server still cancels the next purchase. Use `resetToDefaultState()`, reapply
`disableDialogs`, preserve transaction history, then verify locked access and a
successful retry.

Tooling updates are deliberate maintenance: update the pinned Fastlane version
and Bundler lockfile together, run script regressions and handoff, then rerun
setup. Normal setup uses frozen dependencies and does not update them. Ordinary
app development and hosted CI do not install Fastlane; credential-free deployment
regressions use Ruby's standard library. When the local locked gems are installed,
the same suite also checks real Fastlane token signing and upload-option handling
with the Apple network boundary replaced by fixtures.
