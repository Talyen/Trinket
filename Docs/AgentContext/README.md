# AgentContext cards

Path-routed domain guides. `./Scripts/agent-context.sh` attaches them from
`Scripts/change-classification.sh` (there is no YAML catalog). Cards hold
cross-package exceptions, not restated root policy. Platform docs own architecture
and testing; nested `AGENTS.md` files own local hard stops.

Read the root and nested `AGENTS.md` safeguards and the applicable ownership and
integration constraints. The router lists detailed behavior references separately:
read the sections relevant to the change and follow dependencies across concerns.
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

Apple design procedure: [apple-design skill](../../.agents/skills/apple-design/SKILL.md) (attached for DesignSystem and visual feature paths only). Cursor glob rule `.cursor/rules/design-system-colors.mdc` enforces color routing independently of this catalog.

## Quickstart

1. For an indexed concern, use `python3 Scripts/agent-session.py brief --task shop`.
   This combines scoped status, safeguards, initial guidance, signatures and test pointers.
   Find an index entry with `agent-search.py '<concern>' --task`; otherwise discover
   filenames with `--files <regex> --scope <owner>` or `--overview` for an unknown owner.
2. Preserve actual task scope with `brief --task <concern> --paths <files...>` or
   `./Scripts/agent-context.sh --agent --status --paths <files...>`.
   Read additional relevant contracts and load skills by trigger.
3. Batch relevant sections with `python3 Scripts/agent-read.py 'file.md#anchor' …`.
   Use source `--outline` to locate declarations, then `--symbol <name>` to read
   them. `--full` reads whole files and only the selected section for anchors in
   the same batch. For other mixed modes, repeat `--request 'path [read flags]'`.
   `--related <identifier> --scope <owner>` finds source/test hints. Inspect
   assertions and follow callers; hints do not prove coverage.
4. Review every relevant page of `python3 Scripts/agent-diff.py --paths <files...>`
   before editing overlapping work; preserve unrelated edits.
5. Finish with `./Scripts/handoff.sh --isolate --quiet --paths <files...>`.
   Local handoff proves lightweight checks; compilation and UI checks remain
   CI-owned under [Verification](../Platform/Verification.md).

Session commands bind temporary guidance receipts to `CODEX_THREAD_ID` (or explicit
`--chat`). For a repeated brief, opt into `--reuse-guidance` only while earlier
guidance remains in context. Routing and warnings stay visible; changed guidance
is reread. After context loss, run `agent-session.py forget` and reread contracts.
See [receipt details](Retrieval.md#chat-local-read-receipts).

The [retrieval reference](Retrieval.md) owns filtering, pagination, complete reads,
fingerprints, receipts and diff semantics. The small [task index](../../Scripts/config/agent-tasks.json)
contains navigation pointers only; update a confirmed recurring concern there,
without copying behavior rules or claiming complete test coverage.
