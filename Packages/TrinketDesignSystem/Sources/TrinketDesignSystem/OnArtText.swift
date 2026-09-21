import SwiftUI

public enum OnArtTextEmphasis: Sendable {
    case title
    case eyebrow
}

public extension View {
    func trinketOnArtText(_ emphasis: OnArtTextEmphasis = .title) -> some View {
        modifier(OnArtTextModifier(emphasis: emphasis))
    }
}

private struct OnArtTextModifier: ViewModifier {
    let emphasis: OnArtTextEmphasis

    func body(content: Content) -> some View {
        let ink = TrinketDesign.Colors.Overlay.ink
        let width: CGFloat = emphasis == .title ? 1 : 0.75
        // Zero-blur shadows accumulate into a continuous ink edge, including
        // diagonals, without duplicating text or replacing colored/shine fills.
        content
            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            .shadow(color: ink, radius: 0, x: width)
            .shadow(color: ink, radius: 0, x: -width)
            .shadow(color: ink, radius: 0, y: width)
            .shadow(color: ink, radius: 0, y: -width)
    }
}
