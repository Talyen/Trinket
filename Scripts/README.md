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

Canonical commit format for agents and release parsers (`cliff.toml`, `validate-commit-msg.sh`). Agent workflow overview: `AGENTS.md`.

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

## Verification gates & test tiers

Task → script routing for day-to-day work lives in `AGENTS.md`. This section owns gate composition and tier inventory.

| Gate | Runs |
|------|------|
| `ci-gate.sh` | generate → assert → boundaries → Swift Testing check → style → release-notes validate |
| `ci-locally.sh` | `ci-gate.sh` → unit → quick smoke (+ timing reports) — **pre-push** |
| `test-deploy.sh` | gate-style checks → unit → full UI — **pre-merge** |
| GitHub `pr.yml` | gate → one self-contained build → unit + full smoke (`smoke-full`) on `macos-26` |
| GitHub `ci.yml` (main) | PR verification shape plus one self-contained exhaustive UI job on `macos-26` |

| Tier | Command | When |
|------|---------|------|
| Unit | `test.sh unit` | Every logic change |
| Unit (filtered) | `test.sh unit <Class>` | Focused app logic (`TrinketTests` only) |
| Package unit | `test-package.sh <Package>` | Focused package logic |
| UI smoke canary | `test.sh smoke` | Local / agents — Homestead canary (`QuickSmoke.xctestplan`) |
| Targeted smoke | `test.sh smoke <Class>` | Iterate on one smoke class (`Smoke.xctestplan` + filter) |
| Full smoke | `test.sh smoke-full` | CI / PR only — full `Smoke.xctestplan` |
| Targeted UI | `test.sh ui <Class>` | Focused exhaustive UI iteration |
| Full UI | `test.sh ui` | Pre-merge (includes exhaustive) |
| Integration | `test.sh all` | Nightly / manual |
| Battle performance | `performance.sh` | Exclusive repeated full-fidelity matrix; nightly calibration |

For agent or local task handoffs, `./Scripts/agent-context.sh --paths <file...>`
prints a compact briefing with applicable nested `AGENTS.md` guides, context
cards/skills, generated-output and boundary warnings, and the verification route.
Use `--json` for machine-readable output or `--agent` for a concise handoff.
Without `--paths`, it reports the entire working tree, which is useful only when the
tree represents one task. Agents must run
`./Scripts/verify-changed.sh --isolate --paths <file...>` (preview with `--dry-run`).
`--isolate` acquires a reusable agent simulator slot (`Trinket Agent N`) and
DerivedData under `.DerivedData/runs/agent-N/` via `Scripts/run-env.sh` so concurrent
agents do not share `build.db` or `Trinket CI`. Pool size is `TRINKET_MAX_AGENT_SIMS`
(default 3); slot sims stay Booted between runs. Humans/CI may omit `--isolate` to keep
the shared warm cache. It intentionally does
not replace the pre-push or pre-merge gates.

`test.sh` runs the generation preflight, then builds and tests (unless `--no-build`).
Generation uses a shared lock (timeout via `TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS`,
default 120). Isolated runs take an agent sim slot; UI/smoke modes also take a fail-fast
UI concurrency slot (`TRINKET_MAX_CONCURRENT_UI`, default 2). XcodeGen uses its cache so
unchanged project inputs do not rewrite the project, and the app/test source roots are
Xcode synchronized folders so ordinary source-file additions and deletions do not require
regeneration. CI reports timing regressions from per-run artifacts, but does not fail a
passing suite solely because hosted-runner session overhead exceeds a wall-clock budget.
Pin format/lint/XcodeGen with `./Scripts/ensure-ci-tools.sh`. Warm `agent-N` run dirs are
kept; one-off legacy run dirs under `.DerivedData/runs/` and orphan `Trinket Run *`
simulators are pruned by `./Scripts/prune-derived-data-cache.sh` (age via
`TRINKET_RUN_MAX_AGE_DAYS`, default 3; set `TRINKET_PRUNE_ORPHAN_SIMULATORS=0` to skip
sim deletes). Parallel source trees:
`./Scripts/agent-worktree.sh create <slug>`.

`performance.sh` is intentionally separate from smoke and integration gates. It takes an
exclusive Battle-performance lock, forces one UI lane, runs `BattlePerformance.xctestplan`
with one measured report per scenario by default, collects raw frame reports, and compares
them with the observe/enforce policy in `Performance/Baselines/simulator-60.json`. Override
repetitions for diagnostic spreads with `TRINKET_PERFORMANCE_REPETITIONS=N` (skips the
single-report gate compare when N > 1). Use `test.sh performance <Class[/method]>`
only for focused harness iteration; use `performance.sh` for comparable artifacts.

For failure report schemas and triage order, read
`Docs/AgentContext/ci-diagnostics.md`. Operators can aggregate current reports with
`./Scripts/ci-diagnostics.sh .DerivedData/TestResults` (or the isolated
`.DerivedData/runs/agent-N/TestResults`) or clear cached status and
diagnostic artifacts with `./Scripts/ci-diagnostics.sh --reset
.DerivedData/TestResults`. Consume the structured aggregate and per-invocation reports
before raw xcodebuild logs; an `unknown` category is the explicit escalation path.
CI keeps the existing `test.sh`/`test-package.sh` scopes and omits `--verbose` so
structured reports remain the primary actionable output while raw logs stay available
as artifacts.

### Toolchain ladder (cloud / no Xcode 26)

Local and CI expect **Xcode 26+**. Without the simulator toolchain:

1. Land correct source/docs changes.
2. Run what you can: `./Scripts/generate.sh`, `./Scripts/assert-generated-output.sh`, `./Scripts/check-module-boundaries.sh`, `./Scripts/check-ui-style.sh`, `./Scripts/ci-gate.sh`.
3. Skip `build.sh` / `test.sh` / simulator work — state that clearly in the commit/PR body.
4. When Xcode 26 + simulator **are** present, `build.sh` / `test.sh` (or the AGENTS Task Router row) are mandatory before claiming the change is verified.

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
| `./Scripts/agent-context.sh [--agent\|--json] [--paths <file...>]` | Emit a compact task context briefing and verification plan |
| `./Scripts/changed-source-summary.sh [--paths <file...>]` | Summarize task-scoped or working-tree changes and focused agent route |
| `./Scripts/verify-changed.sh [--dry-run] [--isolate] [--paths <file...>]` | Run the minimum sequential verification; agents always pass `--isolate` |
| `./Scripts/agent-worktree.sh create\|list\|remove <slug>` | Sibling git worktree for parallel agent checkouts |
| `./Scripts/ci-diagnostics.sh [--reset] [RESULTS_DIR]` | Aggregate current invocation diagnostics or clear cached status artifacts |
| `./Scripts/balance-sweep.sh` | Headless battle balance sweep → `BalanceSweepReports/*.md` |

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

## Style & lint ownership

`./Scripts/test.sh style` runs five complementary checks. Do not blur their roles.
The style mode **fails closed**: any non-zero SwiftFormat / SwiftLint / UI style /
platform-ban / exclusivity exit fails the gate (matching CI).

| Tool | Config | Owns |
|------|--------|------|
| SwiftFormat | `.swiftformat` | Whitespace, commas, import order, trailing newlines, brace layout |
| SwiftLint | `.swiftlint.yml` | Semantics, API idioms, structural size, force unwrap/cast/try; macOS custom_rules for platform bans |
| UI style | `Scripts/check-ui-style.sh` | Product chrome **and colors** — glass/material/button styles, raw RGB/`UIColor`/`#colorLiteral`, SwiftUI system color literals, app-bundle/`Color("…")` names, and `.accentColor`; route through `TrinketDesign` |
| Platform bans | `Scripts/check-platform-api-bans.sh` | `NavigationView` / `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` / `@ObservedObject` (SourceKit-free) |
| Exclusivity | `Scripts/check-exclusivity-footguns.sh` | `inout` of `self.` / likely stored properties without a local copy (`ExclusivityCheck: allow`) |

Pinned versions live in `Scripts/tool-versions.env`. Shared format/lint roots live in `Scripts/swift-source-dirs.env` (app, packages, package tests, `TrinketTestSupport`). Install with `./Scripts/ensure-ci-tools.sh`. Module layering is a separate gate: `./Scripts/check-module-boundaries.sh`.

The app-wide palette is centralized in `TrinketDesignSystem`: feature views use `TrinketDesign.Colors`, keyword/homestead/resource helpers, and hero scrim APIs instead of `Color(red:green:blue:)`, SwiftUI system colors (`Color.green`, `.foregroundStyle(.white)`, …), app-bundle `Color("…", bundle: .main)`, or `.accentColor`. Domain colors (keywords, encounters, resources) still live as named assets in `DesignColors.xcassets`. Reserve `UIStyleCheck: allow` for narrowly scoped exceptions with a nearby reason.

## Configuration files

| File | Role |
|------|------|
| `.swiftformat` / `.swiftlint.yml` | Format + semantic lint (see Style & lint ownership) |
| `Scripts/swift-source-dirs.env` | Shared Swift roots for `format.sh` / `lint.sh` |
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
- `.githooks/pre-push` → format lint + SwiftLint + UI style + platform bans + exclusivity + generate/assert (blocks push on drift)

Install pinned SwiftFormat/SwiftLint with `./Scripts/ensure-ci-tools.sh` (versions in `Scripts/tool-versions.env`). Skip the pre-push gate once with `SKIP_TRINKET_PREPUSH=1`. For the full local CI gate without unit/quick-smoke, run `./Scripts/ci-gate.sh`. Commit-msg warnings are advisory and do not block commits.
