import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Localizes canonical content labels in the rendering environment, preserving their data identities.
public struct GameLabel: View {
    @Environment(\.locale) private var locale
    private let english: String
    private let balanced: Bool

    public init(_ english: String, balanced: Bool = false) {
        self.english = english
        self.balanced = balanced
    }

    public var body: some View {
        let text = ContentCopy.localized(english, locale: locale)
        Text(verbatim: balanced ? text.trinketBalanced() : text)
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
