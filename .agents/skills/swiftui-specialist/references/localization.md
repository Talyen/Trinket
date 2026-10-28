# Trinket localization ownership

Read [Localization](../../../../Docs/Platform/Localization.md#agent-workflow)
for authored inputs, generated accessors, translation and independent review.
Trinket manually owns its source catalogs; compiler extraction is a read-only
coverage check. Edit canonical English catalogs or content, then run the repository
workflow. Do not rely on a build to author keys or edit generated `L10n` and
`ContentCopy` Swift. Preserve serialized identifiers and existing catalog keys.

Use existing typed resources and the owning presentation APIs at Trinket call
sites. The framework examples below explain lookup and formatting; they do not
replace that pipeline or require converting already-localized `String` values.
Resolve nested content names and sentence resources in the same rendering locale
under the owner's resource-argument rules.

# Bundle for Swift Packages and Frameworks

A lookup must target the bundle that actually owns its catalog. Preserve bundle
context carried by generated accessors and `LocalizedStringResource`. For a raw
lookup into package-owned resources, pass the package's resource bundle explicitly;
omitting it normally searches the main bundle. A package deliberately consuming
app-owned strings is a different case, so package location alone does not establish
a lookup bug.

Use the repository's existing bundle access pattern. Before adopting `#bundle`,
check the selected toolchain's support; do not replace working `Bundle.module`
accessors solely because a framework example uses a newer spelling.

# SwiftUI Views Localize String Literals Automatically

SwiftUI initializers that accept `LocalizedStringKey` (e.g., `Text`, `Button`, `.navigationTitle`) automatically treat string literals as localization keys. Do not wrap literals in `NSLocalizedString`, `String(localized:)`, or `LocalizedStringResource`.

```swift
// AVOID: Text already treats literals as LocalizedStringKey; wrapping
// also resolves the string eagerly, ignoring \.locale overrides.
Text(NSLocalizedString("start_workout", comment: ""))
Text(String(localized: "start_workout"))
```

```swift
// PREFER: Pass the string literal directly.
Text("start_workout")
```

Both opaque keys (`"start_workout"`) and natural-language strings (`"Start Workout"`) work as `LocalizedStringKey` values. Choose whichever convention the project uses consistently — with opaque keys, the source-language text is set in the String Catalog directly, not at the call site.

Use `Text(verbatim:)` to opt out of localization for a string literal — most often a debug label that interpolates a runtime value (e.g., `Text(verbatim: "Session: \(sessionID)")`), where the literal would otherwise be treated as a localization key. When the argument is already a `String` variable, `Text(value)` calls the `StringProtocol` overload and skips localization on its own — no `verbatim:` needed.

# Localizing Variables and Custom Types

When a `String` variable is passed to `Text`, the `StringProtocol` overload displays
it verbatim. `Text(LocalizedStringKey(value))` instead looks up that runtime key
in the selected table and bundle, as described by
[Apple's LocalizedStringKey reference](https://developer.apple.com/documentation/swiftui/localizedstringkey).
Runtime lookup and automatic extraction are separate: Xcode cannot extract a key
from a runtime value, so its catalog entry must already exist or be maintained
explicitly. For a known set of statically authored translatable values, prefer
a type that exposes literal `LocalizedStringResource` values:

```swift
enum Category {
    case appetizers, mains, desserts
    var name: LocalizedStringResource {
        switch self {
        case .appetizers: "Appetizers"
        case .mains: "Mains"
        case .desserts: "Desserts"
        }
    }
}

Text(category.name)
```

For statically authored translatable copy, use `LocalizedStringKey` or
`LocalizedStringResource` where the consuming API supports it; the latter also
carries table and bundle context. Keep user-provided or deliberately verbatim
text as `String`.

```swift
// AVOID: String properties lose localization context.
struct SectionHeader {
    let title: String
}
```

```swift
// PREFER: LocalizedStringResource keeps the string localizable.
struct SectionHeader {
    let title: LocalizedStringResource
}
```

# String Interpolation vs Concatenation

String interpolation preserves `LocalizedStringKey` and produces a format string in the catalog (e.g., `"Welcome, %@"`). Concatenation with `+` produces a `String` — the result is not localized.

```swift
// AVOID: + produces String, not LocalizedStringKey. Not localized.
Text("Error: " + statusMessage)
```

```swift
// PREFER: Interpolation preserves LocalizedStringKey.
Text("Error: \(statusMessage)")
```

Never glue separately localized fragments to form a sentence — word order varies across languages.

```swift
// AVOID: Sentence assembly breaks in languages with different word order.
Text(String(localized: "Created by")) + Text(" ") + Text(authorName)
```

```swift
// PREFER: A single string lets translators rearrange the structure.
Text("Created by \(authorName)")
```

# Casing

Bake the desired case into the string itself rather than transforming case at runtime via `.textCase(_:)`, `.localizedUppercase`, or `.localizedCapitalized`. A runtime transform forces the same casing decision across all translations, leaving translators no way to adjust per language.

```swift
// AVOID: forces the same casing on every translation.
Text("Section Header").textCase(.uppercase)

// PREFER: provide the desired case in the string itself.
Text("SECTION HEADER")
```

This applies to localized strings. Strings the user typed in should display as-is; you don't know what casing they intended. If a transform is unavoidable, prefer `.localizedUppercase` / `.localizedCapitalized`, which honor the user's locale (Turkish dotted/dotless I, German ß, etc.).

# Formatting Dates, Numbers, and Currencies

Use `Text`'s `format` parameter or `.formatted()` instead of `DateFormatter` or `NumberFormatter` with hardcoded format strings. Format styles adapt to the user's locale; hardcoded format strings do not. These overloads localize through the format style — they're not a bypass of localization, and the value itself doesn't produce a catalog entry. When the value is interpolated into a localized literal (e.g., `"Total: \(price, format: ...)"`), the surrounding literal still accepts a `comment:` as usual.

```swift
// AVOID: Hardcoded format does not adapt to locale.
let formatter = DateFormatter()
formatter.dateFormat = "MM/dd/yyyy"
Text(formatter.string(from: workout.date))
```

```swift
// PREFER: Format styles adapt to the user's locale automatically.
Text(workout.date, format: .dateTime.month().day().year())
```

Date field components (`.month()`, `.day()`, `.year()`) enable which fields appear; the locale determines output order — the chain order doesn't lock layout.

```swift
// AVOID: Hardcoded currency formatting.
Text("$\(product.price, specifier: "%.2f")")
```

```swift
// PREFER
Text(product.price, format: .currency(code: store.currencyCode))
```

For lists of strings, `Array.formatted()` inserts locale-correct separators and conjunctions instead of a hardcoded `joined(separator: ", ")`.

```swift
// AVOID
Text("Order: \(items.joined(separator: ", "))")
```

```swift
// PREFER
Text("Order: \(items.formatted())")
```

When `DateFormatter` is genuinely unavoidable, use `setLocalizedDateFormatFromTemplate(_:)` rather than assigning `dateFormat` directly — the template reorders fields per locale.

# Layout for Localization

Use semantic `.leading` and `.trailing` alignment for reading-direction layout.
Preserve deliberately spatial game relationships rather than mirroring them blindly.

```swift
// PREFER: .leading flips to the trailing edge in RTL locales.
Text(recipe.title)
    .frame(maxWidth: .infinity, alignment: .leading)
```

Do not hardcode frame widths or heights for text — translations vary in length and scripts vary in height. Use `ViewThatFits` when a layout might not fit longer translations.

```swift
// PREFER: ViewThatFits picks the first layout that fits.
ViewThatFits {
    HStack { actionButtons }
    VStack { actionButtons }
}
```

Use Trinket's existing [typography roles](../../apple-design/typography.md).
Check translated text for clipping and fit before changing shared metrics; do not
replace the design system with ad hoc `.font(.body)` styling as a localization fix.

# Reading the Current Locale

Use `@Environment(\.locale)` instead of `Locale.current` for locale-dependent logic in views — the environment respects preview overrides and per-view injection; `Locale.current` does not.

# String(localized:) Outside SwiftUI Views

When you need a localized `String` outside of SwiftUI views, use `String(localized:)`, not `NSLocalizedString`.

```swift
// AVOID
let title = NSLocalizedString("activity_summary", comment: "Dashboard header")
```

```swift
// PREFER
let title = String(localized: "activity_summary", comment: "Dashboard header")
```

Do not interpolate inside `NSLocalizedString` — Xcode extracts keys from literal strings at build time and cannot extract interpolated values. Use `String(localized:)` with interpolation instead; Xcode extracts the format string (e.g., `"reminder_body %@"`) and treats interpolated values as runtime arguments.

Prefer `String(localized:)` over `String(format:)` and `String.localizedStringWithFormat`. `String(format:)` always renders digits as 0–9 regardless of locale and is unsuitable for user-facing text; `String.localizedStringWithFormat` works when paired with `NSLocalizedString`, but `String(localized:)` is the modern API and the right default.

# LocalizedStringResource for Non-View Types

Use `LocalizedStringResource` when a non-view type carries statically authored
translatable copy for later display, such as a tip or queued notification.
It retains localization context without eagerly resolving a `String`.
Runtime content and deliberately verbatim text can remain `String`; a runtime
catalog key uses the explicit lookup described above. Apply this when designing
new types or changing translatable copy, without sweeping through unrelated
`String` properties.

```swift
// AVOID: Resolving at creation time loses the ability to display
// in a different locale later.
struct Tip {
    let headline: String
}
let tip = Tip(headline: String(localized: "Tip of the Day"))
```

```swift
// PREFER: LocalizedStringResource defers resolution to display time.
struct Tip {
    let headline: LocalizedStringResource
}
let tip = Tip(headline: "Tip of the Day")
```

# Comments for Translators

Add a `comment` describing the UI element and its purpose, especially for ambiguous strings. For interpolated strings, describe each placeholder by position — translators don't see Swift variable names.

```swift
// AVOID: "Edit" could be a noun or a verb — different translations.
Text("Edit")
```

```swift
// PREFER
Text("Edit", comment: "Toolbar button that enters editing mode for the list.")
```

```swift
// PREFER: refer to placeholders by position, not by Swift name.
Text("Completed \(count) of \(total)",
     comment: "Progress label — the first variable is finished items, the second is the total.")
```

Comments can also live in the String Catalog (per-string Comment field), equivalent to passing `comment:` at the call site — keep one source of truth per string.
