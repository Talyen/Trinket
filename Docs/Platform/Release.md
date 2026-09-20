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
rolling support window; verify both supported majors before claiming readiness.

Before App Store submission, complete the
[purchase release prerequisites](Purchases.md#before-release), including the
public support contact and published support/privacy pages. When enabling iCloud
progress sync, also complete the [CloudKit checklist](CloudKitPreShipChecklist.md).
Local-only releases do not require CloudKit enablement. The commands below
produce verified release artifacts; they do not provision these external services.

### Prepare while the beta is running

Use the existing App Store Connect record for TestFlight (provisioning:
[CloudKit setup baseline](CloudKitPreShipChecklist.md#setup-baseline).
Complete its public listing using the [metadata draft](AppStoreMetadata.md);
do not create another app or change the bundle ID to match the display name.

1. In **Apps → Trinket: Heroes & Companions → App Information**, prepare the
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

```sh
./Scripts/release.sh --dry-run
./Scripts/release.sh
git push origin main --tags
```

The release command runs deploy verification, chooses or accepts a semantic
version, increments the build number, generates changelog and store notes,
checks unsigned device Release compilation after updating the version, commits
release artifacts, and creates a tag. This compile check does not validate signing
or App Store distribution. Useful exceptions include
`--version X.Y.Z`, `--no-tag`, and emergency-only `--skip-tests`.

A pushed `v*` tag triggers the GitHub release workflow. It confirms that the
tagged commit is on `main` with green CI, then creates a GitHub Release whose
body is `ReleaseNotes/en-US.txt` plus a pointer to `CHANGELOG.md` and uploads that file as an artifact. It does
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

This is the canonical agent entry point for TestFlight. It runs the full
[deploy verification gate](Verification.md#gate-composition) with simulator
isolation, archives and exports a signed Release build, uploads it, and waits
for the exact build to be available to the configured internal testing group.
Fastlane is [free, MIT-licensed local tooling](https://github.com/fastlane/fastlane);
there is no additional hosted service or subscription. Agents manage the tooling.

The command preserves the marketing version and allocates a build number above
Apple's existing builds for that version, the project baseline, and retained
local reservations. It passes the number to Xcode without modifying tracked
files. Local deployments are serialized; concurrent uploads from another Mac
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
2. In App Store Connect, use the existing **Trinket: Heroes & Companions** app
   (`com.ryanmcintire.Trinket`) and select an existing internal group with its
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

Each run retains its receipt, archive, IPA, symbols, and logs under
`.DerivedData/testflight/`. The receipt links command logs and records the source
commit, Xcode, build number, cloud setting, IPA checksum, and Apple build ID.
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
| Verification fails | Follow [verification failure handling](Verification.md#failures-and-reporting); there is no TestFlight skip-tests switch. |
| Certificate, private-key, provisioning, or keychain error | Read archive/export logs, check signing permissions and the local keychain. API access alone does not establish signing access. Do not revoke unrelated certificates. |
| Unsupported Xcode/SDK | Check [Apple's upload requirements](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), select an accepted installation with `DEVELOPER_DIR`, and start a new run. Do not change global `xcode-select`. |
| Agreements or export compliance | Report Apple's exact error; the account owner resolves legal/account answers in App Store Connect. Never guess new compliance answers. |
| Duplicate build number | Check the existing build and its source; start a new run for a new binary. Never relabel or overwrite a retained IPA. |
| Upload interrupted, processing delayed, or distribution pending | Use `--resume RUN`. Do not equate upload acceptance with tester availability. |
| Apple rejects processing or build expires | Inspect the exact Apple build, fix the cause, and start a new run with a new number. |

Tooling updates are deliberate maintenance: update the pinned Fastlane version
and Bundler lockfile together, run script regressions and handoff, then rerun
setup. Normal setup uses frozen dependencies and does not update them. Ordinary
app development and hosted CI do not install Fastlane; credential-free deployment
regressions use Ruby's standard library. When the local locked gems are installed,
the same suite also checks real Fastlane token signing and upload-option handling
with the Apple network boundary replaced by fixtures.

## Local hooks and push discipline

The Git safety shim refuses destructive commands on a dirty tree without
stashing files or changing the index. Leading Git options such as `-C` and `-c`
apply to both its checks and the requested command.

`git config core.hooksPath .githooks` enables the advisory commit-message hook,
staged-project validation, and pre-push checks. Generation and idempotence policy
lives in [Verification.md](Verification.md#generated-project-consistency); the hooks
enforce it at commit/push time. Pre-push styles Swift files in the
commits being pushed (platform bans stay full-tree), runs the internal
push gate, then path-scoped package tests against
that generated tree. A requested push still requires a green path-scoped
handoff before commit. Review and include only task-related authored and
generated files; stage individual hunks when task and unrelated changes share a file.

Pre-push invokes `agent-push-gate.sh` internally; do not run it manually after
commit. Landing policy remains in [AGENTS.md](../../AGENTS.md#protect-the-workspace).

Direct pushes to `main` justify repeating these inexpensive path-scoped
safeguards at pre-push: style, generated-output completeness, and
touched-package tests rerun even when handoff just verified the same tree;
there is no receipt reuse. The hook implements `SKIP_TRINKET_PREPUSH=1` as a
manual bypass, but it does not satisfy the required verification or authorize
skipping checks during routine agent work. Report blocked checks under
[Verification.md](Verification.md#failures-and-reporting).

TestFlight uploads use the [local deployment command](#local-testflight-deployment).
App Store submission remains a separate owner-requested action.
