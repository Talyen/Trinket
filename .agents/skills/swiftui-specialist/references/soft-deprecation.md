# Soft-deprecated APIs

SwiftUI marks some APIs deprecated with version `100000.0`. This suppresses
compiler warnings while signaling that new code should use a replacement.
Soft deprecation alone does not mean an existing player flow is broken.

Search the [API catalog](soft-deprecated-apis.md) for the symbol being considered.
The catalog records its SDK versions at the top. For a newer SDK or an uncertain
replacement, inspect the public declaration and availability in the selected SDK.
The catalog's replacement hints are not necessarily complete callable signatures.

Use current APIs for new code, subject to
[Trinket's platform choices](../../../../Docs/Platform/ApplePlatformReference.md).
The minimum supported OS does not prevent a useful newer API with a small
availability check.

For existing code, apply the scope and encountered-fix rules in
[AGENTS.md](../../../../AGENTS.md#choose-the-change). A clear, bounded replacement
within the task can proceed with the relevant verification. A soft deprecation
does not require a separate approval checkpoint or an unrelated migration sweep.
Preserve player behavior and source compatibility where a current consumer needs
it; resolve product or ownership decisions before making a broader change.

This reference adapts Apple's migration procedure to Trinket's change policy.
