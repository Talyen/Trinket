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
`test`, `ci`, `chore`, and `docs`. Plain imperative subjects remain supported.
Prefer `feat` or `fix` when a change is player-visible; use `refactor` for
internal reshaping. Player-facing notes are inferred from commit type and
touched paths at release time.

## Shipping

```sh
./Scripts/release.sh --dry-run
./Scripts/release.sh
git push origin main --tags
```

The release command runs deploy verification, chooses or accepts a semantic
version, increments the build number, generates changelog and store notes,
commits release artifacts, and creates a tag. Useful exceptions include
`--version X.Y.Z`, `--no-tag`, and emergency-only `--skip-tests`.

A pushed `v*` tag triggers the GitHub release workflow. It confirms that the
tagged commit is on `main` with green CI, then creates a GitHub Release whose
body is `ReleaseNotes/en-US.txt` and uploads that file as an artifact. It does
not repeat the full suite already run by the release command and main CI.

Apple's What's New field is required for updates after the first version, is
plain text and localizable, and permits up to 4,000 characters. See
[Apple's platform version reference](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).
`release-notes-user.py` infers player-facing commits and writes
`ReleaseNotes/en-US.txt`. Paste that file into App Store Connect when submitting.

## Local hooks and push discipline

`git config core.hooksPath .githooks` enables the advisory commit-message hook
and the pre-push style/generation checks. Pre-push styles Swift files in the
commits being pushed (platform bans stay full-tree), runs `agent-push-gate.sh`
(regenerate only when classification says content, project, or assets changed),
then path-scoped package tests against that generated tree. A requested push
still requires a green path-scoped handoff before commit. Review and include only task-related authored and generated files.

A green `handoff.sh --isolate` writes a content-addressed receipt
(`.DerivedData/handoff-receipt.json`) keyed by the verified tree hash. Both
`agent-push-gate.sh` and the `pre-push` hook reuse that receipt: when the tree
about to be pushed is exactly the tree handoff just verified, the push gates
skip the duplicate generate/style/package work and only run a cheap idempotent
assert. Any new diff, ancestry change, or classification mismatch falls through
to the full gates — there is no time-window trust.

Fastlane upload remains a separate future step: provide an App Store Connect API
key, configure `deliver`, and extend the release workflow only when automated
TestFlight/App Store submission is deliberately enabled.
