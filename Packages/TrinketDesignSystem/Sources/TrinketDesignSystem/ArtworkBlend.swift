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

/// Optional bottom-edge blend for integrating artwork with its containing surface.
/// The `perimeter` case is preserved for API compatibility but has no visual effect.
public enum ArtworkBlend: Equatable, Sendable {
    case none
    case perimeter(into: ArtworkBlendDestination)
    case bottom(into: ArtworkBlendDestination)
}

enum ArtworkBlendRecipe {
    static let edgeOpacity = 1.0
    static let shoulderOpacity = 0.35
    static let shoulderInset = 0.08
    static let clearInset = 0.22
}

private struct ArtworkBlendModifier: ViewModifier {
    let blend: ArtworkBlend

    func body(content: Content) -> some View {
        switch blend {
        case .none, .perimeter:
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
