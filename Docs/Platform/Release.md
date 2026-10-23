# Release process

Trinket generates a developer changelog and player-facing App Store notes at a
release boundary. Agents do not edit `CHANGELOG.md` or `ReleaseNotes/en-US.txt`
for ordinary commits.

## Sources of truth

- `project.yml`: `MARKETING_VERSION` and the baseline `CURRENT_PROJECT_VERSION`
- Local TestFlight receipt: allocated upload build number and source commit;
  TestFlight overrides the baseline at archive time without editing the project
- `cliff.toml`: developer changelog categories
- `ReleaseNotes/en-US.txt`: generated App Store/TestFlight notes

Run `generate.sh` after changing a version so the generated Xcode project stays
in sync.

## Commit messages

Use an imperative subject, preferably:

```text
<type>(<scope>): <subject no longer than 72 characters>

- <notable change>
```

Supported types are `feat`, `fix`, `perf`, `refactor`, `content`, `style`,
`test`, `ci`, `chore`, `build`, and `docs` (`build` and `chore` are excluded
from release notes). Plain imperative subjects remain supported.
Prefer `feat` or `fix` when a change is player-visible; use `refactor` for
internal reshaping. Player-facing notes are inferred from commit type and
touched paths at release time.

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
[isolated workflow](#isolated-chat-workflow).

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
Pro / iOS 26.2 runtime if needed, reuses compatible products or the shared warm
build cache, and runs qualified Smoke plus purchase denial/retry, durable rewards, battle/background
lifecycle, navigation, and real audio recovery. Changed functional UI classes
since the preceding commit and previously failed classes are selected alongside Smoke. The authored
Smoke/FullUI registry bounds selection; Profiles and Soak are excluded. A selected
full class covers its critical methods once. These checks protect a critical
subset, not every FullUI scenario.

Successful journey inputs and failed-class markers are retained in a hosted cache.
Reuse compares committed app, resources, configuration, tooling, shared helpers,
selected tests, Xcode/SDK, architecture, simulator profile, and verification
settings. Every expected UI case must execute once and pass before evidence is
saved. A failure revokes prior evidence for its class and selects that class again
on the next candidate. Pending selectors share one invocation per test plan;
complete passed selectors remain checkpointed if another selector fails.
Unknown shared helpers invalidate conservatively.

Deployment consumes the exact-commit workflow's successful qualified job and
proof artifact. Its receipt must match the release commit, Xcode, SDK, host
architecture, and qualified simulator profile, and cover every critical journey.
The standard CI `CI OK` gate must also succeed for that commit. Smoke is
proven by the complete qualified hosted classes, or an actual standard CI Smoke
execution; a skipped standard Smoke job does not force unrelated package reruns. Missing, failed, cancelled, unreadable, expired, or mismatched proof
blocks upload; there is no automatic local test fallback. Resume retains signed
artifacts while awaiting CI. Signing keys and App Store Connect credentials stay
on the Mac; simulator CI needs no Apple distribution credentials.

Hosted warm builds also retain a source-timestamp manifest. Before Xcode runs,
CI restores an input's prior timestamp only when its current bytes, size, mode,
and checkout/toolchain context match the cached record. Changed, new, missing,
or symlinked inputs stay fresh. This avoids treating every file in a fresh Git
checkout as changed while retaining Xcode's normal build/dependency checks.
The manifest is refreshed only after a successful build and saved with DerivedData.

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
2. In App Store Connect, use app record `6811284921` (currently **Trinket!**;
   `com.ryanmcintire.Trinket`) and select an existing internal group with its
   intended testers. Obtain a team API key through **Users and Access →
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

Backfill a retained archive using its original receipt and exported IPA:

```sh
python3 Scripts/build-symbols.py --archive /absolute/path/Trinket.xcarchive --ipa /absolute/path/Trinket.ipa --receipt /absolute/path/receipt.json
```

`verification.json` checkpoints successful package suites and UI selectors, with
phase timings and local or hosted evidence. Resume runs only missing phases for
the same clean commit, checkout, toolchain/SDK, architecture, and simulator
profile. A changed identity invalidates the checkpoints; a failed phase never
becomes a checkpoint. Missing build products are rebuilt before remaining tests.
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
Keep these artifacts through the beta's debugging window; do not delete them
while a run needs recovery. This directory is outside routine simulator-run
cleanup. Retention is manual because archives and symbols may be needed later.

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

Local StoreKit qualification (2026-10-11): Xcode 27.0 (27A266a) with iOS 27.0
(24A434) exposed a denied Ask to Buy purchase as a verified current entitlement
in a standalone app. With the same Xcode, iOS 26.2 (23C54) passed both the
standalone approval/denial/retry controls and Trinket's denial/retry journey.
Requalified 2026-10-12 with Xcode 27.1 RC (27A9275): iOS 27.1 (24A94232)
still returns the declined transaction as a verified, unrevoked current entitlement
while StoreKitTest marks the same transaction failed. An independent direct
`Transaction.currentEntitlements` probe reproduced this before Trinket's access
assertion failed. The same RC-built app on iOS 26.2 (23C54) returned no entitlement
after denial and passed denial plus a subsequent purchase. This is an iOS 27 local
StoreKit testing defect, not evidence of a production App Store failure. Do not
filter valid signed entitlements or skip the denial assertion to accommodate it.
Until requalified, hosted beta verification requires iOS 26.2 and records its
actual runtime in the proof. Deliberate local diagnostics may select the same
managed profile with an explicit runtime/type pair. A newer runtime is not automatically qualified.
Retain the selected beta or full-release gate and the player-facing denial and retry checks;
legacy `SKTestTransaction.state` can remain deferred after a correctly resolved
denial. This finding concerns local StoreKit testing, not production App Store
behavior. Apple's [Ask to Buy testing contract](https://developer.apple.com/documentation/storekit/testing-ask-to-buy-in-xcode)
says denial delivers no transaction to the app. On iOS 26.2, clearing a simulated
purchase cancellation with `setSimulatedError(nil, forAPI: .purchase)` reports nil
but can leave the following purchase canceled by the test server. Reset the test
configuration with `resetToDefaultState()` and reapply `disableDialogs` before
retrying; keep the transaction history and verify locked access and successful retry.

Tooling updates are deliberate maintenance: update the pinned Fastlane version
and Bundler lockfile together, run script regressions and handoff, then rerun
setup. Normal setup uses frozen dependencies and does not update them. Ordinary
app development and hosted CI do not install Fastlane; credential-free deployment
regressions use Ruby's standard library. When the local locked gems are installed,
the same suite also checks real Fastlane token signing and upload-option handling
with the Apple network boundary replaced by fixtures.

## Isolated chat workflow

Use one isolated worktree and task branch per implementation chat; reuse its own
suitable worktree. Task-scoped branch/worktree creation, commits, and local landing
are authorized for implementation unless the user restricts the task. Pushes, PRs,
publication, destructive cleanup, and unrelated changes need separate authorization.
Read-only investigations can stay in the current checkout.

From any checkout, create from committed local `main` (no fetch or dirty-file copy):

```sh
node Scripts/agent-worktree.mjs create --task <slug>
```

The helper prints the primary checkout's `.worktrees/<slug>` path and creates
`codex/<slug>`. Use `--base <ref>` only for a user-specified alternative. Existing
branches/directories are preserved; choose a unique slug for a new task. Run all
implementation, review, and scoped checks inside the task worktree. Worktree
isolation does not isolate external resources; retain existing simulator leases,
asset-library safeguards, and verification limits. Supported check commands resolve
installed tools from the task checkout first,
then the primary checkout, then `PATH`; version and checksum gates still enforce
pins. No manual `PATH` setup is needed in a fresh worktree. If tools are absent,
use `./Scripts/ensure-ci-tools.sh`; lookup never installs implicitly. Build directories
and generated resources remain checkout-local.

For API or combat-semantic migrations, repeat the
[consumer review](Testing.md#fixtures) after incorporating current main; include
unchanged downstream tests and shared fixtures. Review the complete task diff and
relevant integration contracts, run any focused checks needed while iterating,
and commit only task-related files under the staging discipline below. Integration
provides the required final handoff; a separate pre-commit handoff is unnecessary.
Then, **from the task worktree**, run:

```sh
node Scripts/agent-worktree.mjs integrate
```

`Scripts/agent-integrate.py` takes a nonblocking OS file lock at
`trinket-integration.lock` in Git's common directory, shared by all linked worktrees.
It requires a clean task checkout on `codex/` and a clean primary checkout already
on `main`, with no unfinished Git operations. While holding the lock, it rebases
onto current local `main`, runs `handoff.sh --isolate --quiet --paths` for the full
rebased task diff (including deletions and both rename endpoints), rechecks both
checkouts, protects ignored files from incoming tracked-path collisions, and
fast-forwards primary `main`. All automated local main landings must
use this command. Keep manual main edits out of the integration window; the lock
is cooperative. The command does not fetch, push, create a PR, or run hosted checks.

A busy lock means retry later without messaging peers. The OS releases it when the
process exits, including crashes; never delete the lock file, which would split
lock ownership. Dirty primary main remains untouched: leave the task committed and
report the blocker if it persists. A rebase conflict stays in the task worktree;
resolve understood conflicts there, review the combined result, finish the rebase,
and retry. Bring ambiguous behavior decisions to the user. A failed handoff leaves
main unchanged; repair the task, review and commit the fix, then retry. If the safe
integration command is unavailable, retain reviewed commits on the task branch and
report that limitation rather than landing through an unguarded command.

No routine chat coordination is needed; the root guide's
[communication rules](../../AGENTS.md#communication) own peer messaging.

Successful integration automatically deletes and unregisters only the invoking
task worktree under the same integration lock, including ignored files and build
outputs. Handoff automatically saves compact verification reports; integration
adds `task-report.json` with the verified commit, main base, task paths and report
links. Before landing or cleanup, it preserves `.DerivedData/Deliverables/` in
Git's shared `trinket-evidence/<branch>/` directory, outside task worktrees, with
the preservation commit, branch, and original paths. This metadata records
when files were preserved; capture/build identity still comes from the evidence.
Evidence copies never follow symlinks; a failed preservation stops landing/cleanup. Each copy gets a unique
directory, so retries do not overwrite earlier evidence. To preserve other
task-local files immediately, run `node Scripts/agent-worktree.mjs evidence <paths...>`;
without paths it prints the durable directory for direct captures. Evidence is
retained until deliberately removed, separately from expiring diagnostic logs.
Cleanup rechecks its registration,
branch, commit, clean state and Git operation state; locked worktrees and submodules
are preserved. A failed handoff never cleans up. Cleanup failure reports after the
completed integration; it does not roll main back. From the retained task checkout,
`node Scripts/agent-worktree.mjs cleanup` retries preservation and removal only,
without rebase, verification or another landing. It accepts a task whose commit
is already an ancestor of main, even after later tasks land. The shared lock,
clean-task, registration, branch, submodule and symlink protections still apply;
dirty primary files are untouched because cleanup does not change main.

The checkout first moves atomically to a temporary directory under
`~/.codex/worktree-archives/Trinket/` so failed unregistration can restore it.
After unregistration, the temporary directory is deleted immediately; successful
integration retains no archived checkout or build output. The task branch remains
available through `git worktree add <original-path> <branch>`; ignored and other
local-only files are permanently deleted. Use `--keep-worktree` when those files
are still needed. `CODEX_WORKTREE_ARCHIVE_ROOT` can select an external staging
directory; a cross-filesystem move fails without deleting the source. If cleanup
fails after integration, inspect the reported checkout or staging directory;
`recovery.json` records the original path, branch and commit.

Pass `node Scripts/agent-worktree.mjs integrate --keep-worktree` for intermediate
integration when requested work, a preview or an experiment still needs the checkout.
Report the local main commit, verification boundary and cleanup result. Hosted checks
remain pending until a separately authorized push. Explicit removal from primary
remains available with `node Scripts/agent-worktree.mjs remove --task <slug>` after
preserving ignored files; it refuses dirty, unmerged or unexpected worktrees and
retains the branch.

## Local hooks and push discipline

The Git safety shim refuses destructive commands on a dirty tree without
stashing files or changing the index. Leading Git options such as `-C` and `-c`
apply to both its checks and the requested command.

`git config core.hooksPath .githooks` enables the advisory commit-message hook,
staged-project validation, and pre-push checks. Generation and idempotence policy
lives in [Verification.md](Verification.md#generated-project-consistency); the hooks
enforce staged-project completeness at commit time. Pre-push styles Swift files in
the commits being pushed (platform bans stay full-tree) and checks committed
generated-output completeness. Asset-routed pushes also check selected Asset Library
sources for freshness; other pushes check prepared outputs without the library.
Prepare changed media and download offloaded sources before an asset-routed push;
[media preparation](../AgentContext/content-and-manifests.md#media-assets) owns that workflow.
Pre-push does not regenerate assets or run package tests;
CI owns content generation freshness, idempotence, compilation, and game/UI suites.
A requested push still requires a green path-scoped
handoff for the complete task; successful locked integration supplies it. A
standalone task must run handoff explicitly. Review and include only task-related
authored and generated files; stage individual hunks when task and unrelated changes share a file.

Pre-push validates Git's outgoing ref/object pairs against the checked-out HEAD
and requires a clean checkout, including nonignored untracked files. It fails on
unavailable revisions or failed Git inspection; new remote refs select their full
tree, and deletions and both rename endpoints remain in scope. Checks revalidate
source before reporting success. Preserve outstanding work rather than clearing
it to pass the hook.

Pre-push invokes `agent-push-gate.sh` internally with that outgoing scope; do not
run it manually after commit. Landing policy remains in [AGENTS.md](../../AGENTS.md#protect-the-workspace).

Direct pushes to `main` retain inexpensive pre-push safeguards: scoped style and
committed generated-output completeness, plus the asset checks described above.
A local handoff is lightweight evidence;
watch CI for the deferred compile, package, and UI checks. There is no receipt reuse. The hook implements `SKIP_TRINKET_PREPUSH=1` as a
manual bypass, but it does not satisfy the required verification or authorize
skipping checks during routine agent work. Report blocked checks under
[Verification.md](Verification.md#failures-and-reporting).

TestFlight uploads use the [local deployment command](#local-testflight-deployment).
App Store submission remains a separate owner-requested action.
