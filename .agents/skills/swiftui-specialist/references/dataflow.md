# Data flow

Keep one owner for each piece of mutable state. SwiftUI observation and view
boundaries help control updates; they do not justify duplicating Trinket's save,
session, or presentation owners. These are local adaptations of the Apple
reference snapshot, not requirements to introduce a model for every view.

## Passing data into views

Pass the data and actions the view uses, including values it forwards to children.
A narrow value input can avoid unrelated updates from a large changing snapshot.
An existing `@Observable` reference is useful when a view needs live properties:
Observation tracks property reads made while evaluating its body.

Do not assume every update performs a deep comparison of every nested field.
SwiftUI's comparison details are implementation-dependent, and environment,
state, and observation can also invalidate a view. Preserve value semantics and
existing ownership unless the actual update path warrants a different boundary.

## View-local state with @State

Make view-owned `@State` private. Children edit it through a binding or an action,
not by reaching into the view's storage. Inspect consumers before tightening
existing access. A bounded internal fix does not require separate permission;
public compatibility follows the root guide.

State belongs to view identity, not each newly constructed view value. For SDK 27
initializer issues, use the [State migration reference](../../swiftui-whats-new-27/references/state-macro.md).

## Model objects with @Observable

Use `@Observable` for observable models under Trinket's API policy. Keep UI-owned
models main-actor isolated, explicitly or through the target's default isolation.
Observation does not provide synchronization. Preserve deliberate non-UI owners
and their concurrency contracts rather than annotating every model indiscriminately.

### Equatable properties

Current Observation macros can suppress notifications for equal assignments when
the property supports equality. Use meaningful `Equatable` semantics where they
fit. Do not add expensive deep equality or ignore relevant fields solely to reduce
notifications; inspect the macro expansion and measured update cost if needed.

### Per-property dependency granularity on @Observable models

Reading `model.player.name` depends on the stored `player` property when `player`
is a struct. Reading `model.items[index]` likewise depends on the collection.
Computed properties track their underlying reads; a new accessor name does not
create narrower observation.

For rows, pass the item or the fields needed rather than making every row look
itself up in the whole collection. Persisted observable element models can help
when elements already have independent ownership. Do not construct new models
on each read or convert all value models to classes merely for this pattern.

### Derived values and caching

Keep cheap derived values computed by default. Cache when a costly calculation
or broad dependency creates a demonstrated problem. The cache needs a clear owner
and updates for all inputs; test the consequential stale-state failure if existing
coverage does not protect it.

For example, a selected item computed from `items` and `selectedID` observes both.
That can be entirely appropriate. A stored selected-item projection may reduce
updates, but introduces synchronization work. Prefer an existing read lane before
adding another model, and never duplicate authoritative save state for convenience.

A view reading several individual properties is not automatically oversubscribed.
Extract a smaller view or model only when it expresses a useful boundary.

## Side effects in views

### Isolating onChange(of:) side-effect invalidation

The expression passed to `onChange(of:)` is read during body evaluation. If it
changes frequently and only drives a side effect, a small separate observer view
may spare expensive parent work. It provides no benefit when the parent also
needs the value to render, or is already trivial.

Keep effect lifetime with its existing owner. A view callback must not become the
authority for persistence, battle completion, or a process-wide service. Follow
Trinket's routed lifecycle contracts before moving callbacks.

## Bindings

Prefer projected/key-path bindings for direct editing of owned state. For an
existing computed projection, a writable property or subscript can preserve a
natural binding path. Use a closure binding when adapting an API genuinely needs
it; do not invent a subscript solely to disguise a closure.

A binding is not a transaction boundary. Trinket save changes use explicit domain
commands, and success/navigation follow their committed result. Preserve any
validation, conversion, and animation transaction behavior when replacing a binding.

## @Entry macro

Prefer `@Entry` for straightforward custom environment values. Keep stable defaults
and use the [environment reference](environment.md#unstable-environment-default-values)
for ownership and fallback choices. A manual key with a stored default remains
valid when it makes lifetime or isolation clearer; it is not a top-priority review
finding merely because the macro exists.

Primary reference: [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app).
