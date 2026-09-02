# Friction Log

Centralized intake for agent pain points, confusion, and struggle while working in this codebase. Keep entries short — one line in the table is enough. Use the expanded template only when extra context helps.

Add a row to `Open` when docs mislead, behavior surprises, or repeated friction appears. Move it to `Resolved` with a link to the fix when addressed.

## How to log

1. Add a row to `## Open` below.
2. For longer context, add a `### YYYY-MM-DD — short slug` subsection under `## Details` using the template at the bottom.
3. When resolved, move the row to `## Resolved` and include a commit, PR, or `knowledge/patterns/<name>.md` link.

## Open

| Date | Area | Symptom (expected vs actual) |
|------|------|------------------------------|
|      |      |                              |

## Resolved

| Date | Area | Resolution (commit / pattern link) |
|------|------|------------------------------------|
|      |      |                                    |

## Details

_Add expanded entries here when the table row is not enough. Keep the table as the index._

### Expanded entry template

Copy and fill when needed:

```
### YYYY-MM-DD — short slug

- **Context:** what you were trying to do
- **Expected:** what you expected to happen / where you expected to find it
- **Actual / confusion:** what happened or what was confusing
- **Impact:** how it slowed you down or affected the task
- **Suggestion (optional):** what would have helped
```
