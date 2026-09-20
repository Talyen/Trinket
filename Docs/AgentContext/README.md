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

Start unknown-owner discovery with `agent-search.py --overview`, then
`agent-search.py --files <pattern> --scope <owner>`; use scoped content
`rg` and direct reads after narrowing files. Read enough surrounding context to understand the contract and
its exceptions, including relevant callers, tests, configuration, and generated
references. Prefer targeted catalog lookups and bounded diagnostic output over
loading unrelated material. [CI diagnostics](ci-diagnostics.md) explains retained
reports and raw-log access when summaries are insufficient.

Default searches should avoid build products and raw logs. Scope hidden-file
searches to the relevant owner (for example `.agents/` or `.github/`). Inspect
`.DerivedData/`, `BalanceSweepReports/`, or other artifacts when needed for the
investigation, using explicit paths and bounded output.

The `agent-search.py` helper defaults to authored production text from Git's tracked and nonignored
untracked inventory. Generated paths use the existing generated-output registry;
tests (including test-support targets), Markdown/`.mdc` and generated output have explicit
`--mode` surfaces. Results default to filenames with matching-line counts.
For plain identifiers, exact filename stems, filename word/prefix matches, and declarations
rank before other references outside docs; declaration-like
matching lines include jump locations. Both are lookup hints, not proof of symbol ownership. `--files` matches relative filenames
without reading their contents, using the same filters and bounds. Use
`--mode assets --files` to include raw/processed media and asset metadata without
reading binary contents. `--overview` pages owner counts and entry points from
the Git inventory; individual asset filenames are omitted. Scopes and fingerprinted
pagination apply to both modes. Scoped `rg --files` remains available.
Documentation results put current guides and references first, procedures/knowledge
next, and task records last, alphabetically within each group. This ordering
applies before either file or excerpt limits; explicit scopes can still retrieve
plans, evals, and friction records directly. Resolved friction archives are excluded
unless `--scope` names `.agents/friction-archive` or a file within it. For direct
`rg` discovery, likewise omit that archive unless investigating past friction.
Search continuation commands use `--offset` and a result fingerprint (`--expect`);
changed results require restarting instead of silently skipping or repeating matches.
Bounds always report omitted
files/lines and shortened excerpts; no matches means no
matches within the displayed surface, not within the whole repository.

The router prints source/test roots. Example discovery and reads:

```sh
python3 Scripts/agent-search.py '(^|/)DamagePipeline\.swift$' --files --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --mode tests --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --scope Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps.swift --excerpts
sed -n '40,100p' Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineResolutionSteps.swift
```

For section-based reads with heading context, use the section reader:

```sh
python3 Scripts/agent-read.py Docs/Platform/Verification.md --outline
python3 Scripts/agent-read.py 'Docs/Platform/Verification.md#local-simulator-budget'
```

The reader prints source lines and parent headings. Unanchored Markdown over
12,000 characters returns a paginated heading outline labeled navigation only;
read the relevant anchors or explicitly use `--full` for the entire document.
Smaller documents still read completely by default. Read applicable constraints and relevant behavior sections,
including their exceptions; unrelated sections are not mandatory prereads.
Missing anchors fail explicitly. Sections are never silently truncated. Known Battle presentation leaves route directly
to relevant anchors plus shared display-lifetime constraints; shared owners retain
whole-card references.

For Swift or Python, `agent-read.py path.swift --outline` lists qualified types and
members with complete lexical source ranges and the file path once. Swift uses the
pinned SwiftFormat tokenizer; this is not a semantic ownership map. Add
`--include-locals` for declarations inside functions. `--symbol Qualified.name`
reads an attached comment/attribute block and complete declaration; overloaded or
ambiguous names return candidate ranges without choosing one. `--offset` /
`--limit` page the outline; `--lines START:END` reads an explicit complete range.

For a generated-content investigation, explicitly target the catalog and entry:

```sh
python3 Scripts/agent-search.py 'enum ArtCatalog' --mode generated --scope Packages/TrinketContent --excerpts
```

Focused contracts replace the corresponding detail in package READMEs. Known
paths suggest their concern; shared or unknown engine/persistence paths list all
operation references for discovery. Select the relevant sections and follow calls
across concerns. This reading choice does not narrow verification routing.
Use the package README as an index to optional API and behavior references.

The default router omits empty sections, repeated policy, and expanded check
commands. `--full` includes authored paths, route metadata, and the sequential
verification plan. Both forms retain ownership guidance, behavior references, and
safety warnings.

Use `--status` on the initial route to see global dirty counts and exact status
for task files, including either endpoint of a rename. Counts are informational;
inspect overlapping diffs and resolve unclear ownership before editing. Reroutes
can omit status when the relevant workspace state is unchanged.

For review, `python3 Scripts/agent-diff.py --paths <files...>` shows authored
unstaged patches and generated-file statistics using the generated-path registry.
Use `--staged` for the index, `--stat` for statistics only, or `--generated` to
expand generated patches. Output defaults to a 12,000-character content budget,
paged at complete hunks/records with repeated file headers. Follow the printed
continuation command; its fingerprint rejects a changed diff. An oversized hunk
is disclosed with an explicit larger-budget command, never silently cut. `--full`
is an intentional unbounded read. Review every relevant page before editing
overlapping work. Untracked files are listed for explicit reads. Whole-tree
review requires `--working-tree`. This view does not replace overlapping diff
inspection, generated consistency review, or idempotence verification.
