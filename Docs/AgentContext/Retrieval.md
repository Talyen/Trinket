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
text.

For mixed modes, repeat `--request` with a quoted target and its own flags:

```sh
python3 Scripts/agent-read.py --request 'Docs/AgentContext/audio.md' --request 'Scripts/agent-read.py --symbol main' --request 'Scripts/tool-versions.env --lines 1:3'
```

Requests are parsed as arguments without shell execution. Each request supplies its own read flags. Duplicate requests read once;
failed requests remain nonzero while later reads continue. Read errors print an
executable recovery command or filename discovery command; navigation does not
establish a complete read.

`--full` explicitly reads any supported UTF-8 text file, including Swift, Python,
shell and config files. In a mixed batch, an anchored Markdown target reads only
that complete section; the flag never widens an anchor to the whole document.
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

Start indexed concerns with `python3 Scripts/agent-brief.py --task <concern>`.
Use `--paths <files...>` for an unindexed task or to supply its actual scope.
The concern index supplies navigation hints; explicit files always determine
all applicable safeguards, ownership guidance, and verification requirements.
`--status` prints scoped changes and global owner counts. Whole-tree work requires
`--working-tree`; use `--allow-broad-scope` only when intentionally reviewing a
large working tree. The shell `agent-context.sh` entry point uses this same briefing.

Read root/local safeguards and relevant ownership and behavior sections. Skills
remain conditional on their descriptions. Reuse unchanged guidance still present
in conversation context; reread relevant contracts after context loss. Briefings
are stateless and never hide safeguards based on prior reads.

### Concern and test pointers

Find concerns with `agent-search.py '<concern>' --task`, or list them with
`agent-search.py --task --overview`. Unknown or ambiguous concern names fail with
available choices; use file-scoped discovery for unindexed work. The index is
navigation, not proof that tests cover the behavior.

For a concern, the briefing prints a runnable `agent-read.py --request ...` batch
for initial ownership guidance. `agent-context.sh --task <concern> --read-command`
prints just that command. Read source bodies and actual assertions independently;
source signatures and file pointers are navigation only. Explicit scopes continue
to control caller and test searches.

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
overlapping work. Symbolic links use their link payload, never the target's bytes.
Untracked files are listed for explicit reads. Whole-tree
review requires `--working-tree`. This view does not replace overlapping diff
inspection, generated consistency review, or idempotence verification.
