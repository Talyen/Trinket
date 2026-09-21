# ForEach

Rows need identities that are unique within the collection and stable for the
lifetime of the represented element. Identity controls state, selection, and
insert/remove/move behavior. The same principle applies to data-driven `List`,
`Table`, and outline content.

## Avoid collection indices as identity

For mutable collections, identify the element rather than its current position:

```swift
ForEach(items) { item in
    ItemRow(item: item)
}

ForEach(items.enumerated(), id: \.element.id) { index, item in
    ItemRow(number: index + 1, item: item)
}
```

Indices can be appropriate when the position itself is the identity, such as
fixed board slots. `id: \.self` is appropriate for unique, stable values; it is
not a general solution for duplicate or editable content. An insertion using
positional IDs can attach existing row state to the wrong item, not merely reset it.

## Don't create a new id on every body evaluation

Do not generate UUIDs while mapping the collection in `body`. Create identity
with the underlying item and retain it across updates. A stored `let id = UUID()`
is fine when that item outlives the view evaluation; reconstructing the item on
every read defeats it.

## Prefer `Identifiable` conformance

Use `Identifiable` when the type has a natural identity; an explicit `id:` key
path is equally valid for a context-specific identity. Do not add a wrapper or
change a domain model merely to omit the key path at one call site.

## Keep the id cheap to hash

Prefer a small stable key over hashing an entire payload. Changing an ID to
force an update also replaces view state; reserve that for intentional replacement.

## Identity must outlive the view that renders the `ForEach`

Keep identity with the data owner, not a temporary display projection. A title,
array offset, or mutable URL is unsuitable when it can change while the item
remains the same item. Reopening or reordering a view must not invent new domain
identity. Preserve serialized Trinket IDs under the root save-compatibility rules.

## Sorting and filtering

A transformation in `body` runs when that body is evaluated. Small, cheap filters
are often the simplest correct solution. For a large or frequently updated
collection, measure repeated work before introducing cached state.

When caching is justified, keep the derived collection with its existing owner
and update it for every relevant input: content, query, sort choice, and locale
where applicable. A computed property improves naming but does not cache work.
A cache maintained by several `onChange` callbacks can introduce stale results;
its correctness and maintenance cost belong in the decision.

## Prefer unary row views in `List`

A predictable number of rows per element lets lazy containers discover row
identity without building all content. If an element should be omitted, filter
it out before `ForEach`. If one row has optional internal content, a suitable
single-root container can make that row's structure explicit. Do not wrap a
filtered-out element in an empty stack and accidentally leave an empty row.

Avoid unnecessary `AnyView` erasure in large lists. Prefer concrete rows and
normal builder branches. A simple conditional modifier is appropriate when only
styling changes; do not add a stack solely to avoid that simpler expression.
Do not infer a measurable slow path from every `if` or `switch`: inspect row
cardinality and the selected SDK's behavior.

When supported by the selected runtime, `-LogForEachSlowPath YES` can identify
non-constant row builders. Treat its output as a diagnostic lead and verify the
affected list. [Apple's performance session](https://developer.apple.com/videos/play/wwdc2023/10160/)
explains identity and row-count costs.
