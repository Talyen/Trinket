# Scripts

This is the command index for Trinket's generated project, verification, asset,
and release tooling. The scripts and checked-in configuration are authoritative;
the linked guides explain routing and operating policy.

## Everyday workflow

```sh
./Scripts/generate.sh
./Scripts/test-package.sh BattleEngine
./Scripts/test.sh unit
./Scripts/agent-context.sh --agent --paths <changed-paths...>
./Scripts/handoff.sh --isolate --paths <changed-paths...>
```

Agents always use an isolated path-scoped handoff. Humans may omit `--isolate`
to reuse the shared warm build tree. Do not regenerate assets during ordinary
Swift iteration unless an asset manifest or source changed.

Read these focused guides:

- [Documentation map](../Docs/README.md) — source-of-truth owners.
- [Verification and CI](../Docs/Platform/Verification.md) — task routing, test
  tiers, gate composition, style ownership, and diagnostics.
- [Simulator operations](../Docs/Platform/SimulatorOperations.md) — isolation,
  local Xcode setup, cache hygiene, and CrashReporter guidance.
- [Release process](../Docs/Platform/Release.md) — versions, commit messages,
  release notes, tags, and App Store handoff.
- [CI diagnostics](../Docs/AgentContext/ci-diagnostics.md) — structured failure
  reports and triage order. `./Scripts/agent-context.sh` discovers nested
  guides, context cards, and skills for the given paths.

## Command index

| Command | Purpose |
|---|---|
| `./Scripts/generate.sh` | Generate the Xcode project and authored derived content |
| `./Scripts/generate.sh --assets` | Also prepare art, music, SFX, and cinematics |
| `./Scripts/assert-generated-output.sh --idempotent` | Confirm regeneration produces no diff |
| `./Scripts/build.sh` | Build the app with the routed local toolchain |
| `./Scripts/test-package.sh <Package>` | Run one package's tests |
| `./Scripts/test.sh unit` | Run all package unit suites |
| `./Scripts/test.sh smoke` | Run the three-class smoke plan (tab shells, Battle, Shop) |
| `./Scripts/test.sh smoke <Class...>` | Run targeted smoke classes |
| `./Scripts/test.sh smoke-full` | Same plan as `test.sh smoke` (CI alias) |
| `./Scripts/test.sh ui [Class]` | Run exhaustive UI tests, optionally filtered |
| `./Scripts/test.sh all` | Run the integration suite |
| `./Scripts/performance.sh` | Ad hoc app + battle performance matrix (not CI) |
| `./Scripts/test-iterate.sh <Class>` | Re-run a focused test against a warm build |
| `./Scripts/agent-context.sh --agent --paths …` | Print applicable guidance and verification routing |
| `./Scripts/handoff.sh --isolate --paths …` | Canonical path-scoped source gate |
| `./Scripts/ci-gate.sh` | Generation, style, boundaries, script regressions, and release-note validation |
| `./Scripts/ci-assets-gate.sh` | Asset generation, idempotence, and locale-stability gate |
| `./Scripts/check-docs.py` | Check local Markdown links, heading anchors, package guide coverage, smoke classes, and known stale terms |
| `./Scripts/test-deploy.sh [--mode smoke]` | Full local deploy confidence or smoke canary |
| `./Scripts/agent-push-gate.sh` | Post-commit generation completeness check |
| `./Scripts/ci-diagnostics.sh [RESULTS_DIR]` | Aggregate current structured diagnostics |
| `./Scripts/change-budget.sh --paths …` | Advisory authored-surface report against HEAD |
| `./Scripts/ensure-ci-tools.sh` | Install pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify |
| `./Scripts/run-simulator.sh` | Build and launch on a managed simulator |
| `./Scripts/prune-derived-data-cache.sh` | Prune safe, old local build artifacts |
| `./Scripts/balance-sweep.sh` | Run the headless battle balance sweep |
| `./Scripts/release.sh [--dry-run]` | Preview or execute a release |

Use each command's `--help` for current flags. Pinned tool versions live in
`Scripts/tool-versions.env`; shared Swift roots live in
`Scripts/swift-source-dirs.env`.

## Toolchain ladder

Local and CI verification requires Xcode 26 or newer. If the simulator
toolchain is unavailable, run the non-simulator checks that the host supports
(`generate.sh`, generated-output assertion, boundaries, style, and `ci-gate.sh`)
and explicitly report skipped build/test work. Do not claim full verification
until the routed build and test commands pass with the required Xcode toolchain.
