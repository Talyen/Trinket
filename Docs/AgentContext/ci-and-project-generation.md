# CI and project-generation context

Use for XcodeGen, isolate slots, generation freshness, or release tooling exceptions.

Gate composition: [Verification.md](../Platform/Verification.md#gate-composition).
UI smoke selection: [local simulator budget](../Platform/Verification.md#local-simulator-budget).
Isolation and IDE workflows: [SimulatorOperations.md](../Platform/SimulatorOperations.md).
Swift Testing conventions: [Testing.md](../Platform/Testing.md).
Preview an unfamiliar route with the dry-run form documented in
[verification commands](../../Scripts/Reference.md#verification); a preview is not verification.

## Key exceptions

- **Generation freshness**: Build preparation uses `$RESULTS_DIR/.last-generate.stamp` to avoid unnecessary generation. Input freshness does not prove output consistency; uncached generation, idempotence, and staged-project validation follow [Verification.md](../Platform/Verification.md#generated-project-consistency).
- **Commit and push gates**: [Release.md](../Platform/Release.md#local-hooks-and-push-discipline) owns their sequence and safeguards.
- **Environment & pinning**: `generate.sh` exports `LC_ALL=C` and pins `DEVELOPER_DIR` + `SDKROOT` to Xcode's macOS SDK. `--force-xcodegen` explicitly requests the default uncached behavior. Project generation installs/verifies pinned tools before invoking `.tools/xcodegen`. CI selects Xcode from `Scripts/tool-versions.env` (`XCODE_VERSION`).
- **Diagnostics**: When a test or CI invocation fails, load [`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs.
- **Linux style builds**: SourceKit `custom_rules` are skipped on Linux — treat Linux style PASS as provisional.
