# View structure

Choose boundaries for a coherent job, state lifetime, or meaningful update cost.
A separate `View` gives SwiftUI a body-evaluation boundary; a computed property
or `@ViewBuilder` helper organizes the parent's expression without creating one.
Neither form is a defect by itself.

## Extract a view when the boundary helps

Use a separate view for substantial sections, reused components, independently
owned transient state, or content that should observe different inputs. Keep
small, readable fragments local when extraction would mostly add forwarding.
A named section does not automatically require a new type or file.

Give extracted views the values and actions they use. For example, a header that
only displays a name can accept `name` rather than the entire changing player
snapshot. An existing observable owner can be appropriate when the view needs
its live properties. See [data flow](dataflow.md#passing-data-into-views).

Extraction lets SwiftUI avoid some unrelated body work; it does not guarantee
that the child's body runs only when its explicit inputs change. Environment,
local state, and observed properties also create dependencies. Establish the
actual update path before claiming a performance improvement.

## Keep view `init` cheap

SwiftUI can construct view values repeatedly. Initializers are not one-time
lifecycle hooks: avoid file access, image decoding, expensive formatting, and
large derived collections there. Pass prepared values from the existing owner;
use native formatting for displayed dates and numbers.

Use view-owned state or lifecycle work only when that is the right owner. Moving
work into `.task` does not by itself make it execute once, and adding an observable
model solely to cache a cheap expression can cost more than recomputation. Preserve
Trinket's [prepared artwork contract](../../../../Docs/AgentContext/ui-performance.md).

## Single Child `Group`

Remove a `Group` around one concrete child when it serves no purpose. Keep it
when it applies modifiers to sibling views or a conditional expression without
introducing a layout container. For example:

```swift
Group {
    if let message {
        Text(message)
    } else {
        ProgressView()
    }
}
.padding()
```

This is a readability choice unless compiler or runtime evidence shows a cost.
Do not report a redundant wrapper as a measured performance defect.

Background: [Demystify SwiftUI performance](https://developer.apple.com/videos/play/wwdc2023/10160/).
