---
name: architect
description: Type-First & Boundary Specification Guard. Auto-triggers when adding new types, protocols, or schemas under Packages/*/Sources/ or core game models. Ensures Swift protocols, value types, and package API contracts are drafted before concrete implementation.
---

# Type-First Specification & Boundary Guard

Draft minimal, robust Swift protocols, value types (`struct`, `enum`), and public package boundaries before authoring concrete implementation logic.

## Trigger Scenarios

Auto-triggers when:
- Creating new Swift files or modules under `Packages/*/Sources/`.
- Defining or modifying public package protocols, core game models, or persistence schemas.
- Designing new features or state-machine pipelines before implementation.

## Execution Steps

1. **Draft Public Types & Protocols First**:
   - Write out `protocol`, `struct`, and `enum` declarations with precise docstrings explaining domain invariants.
   - Avoid writing concrete method bodies or UI view implementations in this step.

2. **Verify Module Boundaries**:
   - Verify package DAG constraints before adding imports:
     - `TrinketDesignSystem` depends only on `TrinketCore`.
     - `TrinketFeatureSupport` sits below `TrinketBattleFeature` and `TrinketAppState`.
     - `TrinketBattleFeature` must not import `TrinketAppState`.
     - Package code must never import the `Trinket` app target.

3. **Check Downstream Impact (`blast-radius`)**:
   - Evaluate symbol fan-out across packages before committing to protocol signatures.
   - Ensure generic abstractions have at least three current uses or an enforced architectural boundary (per `AGENTS.md`).

4. **Proceed to Implementation**:
   - Once type signatures and boundary checks are solid, implement concrete logic in the smallest suitable scope.
