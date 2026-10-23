# Documentation map

Each rule has a canonical owner. Start with the document for the task; this map
is a lookup aid, not a reading checklist.

For implementation, follow [AGENTS.md](../AGENTS.md#route-and-read) and its scoped
briefing. Read the applicable safeguards and behavior contracts; indexes and
outgoing links are references, not additional workflow steps.

## Source of truth

| Fact | Owner |
|------|-------|
| Toolchain versions, schemes, entitlements | [project.yml](../project.yml), `Packages/*/Package.swift`, [tool-versions.env](../Scripts/tool-versions.env); required CI Xcode version/build in [ci-xcode.json](../Scripts/config/ci-xcode.json) |
| Commands and flags | script usage/option parsing and [command reference](../Scripts/Reference.md) |
| When to run which gate and what completion means | [Platform/Verification.md](Platform/Verification.md); hosted implementation details in [VerificationInternals](Platform/VerificationInternals.md) |
| What a good test is | [Platform/Testing.md](Platform/Testing.md) |
| Module DAG and hub containment | [Platform/Architecture.md](Platform/Architecture.md) (`check-module-boundaries.sh`) |
| Player-facing locked choices | [Product/Decisions.md](Product/Decisions.md) |
| Input feedback and failure presentation | [Product/DesignPrinciples.md](Product/DesignPrinciples.md) |
| iOS support window and native API adoption | [Platform/ApplePlatformReference.md](Platform/ApplePlatformReference.md) |
| Current vs banned SwiftUI/observation APIs | [Platform/ApplePlatformReference.md](Platform/ApplePlatformReference.md#current-vs-banned-swiftui) (enforced by `check-api-bans.sh`) |
| Style and boundary checker split | [Platform/Verification.md](Platform/Verification.md#style-and-boundary-ownership) |
| AccessibilityID rubric vs launch details | [Test rubric](Platform/Testing.md#ui-keep-drop-rubric), [launch arguments and helpers](../TrinketUITests/README.md), and [feature placement](AgentContext/swiftui-features.md) |
| Artwork pins and memory budgets | [Pin lifecycle](AgentContext/ui-performance.md); [artwork budgets](Platform/PerformanceInvestigationPlaybook.md#artwork-budgets), verified by `PreparedArtworkCacheTests` ([focused command](../Scripts/check-artwork-budget.sh)) |
| Balance rules and tuning | [AgentContext/battle-balance.md](AgentContext/battle-balance.md), subject to current [Product decisions](Product/Decisions.md) and their linked mode contracts |
| Audio routing and playback behavior | [TrinketAppState](../Packages/TrinketAppState/README.md) (routed via [audio context](AgentContext/audio.md)) |
| Game surfaces and modes | [Product/Overview.md](Product/Overview.md) |
| Art direction and delivery constraints | [Product/ArtworkStyleGuide.md](Product/ArtworkStyleGuide.md) |
| Cross-package battle / persistence / content | matching [AgentContext](AgentContext/) card |
| Manifest column formats | that manifest directory’s README |
| Package public types / how to extend | that package README |
| Agent workflow and safety hard stops | root and nested `AGENTS.md` |
| Simulator isolation and leases | [Platform/SimulatorOperations.md](Platform/SimulatorOperations.md) (leases and recovery); interaction technique in the [ios-simulator skill](../.agents/skills/ios-simulator/SKILL.md) |
| StoreKit purchase prerequisites | [Purchases](Platform/Purchases.md) (infra checklist); [Monetization](Product/Monetization.md) owns product rules |
| Localization ownership and synchronization | [Localization](Platform/Localization.md), [English store copy](../Localization/Store/English.json) |
| App Store metadata draft (data, not policy) | [App Store field drafts](Platform/AppStoreMetadata.md); [Release](Platform/Release.md) owns the procedure |
| CloudKit enablement gates | [CloudKit checklist](Platform/CloudKitPreShipChecklist.md) (ordered gates); [storage contract](AgentContext/persistence-storage.md) owns save behavior |
| Commit format, hooks, and push preconditions | [Platform/Release.md](Platform/Release.md) |
| Audit procedure | [Audits/README.md](Audits/README.md) plus the cited audit file |

Link to the owner for detailed rules. A short local summary is useful when it
lets a reader act without another lookup; keep its owner linked and avoid copying
mutable numbers, command options, or exception lists. A chain of index pages is
not a substitute for a usable explanation.

## Lifecycle and retention

| Surface | Authority and retention |
|---------|-------------------------|
| Standing Product, Platform, package, and AgentContext docs | Current and authoritative; update with the behavior they describe |
| Skills | Task-specific procedure; use when the trigger applies, with references loaded only for the relevant mode |
| Knowledge | Searchable rationale and rejected approaches; load only by trigger and remove facts already enforced elsewhere |
| Audit guides | Re-runnable procedure, never run history or backlog |
| `Docs/Audits/Proposals.md` | Narrow durable audit memory; evidence pointers must continue to resolve |
| Active execution plans | Temporary, with advisory review dates; allowed only directly under `Docs/Plans/` |
| Completed or cancelled plans | Fold current requirements into their canonical owners, then delete; no outcome archive |
| Diagnostic logs and comparison output | Successful logs are removed after consumers finish; remaining output expires after 24 hours unless explicitly kept for active investigation |
| Task deliverables | Handoff writes compact execution reports automatically; integration adds the task scope and preserves `.DerivedData/Deliverables/` outside the checkout. `agent-worktree.mjs evidence` preserves other files. These deliverables do not expire with diagnostic logs |
| Evals | Representative validation fixtures, not standing workflow policy |

Do not create execution plans under `.agents/` or another parallel plan folder.

## Policy precedence

Root `AGENTS.md` sets repository-wide constraints; narrower guides may add safeguards
but cannot silently relax them. Use the source-of-truth table above for each fact.

Configuration and script parsing establish what runs, not necessarily what is
intended. When execution and prose disagree, inspect the implementation and
intent, then fix the incorrect owner. Ask for a decision when intent is ambiguous.

## Editing guidance

Add guidance only for a concrete failure or recurring decision. State the trigger
and action at the narrowest owner; link to mechanics rather than copying flags,
tuning values, or exception lists. Remove superseded guidance and duplicates.
Keep rationale beside surprising rules, and substantial rejected approaches in
knowledge. Preserve non-obvious game rules, save contracts, and recovery steps.

Distinguish requirements from defaults, examples, history, and implementation gaps.
Reserve “always” and “never” for invariants; examples do not mandate abstractions,
tests, or approval steps.

For documentation-only changes, check local links and routed gates, and compare
changed commands or behavioral claims with their executable owners. Link checks
alone do not establish correctness. Consequential skill workflow changes also use
a relevant [evaluation scenario](../.agents/evals/README.md); wording edits need no
synthetic feature or promotion log.
