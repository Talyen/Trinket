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
| [battle-damage.md](battle-damage.md) | Damage pipeline, effect handlers and expiry |
| [battle-actions.md](battle-actions.md) | Card/action identity, hand, Mana and preparations |
| [battle-healing.md](battle-healing.md) | Healing, overflow and gains |
| [battle-talents.md](battle-talents.md) | Talent manifest; otherwise look up the named talent only |
| [battle-runtime.md](battle-runtime.md) | `BattleRuntime`/`BattleSession`, app battle launch, BattleFeature presentation |
| [battle-balance.md](battle-balance.md) | `balance-sweep.sh`, engine `Balance*` sources, scaling/pacing/talent tuning |
| [persistence.md](persistence.md) | `TrinketPersistence` |
| [persistence-storage.md](persistence-storage.md) | Schema, save graph, sanitization and failure recovery |
| [persistence-progression.md](persistence-progression.md) | Rewards, claims and encounter domain writes |
| [content-and-manifests.md](content-and-manifests.md) | manifests, content catalogs, `project.yml` |
| [swiftui-features.md](swiftui-features.md) | visual UI paths under `Trinket/Features`, feature packages, `TrinketUITests` |
| [ui-performance.md](ui-performance.md) | Launch/tab mounting, Collection retention, prepared artwork; other UI tasks load it when touching those concerns |
| [audio.md](audio.md) | `TrinketAppState` audio paths |
| [ci-and-project-generation.md](ci-and-project-generation.md) | `Scripts/`, `.github/`, `project.yml` |
| [ci-diagnostics.md](ci-diagnostics.md) | **Lazy:** load only after a test/CI failure |

Apple design procedure: [apple-design skill](../../.agents/skills/apple-design/SKILL.md) (attached for DesignSystem and visual feature paths only). Cursor glob rule `.cursor/rules/design-system-colors.mdc` enforces color routing independently of this catalog.

Reading budget: discover owners with `agent-search.py`, read a bounded line range, and open a
linked guide only when the task crosses that guide's concern. Generated catalogs and
schemas are lookup outputs; inspect the targeted entry rather than loading the whole
file. Do not recursively follow every link in a card.
If a command emits a long log, consume its structured summary or a bounded tail
before opening the raw file.

Search fence: default searches are tracked/authored paths or the explicit owner
directory. Do not use whole-tree `find`, `--hidden`, or recursive file browsing over
`.DerivedData/`, `BalanceSweepReports/`, build products, or raw logs unless the
task is specifically an artifact investigation.

Search defaults to authored production text from Git's tracked and nonignored
untracked inventory. Generated paths use the existing generated-output registry;
tests (including test-support targets), Markdown and generated output have explicit
`--mode` surfaces. Results default to filenames with matching-line counts. Bounds
always report omitted files/lines and shortened excerpts; no matches means no
matches within the displayed surface, not within the whole repository.

The router prints source/test roots. Locate owners before opening excerpts:

```sh
python3 Scripts/agent-search.py DamagePipeline --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --mode tests --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --scope Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps.swift --excerpts
sed -n '40,100p' Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps.swift
```

For a generated-content investigation, explicitly target the catalog and entry:

```sh
python3 Scripts/agent-search.py 'enum ArtCatalog' --mode generated --scope Packages/TrinketContent --excerpts
```

Focused contracts replace the corresponding detail in package READMEs. Known
paths select their concern; shared or unknown engine/persistence paths retain all
operation contracts. When following a call across concerns, load its contract too.
Use the package README as an index to optional API and behavior references.

The default router omits empty sections, repeated policy, and expanded check
commands. `--full` includes authored paths, route metadata, and the sequential
verification plan. Both forms retain required guidance and safety warnings.
