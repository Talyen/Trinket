# AgentContext cards

Path-routed domain guides. `./Scripts/agent-context.sh` attaches them from
`Scripts/change-classification.sh` (there is no YAML catalog). Cards hold
cross-package exceptions, not restated root policy. Platform docs own architecture
and testing; nested `AGENTS.md` files own local hard stops.

The router prints a read contract. Read the root and nested `AGENTS.md` files plus
the listed focused card(s) first. Skills are optional lookups: open one only when
the trigger applies. A route card such as `battle.md` is lookup-only metadata shown with `--full`;
read it only when ownership is unclear. Reuse unchanged guidance already in
context and read newly applicable material when scope expands.
All skills live under `../../.agents/skills/`; the design skill below is the one
most routes attach.

Sample briefing shape (exact cards vary by path):

```text
Read first: AGENTS.md, Packages/BattleEngine/AGENTS.md
Context cards: Docs/AgentContext/battle-engine.md
Verification: ./Scripts/handoff.sh --isolate --paths <files...>
```

| Card | Typical trigger |
|------|-----------------|
| [battle.md](battle.md) | Battle ownership router; load one focused battle subcard |
| [battle-engine.md](battle-engine.md) | `BattleEngine` rules, effects, damage, triggers, balance tools |
| [battle-runtime.md](battle-runtime.md) | `BattleRuntime`/`BattleSession`, app battle launch, BattleFeature presentation |
| [battle-balance.md](battle-balance.md) | `balance-sweep.sh`, engine `Balance*` sources, scaling/pacing/talent tuning |
| [persistence.md](persistence.md) | `TrinketPersistence` |
| [content-and-manifests.md](content-and-manifests.md) | manifests, content catalogs, `project.yml` |
| [swiftui-features.md](swiftui-features.md) | visual UI paths under `Trinket/Features`, feature packages, `TrinketUITests` |
| [ui-performance.md](ui-performance.md) | Launch/tab mounting, Collection retention, prepared artwork; other UI tasks load it when touching those concerns |
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

Locate authored Swift symbols within their owner before reading whole files:

```sh
rg -n -g '*.swift' -g '!**/Generated/**' -g '!*.generated.swift' 'DamagePipeline' Packages/BattleEngine/Sources
sed -n '40,100p' Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps.swift
```

For a generated-content investigation, explicitly target the catalog and entry:

```sh
rg -n -C 3 'enum ArtCatalog' Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift
```

The default router omits empty sections, repeated policy, and expanded check
commands. `--full` includes authored paths, route metadata, and the sequential
verification plan. Both forms retain required guidance and safety warnings.
