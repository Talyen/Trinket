---
type: execution-plan
status: active
created: 2026-08-20
updated: 2026-08-20
expires: 2026-09-19
---

# AI agent token-efficiency plan

## Objective

Reduce avoidable agent context, rabbit holes, and diagnostic-output volume while
preserving correctness gates, source-of-truth ownership, and the existing
path-scoped verification model. This is a plan for process/tooling changes; no
production game behavior is in scope.

The measurements below use bytes, lines, file counts, and routed command counts
as stable proxies. They are not tokenizer-specific estimates.

The inventory is a 2026-08-20 snapshot of the then-current worktree. Re-run the
Phase 0 inventory before implementation; use the numbers here to prioritize, not
as a permanent quota or claim about every future run.

## Default operating policy

- Test results, diagnostics, raw logs, result bundles, timing data, performance
  reports, and balance-sweep output are current-run state, not a historical
  archive. Keep enough structured status for the active command to classify the
  result and print its handoff summary, then clean it by default.
- The CI job's pass/fail status and step summary remain required operational
  records; this policy removes attached diagnostic payloads, not the status that
  tells the team whether the job passed.
- Historical retention is opt-in (`--keep-artifacts`, an equivalent environment
  flag, or an explicit output directory). A retained run must print its path and
  remain inspectable without making retention the normal agent workflow.
- Do not remove authored source or warm build caches as part of report cleanup.
  Cleanup must never run while a producer is active; interrupted-run cleanup is
  limited to validated, run-scoped directories.

## Reading contract

- For a quick decision, read `Objective`, `Default operating policy`, and
  `Priority summary` only.
- For implementation, read the one relevant finding, its likely owners, and the
  matching phase/verification bullets. The evidence inventory is baseline
  context, not a requirement to inspect every referenced file first.
- Read the full plan only when sequencing cross-cutting changes or refreshing
  the measurements.

## Priority summary

1. **P1 — Scope diagnostics to one run and bound the default failure narrative.**
   This is the largest measured source of misleading context.
2. **P1 — Make failure reports root-cause-first and byte-bounded.**
   Current “bounded” reports can still be tens of kilobytes each.
3. **P1/P2 — Tighten `agent-context` routing.** Remove irrelevant cards and
   skills before asking an agent to read anything.
4. **P2 — Collapse duplicated guidance around command routing and test policy.**
5. **P1/P2 — Make transient test artifacts ephemeral by default and keep them
   out of normal search paths.**
6. **P2 — Make accidental whole-tree classification fail safe.**
7. **P2 — Resolve wording conflicts and make required/optional reads explicit.**

## Confirmed findings and remedies

### 1. Shared diagnostics aggregate stale history and prints an unbounded label list (P1)

Evidence:

- `.DerivedData/TestResults` currently contains **892** invocation manifests,
  **459** classified failures, **394** missing result bundles, and **359** missing
  diagnostics reports. They span 2026-08-17 through 2026-08-20 rather than one
  task run.
- `python3 Scripts/ci-diagnostics.py .DerivedData/TestResults …` writes a
  454,836-byte aggregate and prints an 8,607-character single-line detail because
  `Scripts/ci-diagnostics.py:347-350` joins every failed invocation label.
- `Docs/AgentContext/ci-diagnostics.md:50-54` tells agents to inspect the
  aggregate first. A stale aggregate therefore looks authoritative and sends an
  agent into old failures before it reaches the current run.

Preferred remedy:

- Give every test session a first-class run/session identifier and make the
  aggregate default to that session (or the newest invocation set), not every
  manifest in a shared directory. Keep an explicit historical mode for humans.
- Have wrappers create a run-scoped results directory or write a small current-
  run manifest; do not make agents infer recency from filenames.
- Replace the all-label detail string with bounded counts plus at most a few
  representative labels/root causes. Keep per-invocation paths for drill-down.
- Preserve `--full` as an explicit forensic mode. During rollout, do not remove
  current failure evidence before classification; the eventual default retention
  policy is defined in Finding 5.

Success measures and verification:

- Default aggregate contains only the selected run and prints a short summary
  (target: <= 1 KB of terminal narrative), while preserving category, exit codes,
  and links to every selected invocation.
- Add regression fixtures for mixed old/new manifests, no-manifest runs, and
  repeated labels. Run `Scripts/Tests/test_summarize_failures.py` and the script
  regression suite.

Likely owners: `Scripts/ci-diagnostics.py`, `Scripts/ci-diagnostics.sh`,
`Scripts/xcode-runner.sh`, `Scripts/test.sh`, `Scripts/test-package.sh`,
`Docs/AgentContext/ci-diagnostics.md`.

### 2. Failure reports are count-bounded but not context-bounded (P1)

Evidence:

- `Scripts/diagnostic_model.py:27-32` allows 20 issues, 1,200-character
  messages, 20 detail lines, 4,000 detail characters, and 400-character lines.
- `Scripts/diagnostic_rendering.py:50-71` renders those limits into Markdown.
  Existing reports reach **36,298 bytes in 27 lines** because each “issue” can be
  a full `xcodebuild` command or tool invocation.
- `Scripts/xcode-runner.sh:131-143` adds up to 80 matching log lines (or 80 tail
  lines), each up to 400 characters: up to roughly 32 KB of terminal output for
  one failed invocation. Deferred package runs can surface that output again.
- The result is duplicated narrative: runner excerpt, per-invocation Markdown,
  package-parent output, aggregate JSON, and CI step summary.

Preferred remedy:

- Normalize machine-heavy messages: strip repeated absolute build paths and
  collapse repeated `Xcode invocation`/`Tooling failure` observations to the
  first actionable root cause plus a count.
- Set separate small defaults for terminal, Markdown, and JSON previews (for
  example, 3–5 root issues, short messages, and a couple of detail lines). Keep
  full raw logs/result bundles available only by explicit path or `--full`.
- When `--defer-terminal-output` is active, suppress the runner’s raw excerpt and
  surface only the Markdown path/one-line summary; let the parent aggregate once.
- Add a clearly named opt-in for a larger tail instead of making a large excerpt
  the failure default. For CI, reuse the existing `gh run view --log-failed`
  path; add a separate local flag only if local investigations need it.

Success measures and verification:

- Default failure terminal output and Markdown stay below agreed byte budgets
  (record the budgets in the diagnostics card and regression fixtures).
- Root-cause classification, source locations, annotations, and raw-artifact
  paths remain intact. Extend `test-xcode-runner.sh` and
  `test_summarize_failures.py`; do not weaken failure detection.

Likely owners: `Scripts/diagnostic_model.py`, `Scripts/diagnostic_rendering.py`,
`Scripts/failure_diagnostics.py`, `Scripts/xcode-runner.sh`,
`Scripts/test-package.sh`, `Docs/AgentContext/ci-diagnostics.md`.

### 3. `agent-context` attaches irrelevant guidance on common paths (P1/P2)

Evidence:

- `Scripts/change-classification.sh:203-214` treats every
  `Packages/TrinketDesignSystem/*` path and every `TrinketUITests/*` path as
  visual UI. A `Package.swift`, a test helper, and a UI test all receive
  `Docs/AgentContext/swiftui-features.md` and `Docs/Skills/apple-design/SKILL.md`.
- A new internal/test Swift file also receives `.agents/skills/architect` because
  `trinket_path_needs_architect` returns true for every new Swift path
  (`:198-201`). If the file has comments, `doc-budget` is attached as well. The
  architect skill asks for explanatory docstrings while doc-budget removes
  self-evident comments, encouraging an add-then-prune loop.
- An audio-only AppState path currently routes
  `battle.md`, `battle-runtime.md`, and `audio.md`; the package-wide cases at
  `:221-223` are broader than the card’s “load one focused subcard” instruction.
- `battle.md:3` says to load one focused subcard, but the router emits both the
  router card and the focused card. That makes the routing card look like a
  required second preread.

Preferred remedy:

- Route by semantic owner first: AppState audio paths get audio only; battle
  runtime cards attach only to launch/session paths; tests and package manifests
  do not get visual design guidance.
- Narrow visual matching to authored view/design-system source directories, not
  tests, `Package.swift`, or every file in a design-system package.
- Attach `architect` only for a new/changed public type, protocol, schema, or
  enforced boundary. Attach `doc-budget` only when the diff actually adds or
  changes comments. Do not require docstrings as part of architecture review.
- Mark the battle router as metadata (“route only; do not read”) and emit the one
  focused card as the required read. Keep the router link available for humans.
- Add a small representative routing matrix to script regression tests.

Success measures and verification:

- Representative nonvisual/test paths have no Apple design skill; audio-only
  paths have no battle card; battle paths have one required focused card.
- Context output remains deterministic and path-scoped, and all existing package,
  smoke, generation, and boundary commands are unchanged.

Likely owners: `Scripts/change-classification.sh`, `Scripts/agent-context.sh`,
`Docs/AgentContext/README.md`, `.agents/skills/architect/SKILL.md`,
`.agents/skills/doc-budget/SKILL.md`, and script regression fixtures.

### 4. Guidance is duplicated across layers and contains at least one stale claim (P2)

Evidence:

- The repository itself declares “one fact has one owner” in `Docs/README.md`,
  but the same command and policy facts recur in `AGENTS.md` (6,614 bytes),
  `Scripts/README.md` (5,036), `Docs/Platform/Verification.md` (5,711),
  `Docs/Platform/Testing.md` (10,595), AgentContext cards (24,539 total), and
  package/UI READMEs.
- `Scripts/README.md` has the command index and `Docs/Platform/Verification.md`
  repeats command syntax in confidence/test-tier tables. `Testing.md` repeats
  smoke/FullUI guidance also present in `TrinketUITests/README.md` and
  `swiftui-features.md`. Handoff/isolation rules recur in the root guide,
  Scripts README, Verification, and CI context.
- `Docs/Platform/Verification.md:88` says every completed handoff prints a
  change-budget report, but `Scripts/handoff.sh` does not invoke
  `change-budget.sh`; the push gate does. This can cause agents to wait for or
  independently rerun an expected report.

Preferred remedy:

- Keep script `--help`/`Scripts/README.md` authoritative for command syntax;
  reduce Verification to “when/why” routing and links.
- Keep `Testing.md` authoritative for semantic test ownership and the keep/drop
  rubric; keep `TrinketUITests/README.md` to launch args/helpers/speed details.
- Keep AgentContext cards to exceptions and narrow owner facts; replace repeated
  root/Platform policy with links. Keep package READMEs package-local.
- Correct the handoff/change-budget statement and add a stale-doc regression for
  it. Do not build a generic duplicate-text linter; it would create noise.

Success measures and verification:

- Fewer required preread files for a routine package/UI task, with one clear
  owner for each command/policy fact. Validate links and structure with
  `Scripts/check-docs.py` and run `Scripts/test-scripts.sh`.

Likely owners: `AGENTS.md`, `Scripts/README.md`,
`Docs/Platform/Verification.md`, `Docs/Platform/Testing.md`,
`Docs/AgentContext/*.md`, `TrinketUITests/README.md`, and package READMEs.

### 5. Ignored artifacts are a large accidental search surface (P1/P2)

Evidence:

- `BalanceSweepReports/` currently contains **107 files / 46 MB** of ignored
  Markdown, JSON, and stderr/stdout artifacts. It is not hidden, so broad
  `find`, shell globbing, or an AI file browser can enumerate it even though
  ripgrep normally honors `.gitignore`.
- `.DerivedData/TestResults` is **4.4 GB** and `.DerivedData/runs` is **9.1 GB**;
  raw local test logs alone total about **501 MB**. The shared timing log is
  **5.7 MB**. These are useful forensic data, but not normal source context.
- `.gitignore` excludes the directories, yet `Docs/AgentContext/README.md` only
  explains generated catalogs and does not give a prominent “never search
  transient artifacts” rule.
- The current policy is retention-oriented rather than ephemeral: `run-env.sh`
  defaults to a three-day age prune, `ci-diagnostics.sh --reset` deliberately
  keeps raw logs and `.xcresult` bundles, `test-timing.sh` appends up to 250
  timing entries, and `balance-sweep.sh` does not prune its output. The ad hoc
  `performance.sh` runner creates timestamped report directories and only cleans
  its lock. CI stages retained artifacts for each run, with raw data included for
  failures/unknown results.

Retention decision based on the owner's workflow:

- Historical test results, diagnostics, raw logs, result bundles, timing history,
  performance captures, and balance-sweep reports are not useful enough to
  justify default retention. Treat them as **ephemeral run state**, not as a
  second source of truth for the repository.
- This is not Git-history cleanup: these paths are already ignored. It is still
  worthwhile because they consume local disk, enlarge broad searches, and can
  become CI artifact storage and stale-agent context.
- Keep the current run's small status/summary available until the wrapper has
  classified the result and printed the handoff narrative. After that, remove
  historical files by default. Never clean a directory while its test process
  is still active.
- Retention should be an explicit escape hatch, such as `--keep-artifacts` or
  `TRINKET_KEEP_TEST_ARTIFACTS=1`, rather than a multi-day default. The escape
  hatch must print the retained run path so a human can inspect it deliberately.
- Build products and other warm caches are a separate performance concern and
  should not be deleted merely because test reports are ephemeral.

Preferred remedy:

- Give each test/balance command a run-scoped results root. Keep only the
  concise findings/status brief on stdout, then clean the run root on normal
  completion and on the next safe startup. Confirm consumers before changing
  the path.
- Change `ci-diagnostics.sh --reset` and the run wrappers so manifests,
  diagnostics, raw logs, `.xcresult` bundles, attachments, and timing data do
  not accumulate across ordinary runs. Preserve the current-run files until
  aggregation, failure classification, any `assert-budget` step, and any
  explicitly requested CI staging step finish.
- Make `BalanceSweepReports` a temporary default output (or place it below the
  run root) and delete it after the findings brief is emitted. Keep an explicit
  output directory/keep flag for investigations that need reproducible files.
- Apply the same run-scoped/keep-mode rule to `performance.sh` and its collected
  or aggregated reports. Performance comparisons still read the checked-in
  baseline; historical generated captures do not need to persist by default.
- In CI, do not upload historical raw artifacts by default. Keep the job's
  structured pass/fail status in the job summary; upload a retained run only
  when a workflow input or environment flag requests it (a failed-run-only policy
  can remain an optional team setting). If an upload is required by CI plumbing,
  use the shortest supported retention and gate it rather than archiving every
  run.
- Add explicit search boundaries to AgentContext/Scripts guidance: search tracked
  authored paths or an explicit owner directory; do not use whole-tree `find` or
  `--hidden` over `.DerivedData`, `BalanceSweepReports`, build products, or raw
  logs.
- Extend the existing safe age-prune path as a backstop for interrupted runs and
  shared metadata. The default retention knob should mean “current run only”;
  nonzero retention is opt-in and cleanup must target validated run directories,
  not broad workspace paths.

Success measures and verification:

- After an ordinary test, performance, or balance run, no historical
  `TestResults`, timing, raw-log, `.xcresult`, attachment, performance-report,
  or balance-report files remain by default; the current run still yields the
  same classification and concise findings brief.
- CI does not grow a retained artifact set unless the explicit keep option is
  used. A kept run remains inspectable at the printed path.
- Normal source searches do not enumerate transient artifacts; report generation
  still produces the same findings and JSON when explicitly requested. Add
  script regressions for cleanup timing, active-process protection, keep-mode,
  output location/exclusion, and interrupted-run backstop pruning.

Likely owners: `Scripts/balance-sweep.sh`, `Scripts/performance.sh`,
`Scripts/test-timing.sh`, `Scripts/run-env.sh`,
`Scripts/prune-derived-data-cache.sh`, `Scripts/ci-diagnostics.sh`,
`.github/actions/test-job/action.yml`, `.gitignore`,
`Docs/AgentContext/README.md`, `Docs/AgentContext/ci-diagnostics.md`,
`Scripts/README.md`.

### 6. Accidental `--working-tree` classification expands both context and verification (P2)

Evidence:

- The root guide, Scripts README, and Verification all prefer explicit `--paths`,
  but `--working-tree` remains easy to invoke and has no broad-scope threshold.
- In the current dirty worktree, `./Scripts/agent-context.sh --agent
  --working-tree` classified **140 paths**, listed 10 nested guides, 9 context
  cards, 3 skills, and planned 8 package suites plus an app build and three smoke
  classes. The output itself was 2,938 bytes, while the likely preread and test
  fan-out are much larger.

Preferred remedy:

- Keep the explicit whole-tree escape hatch, but require a conspicuous
  confirmation/override above a path-count threshold and print a short estimate
  before proceeding. Offer a “changed since baseline” mode for broad audits.
- Make the agent briefing label whole-tree results as “mixed scope; do not read
  every card” and separate unrelated path clusters where possible.
- Preserve whole-tree CI/push behavior; this is a safety rail against accidental
  invocation, not a gate demotion.

Success measures and verification:

- Accidental broad calls stop before emitting a full plan; intentional calls with
  the override remain behaviorally equivalent. Cover both paths in shell tests.

Likely owners: `Scripts/agent-context.sh`, `Scripts/handoff.sh`,
`Scripts/change-classification.sh`, `Docs/Platform/Verification.md`.

### 7. Clarify a test-policy phrase that can send persistence work in the wrong direction (P2)

Evidence:

- `AGENTS.md:42-43` and `Docs/Platform/Testing.md:68` say not to test “stored-
  property round trips.”
- The same Testing document (`:53`), the Persistence AGENT, the Persistence
  README, and `Docs/AgentContext/persistence.md` explicitly require mutate →
  reload-from-disk → assert coverage for stores. An agent can reasonably read
  the shorter prohibition as forbidding the required persistence invariant.

Preferred remedy:

- Replace the ambiguous phrase with “do not test in-memory accessor/setter
  round-trips; do test durable store write → reload → semantic result.”
- Add a precedence sentence to the root/Platform docs: path-specific persistence
  guidance refines the general test anti-plumbing rule.
- Correct other stale claims discovered during the documentation pass, starting
  with the handoff/change-budget statement above.

Success measures and verification:

- A new agent can identify the required persistence test tier without opening
  multiple documents. Validate with `check-docs.py` and a targeted documentation
  review; no test behavior changes are required.

Likely owners: `AGENTS.md`, `Docs/Platform/Testing.md`,
`Packages/TrinketPersistence/AGENTS.md`, `Packages/TrinketPersistence/README.md`,
`Docs/AgentContext/persistence.md`.

### 8. Replace “follow links until comfortable” with explicit required/optional reads (P2)

Evidence:

- `Docs/AgentContext/README.md:24-27` asks for bounded reading, but the cards
  link to long documents without line ranges or a required/optional label.
- The Apple design skill is 4,087 bytes plus 19 KB of focused references and
  says to read the checklist and each matching reference. UI paths also point at
  `Testing.md` (10,595 bytes), `Architecture.md` (11,830), and
  `TrinketUITests/README.md` (4,522), so a routine visual edit can accumulate a
  large preread even when only one rule is relevant.
- `Docs/Audits/README.md` is 14,542 bytes and all audit guides total 82,101
  bytes. The audit workflow requires fully reading selected guides; broad audit
  wording can accidentally turn into an “all audits” preread.

Preferred remedy:

- Add a compact read contract to `agent-context`: `required` (root/nested
  hard-stops and one focused card), `optional` (only for a named concern), and
  `lookup` (specific symbol/section). Include line ranges or a short symbol
  index where practical.
- Change cards/skills to name the exact trigger for each linked reference; do not
  require all Apple-design references for a localized fix.
- Add a dedicated token-efficiency/context audit route rather than asking agents
  to load unrelated audit guides. Keep “all audits” explicit and exceptional.
- Include a byte/line context estimate in `agent-context --json` so a caller can
  see when a path set is anomalously broad before opening files.

Success measures and verification:

- Representative tasks have a documented maximum required-read set and a visible
  reason for every optional link. Validate routing JSON and documentation links;
  do not inject full document contents into every briefing.

Likely owners: `Scripts/agent-context.sh`, `Scripts/change-classification.sh`,
`Docs/AgentContext/README.md`, AgentContext cards, Apple design skill, and the
audit routing documentation.

## Sequenced implementation phases

### Phase 0 — Baseline and fixtures (no policy change)

- Add representative routing fixtures for engine, persistence, AppState audio,
  BattleFeature presentation, DesignSystem source/test, UI test, manifest, and
  script paths.
- Record current diagnostics sizes and mixed-run behavior in script tests rather
  than relying on the live dirty worktree.
- Agree byte/count budgets for terminal output, Markdown previews, aggregate
  stdout, and required context-card counts.

### Phase 1 — Stop misleading or oversized failure context

- Implement run/session-scoped diagnostics aggregation.
- Make failure rendering root-cause-first and byte-bounded; suppress duplicate
  deferred excerpts.
- Update the diagnostics card to describe the current-run default and the exact
  opt-in forensic commands.

### Phase 2 — Fix routing before trimming prose

- Narrow classifier predicates and remove router-card double reads.
- Correct skill activation boundaries and add the routing matrix tests.
- Add the broad-scope confirmation for `--working-tree`.

### Phase 3 — Consolidate documentation ownership

- Remove repeated command syntax and test-tier prose from secondary documents;
  replace it with links to the owning source.
- Clarify persistence-test wording and correct stale operational claims.
- Add required/optional/lookup read labels and context-size reporting.

### Phase 4 — Isolate transient artifacts and ratchet budgets

- Make test diagnostics, raw logs, result bundles, timing history, performance
  captures, and balance reports current-run-only by default; add an explicit
  keep/retention mode, cleanup after final classification, and an interrupted-
  run backstop.
- Move or scope balance reports, and document search fences and the distinction
  between ephemeral reports and warm build caches.
- Add a lightweight periodic report of context-card count, diagnostics byte size,
  stale-manifest count, and transient-artifact size. Emit it as a current-run
  or CI summary rather than an accumulating history file. Ratchet only after a
  green correctness baseline.

## Guardrails and non-goals

- Do not weaken `handoff.sh`, package tests, smoke tests, generated-output checks,
  module boundaries, or failure detection to make output shorter.
- Do not delete authored/generated source or warm build caches as part of report
  cleanup. Ephemeral report cleanup is intentional, must happen only after the
  current run is classified, and must have an explicit keep/retention escape
  hatch for investigations.
- Do not collapse distinct package ownership or remove persistence reload tests.
- Keep raw forensic artifacts available behind an explicit path/flag when needed;
  optimize the default narrative shown to agents and do not retain history by
  accident.
- Preserve the existing structured-first diagnostics strategy, simulator
  isolation, and explicit path-scoping model.

## Verification for the eventual implementation

- `./Scripts/test-scripts.sh`
- Focused Python/shell regressions for routing, diagnostics aggregation, output
  budgets, retention/cleanup timing, active-process protection, and keep-mode
- `python3 ./Scripts/check-docs.py`
- `./Scripts/handoff.sh --isolate --paths <integrated authored paths>`
- Re-run the representative routing/output inventory and record before/after
  proxies plus unchanged correctness signals in the handoff.
