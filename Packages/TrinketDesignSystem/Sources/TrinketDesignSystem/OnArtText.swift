import SwiftUI

public enum OnArtTextEmphasis: Sendable {
    case title
    case eyebrow
}

public extension View {
    func trinketOnArtText(_ emphasis: OnArtTextEmphasis = .title) -> some View {
        modifier(OnArtTextModifier(emphasis: emphasis))
    }

    func trinketOnArtTextBackdrop() -> some View {
        background {
            EllipticalGradient(
                stops: [
                    .init(color: TrinketDesign.Colors.Overlay.ink.opacity(0.24), location: 0),
                    .init(color: TrinketDesign.Colors.Overlay.ink.opacity(0.16), location: 0.45),
                    .init(color: TrinketDesign.Colors.Overlay.ink.opacity(0), location: 1),
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5,
            )
            .padding(-TrinketDesign.Spacing.large)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct OnArtTextModifier: ViewModifier {
    let emphasis: OnArtTextEmphasis

    func body(content: Content) -> some View {
        let paper = TrinketDesign.Colors.Overlay.paper
        let ink = TrinketDesign.Colors.Overlay.ink
        switch emphasis {
        case .title:
            content
                .foregroundStyle(paper)
                .shadow(color: ink.opacity(0.98), radius: 1.5, y: 1)
                .shadow(color: ink.opacity(0.55), radius: 7, y: 2)
        case .eyebrow:
            content
                .foregroundStyle(paper)
                .shadow(color: ink.opacity(0.85), radius: 1.5, y: 1)
                .shadow(color: ink.opacity(0.4), radius: 5, y: 2)
        }
    }
}
