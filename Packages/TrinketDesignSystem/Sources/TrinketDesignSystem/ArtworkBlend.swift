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
    /// Normalized distances measured inward from every treated artwork edge.
    static let edgeOpacity = 1.0
    static let shoulderOpacity = 0.24
    static let shoulderInset = 0.05
    static let clearInset = 0.11
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
                .init(color: color.opacity(recipe.edgeOpacity), location: 0),
                .init(
                    color: color.opacity(recipe.shoulderOpacity),
                    location: recipe.shoulderInset
                ),
                .init(color: .clear, location: recipe.clearInset),
                .init(color: .clear, location: 1 - recipe.clearInset),
                .init(
                    color: color.opacity(recipe.shoulderOpacity),
                    location: 1 - recipe.shoulderInset
                ),
                .init(color: color.opacity(recipe.edgeOpacity), location: 1)
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
                .init(color: .clear, location: 1 - recipe.clearInset),
                .init(
                    color: color.opacity(recipe.shoulderOpacity),
                    location: 1 - recipe.shoulderInset
                ),
                .init(color: color.opacity(recipe.edgeOpacity), location: 1)
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
