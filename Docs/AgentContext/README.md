# AgentContext cards

Path-routed domain guides. `./Scripts/agent-context.sh` attaches them from
`Scripts/internal/change_routing.py`. Cards hold
cross-package exceptions, not restated root policy. Platform docs own architecture
and testing; nested `AGENTS.md` files own local hard stops.

The required briefing reads local `AGENTS.md` safeguards and concise ownership.
Behavior cards remain links for the concern being changed; `--full --read` expands
all routed depth, while optional `--task <concern> --read` reads that concern's
focused contracts. Guidance follows owner directories rather than source leaf
names. Briefings surface applicable skills and the short UI interaction constraints directly.
Skills apply by their own triggers; the catalog below is optional lookup.

Sample briefing shape (exact cards vary by path):

```text
Read first: AGENTS.md, Packages/BattleEngine/AGENTS.md
Ownership and integration: Docs/AgentContext/battle-engine.md
Behavior references: Docs/AgentContext/battle-damage.md
Landing (after review and commit): node Scripts/agent-worktree.mjs integrate
Optional iteration check: ./Scripts/handoff.sh --quiet --paths <files...>
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

Follow [Route and read](../../AGENTS.md#route-and-read) in the root guide. The
briefing prints local safeguards and concise ownership;
reuse unchanged guidance and read broader references only for the affected
behavior. This catalog is for lookup, not an additional reading sequence.

`--base main` includes task commits plus dirty files; `--paths` selects intended
files. Concern shortcuts and specialized helpers remain optional. The
[task index](../../Scripts/config/agent-tasks.json) supplies navigation hints,
not coverage proof. `localization` routes copy work; `localization-tooling` routes
its implementation. Use [Retrieval](Retrieval.md) only for a navigation question.
