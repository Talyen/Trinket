# Complexity Reduction Audit

Goal: Shrink the single worst complexity hotspot in the codebase — fewer lines, fewer layers, same player-visible behavior, easier to change safely.

Point-in-time audit snapshot. Use the agent prompt below to task a coding agent with one focused simplification pass. Do not treat this as standing product requirements unless explicitly cited.

## Agent prompt

Copy everything between the markers into a new agent session:

```text
--- BEGIN COMPLEXITY REDUCTION TASK ---

You are working on Trinket, a portrait-first iOS fantasy idle auto-battler (Swift 6 / SwiftUI, iOS 26). Read `AGENTS.md` and `Docs/Architecture.md` before editing.

**Mission:** Find the single most complex, over-engineered, or bloated area of the codebase *right now*, then simplify it. Deliver a meaningful reduction in lines of code and cognitive complexity while preserving player-visible behavior and improving maintainability, readability, and reliability.

**Workflow**

1. **Survey** — Score candidate areas using the signals in this audit (§ Targets and § Checks). Exclude generated output, build artifacts, and roadmap-only ideas.
2. **Select one target** — Choose exactly one cohesive module, type cluster, coordinator, or feature slice. In your summary, name 1–2 runner-ups and explain in 3–5 bullets why the winner is worse (LOC, indirection, duplication, test pain, or boundary smell).
3. **Plan briefly** — Before large deletes, list what you will remove, collapse, or inline and which tests prove the behavior still holds. Prefer deletion and inlining over new abstractions.
4. **Simplify** — Execute the smallest correct diff: delete dead paths, collapse pass-through layers, merge duplicate logic, replace factories used once, narrow `public` APIs. Do not add third-party dependencies or new packages.
5. **Preserve contracts** — Keep save/load and battle semantics stable. Retain `accessibilityIdentifier` values referenced by `TrinketUITests`. Do not hand-edit `Generated/`, `.DerivedData/`, or `Assets.xcassets`.
6. **Verify** — Run the tier from `AGENTS.md` that matches your edit (see § Verification in this audit). `./Scripts/check-module-boundaries.sh` and `./Scripts/lint.sh` must pass.
7. **Deliver** — Commit with the project message format (`User-Facing: yes|no`). Report approximate net LOC change, what was removed, and any behavior you intentionally left unchanged.

**Hard stops**

- Do not implement `Docs/Roadmap.md` items unless this task explicitly names one.
- Do not spread one simplification across unrelated modules — one target, one focused diff.
- Do not do rename-only or format-only churn without structural simplification.
- Do not weaken battle test determinism (`BattleStateTestFactory.makeBattle(..., rngSeed: 0)`).
- Do not bypass `// UIStyleCheck: allow` rules by restyling unrelated UI.

**Reference audits** (consult when your target touches these concerns; do not run full-repo sweeps unless the target demands it):

- `Docs/Audits/DeadCodeRatioAudit.md` — unused exports and orphaned files
- `Docs/Audits/ImportCouplingBoundaryAudit.md` — package graph and layer imports
- `Docs/Audits/SideEffectSurfaceAudit.md` — I/O and RNG seams
- `Docs/Audits/BehaviorHardeningAudit.md` — persistence, async, idempotency
- `Docs/Audits/TestQualityAudit.md` — assertion style and fixture reuse

--- END COMPLEXITY REDUCTION TASK ---
```

## Targets

Use these signals to rank candidates. The winner should score high on several rows, not just raw file size.

| Signal | How to measure | Why it matters |
|--------|----------------|----------------|
| LOC density | `wc -l` on the target file(s) and immediate helpers | Large files often hide multiple responsibilities |
| Indirection depth | Count wrappers, coordinators, and “forward to” methods with no added logic | Layers that only delegate are maintenance tax |
| Single-use abstractions | Types or protocols referenced from one call site | Abstraction without reuse adds ceremony |
| Duplicate logic | `rg` for near-identical blocks in sibling files | Two copies will diverge |
| Import fan-out | Files with many `import` lines or cross-layer violations | Coupling makes refactors risky (`ImportCouplingBoundaryAudit.md`) |
| Test friction | Tests that need huge setup, log fingerprints, or sleeps | Complexity leaks into `*Tests/` |
| Churn history | `git log --oneline -20 -- <path>` | Frequent patch stacks suggest the design fights change |
| Generated adjacency | Logic that re-implements or shadows codegen | Hand-rolled catalogs belong in manifests |

**Out of scope for selection**

- `Packages/TrinketContent/Sources/TrinketContent/Generated/*` — edit manifests, run `./Scripts/generate.sh`
- `Trinket/Assets.xcassets`, `Trinket/Resources/Music`, `.DerivedData/`, build products
- `Docs/Roadmap.md` speculative features
- Entire packages or tabs in one pass — pick a slice inside an owner from `Docs/Architecture.md` § Module ownership

**Tie-breakers** (when two candidates score similarly)

1. Prefer the target whose simplification removes the most *indirection*, not just whitespace.
2. Prefer code on the hot path (battle tick, save write, tab shell) over rarely opened screens.
3. Prefer app `State/` or `BattleShell/` glue over stable package rules — unless the package type is clearly a god-object.
4. Prefer deleting code over rewriting it in a new style.

## Checks

### Is this the right single target?

- [ ] You can name the target in one sentence (“`PlayFlowCoordinator` + its three pass-through helpers”, not “the whole app”).
- [ ] Net LOC is expected to drop by at least ~10% in the target cluster, or a full file/type is removed.
- [ ] At least two complexity signals from § Targets apply.
- [ ] Simplification does not require changing `ContentManifest/` unless you are deleting unused manifest-driven content.
- [ ] Runner-ups are documented so the next audit pass can pick a different winner.

### Simplification patterns (prefer in this order)

1. **Delete** — unreachable branches, commented-out code, unused types, duplicate helpers, orphaned tests (`DeadCodeRatioAudit.md`)
2. **Inline** — single-use private helpers, one-case enums, wrappers that only forward
3. **Collapse** — merge sibling types with the same owner; replace coordinator chains with direct calls on the owning store/session
4. **Narrow API** — `public` → `internal` when callers are same-module; remove re-export barrels
5. **Extract only when duplicated** — shared helper is justified at 3+ call sites, not 2

### Architecture guardrails

Enforce `Docs/Architecture.md` dependency rules after edits:

- `TrinketDesignSystem` → `TrinketCore` only
- `BattleEngine` and `TrinketPersistence` do not import each other
- Packages do not import `Trinket` app code or feature views
- `BattleShell/` does not import `Features/`
- `State/` does not import feature views

Run `./Scripts/check-module-boundaries.sh` before commit.

### Behavior preservation

- **Battle rules** — outcome semantics unchanged; existing `BattleEngineTests` still pass; use `BattleStateTestFactory` for any new battle tests
- **Persistence** — mutate → reload → assert for store changes; no silent save failures (`BehaviorHardeningAudit.md`)
- **UI flows** — smoke `accessibilityIdentifier`s unchanged unless the control is removed; update `TrinketUITests` only when the flow truly changed
- **Launch args** — `AppEnvironment` parsing stays backward-compatible for `TestLaunchArg` helpers
- **Player-visible copy and balance** — do not retune numbers or rename player-facing strings unless removing dead UI

### Anti-patterns (do not “simplify” into these)

- New generic protocols or “framework” base classes to replace one concrete type
- Moving logic into SwiftUI views that belongs in `State/`, stores, or `BattleEngine`
- Splitting one bloated file into many small files without reducing total LOC or coupling
- Replacing explicit code with clever metaprogramming or heavy `@resultBuilder` chains
- Deleting tests that still protect behavior, or asserting less to make tests pass
- Broad `// swiftlint:disable` or `// UIStyleCheck: allow` to avoid fixing real issues

## Verification

Match the verification tier to the edit (`AGENTS.md`):

| Change shape | Minimum verification |
|--------------|----------------------|
| `Packages/BattleEngine/` or `TrinketCore/` rules | `./Scripts/test-package.sh BattleEngine` or full `./Scripts/test.sh unit` |
| `TrinketPersistence/` stores or save model | `./Scripts/test-package.sh TrinketPersistence` + any touched `TrinketTests` persistence tests |
| `Trinket/State/`, `BattleShell/`, app orchestration | `./Scripts/test.sh unit <FocusedClass>` then full `./Scripts/test.sh unit` if multiple files changed |
| SwiftUI layout / identifiers in a product tab | `./Scripts/test.sh smoke` for the affected smoke class |
| Cross-cutting refactor in app + package | `./Scripts/test.sh unit` then `./Scripts/test.sh smoke` |

Always run:

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
```

If manifests changed: `./Scripts/generate.sh` (or `--assets` when art/music/SFX manifests changed) and commit regenerated output.

## Fixes

Document in the commit / PR summary:

- **Target:** path(s) simplified and why they won
- **Removed:** types, files, layers, or duplicate logic deleted
- **LOC:** approximate net line change (e.g. `git diff --stat`)
- **Unchanged:** player-visible behavior explicitly left alone
- **Follow-ups:** optional next targets surfaced during survey (no need to implement)

Commit message example:

```text
refactor(<scope>): collapse <target> pass-through layer

- Remove <N> single-use types and inline <helper>
- Drop ~<N> LOC with no player-visible behavior change

User-Facing: no
```
