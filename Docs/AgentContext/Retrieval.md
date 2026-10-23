# Agent retrieval reference

Use `rg`, file reads and Git diffs. Before editing, run the scoped briefing from
[the root workflow](../../AGENTS.md#route-and-read). No other retrieval helper is required.

## Search and discovery

Start with `rg --files` and scoped `rg`. Avoid generated output and raw logs unless
those artifacts are the subject; search `.agents/` and `.github/` explicitly when needed.

## Complete reads and navigation

Read the implementation, relevant callers and assertions. Briefings supply
safeguards and ownership; linked behavior contracts apply to the changed concern.
`agent-read.py` renders Markdown sections and powers the briefing.

## Routing and guidance reuse

Reuse unchanged guidance. `--base main` includes task commits and dirty files;
`--paths` selects files and `--working-tree` selects dirty files only. Renames and
deletions retain both endpoints. Owner routing is not semantic dependency analysis.

### Concern and test pointers

`--task <concern>` is an optional navigation shortcut, not evidence of test coverage.

### Caller navigation

Legacy `agent-search.py`, `agent-investigate.py` and source modes of `agent-read.py`
remain compatible. Their own `--help` describes pagination/fingerprints and lexical
hints; they do not resolve Swift types or establish complete call graphs.

## Diff review

Use `git diff`, `git diff --cached` and explicit untracked-file reads. Review
applicable full dirty diffs before editing. `agent-diff.py` is an optional paged
view; summaries do not replace source review.
