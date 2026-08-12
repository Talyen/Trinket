import SwiftUI

/// Semantic surface that artwork can visually dissolve into.
public enum ArtworkBlendDestination: Equatable, Sendable {
    case canvas

    var color: Color {
        switch self {
        case .canvas: TrinketDesign.Colors.canvas
        }
    }
}

/// Optional edge blend for integrating artwork with its containing surface.
public enum ArtworkBlend: Equatable, Sendable {
    case none
    case bottom(into: ArtworkBlendDestination)
}

private enum ArtworkBlendRecipe: Sendable {
    /// Bottom-edge clear band before the destination color fully takes over.
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
    /// Blends artwork toward a semantic surface. The default preserves the source unchanged.
    func trinketArtworkBlend(_ blend: ArtworkBlend = .none) -> some View {
        modifier(ArtworkBlendModifier(blend: blend))
    }
}
