# Release process

Trinket generates a developer changelog and player-facing App Store notes at a
release boundary. Agents do not edit `CHANGELOG.md` or `ReleaseNotes/en-US.txt`
for ordinary commits.

## Sources of truth

- `project.yml`: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
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
artifacts use the newest installed Xcode; [toolchain selection](../../Scripts/Reference.md#toolchain-ladder)
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
generated files.

Pre-push invokes `agent-push-gate.sh` internally; do not run it manually after
commit. Landing policy remains in [AGENTS.md](../../AGENTS.md#protect-the-workspace).

Direct pushes to `main` justify repeating these inexpensive path-scoped
safeguards at pre-push: style, generated-output completeness, and
touched-package tests rerun even when handoff just verified the same tree;
there is no receipt reuse. The hook implements `SKIP_TRINKET_PREPUSH=1` as a
manual bypass, but it does not satisfy the required verification or authorize
skipping checks during routine agent work. Report blocked checks under
[Verification.md](Verification.md#failures-and-reporting).

Fastlane upload remains a separate future step: provide an App Store Connect API
key, configure `deliver`, and extend the release workflow only when automated
TestFlight/App Store submission is deliberately enabled.
