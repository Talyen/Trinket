import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Localizes canonical content labels in the rendering environment, preserving their data identities.
public struct GameLabel: View {
    @Environment(\.locale) private var locale
    private let english: String
    private let resource: LocalizedStringResource?
    private let balanced: Bool

    public init(_ english: String, balanced: Bool = false) {
        self.english = english
        resource = nil
        self.balanced = balanced
    }

    public init(_ english: String, resource: LocalizedStringResource?, balanced: Bool = false) {
        self.english = english
        self.resource = resource
        self.balanced = balanced
    }

    public init(_ resource: LocalizedStringResource, balanced: Bool = false) {
        english = ""
        self.resource = resource
        self.balanced = balanced
    }

    public var body: some View {
        let text = resource.map(localized) ?? ContentCopy.localized(english, locale: locale)
        Text(verbatim: balanced ? text.trinketBalanced() : text)
    }

    private func localized(_ value: LocalizedStringResource) -> String {
        LocalizedGameText(value, locale: locale).text
    }
}

public extension View {
    func gameAccessibilityLabel(_ canonicalEnglish: String) -> some View {
        modifier(GameAccessibilityLabel(source: canonicalEnglish))
    }
}

private struct GameAccessibilityLabel: ViewModifier {
    @Environment(\.locale) private var locale
    let source: String

    func body(content: Content) -> some View {
        content.accessibilityLabel(Text(verbatim: ContentCopy.localized(source, locale: locale)))
    }
}
