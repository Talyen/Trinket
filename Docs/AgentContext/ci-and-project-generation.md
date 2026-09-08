# CI and project-generation context

Use for XcodeGen, isolate slots, generation freshness, or release tooling exceptions.

Gate composition and test tiers: [Verification.md](../Platform/Verification.md).
Isolation and IDE workflows: [SimulatorOperations.md](../Platform/SimulatorOperations.md).
Swift Testing conventions: [Testing.md](../Platform/Testing.md).
Preview an unfamiliar route with the dry-run form documented in
[Verification.md](../Platform/Verification.md); a preview is not verification.

## Key exceptions

- **Agent isolation (`--isolate`)**: Use `--isolate` for all agent verification; see [SimulatorOperations.md](../Platform/SimulatorOperations.md) for pool (`Trinket Agent N` vs `Trinket Run`), `RESULTS_DIR` (`runs/agent-N`), lease, and watchdog rules. Use `--working-tree` only for an intentional whole-tree gate.
- **Generation freshness**: Build preparation uses `$RESULTS_DIR/.last-generate.stamp` to avoid unnecessary generation. Project generation always uses a fresh XcodeGen cache path through the pinned wrapper. Idempotent assertions explicitly force regeneration and compare outputs; input freshness alone cannot prove output consistency.
- **Commit gate**: The pre-commit hook checks staged project inputs or staged `project.pbxproj` by regenerating an index snapshot. It preserves the index and working files; partially staged tool/hook changes must be resolved first. See [Verification.md](../Platform/Verification.md#generated-project-consistency).
- **Push gates**: Pre-push runs path-scoped style, then `./Scripts/agent-push-gate.sh` (generation completeness), then path-scoped package tests for pushed packages. Landing policy is owned by root `AGENTS.md` and [Verification.md](../Platform/Verification.md).
- **Environment & pinning**: `generate.sh` exports `LC_ALL=C` and pins `DEVELOPER_DIR` + `SDKROOT` to Xcode's macOS SDK. `--force-xcodegen` explicitly requests the default uncached behavior. Project generation installs/verifies pinned tools before invoking `.tools/xcodegen`. CI selects Xcode from `Scripts/tool-versions.env` (`XCODE_VERSION`).
- **Diagnostics**: When a test or CI invocation fails, load [`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs.
- **Linux style builds**: SourceKit `custom_rules` are skipped on Linux — treat Linux style PASS as provisional.
