import SwiftUI

public enum ArtworkBlendDestination: Equatable, Sendable {
    case canvas

    var color: Color {
        switch self {
        case .canvas: TrinketDesign.Colors.canvas
        }
    }
}

public enum ArtworkBlend: Equatable, Sendable {
    case none
    case bottom(into: ArtworkBlendDestination)
}

private enum ArtworkBlendRecipe: Sendable {
    static let clearInset = 0.22
}

private struct ArtworkBlendModifier: ViewModifier {
    let blend: ArtworkBlend

    func body(content: Content) -> some View {
        switch blend {
        case .none:
            content
        case let .bottom(destination):
            content.overlay {
                BottomArtworkBlend(destination: destination)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct BottomArtworkBlend: View {
    let destination: ArtworkBlendDestination

    var body: some View {
        let color = destination.color
        let recipe = ArtworkBlendRecipe.self

        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 1 - recipe.clearInset),
                .init(color: color, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

public extension View {
    func trinketArtworkBlend(_ blend: ArtworkBlend = .none) -> some View {
        modifier(ArtworkBlendModifier(blend: blend))
    }
}
