import SwiftUI

public struct ArtworkBlendDestination: Equatable, Sendable {
    let color: Color
    private let id: String

    public static let canvas = Self(color: TrinketDesign.Colors.canvas, id: "canvas")
}

public enum ArtworkBlend: Equatable, Sendable {
    case none
    case bottom(into: ArtworkBlendDestination)
}

private struct ArtworkBlendModifier: ViewModifier {
    let blend: ArtworkBlend

    func body(content: Content) -> some View {
        switch blend {
        case .none:
            content
        case let .bottom(destination):
            content.overlay {
                BottomArtworkBlend(color: destination.color).allowsHitTesting(false)
            }
        }
    }
}

private struct BottomArtworkBlend: View {
    let color: Color
    private let clearInset: CGFloat = 0.22

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 1 - clearInset),
                .init(color: color, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom,
        )
    }
}

public extension View {
    func trinketArtworkBlend(_ blend: ArtworkBlend = .none) -> some View {
        modifier(ArtworkBlendModifier(blend: blend))
    }
}
