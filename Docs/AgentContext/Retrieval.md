# Agent retrieval reference

Use scoped `rg`, ordinary file reads, and `git diff` for discovery and review.
Before editing, run `python3 Scripts/agent-brief.py --status --read --paths
<files...>`. The briefing supplies safeguards, ownership, and focused contract
sections together. Reuse unchanged guidance; load broader references and skills
only for the behavior being changed. Follow source bodies, callers, tests, and
configuration independently of navigation hints.

## Search and discovery

Start with the owning directory when known, or `rg --files` to locate it. Avoid
build products and raw logs unless investigating those artifacts. Scope hidden
searches to the relevant directory, such as `.agents/` or `.github/`.

The optional `agent-search.py` helper offers ranked files, documentation sections,
related tests, and caller hints. Use its `--help` when these capabilities would
help; its modes and pagination are not prerequisites for ordinary searches.

```sh
rg --files Packages/TrinketPersistence -g '*Shop*'
rg -n 'purchase' Packages/TrinketPersistence
python3 Scripts/agent-search.py 'simulator budget' --mode docs --sections --scope Docs/Platform
```

## Complete reads and navigation

Read enough surrounding text to understand the contract and exceptions. A
filename, signature, outline, or passing link check does not establish behavior.

For long references, the optional section reader accepts Markdown anchors and
Swift/Python declarations. It prints complete sections/bodies with source lines;
large unanchored Markdown defaults to a heading outline. Use `--full` when the
whole document is relevant, or ordinary reads for any supported text file.

```sh
python3 Scripts/agent-read.py 'Docs/Platform/Verification.md#local-simulator-budget'
python3 Scripts/agent-read.py Scripts/verify.py --symbol main
```

Specialized helpers disclose omitted content and print continuation or recovery
commands. Follow relevant omissions before drawing conclusions. Fingerprinted
continuations reject changed inputs; restart that helper's query when necessary.
Detailed options live in each command's `--help`.

## Routing and guidance reuse

`--base main` includes task commits since the shared ancestor plus staged,
unstaged, and untracked work, deletions, and both rename endpoints. Use the
user-specified base when different. `--paths` focuses individual files;
`--working-tree` intentionally selects dirty files only. Missing bases fail.
Rerun briefing when entering another owner. Briefings are stateless and do not
hide safeguards based on earlier reads.

### Concern and test pointers

Concern shortcuts such as `--task shop` are optional navigation. Discover them
with `python3 Scripts/agent-search.py --task --overview`; use file-scoped discovery
for unindexed work. The concern index is not proof of ownership or test coverage.

### Caller navigation

Ordinary scoped searches and source reads are sufficient. The optional helpers
can collect lexical invocation locations or caller/test bodies together:

```sh
python3 Scripts/agent-search.py purchase --callers --scope Packages/TrinketPersistence
python3 Scripts/agent-investigate.py --path Packages/TrinketPersistence/Sources/TrinketPersistence/Encounters/ShopPurchaseApplier.swift --symbol ShopPurchaseApplier.purchase --scope Packages/TrinketPersistence
```

These are textual/lexical hints, without receiver or type resolution, indirect
call analysis, or complete Swift call-syntax coverage. Inspect assertions and
follow cross-owner dependencies explicitly. Swift declaration/caller helpers
use the pinned SwiftFormat tokenizer and fail explicitly when it is unavailable.

## Diff review

Use `git diff`, `git diff --cached`, and explicit untracked-file reads. Inspect
every overlapping dirty diff before editing; preserve unrelated work.
`agent-diff.py` optionally separates authored patches from generated statistics
and supplies record summaries for supported catalogs. Its bounded output prints
continuations; `--full` is an explicit unbounded read. Those summaries do not
replace full review where needed or generated consistency checks.
