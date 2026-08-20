---
name: blast-radius
description: Impact & Dependency Fan-out Analyzer. Auto-triggers when touching files under Packages/*/Sources/, core data models, or shared protocols. Evaluates module boundaries and symbol usage across packages before edits are applied.
---

# Blast Radius Impact Analysis

Evaluate downstream impact, module boundaries, and dependency fan-out before modifying core data models, shared protocols, or public package APIs.

## Trigger Scenarios

Auto-triggers when:
- Editing files in `Packages/*/Sources/` that define public types, protocols, or schemas.
- Modifying core game models, combat state structures, or persistence schemas.
- Altering function signatures or protocols consumed by multiple SPM packages.

## Execution Steps

1. **Identify Public Surface**:
   - Determine if touched symbols (structs, protocols, methods, enums) are marked `public` or exposed across package boundaries.

2. **Check Module Boundaries & Context**:
   - Run `./Scripts/check-module-boundaries.sh` to check for boundary violations.
   - Run `./Scripts/agent-context.sh --agent --paths <files...>` to discover package owners and nested documentation.

3. **Trace Dependent Symbols**:
   - Perform scoped symbol searches across `Packages/` and app targets to identify all call sites:
     ```bash
     rg "SymbolName" Packages/
     ```

4. **Map Blast Radius**:
   - List all affected SPM packages.
   - Identify dependent test suites (`test-package.sh <Package>`).
   - Summarize potential side effects or balance impacts before making code edits.
