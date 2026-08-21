---
type: execution-plan
status: complete
created: 2026-08-20
updated: 2026-08-21
expires: 2026-09-19
---

# Documentation simplification plan

> Superseded by [`DocsToolingSimplification.md`](DocsToolingSimplification.md),
> which owns the remaining work items from this plan.

## Objective

Reduce the amount of documentation an agent or teammate must read while keeping
the rules that protect game behavior, source ownership, and verification. Make
one fact have one durable owner, link to it everywhere else, and let executable
scripts, manifests, project configuration, and code own mutable details.

This review covered the repository's tracked Markdown, including root and
nested `AGENTS.md`, package and manifest READMEs, `Docs/`, `Scripts/README.md`,
and UI-test guidance. The snapshot contains 99 tracked Markdown files. The
documentation checker also traverses ignored generated balance reports; that
is a separate finding below. Existing `TokenEfficiencyPlan.md` already covers
some context-routing and transient-artifact work; merge overlapping work rather
than maintaining two plans for the same remedy.

## Priority findings and recommendations

### P1 — Make the documentation checker inspect authored docs only

`Scripts/check-docs.py` uses a recursive Markdown walk and therefore includes
ignored `BalanceSweepReports/` output (the pre-review workspace contained dozens
of generated report files). These reports are run artifacts, not durable docs;
they add noise, repeated headings, and stale snapshots to link/structure checks.

Plan:

- Make the checker enumerate tracked Markdown plus explicitly allowlisted
  authored/untracked docs, instead of walking every `*.md` below the workspace.
- Keep generated report directories out of the normal doc/search surface; add a
  narrow regression proving ignored reports do not affect the count or checks.
- Keep the existing link, plan-lifecycle, smoke-registry, and stale-term checks.
  Do not replace them with a general duplicate-text linter.

### P1/P2 — Separate command syntax from workflow policy

Command names, flags, isolation, smoke membership, CI composition, and handoff
behavior recur in `README.md`, `AGENTS.md`, `Scripts/README.md`,
`Docs/Platform/Verification.md`, `Docs/Platform/Testing.md`, `Release.md`,
`SimulatorOperations.md`, `ci-and-project-generation.md`, and package/UI
READMEs. This is both verbose and a drift trap whenever a script changes.

Target ownership:

- Executable scripts and their `--help` output own exact flags, defaults,
  environment variables, and generated paths.
- `Scripts/README.md` keeps a short human command index and links to the owning
  script; it should not explain every flag or repeat test policy.
- `Docs/Platform/Verification.md` owns when/why to choose a tier and what each
  gate means, not command syntax copied from scripts.
- `Docs/Platform/Testing.md` owns semantic test ownership and the keep/drop
  rubric; UI launch args and speed rules stay in `TrinketUITests/README.md`.
- `AGENTS.md`, `Release.md`, and `SimulatorOperations.md` keep only hard stops
  and release/IDE decisions that are not already executable behavior.
- Package READMEs link to the relevant package test command instead of restating
  the smoke plan or global handoff rules.

The four-class smoke plan is currently repeated in `Scripts/README.md`,
`Verification.md`, `Testing.md`, and `TrinketUITests/README.md`. Keep the class
registry and selected tests in `Smoke.xctestplan` /
`Scripts/config/smoke-classes.txt`; document the meaning once and link to it.

### P1/P2 — Collapse shared audit policy into the audit index

`Docs/Audits/README.md` already owns the evidence cone, severity scale,
right-size policy, proposal bar, pass shape, budgets, verification, and routing.
Most of the 17 audit guides repeat parts of that contract with their own hard
stops, severity wording, and routing prose. This makes each audit longer and
lets policy drift between guides.

Plan:

- Keep the shared contract, confusable-pair table, and template only in
  `Docs/Audits/README.md`.
- Reduce each numbered audit to: goal, domain-specific exclusions/allowlists,
  evidence that is unique to the domain, and success criteria.
- Replace repeated “full routing” and generic verification paragraphs with one
  link to the index.
- Keep `Proposals.md` as run memory only; do not add dated “last run”, Done, or
  implementation logs to audit guides.
- Make the existing template in `Docs/Audits/README.md` the only authoring
  template so new audits cannot silently reintroduce the shared boilerplate.

### P1/P2 — Simplify AgentContext routing and the battle card graph

The battle router plus four focused subcards is useful, but it duplicates the
ownership tables in `Architecture.md`, package READMEs, and nested `AGENTS.md`.
The router is also emitted alongside the focused card even though it says not to
read it by default. Similar duplication exists between `swiftui-features.md`,
the Apple design skill, and feature/package guides.

Plan:

- Keep one compact machine-routed card per semantic owner. If the battle split
  remains useful, store the owner map once and generate the router/index from it.
- Have `agent-context.sh` emit exactly one required focused card; mark the
  router as lookup-only in output, not as a second required read.
- Keep cards to exceptions and boundary facts. Link to Platform policy and
  package READMEs instead of repeating it.
- Make the classifier's required/optional/lookup distinction explicit and add a
  small routing fixture matrix for engine, persistence, audio-only AppState,
  BattleFeature presentation, DesignSystem test, UI test, manifest, and script
  paths.
- Keep the existing explicit `--paths` and `--isolate` safety behavior; this is a
  context reduction, not a verification demotion.

### P2 — Narrow Architecture and package README responsibilities

`Docs/Platform/Architecture.md` contains the module map, ownership table,
generated asset details, persistence notes, battle launch notes, and deferred
improvements. Package READMEs repeat many of those same ownership facts, while
AgentContext cards repeat them again.

Target shape:

- Architecture: module DAG, dependency rules, hub-containment rule, and the
  small set of cross-package boundaries that must not move.
- Package README: what the package exports, how to extend it, and package-local
  tests. Do not duplicate the full DAG or product layout.
- AgentContext / nested `AGENTS.md`: only path-triggered hard stops and
  exceptions. Keep verification commands only where the path-specific command
  is genuinely different.
- Product layout details belong to the owning product/feature doc, not both
  Architecture and package README.

This also removes stale lists of concrete type names when a type is renamed;
the architecture document can name the boundary and link to the package owner.

### P2 — Consolidate the four media pipeline READMEs

`ArtManifest`, `MusicManifest`, `SoundManifest`, and `CinematicManifest` repeat
the same folder/source/generated-output pattern, generation instructions,
path-scoped handoff command, and `content-and-manifests.md` pointer. Keep the
manifest-specific schema and review constraints locally, but move the common
workflow to one short asset-pipeline section (the existing content/manifests
card is the natural owner).

For art, keep kind-specific crop semantics and source-rights review. For audio
and cinematics, keep encoding-specific settings and runtime routing. Remove
repeated “run generate / run handoff” prose and use one link to the common
workflow. Avoid a new abstraction or generator solely to share Markdown.

### P2 — Make content and generated-catalog documentation less brittle

`ContentManifest/README.md`, `Packages/TrinketContent/README.md`,
`content-and-manifests.md`, and Architecture all list generated filenames,
ability sources, and catalog ownership. These lists become stale whenever a
generator adds or renames an output.

Plan:

- Keep one schema owner for each TSV in `ContentManifest/README.md`.
- Keep the package README to the authored-vs-generated boundary and the public
  lookup types.
- Keep the context card to the single entry command and input/output rules.
- Replace long generated-file inventories with a short “generated by” pointer
  and, where useful, a generated inventory emitted by the existing codegen.
- Prefer stable symbols (`AbilityCatalog.all`, a catalog type, or a manifest
  column name) over exhaustive current filenames and IDs.

### P2 — Reduce test-matrix and launch-argument duplication

The package test READMEs, `Testing.md`, `Verification.md`, `TrinketUITests/README.md`,
and several AgentContext cards each describe test ownership, smoke classes,
launch arguments, and what not to test. Keep the semantic rubric in `Testing.md`
and the UI mechanics in the UI-test README; package test READMEs should contain
only package-specific ownership rows that cannot be inferred from the test
names.

Do not maintain a hand-copied exhaustive list of launch arguments in Markdown.
Keep examples for the common paths and point to the `TestLaunchArg` source type
for the complete list; add a generated/help view only if an existing command
already has a natural place for it.

Also clarify the existing persistence wording in one place: “do not test
in-memory accessor/setter round-trips; do test durable mutate → reload →
semantic result.” This avoids the conflict between the root anti-plumbing rule
and the Persistence store requirement.

### P2 — Give CloudKit posture one owner

Local-only posture, identity decisions, reset behavior, future enablement, and
conflict/production caveats are repeated across `Identity.md`,
`CloudKitPreShipChecklist.md`, Architecture, the Persistence README, and
Persistence context. Keep:

- `Decisions.md`: the short locked product decisions (PD-008–PD-011).
- `Identity.md`: player-facing identity model and UX consequences.
- `CloudKitPreShipChecklist.md`: the release gate and human dashboard/device
  checklist.
- Architecture/Persistence docs: one-line ownership pointers only.

Remove repeated “current ship posture” and “when sync ships” paragraphs from
secondary files. Put mutable entitlement/container names and required flags in
the checklist or project configuration, with a link from the other docs.

### P2 — Split Apple design procedure from API and token references

The Apple design skill and its six reference pages overlap with
`iOS26AppleReference.md`, `TrinketDesignSystem/README.md`, feature guides, and
the design-system AGENT. This is a large read surface for a localized UI edit.

Target ownership:

- `Docs/Skills/apple-design/SKILL.md`: routing and a compact review checklist.
- Focused skill pages: only the principle that is not already a platform/token
  rule; link to the relevant page instead of requiring all six.
- `iOS26AppleReference.md`: Apple API choices and banned/approved API pairs.
- `TrinketDesignSystem/README.md`: public design-system tokens and modifiers.
- Feature guides: only the local owner and accessibility/test trigger.

Centralize duplicate Apple URLs in the API/reference page or a focused skill
page. Keep external links near the rule they support and avoid copying Apple
API names into multiple guidance layers.

### P1/P2 — Remove mutable snapshots and line-number citations from living docs

Several docs contain exact counts, thresholds, scenario totals, seed values,
generated filenames, current API lists, and source line ranges. Examples include
the deterministic seed in Testing and battle context, smoke class counts,
performance scenario/threshold details, art dimensions/memory budgets, and many
`path:line-line` citations in `TokenEfficiencyPlan.md`.

Plan:

- Replace line-number citations with paths plus stable symbols/section names.
- Replace “currently N” with “use the default from `<symbol/script --help>`”.
- Keep a number only when it is a product invariant or a checked-in baseline;
  link to the source that enforces it.
- For performance, memory, diagnostics, and asset settings, make scripts or
  checked-in JSON baselines the source of truth; docs explain interpretation and
  decision rules, not a second copy of every threshold.
- Add targeted stale checks only for high-consequence facts (smoke registry,
  project/toolchain baseline, and release commands). Do not build a broad parser
  for prose.

### P2 — Prune active plans and future-only prose

`Docs/Plans/TokenEfficiencyPlan.md` is a 652-line active plan containing large
measurement tables, a model-specific benchmark recipe, source line ranges, and
historical snapshots. It also overlaps the documentation/routing work above.
Keep the objective, current findings, phases, owners, and verification; move
disposable benchmark output out of the living plan and delete it once the
decision is made. Repair the malformed duplicated command continuation and the
duplicated sentence in the transient-artifact finding while editing.

Apply the same rule to “later”, “when sync ships”, “future step”, and draft/legal
notes: keep a short explicit deferment only when it protects a current boundary;
otherwise delete it or move it to the decision/checklist owner. Keep active
plans focused on current work; when one is complete, retain it under
`Docs/Plans/Archived/` as a historical record.

## Sequenced implementation phases

### Phase 0 — Establish the ownership map (no behavior change)

- List each mutable fact currently repeated in more than one document:
  commands/flags, smoke classes, test tiers, module ownership, manifest
  outputs, CloudKit posture, design APIs, performance thresholds, and release
  steps.
- Assign one owner using `Docs/README.md`; mark every other occurrence as a
  link, a short local exception, or removable duplication.
- Record before/after line counts and required-read sets by category. Use these
  as diagnostics, not absolute quotas.

### Phase 1 — Fix doc boundaries and high-risk drift

- Restrict `check-docs.py` to authored Markdown and add the ignored-artifact
  regression.
- Remove line-number citations and correct known stale/ambiguous claims,
  including the handoff/change-budget wording and persistence test wording.
- Trim `TokenEfficiencyPlan.md` to a living plan and merge overlapping actions
  into this plan or close one of the two plans.

### Phase 2 — Consolidate routing, command, and testing guidance

- Reduce `Scripts/README.md` / Verification / Testing / UI-test overlap.
- Make the smoke registry and launch-argument source authoritative; retain only
  short human explanations in Markdown.
- Collapse audit boilerplate and simplify AgentContext's required/optional/lookup
  output. Add the small classifier fixture matrix.

### Phase 3 — Consolidate domain documentation

- Narrow Architecture and package README responsibilities.
- Consolidate media pipeline workflow prose and content/generated-catalog maps.
- Deduplicate product/CloudKit posture and Apple design/API guidance.

### Phase 4 — Add lightweight maintenance guardrails

- Keep targeted checks for links, smoke registry, plan lifecycle, and the few
  high-consequence mutable facts.
- When measurements are needed, emit a one-off non-retained summary of Markdown
  count, duplicated-owner candidates, and required context-card bytes. Do not
  create a periodic report store.
- At plan expiry, either implement the approved changes, fold durable policy
  into its owner, or renew the plan with fresh evidence. Completed plans move
  to `Docs/Plans/Archived/`.

## Success criteria

- `check-docs.py` ignores transient/generated report Markdown and still passes
  all authored-doc checks.
- Every command, smoke membership, test rubric, module boundary, manifest
  schema, CloudKit posture, design API rule, and performance baseline has one
  obvious owner.
- A routine task needs the root/nested hard stops plus one focused context card
  and one relevant owner document; linked material is optional and named by
  trigger.
- No living plan or guidance depends on source line numbers or unbounded current
  snapshots.
- The refactor removes repeated policy and stale-prone prose without weakening
  generation, boundary, package, smoke, UI, persistence, or release gates.

## Verification

- `python3 Scripts/check-docs.py`
- `./Scripts/test-scripts.sh`
- `./Scripts/handoff.sh --isolate --paths Docs/Plans/DocumentationSimplificationPlan.md`
- After implementation, rerun the representative `agent-context.sh --json`
  fixtures and the existing path-scoped handoff routes for every changed owner.
