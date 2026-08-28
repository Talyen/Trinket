# AgentContext cards

Path-routed domain guides. `./Scripts/agent-context.sh` attaches them from
`Scripts/change-classification.sh` (there is no YAML catalog). Cards hold
cross-package exceptions, not restated root policy. Platform docs own architecture
and testing; nested `AGENTS.md` files own local hard stops.

The router prints a read contract. Read the root and nested `AGENTS.md` files plus
the listed focused card(s) first. Skills are optional lookups: open one only when
the trigger applies. A route card such as `battle.md` is lookup-only metadata; use
the focused subcard named beside it and do not read the router card by default.

| Card | Typical trigger |
|------|-----------------|
| [battle.md](battle.md) | Battle ownership router; load one focused battle subcard |
| [battle-engine.md](battle-engine.md) | `BattleEngine` rules, effects, damage, triggers, balance tools |
| [battle-runtime.md](battle-runtime.md) | `BattleRuntime`/`BattleSession`, app battle launch, BattleFeature presentation |
| [battle-balance.md](battle-balance.md) | `balance-sweep.sh`, engine `Balance*` sources, scaling/pacing/talent tuning |
| [persistence.md](persistence.md) | `TrinketPersistence` |
| [content-and-manifests.md](content-and-manifests.md) | manifests, content catalogs, `project.yml` |
| [swiftui-features.md](swiftui-features.md) | visual UI paths under `Trinket/Features`, feature packages, `TrinketUITests` |
| [audio.md](audio.md) | `TrinketAppState` audio paths |
| [ci-and-project-generation.md](ci-and-project-generation.md) | `Scripts/`, `.github/`, `project.yml` |
| [ci-diagnostics.md](ci-diagnostics.md) | **Lazy:** load only after a test/CI failure |

Apple design procedure: [apple-design skill](../../.agents/skills/apple-design/SKILL.md) (attached for DesignSystem and visual feature paths only). Cursor glob rule `.cursor/rules/design-system-colors.mdc` enforces color routing independently of this catalog.

Reading budget: locate the symbol with `rg`, read a bounded line range, and open a
linked guide only when the task crosses that guide's concern. Generated catalogs and
schemas are lookup outputs; inspect the targeted entry rather than loading the whole
file. Do not recursively follow every link in a card.
If a command emits a long log, consume its structured summary or a bounded tail
before opening the raw file.

Search fence: default searches are tracked/authored paths or the explicit owner
directory. Do not use whole-tree `find`, `--hidden`, or recursive file browsing over
`.DerivedData/`, `BalanceSweepReports/`, build products, or raw logs unless the
task is specifically an artifact investigation.
