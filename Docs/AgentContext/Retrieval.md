# Agent retrieval reference

Use scoped `rg`, ordinary file reads, and `git diff` for discovery and review.
Before editing, run `python3 Scripts/agent-brief.py --status --read --paths
<files...>`. The briefing supplies safeguards, ownership, and focused contract
sections together. Reuse unchanged guidance; load broader references and skills
only for the behavior being changed. Follow source bodies, callers, tests, and
configuration independently of navigation hints.

## Search and discovery

Use `rg --files` to locate the owner, then scoped `rg` and ordinary file reads.
Avoid generated output and raw logs unless those artifacts are the subject.
Start hidden searches in the relevant directory, such as `.agents/` or `.github/`.

## Complete reads and navigation

Read the implementation and its relevant callers/assertions. Outlines, names and
navigation hints do not establish behavior. `agent-read.py <file>#<anchor>` can
print complete Markdown sections; it also powers the briefing. Its source
navigation and the other optional helpers remain compatible, with flags in
`--help`; they are not prerequisites for ordinary reads.

## Routing and guidance reuse

`--base main` includes task commits since the shared ancestor plus staged,
unstaged and untracked files, deletions and both rename endpoints. Use an explicit
user-specified base when different. `--working-tree` selects dirty files only.
Briefings are stateless; reuse unchanged guidance already read. The router uses
owner directories and focused exceptions; follow dependencies independently.

### Concern and test pointers

Optional `--task <concern>` navigation supplies entry points and test pointers.
Inspect the assertions; an indexed file is not proof of coverage.

### Caller navigation

Scoped `rg` is sufficient. `agent-search.py`, `agent-investigate.py` and the source
modes of `agent-read.py` offer lexical hints without type resolution, indirect-call
analysis or complete Swift syntax coverage. Use them only when their specific
output helps. Follow relevant omitted bodies; restart fingerprinted queries when
inputs change. No task requires learning these modes or using them in sequence.

## Diff review

Use `git diff`, `git diff --cached`, and explicit untracked-file reads. Review
every overlapping dirty diff before editing. `agent-diff.py` remains an optional
paged/generated-summary view; summaries do not replace applicable full review.
