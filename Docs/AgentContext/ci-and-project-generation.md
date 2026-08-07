# CI and project-generation context

Use for XcodeGen, build/test commands, CI workflows, simulator problems, or release tooling.

The root workflow owns task-scoped routing: start with
`./Scripts/agent-context.sh --agent --paths <file...>` for a concise briefing
(`--json` is machine-readable), optionally preview an unfamiliar or potentially
expensive route with `./Scripts/handoff.sh --dry-run --isolate --paths <same files>`,
then run it by omitting `--dry-run`. A preview does not count as verification.
Agents **always** pass `--isolate`.

For complete gate composition, test tier inventory, isolation mechanics, and IDE workflows, see [Scripts/README.md#verification-gates--test-tiers](../../Scripts/README.md#verification-gates--test-tiers).

## Key exceptions & operational details

- **Agent isolation (`--isolate`)**: `handoff.sh --isolate` shares the simulator-slot environment from `Scripts/run-env.sh` (`Trinket Agent N`, `.DerivedData/runs/agent-N/`, `TMPDIR`, `TRINKET_RUN_ID`). Run-env self-clean reclaims non-empty Preview sims (shutdown Booted), enforces one Booted managed sim, and age-prunes bulky build artifacts. xcode-runner wall/idle watchdogs kill host xcodebuild trees only (no `simctl`).
- **Generation freshness**: Verify stamps `$RESULTS_DIR/.last-generate.stamp` with a porcelain sidecar. Idempotent asserts skip redundant regenerates when fresh against input mtimes and porcelain state.
- **Push gates**: Use `./Scripts/agent-push-gate.sh` for post-commit generate/assert checks (does not run style/compile).
- **Environment & pinning**: `generate.sh` exports `LC_ALL=C` and pins `DEVELOPER_DIR` + `SDKROOT` to Xcode's macOS SDK. `--force-xcodegen` bypasses cache. Pinned tools require `TRINKET_REQUIRE_PINNED_TOOLS=1`.
- **Diagnostics**: When a test or CI invocation fails, load [`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs.
- **Linux style builds**: SourceKit `custom_rules` are skipped on Linux — treat Linux style PASS as provisional.

## Style gate (fail closed)

`./Scripts/test.sh style` must fail when SwiftFormat lint, SwiftLint `--strict`, UI style, platform API bans, or exclusivity footguns fail. Path-scoped `handoff.sh` includes style on changed Swift files and schedules compile-only `./Scripts/build.sh` for feature paths without a smoke owner. Routing is deterministic — there are no presentation-only demotions; a diff for metrics/copy/SF Symbol still runs its routed package tests or app compile.

## Swift Testing compile checklist

When adding `@Test(arguments:)` cases (see [Testing.md](../Platform/Testing.md)):

1. `private` argument types ⇒ `private` test function.
2. Argument / tuple element types ⇒ `Sendable` (typically also `Hashable`).
3. Keep `#require` arguments simple; compute `first(where:)` / key-path lookups into a local before `#require`.
