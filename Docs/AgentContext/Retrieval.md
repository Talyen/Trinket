# Agent retrieval reference

Detailed command semantics. Start with the [quickstart](README.md);
root and local guides still own safeguards.

## Search and discovery

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
`--files --glob '*.swift'` for an explicit shell pattern instead of the default
regex. Glob `*` crosses directories; patterns without `/` also match basenames.
`--related <identifier>` interleaves declaration, reference, and test/support file
hints from authored source and tests within the supplied scopes. These are textual
mentions, including comments and strings, not semantic ownership or coverage proof.
Use
`--mode assets --files` to include raw/processed media and asset metadata without
reading binary contents. `--overview` pages owner counts and entry points from
the Git inventory; individual asset filenames are omitted. Scopes use exact repository spelling. Invalid scopes fail with a corrected command
when a close path is available, or an owner overview otherwise; they never silently
widen the surface. Scopes and fingerprinted pagination apply to both modes. Scoped `rg --files` remains available.
Documentation results put current guides and references first, procedures/knowledge
next, and task records last, alphabetically within each group. This ordering
applies before either file or excerpt limits; explicit scopes can still retrieve
plans, evals, and open friction records directly.
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
python3 Scripts/agent-search.py DamagePipeline --scope Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineOffenseSteps.swift --excerpts
sed -n '40,100p' Packages/BattleEngine/Sources/BattleEngine/Damage/DamagePipelineOffenseSteps.swift
```

## Complete reads and navigation

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

Pass multiple files or anchors to one reader invocation; the same flags apply to
each target, exact duplicates read once, and a failure remains nonzero while later
targets are still attempted. `--lines START:END` also supports shell and config
text. `--fingerprint` includes the SHA-256 of the exact file bytes read.

For mixed modes, repeat `--request` with a quoted target and its own flags:

```sh
python3 Scripts/agent-session.py read --request 'Docs/AgentContext/audio.md' --request 'Scripts/agent-read.py --symbol main' --request 'Scripts/tool-versions.env --lines 1:3'
```

Requests are parsed as arguments without shell execution. Only session/receipt and
fingerprint options can be shared outside requests. Duplicate requests read once;
failed requests remain nonzero while later reads continue. Read errors print an
executable recovery command or filename discovery command; navigation does not
establish a complete read.

`--full` explicitly reads any supported UTF-8 text file, including Swift, Python,
shell and config files. In a mixed batch, an anchored Markdown target reads only
that complete section; the flag never widens an anchor to the whole document.
Source/config full reads never establish guidance receipts.
Flags may appear between positional targets; per-target modes still use `--request`.

For Swift or Python, `agent-read.py path.swift --outline` lists qualified types and
members with complete lexical source ranges and the file path once. Swift uses the
pinned SwiftFormat tokenizer; this is not a semantic ownership map. Add
`--include-locals` for declarations inside functions. `--symbol Qualified.name`
reads an attached comment/attribute block and complete declaration; repeat `--symbol`
to read several declarations together. `--signatures` shows headers and attached
comments without bodies; filter outlines/signatures with `--kind methods|properties|types`
and `--match <name-substring>`. Overloaded or
ambiguous names return candidate ranges without choosing one. `--offset` /
`--limit` page the outline; `--lines START:END` reads an explicit complete range.

For a generated-content investigation, explicitly target the catalog and entry:

```sh
python3 Scripts/agent-search.py 'enum ArtCatalog' --mode generated --scope Packages/TrinketContent --excerpts
```

## Routing and guidance reuse

Focused contracts replace the corresponding detail in package READMEs. Known
paths suggest their concern; shared or unknown engine/persistence paths list all
operation references for discovery. Select the relevant sections and follow calls
across concerns. This reading choice does not narrow verification routing.
Use the package README as an index to optional API and behavior references.
Known Shop and Homestead leaves include relevant progression sections; shared or
unknown persistence paths retain the full progression contract.

The default router omits empty sections, repeated policy, and expanded check
commands. `--full` includes authored paths, route metadata, and the sequential
verification plan. Both forms retain ownership guidance, behavior references, and
safety warnings.

Use `--status` on the initial route to see global dirty counts and exact status
for task files, including either endpoint of a rename. Counts are informational;
inspect overlapping diffs and resolve unclear ownership before editing. Reroutes
can omit status when the relevant workspace state is unchanged.

Use router `--fingerprints` when guidance reuse needs a current identity. It lists
whole-file SHA-256 hashes without hiding any guides, cards, skills, or warnings.
Reuse a reference only when it was actually read in this chat and its hash still
matches; matching identity alone is not a read receipt. Any file edit invalidates
all its sections, conservatively covering changed surrounding rules and locations.
Skills and knowledge still apply only by trigger. Fingerprints are optional to
avoid adding identity output to tasks that do not need repeated routing.

### Chat-local read receipts

`python3 Scripts/agent-session.py read …` and `context …` derive the same temporary
receipt from `CODEX_THREAD_ID` and the repository root. Outside that environment,
pass `--chat <this-chat-id>` before `read` or `context`. The underlying commands
also accept `--session <chat-id>` directly. Session reads record only complete
Markdown content; source reads, ranges and outlines remain unrecorded. Explicit
`--receipt` reads retain the stricter complete-Markdown-only validation.

After compaction removes a contract, run `python3 Scripts/agent-session.py forget`
and reread it. Parallel readers must use distinct explicit chat/reader IDs to avoid
sharing a receipt. Sessions never suppress routing references. Reads repeat by
default; explicit `--reuse-guidance` on `brief` or `read` skips only unchanged
complete Markdown already delivered to this chat and still available in context.
A whole-file receipt covers sections, but section receipts cannot cover a whole
file. Source, ranges and navigation are still displayed. Changed files or new
sections are read. The flag asserts retained context; it cannot detect compaction.
Run `forget` after context loss before using it again.

Use a unique temporary receipt file and explicit chat ID when repeated routing
would otherwise cause rereads. Keep receipts outside the repository and do not
share one file across parallel readers or chats. For example, substitute the
current chat ID for `example-chat` in both commands:

```sh
python3 Scripts/agent-read.py 'Docs/AgentContext/battle-actions.md#shared-action-invariants' --receipt /tmp/trinket-example-chat.json --chat example-chat
./Scripts/agent-context.sh --receipt /tmp/trinket-example-chat.json --chat example-chat --paths Packages/BattleEngine/Sources/BattleEngine/ManaEmpowermentBudget.swift
```

Only successfully displayed complete Markdown documents/sections become reads.
Outlines, signatures, ranges, failed reads and automatically outlined large
documents do not. A whole-document read covers its sections; reading one section
does not cover another section or the whole document. Whole-file hashes invalidate
all sections after any edit. The receipt also binds to the repository path and
chat ID; mismatches fail explicitly. Receipts expire after 24 hours of inactivity;
missing or expired receipts require rereading guidance. Delete one when the chat
no longer needs it.

Rerouting annotates every applicable reference as unchanged/read or requiring an
applicable read, while retaining all references, skill triggers, boundary warnings
and verification commands. Reuse still requires that the content is available in
the current chat context; after compaction loses a contract, reread it even when
the receipt matches. A receipt records delivery, not model comprehension.

### Concern and test pointers

For an indexed concern, `python3 Scripts/agent-session.py brief --task particles`
combines scoped status, the complete safety route, initial applicable guidance,
source signatures and test pointers. `--paths <files...>` preserves the actual
task scope; `--limit N` bounds signatures per file (default 8) with explicit
continuations. Signatures are navigation, not body inspection; skills and other
behavior sections still apply by relevance. The command never compiles or operates
a simulator. Outside Codex, put `--chat <chat-id>` before `brief`.

Exact duplicate routed references appear once under concern focus, including their
ownership/behavior role where applicable. Broader whole-card references and
different anchors remain visible; verification routing does not narrow.

`agent-search.py '<concern>' --task` searches labels and aliases in
[the authored index](../../Scripts/config/agent-tasks.json), using case-insensitive
word matches. Scopes filter concerns by their source entry points; matching
concerns show the complete cross-owner interaction and a routing command.
Unindexed concerns fall back to normal discovery. Paths and contract anchors are
validated; stale pointers fail explicitly rather than silently disappearing.

The returned route uses `agent-context.sh --task <id>` to highlight those contract
sections alongside all path-routed safeguards and behavior references. Without
`--paths`, the indexed source paths establish the route; with explicit paths,
those paths still determine all ownership warnings and verification. A concern
focus is navigation, not proof that other behavior sections or callers are irrelevant.

Concern routing also prints a suggested batched guidance-read command. It includes
local safeguards, ownership cards and indexed contracts; root guidance is already
injected. Skills and other behavior references remain visible for trigger/relevance
selection. The compact `agent-session.py read --task <id>` command resolves the current route
at execution, including explicit `--paths` when supplied. It uses the current chat
identity; outside Codex add `--chat` before `read`. An explicit custom receipt
produces a full reader command preserving that receipt.
Unanchored guidance is explicitly read in full. The suggestion never executes reads
or skips them based on a receipt.

`--related` prints each file once, combining declaration/reference roles. For
indexed symbols, it supplements textual results with curated test-file pointers,
explicitly labeled without claiming symbol mentions or coverage. Related lookup
retains its source/test scopes; a source-only file scope does not pull in tests
outside that scope. Inspect assertions and dependencies before choosing coverage.

### Caller navigation

`python3 Scripts/agent-search.py apply --callers --scope Packages/TrinketPersistence`
returns invocation lines and enclosing Swift/Python declarations. Use `--mode tests`
to inspect test calls. Results use the same scope filters and fingerprinted pagination.
The index is computed on demand from matching authored files, so edits cannot leave
a persistent cache stale. Comments and literal strings are excluded. These are
lexical hints: no receiver/type resolution, indirect calls, or Swift interpolation,
trailing-closure-only or explicit-generic calls. An enclosing declaration range is
a jump target, not proof of which implementation executes. Swift uses the existing
pinned SwiftFormat tokenizer; unavailable tokenization fails explicitly.

For a bounded body investigation after routing, use:

```sh
python3 Scripts/agent-investigate.py --path Packages/TrinketPersistence/Sources/TrinketPersistence/Encounters/ShopPurchaseApplier.swift --symbol ShopPurchaseApplier.purchase --scope Packages/TrinketPersistence
```

This reads the selected declaration, enclosing type signatures, direct lexical
caller bodies and test bodies containing matching invocations. Add explicit
`--test 'path.py#Suite.test_name'` (or Swift declarations) to inspect assertions
without a direct invocation; add scopes for cross-owner callers. Indexed tests
remain pointers, not automatic evidence. Ambiguous declarations fail with candidates.
Generated output and unscoped calls are excluded. `--limit` bounds bodies per page;
`--max-lines` bounds displayed body lines. Oversized bodies are omitted completely
with explicit read commands, never truncated. Continuations preserve scope/tests
and reject any change to scoped inputs. Follow omitted bodies and relevant callers
before concluding coverage or ownership; no type resolution or indirect-call
analysis is performed.

### Efficiency measurement

Use `agent-efficiency.py probe --workflow concerns --suite extended --output <report.json>`
for bounded retrieval measurements across combat, Shop, persistence, tooling,
particles, feedback, Collection and simulator diagnostics. Reports measure output
characters and command counts, not tokens. Compare before/after reports from the
same immutable product inputs; a busy checkout may invalidate the comparison.

`--workflow briefings` measures a cold briefing followed by a repeated briefing
in an isolated probe chat. The candidate opts into explicit guidance reuse when
supported; older sessions repeat the full brief. Setup/cleanup clears only that
probe's receipt. This measures delivery savings when context is retained, not
reasoning, correctness or actual model token use. The extended suite includes
Voyage and Labyrinth progression to exercise their focused contracts.

For complete-task trials, run `agent-efficiency.py prepare --suite extended
--repetitions 3 --output <trials.json>`. Run matching trials with the same model,
reasoning and tools against identical starting inputs. Record final per-response
provider usage, transcript-derived retries/repeated reads/stops, and an independent
correctness/completion judgement. `collect <trials.json> --output <measured.json>`
validates the usage export; `compare <before.json> <after.json>` rejects mismatched
inputs/settings and fails incorrect or incomplete outcomes even when tokens fall.
Keep comparison reports under the gitignored `.DerivedData/AgentEvaluationResults/`
for automatic 24-hour expiry, or manage custom destinations explicitly. Without
provider usage exports, leave token
counts unmeasured; retrieval savings do not establish complete-task token savings.

## Diff review

For review, `python3 Scripts/agent-diff.py --paths <files...>` shows authored
unstaged patches and generated-file statistics using the generated-path registry.
Add `--summary` for record/field hints in generated talent, affix, and Homestead
catalogs. Unsupported formats and changes outside recognized records are disclosed;
these hints do not replace idempotence or full patch review where needed.
Use `--staged` for the index, `--stat` for statistics only, or `--generated` to
expand generated patches. Output defaults to a 12,000-character content budget,
paged at complete hunks/records with repeated file headers. Follow the printed
continuation command; its fingerprint rejects a changed diff. An oversized hunk
is disclosed with an explicit larger-budget command, never silently cut. `--full`
is an intentional unbounded read. Review every relevant page before editing
overlapping work. Untracked files are listed for explicit reads. Whole-tree
review requires `--working-tree`. This view does not replace overlapping diff
inspection, generated consistency review, or idempotence verification.
