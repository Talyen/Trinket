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
For a documentation content search, add `--mode docs --sections` to group matches
by their nearest real heading and return `path#anchor` plus complete section ranges.
Read those targets with `agent-read.py`; text before the first heading or in an
unheaded file gets an explicit `--lines` range. These are navigation pointers,
not section reads. Duplicate headings use the reader's numbered anchors; fenced
examples do not become headings. Scope, ordering and pagination still apply.
Search continuation commands use `--offset` and a result fingerprint (`--expect`);
changed results require restarting instead of silently skipping or repeating matches.
Bounds always report omitted
files/lines and shortened excerpts; no matches means no
matches within the displayed surface, not within the whole repository.
`--excerpts` prints each filename once per page followed by numbered lines;
continuations repeat the filename even when a page starts inside the same file.

The router prints source/test roots. Example discovery and reads:

```sh
python3 Scripts/agent-search.py '(^|/)DamagePipeline\.swift$' --files --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --scope Packages/BattleEngine
python3 Scripts/agent-search.py DamagePipeline --mode tests --scope Packages/BattleEngine
python3 Scripts/agent-search.py 'simulator budget' --mode docs --sections --scope Docs/Platform
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
Markdown outlines print the filename once per page, followed by `#anchor`, ranges
and heading titles. Add `--outline --match <text>` to filter heading titles/anchors;
continuations preserve the filter. Filtering is navigation, not a section read.
Missing anchors fail explicitly with bounded valid-heading choices, prioritizing
shared words with the requested anchor to avoid an extra outline call.
Sections are never silently truncated. Known Battle presentation leaves route directly
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
Overlapping sections, declarations and ranges reuse text already printed in the
same batch, with an explicit reuse count. Only complete text reads count;
outlines/signatures do not. Reuse never persists across invocations or file changes.

`--full` explicitly reads any supported UTF-8 text file, including Swift, Python,
shell and config files. In a mixed batch, an anchored Markdown target reads only
that complete section; the flag never widens an anchor to the whole document.
Flags may appear between positional targets; per-target modes still use `--request`.

For Swift or Python, `agent-read.py path.swift --outline` lists qualified types and
members with complete lexical source ranges and the file path once. Members appear
under a qualified owner header (`Owner:` followed by `method` means `Owner.method`);
each page repeats the owner when needed, including filtered outlines and signatures. Swift uses the
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

Ordinary scoped `rg`, file reads and `git diff` are supported defaults. Before
editing intended files, use `python3 Scripts/agent-brief.py --status --read --paths
<files...>` for safeguards and initial ownership guidance. Specialized retrieval
commands below are optional; there is no required search/read/investigate sequence.

Use `--base main` to include task commits since the shared ancestor of `main` and
`HEAD`, plus staged, unstaged and untracked files. The comparison includes deletions
and both rename endpoints, fails on an unavailable base, and does not fetch.
A user-specified task base replaces `main`. Explicit `--paths` selects focused files;
`--working-tree` selects only dirty files and retains its broad-scope guard.
The shell `agent-context.sh` entry point uses the same briefing.

Read root/local safeguards and relevant ownership and behavior sections; skills
remain conditional. Reuse unchanged guidance in context and reroute across owners.
Briefings are stateless and never hide safeguards based on prior reads.

### Concern and test pointers

Find concerns with `agent-search.py '<concern>' --task`, or list them with
`agent-search.py --task --overview`. Each result prints a label, ID and runnable
briefing; the briefing owns source/test pointers and contracts, avoiding duplicate
path lists during discovery. Unknown or ambiguous briefing concern names fail;
unmatched names include up to five suggestions ranked by shared words when available.
Suggestions never select a scope. Use file-scoped discovery for unindexed work.
The index is navigation, not proof that tests cover the behavior.
An exact concern ID takes precedence over partial name/alias matches in briefings.

For a concern, the briefing prints a runnable batch for initial guidance.
Ownership sections replace whole-card reads where available. Add `--read` to read that guidance in the briefing
itself, saving a separate tool call. It includes nested safeguards, ownership sections
and indexed contracts; root `AGENTS.md` is already injected. Other behavior
references and skills remain conditional. Use this when guidance is absent from
context; omit it when reusing unchanged guidance. Both `--read` and `--read-command`
also accept explicit `--paths` without a concern. `--read-command` prints only the
command, or nothing when there is no additional initial guidance.
Read source bodies and actual assertions independently;
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
`--max-lines` bounds newly displayed body lines. Overlapping bodies reuse complete
text already printed on the current page; continuation pages read independently.
Oversized bodies are omitted completely
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
paged at complete hunks/records. File headers print once per file on each page,
including when a continuation starts inside that file. Follow the printed
continuation command; its fingerprint rejects a changed diff. An oversized hunk
is disclosed with an explicit larger-budget command, never silently cut. `--full`
is an intentional unbounded read. Review every relevant page before editing
overlapping work. Symbolic links use their link payload, never the target's bytes.
Untracked files are listed for explicit reads. Whole-tree
review requires `--working-tree`. This view does not replace overlapping diff
inspection, generated consistency review, or idempotence verification.
