# Environment performance

Use environment values for dependencies shared by a subtree. Keep frequently
changing state close to its readers, and preserve Trinket's existing owner
boundaries. Comparison and propagation details can change across SwiftUI releases;
measure the affected update path before declaring a performance defect.

## Closures in the Environment

Custom closure-valued keys can cause repeated updates because closure comparison
is not a reliable equality contract. Inspect the writer, captures, readers, and
update frequency. Wrapping the same closure in a struct or a freshly constructed
view property does not establish stable identity.

If this creates a problem, an action value with explicit data and a method, or
an existing stable observable owner, may express the operation more clearly.
Keep dependencies pointing in the permitted direction. Do not introduce a protocol
hierarchy, new service, or duplicated model solely to eliminate a small callback.
Closure presence alone is not evidence of an expensive update or wrong behavior.

Framework actions such as `DismissAction`, `OpenURLAction`, and `RefreshAction`
are intended to be used through their native environment keys. Preserve those
APIs rather than replacing them with custom handlers.

## Rapidly Updating Environment Values

Avoid broadcasting raw per-frame scroll, drag, or animation values through a
broad subtree when only a small part needs them. First consider a local input or
a native visual-effect modifier. When shared state is needed, use the existing
observable owner and expose the level of detail consumers actually need.

A threshold such as `isVisible` may change much less often than a raw offset.
Moving the offset into an observable model does not help if every row still reads
that same offset. Conversely, separate per-row models are unnecessary when a
small shared collection is already cheap. Measure before adding that machinery.

## Unstable Environment Default Values

Inspect the selected SDK's macro expansion when default lifetime matters.
A computed default that evaluates `Model()`, `Date()`, `UUID()`, or random data can
produce a different value on each fallback read. A deterministic value or a
reference to an existing stable instance does not have that problem.

Trace whether any reader actually falls back to the default. Missing dependency
injection can be a correctness issue; an unused fallback is not evidence of
current runtime cost. Choose a remedy that preserves ownership:

- Use a fixed value for a genuine value default.
- Use an optional `nil` default when absence is meaningful, and handle it explicitly.
- Inject a stateful owner from the composition root and retain its intended lifetime.
- Use a stored default, through `@Entry` or a manual key, only when sharing that
  instance is intentional and concurrency-safe. Do not turn a per-session object
  into a global singleton to stabilize its address.

For example, a genuinely optional dependency can use:

```swift
extension EnvironmentValues {
    @Entry var selectedItemID: String? = nil
}
```

Artificial equality that ignores meaningful state does not fix repeated allocation
or incorrect lifetime. Already-stable defaults need no memoization wrapper.
A sentinel check may suggest an optional, but confirm that the sentinel really
means absence before changing the model contract.

## Unused @Environment Reads

Remove unused declarations after checking body helpers, actions, and projected
uses. Key-path environment properties can participate in view updates even when
the value is not visibly rendered. Type-based observable dependencies additionally
track the properties actually read. Cleanup can improve clarity without a claim
of measured speedup.

References: [EnvironmentValues](https://developer.apple.com/documentation/swiftui/environmentvalues)
and [data flow](dataflow.md). Performance evidence follows Trinket's
[verification policy](../../../../Docs/Platform/Verification.md#choosing-ui-verification).
