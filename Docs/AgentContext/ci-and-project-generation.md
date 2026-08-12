# CI and project-generation context

Use for XcodeGen, isolate slots, generation freshness, or release tooling exceptions.

Gate composition and test tiers: [Verification.md](../Platform/Verification.md).
Isolation and IDE workflows: [SimulatorOperations.md](../Platform/SimulatorOperations.md).
Swift Testing conventions: [Testing.md](../Platform/Testing.md).
Preview an unfamiliar route with `./Scripts/handoff.sh --dry-run --isolate --paths …`
(a preview is not verification). Agents **always** pass `--isolate`.

## Key exceptions

- **Agent isolation (`--isolate`)**: `handoff.sh --isolate` shares the simulator-slot environment from `Scripts/run-env.sh` (`Trinket Agent N`, `.DerivedData/runs/agent-N/`, `TMPDIR`, `TRINKET_RUN_ID`). Run-env self-clean reclaims non-empty Preview sims (shutdown Booted), enforces one Booted managed sim, and age-prunes bulky build artifacts. xcode-runner wall/idle watchdogs kill host xcodebuild trees only (no `simctl`).
- **Generation freshness**: Verify stamps `$RESULTS_DIR/.last-generate.stamp` with a porcelain sidecar. Idempotent asserts skip redundant regenerates when fresh against input mtimes and porcelain state.
- **Push gates**: Use `./Scripts/agent-push-gate.sh` for post-commit generate/assert checks (does not run style/compile). Do not require `tests / CI OK` as a GitHub push gate on `main`; that check is required to **merge PRs**.
- **Environment & pinning**: `generate.sh` exports `LC_ALL=C` and pins `DEVELOPER_DIR` + `SDKROOT` to Xcode's macOS SDK. `--force-xcodegen` bypasses cache. Pinned tools require `TRINKET_REQUIRE_PINNED_TOOLS=1`. CI selects Xcode from `Scripts/tool-versions.env` (`XCODE_VERSION`).
- **Diagnostics**: When a test or CI invocation fails, load [`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs.
- **Linux style builds**: SourceKit `custom_rules` are skipped on Linux — treat Linux style PASS as provisional.
