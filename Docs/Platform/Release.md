# Release process

Trinket generates developer changelogs and player-facing App Store notes at a
release boundary. Agents do not edit `CHANGELOG.md` for ordinary commits.

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

User-Facing: yes | no
Breaking: <description when applicable>
```

Supported types are `feat`, `fix`, `perf`, `refactor`, `content`, `style`,
`test`, `ci`, `chore`, and `docs`. Plain imperative subjects remain supported.
Mark player-visible changes explicitly; otherwise release-note generation uses
heuristics.

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
tagged commit is on `main` with green CI, then creates a GitHub Release and
uploads store-note artifacts. It does not repeat the full suite already run by
the release command and main CI.

Apple's What's New field is required for updates after the first version, is
plain text and localizable, and permits up to 4,000 characters. See
[Apple's platform version reference](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).
`release-notes-user.sh` validates the limit and writes an optional polishing
prompt to `ReleaseNotes/.prompt.md`.

## Local hooks and push discipline

`git config core.hooksPath .githooks` enables the advisory commit-message hook
and the pre-push style/generation checks. Pre-push styles Swift files in the
commits being pushed (platform bans stay full-tree), runs `agent-push-gate.sh`
(regenerate only when classification says content, project, or assets changed),
then path-scoped package tests against that generated tree. A requested push
still requires a green path-scoped handoff before commit. Review and include only task-related authored and generated files.

Fastlane upload remains a separate future step: provide an App Store Connect API
key, configure `deliver`, and extend the release workflow only when automated
TestFlight/App Store submission is deliberately enabled.
