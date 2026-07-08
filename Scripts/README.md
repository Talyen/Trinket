# Release pipeline

Automated changelog and App Store release note generation for Trinket. Designed for
agent-driven commits on `main` with release-boundary automation (no per-commit manual
changelog editing).

## Overview

```mermaid
flowchart LR
  commits[Git commits on main]
  release[./Scripts/release.sh]
  changelog[CHANGELOG.md]
  appstore[ReleaseNotes/en-US.txt]
  fastlane[fastlane/metadata/...]
  tag[Git tag vX.Y.Z]
  gh[GitHub Release workflow]

  commits --> release
  release --> changelog
  release --> appstore
  release --> fastlane
  release --> tag
  tag --> gh
```

| Artifact | Audience | Generator |
|----------|----------|-----------|
| `CHANGELOG.md` | Developers, agents | `git-cliff` via `cliff.toml` (Keep a Changelog) |
| GitHub Release body | Contributors, QA | Same as changelog (`.github/workflows/release.yml`) |
| `ReleaseNotes/en-US.txt` | App Store / TestFlight | `./Scripts/release-notes-user.sh` |
| `fastlane/metadata/en-US/release_notes.txt` | Fastlane `deliver` (Phase 3) | Copied from `ReleaseNotes/en-US.txt` |

## Version source of truth

Marketing and build numbers live in `project.yml`:

```yaml
settings:
  base:
    MARKETING_VERSION: "0.1.0"       # semver, bumped at release
    CURRENT_PROJECT_VERSION: "1"     # build number, always increments
```

Run `./Scripts/generate.sh` after changing versions so XcodeGen picks them up.

## Commit message contract

Agents should write commits using this structure (see `AGENTS.md`):

```
<type>(<scope>): <imperative subject ≤72 chars>

- <notable change>
- <another change>

User-Facing: yes | no
Breaking: <description if any>
```

**Types:** `feat`, `fix`, `perf`, `refactor`, `content`, `style`, `test`, `ci`, `chore`, `docs`

Imperative subjects without a type prefix (`Add session state restoration…`) are also
supported via regex parsers in `cliff.toml`.

Set `User-Facing: yes` when players would notice the change. Set `User-Facing: no` for
CI, style, refactor, and tooling-only work. If omitted, heuristics in
`release-notes-user.py` decide.

Agents do **not** edit `CHANGELOG.md` per commit. Release scripts generate it at tag time.

## Commands

| Script | Purpose |
|--------|---------|
| `./Scripts/ensure-git-cliff.sh` | Install/run git-cliff (cached in `.tools/`) |
| `./Scripts/release-notes.sh unreleased` | Preview unreleased changelog |
| `./Scripts/release-notes.sh prepend v0.2.0` | Prepend version section to `CHANGELOG.md` |
| `./Scripts/release-notes.sh bump` | Print suggested next semver |
| `./Scripts/release-notes.sh validate` | Verify `cliff.toml` parses history |
| `./Scripts/release-notes-user.sh` | Generate App Store notes + `.prompt.md` |
| `./Scripts/release.sh` | Full release orchestration |
| `./Scripts/validate-commit-msg.sh` | Advisory commit message check |

### Typical release flow

```sh
# Preview
./Scripts/release.sh --dry-run

# Ship (runs test-deploy.sh, bumps version, commits, tags)
./Scripts/release.sh

# Push when ready
git push origin main --tags
```

Options:

- `--version X.Y.Z` — explicit semver instead of auto-bump
- `--skip-tests` — skip deploy gate (avoid except emergencies)
- `--no-tag` — commit release assets without tagging

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which creates a GitHub
Release and uploads App Store note artifacts.

## Configuration files

| File | Role |
|------|------|
| `cliff.toml` | Developer changelog (Keep a Changelog categories) |
| `cliff-appstore.toml` | Alternate git-cliff template (plain bullets) |
| `ReleaseNotes/.prompt.md` | Generated prompt for optional AI polish (gitignored) |

## App Store guidance (Apple)

Apple documents the **What's New in this Version** field in
[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/):

- Required for every update after the first App Store version
- Up to 4,000 characters, plain text, localizable
- Apple recommends specific, user-meaningful descriptions

Apple does not provide Swift or Xcode changelog tooling. Trinket uses git-cliff plus a
user-facing rewrite step (`release-notes-user.py`) to satisfy store requirements.

`release-notes-user.sh` validates the 4,000-character limit and warns when the summary
line exceeds ~150 characters (mobile truncation point).

## Optional AI polish

After `./Scripts/release.sh`, read `ReleaseNotes/.prompt.md` and ask an agent to rewrite
the draft in `ReleaseNotes/en-US.txt` for player-facing tone. Re-run validation:

```sh
wc -c ReleaseNotes/en-US.txt   # must be ≤ 4000
```

Then amend the release commit or commit the polished notes before pushing the tag.

## Phase 3: TestFlight / App Store automation

When ready to ship builds:

1. Add Fastlane with `deliver` reading `fastlane/metadata/en-US/release_notes.txt`
2. Store an App Store Connect API key in GitHub secrets
3. Extend `release.yml` with a macOS job: build → TestFlight upload → set metadata

See [Create a new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version)
and [Creating Your Product Page](https://developer.apple.com/app-store/product-page/) for
Apple's store-side workflow.

## Commit message hook (optional)

Install locally for advisory warnings:

```sh
git config core.hooksPath .githooks
```

The repo includes:

- `.githooks/commit-msg` → `./Scripts/validate-commit-msg.sh` (advisory)
- `.githooks/pre-push` → format lint + generate/assert (blocks push on drift)

Install pinned SwiftFormat/SwiftLint with `./Scripts/ensure-ci-tools.sh` (versions in `Scripts/tool-versions.env`). Skip the pre-push gate once with `SKIP_TRINKET_PREPUSH=1`. For the full local CI gate without unit/smoke, run `./Scripts/ci-gate.sh`. Commit-msg warnings are advisory and do not block commits.
