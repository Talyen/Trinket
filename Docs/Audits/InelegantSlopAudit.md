# Inelegant Slop Audit

Goal: Find and simplify hotspots of over-engineered, overly verbose, overly complex, or un-pragmatic code — especially agent-produced “slop” — without a whole-repo rewrite.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

Dead / unused symbols → [DeadCodeRatioAudit.md](DeadCodeRatioAudit.md).  
Boundary violations → [ImportCouplingBoundaryAudit.md](ImportCouplingBoundaryAudit.md).  
Custom UI chrome → [AppleNativeUIAudit.md](AppleNativeUIAudit.md).  
Correctness bugs → [BugHuntingAudit.md](BugHuntingAudit.md).

## Mission

Use size, structure, and pattern probes to surface a small set of **confirmed** inelegant hotspots. Simplify one cohesive area (or a few independent micro-fixes) so the result is shorter, clearer, and more pragmatic — without changing player-facing behavior unless the verbosity itself is the bug.

A clean pass is valid. Prefer deleting ceremony over inventing a new abstraction. **Zero findings is a successful audit result.**

## What “slop” means here

Slop is code that looks industrious but fails a pragmatism test: more types, indirection, comments, or branches than the problem warrants. Typical agent tells:

| Tell | Why it is slop |
|------|----------------|
| Protocol + single conformer + factory | Indirection with no second implementation |
| `*Manager` / `*Helper` / `*Coordinator` / `*Wrapper` for one function | Noun theater around a free function or method |
| Narrating comments / restated docs | Comments that rephrase the signature instead of encoding non-obvious intent |
| Boolean parameter soup | Combinatorial call sites that should be an enum or two methods |
| Deep nesting / giant `body` / god file | Complexity that should be extracted *or* collapsed, not both layered |
| Pass-through wrappers / rename-only typealiases | Extra names that do not add a boundary |
| Premature DI / config objects for 2–3 fields | Framework cosplay for a local call |
| Defensive `??` / `Result` / `Any` stacks without a real failure mode | Ceremony that hides the real invariant |
| Near-duplicate blocks with tiny diffs | Copy-paste growth instead of one parameterized path |
| Legacy SwiftUI / observation patterns | Fighting the platform baseline in `AGENTS.md` |

Elegant code in this repo is usually: small value types, thin stores, handlers/engines for rules, design-system chrome, exhaustive switches, and direct call sites.

## Hard stops

- Do not read every file — probe, triage, confirm, fix.
- Do not change player-facing behavior, balance, copy, layout, or `accessibilityIdentifier` values unless removing dead UI.
- Do not hand-edit `Generated/*`, manifests (unless deleting a truly unused generated entry via the owning audit), assets, music, or `.DerivedData/`.
- Do not “simplify” by introducing a new package, framework, or DI container.
- Do not collapse intentional seams: battle RNG injection, persistence write coalescing, design-system tokens, catalog/codegen boundaries, or module import rules.
- Do not rewrite battle pipeline math “for clarity” without package tests proving equivalence.
- Do not turn this into a style-only rename sweep or a docs rewrite.
- Do not delete tests that encode real invariants; only delete empty/existence-only fluff after proof.
- Prefer the owning audit when the hit is primarily dead code, boundaries, concurrency, or type-safety escapes.

## Confirmation policy

A probe hit is **not** a finding. Confirm before editing:

1. **Cost:** The hotspot adds real reading/editing cost (extra types, deep nesting, duplicated logic, or a file that mixes unrelated jobs).
2. **No second need:** The abstraction has one call site / one conformer / no extension point in use.
3. **Safer shape exists:** A shorter local form preserves behavior (inline, exhaust switch, extract *one* helper, delete wrapper).
4. **Blast radius:** Fix stays in one cohesive area; do not “while here” the neighbors.

Skip and note in the commit/PR body when complexity is load-bearing (generated catalogs, damage pipeline steps, save wire format, intentional `@MainActor` lifetime). Never invent a refactor to satisfy a quota.

## Workflow

1. Rank candidate hotspots with the probes below (do not start from a random file).
2. Open only the top candidates; confirm with call-site / conformer / duplication proof.
3. Pick **one cohesive simplification** (or up to three independent micro-fixes).
4. Apply the smallest diff that removes ceremony or collapses duplication.
5. Verify (§ Verification).
6. Commit + report evidence in the commit/PR body — never in this file.

## Discovery methodologies (no full-repo reading)

Use these in order. Always pass an explicit path to `rg` (usually `.` or a scoped directory) — pathless `rg` hangs in Cursor cloud shells.

### 1. Size & density ranking

Large authored files are the cheapest hotspot signal. Ignore `Generated/`, tests (unless test slop is the chosen theme), and processed assets.

```bash
# Largest non-generated production Swift files
find Trinket Packages -name '*.swift' \
  -not -path '*/Generated/*' -not -path '*/.build/*' \
  -not -path '*/Tests/*' -not -path '*UITests*' \
  -print0 | xargs -0 wc -l | sort -rn | awk '$1>=250 && $2!="total"' | head -30

# Deep nesting candidates (16+ spaces before control flow)
rg -n '^\s{16,}(if|guard|switch|for|while|Task|Button|VStack|HStack|ZStack)' \
  --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' . \
  | cut -d: -f1 | sort | uniq -c | sort -rn | head -20
```

Triage files ≥ ~250 lines or with repeated deep nesting. A large file is fine if it is one coherent catalog or a thin switch table; it is slop when it mixes orchestration, formatting, and UI or hides several abstractions that could be one function.

### 2. Ceremony-name & indirection probes

```bash
# Noun-theater type names — triage each; many are legitimate
rg -n '(struct|class|enum|actor|protocol) \w*(Factory|Manager|Helper|Wrapper|Adapter|Coordinator|Provider|Service|Builder|Interactor|UseCase|Repository|Impl)\b' \
  --type swift -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' Packages Trinket

# Protocols — confirm conformer count before deleting
rg -n '^(public )?protocol ' --type swift -g '!*Tests*' -g '!**/Generated/*' Packages Trinket

# Rename-only typealiases & trivial pass-throughs
rg -n '^(public )?typealias ' --type swift -g '!*Tests*' -g '!**/Generated/*' Packages Trinket
rg -n 'return self\.\w+\s*$' --type swift -g '!*Tests*' -g '!**/Generated/*' Packages Trinket | head -40

# Boolean parameter soup (two+ Bool params)
rg -n 'func \w+\([^)]*\bBool\b[^)]*\bBool\b' --type swift \
  -g '!*Tests*' -g '!*UITests*' -g '!**/Generated/*' Packages Trinket
```

For each protocol hit: `rg -n ': ProtocolName|: ProtocolName[,{]|ProtocolName\.|extension ProtocolName' --type swift`. One conformer + one construction site → candidate to delete the protocol and use the concrete type.

### 3. Verbosity & comment theater

```bash
# Narrating / restating doc comments
rg -n '/// (Returns|Gets|Sets|Creates|Initializes|This (function|method|property|type)|The \w+ (function|method|property))' \
  --type swift -g '!*Tests*' -g '!**/Generated/*' Packages Trinket

# MARK density — high density often means a file that should be split *or* was sectioned instead of simplified
rg -c '// MARK:' --type swift -g '!*Tests*' -g '!**/Generated/*' Packages Trinket \
  | awk -F: '$2>=3' | sort -t: -k2 -rn

# Empty / stub extensions and placeholder comments
rg -n '// (TODO|FIXME|HACK|XXX|temporary|for now|just in case|as requested|note for|important:)' \
  --type swift -i -g '!*Tests*' -g '!**/Generated/*' Packages Trinket | head -40
```

Delete comments that restate names or types. Keep comments that encode invariants, units, non-obvious ordering, or why a simpler approach was rejected.

### 4. Duplication & near-copy probes

```bash
# Same multi-line shape repeated — start from suspicious folders
rg -n 'switch .+ \{' --type swift -g '!*Tests*' -g '!**/Generated/*' Trinket/Features Packages/BattleEngine/Sources \
  | cut -d: -f1 | sort | uniq -c | sort -rn | head -20

# Nested private type forests (often agent “organize” residue)
rg -c '^\s*(private |fileprivate )?(struct|enum|class|actor) ' --type swift \
  -g '!*Tests*' -g '!**/Generated/*' Packages Trinket \
  | awk -F: '$2>=8' | sort -t: -k2 -rn | head -20

# Copy-paste UI chrome outside the design system
rg -n '\.background\(|\.ultraThinMaterial|GlassEffect|\.shadow\(|RoundedRectangle' \
  --type swift Trinket/Features Trinket/BattleShell -g '!*Tests*' | head -40
```

When two blocks differ only by a literal or property name, collapse to one helper **in the same module**. If the duplication is design chrome, route through `TrinketDesignSystem` (see [AppleNativeUIAudit.md](AppleNativeUIAudit.md)) rather than a one-off local style.

### 5. Platform / baseline anti-patterns (agent regressions)

```bash
# Banned or obsolete patterns per AGENTS.md
rg -n 'NavigationView|ObservableObject|@StateObject|@Published|@EnvironmentObject' \
  --type swift -g '!*Tests*' Packages Trinket

# Pre-iOS-26 availability theater (baseline is iOS 26+)
rg -n '#available\s*\(|@available\s*\(.*iOS' --type swift \
  -g '!*Tests*' -g '!**/Generated/*' Packages Trinket

# Type-erasure / UIKit bridges where SwiftUI suffices
rg -n '\bAnyView\b|UIViewRepresentable|UIViewControllerRepresentable' --type swift \
  -g '!*Tests*' -g '!**/Generated/*' Packages Trinket | head -40
```

These are high-confidence slop when introduced without a documented platform gap. Prefer `@Observable`, `@Environment(Type.self)`, `@Bindable`, and first-party SwiftUI.

### 6. Recent-churn hotspot selection (optional)

When the user cites a recent agent pass, bias toward files it touched:

```bash
git log --since='90 days ago' --name-only --pretty=format: -- '*.swift' \
  | sed '/^$/d' | grep -v Generated | sort | uniq -c | sort -rn | head -30
```

Churn alone is not guilt; combine with size/ceremony probes. Prefer hotspots that agents re-edit often — that is where inelegance compounds.

## Smell catalog → improvement recipes

| Smell | Confirm | Prefer |
|-------|---------|--------|
| Protocol with one conformer | Single concrete type + construction sites | Delete protocol; use the struct/class directly |
| `FooManager` / `FooHelper` holding no state | Methods never use `self` meaningfully | Free function, `enum Foo` namespace, or method on the owning type |
| Wrapper that only forwards | Every API is `return inner.x` | Expose `inner` or move callers to the real type |
| Rename-only `typealias` | No clarity or boundary benefit | Delete alias; update call sites |
| Bool–Bool parameters | Call sites pass literal pairs | Enum cases, separate methods, or a small option set *only if* needed |
| Nested `if` / `guard` ladders | Happy path buried | Early `guard` returns; flatten; table-drive with `switch` |
| Giant SwiftUI `body` | Multiple unrelated sections | Extract private `@ViewBuilder` pieces **or** delete dead branches — do not add a ViewModel for layout alone |
| Hand-rolled materials / buttons in Features | Duplicates design-system capability | Use `TrinketDesignSystem`; do not invent a parallel style |
| Narrating `/// Returns the X` | Signature already says it | Delete; keep only non-obvious constraints |
| `#available` for older iOS | Deployment is 26.0 | Remove branch; keep the modern path only |
| `AnyView` stacks | Erases identity for convenience | `@ViewBuilder`, generics, or `Group`/`switch` |
| Near-duplicate switches | Arms differ by one token | Shared helper; data-driven map when exhaustive and stable |
| Test that only asserts type exists / mock soup | No behavior oracle | Delete or replace with a state-transition assertion (see [UnitTestAudit.md](UnitTestAudit.md)) |
| Config/`Options` struct for one call | Constructed at a single site | Inline parameters |
| Extension file sprawl without cohesion | Many `+X.swift` with one method each | Merge with the owning type **or** keep only when it separates a real layer (e.g. `+Presentation`) |

### Simplification preferences (in order)

1. **Delete** unused ceremony (type, protocol, alias, comment, dead branch).
2. **Inline** single-use wrappers into the caller.
3. **Collapse** duplicates into one parameterized path in the same module.
4. **Extract** only when a name removes nesting *and* has ≥2 call sites or a clear domain meaning.
5. **Move** shared chrome into `TrinketDesignSystem` / shared rules into the existing owner package — never a new layer for one call site.

## Checks while editing

- Behavior: same inputs → same outputs; battle/persistence paths need focused tests.
- Layers: do not invent imports that violate `BattleShell/` ↛ `Features/`, `State/` ↛ feature views, `Models/` ↛ `State/`/`Features/`.
- Stores stay thin: do not grow `BattleState` / `PlayerSaveStore` to absorb cleanup — push rules to handlers/engines/value types.
- Observation: no new `ObservableObject` / `@Published` / `@StateObject`.
- Comments: leave invariants; remove narration.
- Names: shorter and domain-true beats `Impl` / `Base` / `Helper`.

## Fixes (allowed)

| Finding | Allowed fix |
|---------|-------------|
| Confirmed ceremony type | Delete or inline; update call sites |
| Confirmed duplication | One helper or data-driven path; no new package |
| Verbosity | Delete narrating comments; tighten names; flatten control flow |
| Platform regression | Modernize to `AGENTS.md` baseline |
| Feature-local chrome duplication | Route through existing design-system API |
| God file that is *one* job but unreadable | Split along existing ownership lines only (e.g. presentation vs rules) — not arbitrary `Utils` |

Out of scope for this audit: mass renames, balance retunes, new architecture diagrams, and “clean code” rewrites that grow LOC.

## Verification

| Change | Minimum |
|--------|---------|
| `BattleEngine` / rules | `./Scripts/test-package.sh BattleEngine` |
| Persistence | `./Scripts/test-package.sh TrinketPersistence` |
| Design system | `./Scripts/test-package.sh TrinketDesignSystem` (+ `./Scripts/check-ui-style.sh` if chrome moved) |
| App state / shell | `./Scripts/test.sh unit <FocusedClass>` |
| Feature UI structure | `./Scripts/test.sh style` and, if interaction paths moved, `./Scripts/test.sh smoke` |

Always: `./Scripts/lint.sh` and `./Scripts/check-module-boundaries.sh`.  
Any Swift change: `./Scripts/test.sh style` plus the focused row above.  
Skip build/test when the toolchain is absent; state skips in the commit body.

## Commit / report

```
refactor(<scope>): simplify <hotspot>

- Smell: <ceremony|duplication|verbosity|nesting|platform-regression>
- Before/after: <what deleted or collapsed>
- Proof: <one conformer / one call site / duplicate arms / size probe>
- <verification>

User-Facing: no
```

Commit body table (do not write into this file):

```markdown
| # | Probe | File | Smell | Fix | Verified? |
|---|-------|------|-------|-----|-----------|
```

If zero findings: say so explicitly and list the probes run — that is a successful pass.
