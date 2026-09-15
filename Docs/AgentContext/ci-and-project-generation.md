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
- **Environment & pinning**: `generate.sh` exports `LC_ALL=C` and resolves `DEVELOPER_DIR` + `SDKROOT` to the selected Xcode's macOS SDK. `--force-xcodegen` explicitly requests the default uncached behavior. Project generation installs/verifies pinned tools before invoking `.tools/xcodegen`. CI selects the newest installed Xcode automatically; local scripts inherit the selected Xcode unless explicitly overridden. Use [toolchain selection](../../Scripts/Reference.md#toolchain-ladder) and [platform readiness](../Platform/Verification.md#new-ios-release-readiness) to distinguish stable verification from beta exploration.
- **Diagnostics**: When a test or CI invocation fails, load [`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs.
- **Portable policy checks**: API bans and SwiftLint suppression reasons use SwiftFormat token export without SourceKit. The scripts own enforcement on macOS and Linux; see [style ownership](../Platform/Verification.md#style-and-boundary-ownership).
