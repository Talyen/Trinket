import SwiftUI

/// Semantic surfaces that artwork can visually dissolve into.
public enum ArtworkBlendDestination: CaseIterable, Equatable, Sendable {
    case canvas
    case surface
    case panel
    case elevated

    var color: Color {
        switch self {
        case .canvas: TrinketDesign.Colors.canvas
        case .surface: TrinketDesign.Colors.surface
        case .panel: TrinketDesign.Colors.panel
        case .elevated: TrinketDesign.Colors.elevated
        }
    }
}

/// Optional edge treatments for integrating artwork with its containing surface.
public enum ArtworkBlend: Equatable, Sendable {
    case none
    case perimeter(into: ArtworkBlendDestination)
    case bottom(into: ArtworkBlendDestination)
}

enum ArtworkBlendRecipe {
    static let perimeterEdgeOpacity = 1.0
    static let perimeterShoulderOpacity = 0.30
    static let perimeterShoulderLocation = 0.06
    static let perimeterInnerLocation = 0.13

    static let bottomClearLocation = 0.60
    static let bottomShoulderLocation = 0.76
    static let bottomShoulderOpacity = 0.30
    static let bottomNearEdgeLocation = 0.90
    static let bottomNearEdgeOpacity = 0.78
}

private struct ArtworkBlendModifier: ViewModifier {
    let blend: ArtworkBlend

    func body(content: Content) -> some View {
        switch blend {
        case .none:
            content

        case let .perimeter(destination):
            content.overlay {
                PerimeterArtworkBlend(destination: destination)
                    .allowsHitTesting(false)
            }

        case let .bottom(destination):
            content.overlay {
                BottomArtworkBlend(destination: destination)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct PerimeterArtworkBlend: View {
    let destination: ArtworkBlendDestination

    var body: some View {
        ZStack {
            edgeGradient(startPoint: .leading, endPoint: .trailing)
            edgeGradient(startPoint: .top, endPoint: .bottom)
        }
    }

    private func edgeGradient(startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        let color = destination.color
        let recipe = ArtworkBlendRecipe.self

        return LinearGradient(
            stops: [
                .init(color: color.opacity(recipe.perimeterEdgeOpacity), location: 0),
                .init(
                    color: color.opacity(recipe.perimeterShoulderOpacity),
                    location: recipe.perimeterShoulderLocation
                ),
                .init(color: .clear, location: recipe.perimeterInnerLocation),
                .init(color: .clear, location: 1 - recipe.perimeterInnerLocation),
                .init(
                    color: color.opacity(recipe.perimeterShoulderOpacity),
                    location: 1 - recipe.perimeterShoulderLocation
                ),
                .init(color: color.opacity(recipe.perimeterEdgeOpacity), location: 1)
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
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
                .init(color: .clear, location: recipe.bottomClearLocation),
                .init(
                    color: color.opacity(recipe.bottomShoulderOpacity),
                    location: recipe.bottomShoulderLocation
                ),
                .init(
                    color: color.opacity(recipe.bottomNearEdgeOpacity),
                    location: recipe.bottomNearEdgeLocation
                ),
                .init(color: color, location: 1)
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
