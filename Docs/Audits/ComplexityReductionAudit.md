# Complexity Reduction Audit

Goal: Shrink the single worst complexity hotspot — fewer lines, fewer layers, same player-visible behavior.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append survey results to this file.

Sibling ownership (consult only if the chosen target demands it — do not run full-repo sweeps): see [README.md](README.md).

## Mission

Find the single most complex, over-engineered, or bloated area *right now*, then simplify it. Deliver a meaningful reduction in LOC and cognitive complexity while preserving player-visible behavior.

Read `AGENTS.md` and `Docs/Architecture.md` before editing.

## Hard stops

- Do not expand scope into speculative backlog items the user did not cite.
- One target, one focused diff — do not spread across unrelated modules.
- No rename-only or format-only churn without structural simplification.
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.
- Do not bypass `// UIStyleCheck: allow` by restyling unrelated UI.
- Do not hand-edit `Generated/`, `.DerivedData/`, or `Assets.xcassets`.

## Workflow

1. **Survey** — Score candidates with § Targets and the survey commands below. Exclude generated output and roadmap-only ideas.
2. **Select one** — Name 1–2 runner-ups in the commit body; explain why the winner is worse (3–5 bullets).
3. **Plan** — List deletes/collapses/inlines and which tests prove behavior.
4. **Simplify** — Smallest correct diff. Prefer deletion and inlining over new abstractions.
5. **Verify** — Matching tier in § Verification; boundaries + lint must pass.
6. **Commit** — Format in § Commit. Summarize in the commit body, not in this file.

## Survey commands

```bash
# Largest app glue / shell files
wc -l Trinket/State/*.swift Trinket/BattleShell/*.swift 2>/dev/null | sort -n | tail -20

# Largest package sources (exclude Generated)
find Packages -path '*/Sources/*' -name '*.swift' ! -path '*/Generated/*' \
  -exec wc -l {} + | sort -n | tail -30

# Recent churn on hot glue
git log --oneline -15 -- Trinket/State Trinket/BattleShell
```

## Targets

| Signal | How to measure | Why it matters |
|--------|----------------|----------------|
| LOC density | `wc -l` / survey commands above | Large files hide multiple responsibilities |
| Indirection depth | Wrappers / “forward to” methods with no logic | Maintenance tax |
| Single-use abstractions | Types referenced from one call site | Ceremony without reuse |
| Duplicate logic | Near-identical blocks in siblings | Copies diverge |
| Import fan-out | Many `import` lines or layer violations | Risky refactors |
| Test friction | Huge setup, log fingerprints, sleeps | Complexity leaks into tests |
| Churn | `git log --oneline -20 -- <path>` | Design fights change |

Exclude: `Generated/*`, assets/music build products, `.DerivedData/`, entire packages/tabs in one pass.

Tie-breakers: (1) most indirection removed, (2) hot path over rare screens, (3) `State/` / `BattleShell/` glue over stable package rules unless a package god-object, (4) delete over rewrite.

## Checks

### Scoping

- Name the target in one sentence.
- Expect net LOC drop **or** a full file/type removed (prefer collapsing a real layer over whitespace).
- At least two complexity signals from § Targets.
- Leave `ContentManifest/` alone unless deleting unused manifest-driven content.

### Simplification order

1. Delete unreachable / commented / unused / duplicate
2. Inline single-use helpers and forward-only wrappers
3. Collapse sibling types with the same owner
4. Narrow `public` → `internal` when same-module
5. Extract shared helpers only at 3+ call sites

### Architecture

After edits, `./Scripts/check-module-boundaries.sh` must pass (see [ImportCouplingBoundaryAudit.md](ImportCouplingBoundaryAudit.md)).

### Behavior preservation

- Battle semantics unchanged; use `BattleStateTestFactory` for new battle tests
- Persistence: mutate → reload → assert
- Keep `accessibilityIdentifier`s unless the control is removed
- Launch-arg parsing stays compatible with `TestLaunchArg`
- No balance retunes or player-facing copy renames unless removing dead UI

### Anti-patterns

- New generic protocols / framework bases for one concrete type
- Moving domain logic into SwiftUI views
- Splitting one file into many without reducing LOC or coupling
- Deleting tests that still protect behavior
- Broad `swiftlint:disable` / `UIStyleCheck: allow`

## Verification

| Change shape | Minimum |
|--------------|---------|
| BattleEngine package rules | `./Scripts/test-package.sh BattleEngine` |
| TrinketCore package rules | `./Scripts/test-package.sh TrinketCore` |
| TrinketPersistence | `./Scripts/test-package.sh TrinketPersistence` |
| App State / BattleShell | `./Scripts/test.sh unit <FocusedClass>` (+ full unit if multi-file) |
| Product-tab SwiftUI | `./Scripts/test.sh smoke` (affected class) |
| Cross-cutting app + packages | `./Scripts/test.sh unit` then smoke |

Always:

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
```

If manifests changed: `./Scripts/generate.sh` (add `--assets` when art/music/SFX changed). Skip build/test when the toolchain is absent; note skips in the commit body.

## Commit

```
refactor(<scope>): collapse <target> pass-through layer

- Remove <N> single-use types and inline <helper>
- Drop ~<N> LOC with no player-visible behavior change

User-Facing: no
```

Commit body: **Target**, **Removed**, **LOC** (`git diff --stat`), **Unchanged**, optional **Follow-ups** (do not implement).
