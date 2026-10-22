# AgentContext cards

Path-routed domain guides. `./Scripts/agent-context.sh` attaches them from
`Scripts/internal/change_routing.py`. Cards hold
cross-package exceptions, not restated root policy. Platform docs own architecture
and testing; nested `AGENTS.md` files own local hard stops.

Read the root and nested `AGENTS.md` safeguards and the applicable ownership and
integration constraints. With `--read`, the briefing includes focused behavior
sections alongside safeguards and ownership. Broad behavior references remain
available for the relevant concern; follow dependencies across concerns.
A shared filename does not require reading every listed behavior reference. Skills
apply by trigger. Route metadata such as `battle.md` appears with `--full` for
owner discovery. Reuse unchanged guidance already in context.
All skills live under `../../.agents/skills/`; the design skill below is the one
most routes attach.

Sample briefing shape (exact cards vary by path):

```text
Read first: AGENTS.md, Packages/BattleEngine/AGENTS.md
Ownership and integration: Docs/AgentContext/battle-engine.md
Behavior references: Docs/AgentContext/battle-damage.md
Verification: ./Scripts/handoff.sh --isolate --quiet --paths <files...>
```

| Card | Typical trigger |
|------|-----------------|
| [battle.md](battle.md) | Battle ownership router; load one focused battle subcard |
| [battle-engine.md](battle-engine.md) | `BattleEngine` rules, effects, damage, triggers, balance tools |
| [battle-damage.md](battle-damage.md) | Damage pipeline, effect handlers and expiry |
| [battle-actions.md](battle-actions.md) | Card/action identity, hand, Mana and preparations |
| [battle-healing.md](battle-healing.md) | Healing, overflow and gains |
| [battle-talents.md](battle-talents.md) | Talent manifest; otherwise look up the named talent only |
| [battle-runtime.md](battle-runtime.md) | Common runtime ownership and observation boundaries |
| [battle-launch.md](battle-launch.md) | Preparation, activation, return navigation, reward settlement and retry |
| [battle-presentation.md](battle-presentation.md) | Display lifetime, command playback, feedback, spectacle and leaf Battle views |
| [battle-balance.md](battle-balance.md) | `balance-sweep.sh`, engine `Balance*` sources, scaling/pacing/talent tuning |
| [persistence.md](persistence.md) | `TrinketPersistence` |
| [persistence-storage.md](persistence-storage.md) | Schema, save graph, sanitization and failure recovery |
| [persistence-progression.md](persistence-progression.md) | Rewards, claims and encounter domain writes |
| [content-and-manifests.md](content-and-manifests.md) | manifests, content catalogs, `project.yml` |
| [swiftui-features.md](swiftui-features.md) | visual UI paths under `Trinket/Features`, feature packages, `TrinketUITests` |
| [ui-performance.md](ui-performance.md) | Launch/tab mounting, Collection retention, prepared artwork; other UI tasks load it when touching those concerns |
| [audio.md](audio.md) | `TrinketAppState` audio paths |
| [ci-diagnostics.md](ci-diagnostics.md) | **Lazy:** load only after a test/CI failure |

Apple design procedure: [apple-design skill](../../.agents/skills/apple-design/SKILL.md) (attached for DesignSystem and visual feature paths only). The `check-ui-style.py` gate enforces color routing independently of this catalog.

## Quickstart

Use ordinary scoped search, reads and Git diffs. Before editing intended files:

```sh
python3 Scripts/agent-brief.py --status --read --paths <files...>
```

Read the safeguards and relevant contracts it supplies. Reuse unchanged guidance;
follow additional linked behavior sections only when they apply. After changes,
`python3 Scripts/agent-brief.py --status --read --base main` derives the complete
task scope, including committed and dirty work. Use the user-specified base if different.
Commit reviewed task work and integrate; integration runs the final handoff against
current main. For standalone handoff use `./Scripts/handoff.sh --quiet --base main`.

The briefing is the only required retrieval entry point. Concern shortcuts such
as `--task shop` and the specialized search/read/investigate/diff commands are
optional conveniences, described in [Retrieval](Retrieval.md). They never replace
reading relevant source bodies, assertions, or overlapping dirty diffs.

Briefings are stateless. Inline reads use ownership sections and focused contract
anchors; broad behavior references remain discoverable. The [task index](../../Scripts/config/agent-tasks.json)
contains navigation hints, not coverage proof. `localization` routes copy work;
`localization-tooling` routes changes to its implementation.
