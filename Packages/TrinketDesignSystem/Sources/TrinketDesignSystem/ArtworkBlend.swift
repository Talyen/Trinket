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

/// Optional edge blend for integrating artwork with its containing surface.
public enum ArtworkBlend: Equatable, Sendable {
    case none
    /// Fades all four edges into the destination over a fixed perimeter inset.
    case perimeter(into: ArtworkBlendDestination)
    case bottom(into: ArtworkBlendDestination)
}

private enum ArtworkBlendRecipe: Sendable {
    /// Bottom-edge clear band before the destination color fully takes over.
    static let clearInset = 0.22
    /// All-sides inset for perimeter fades (fraction of the shorter axis is not used —
    /// each edge uses this fraction of width or height respectively).
    static let perimeterInset = 0.22
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

/// Thick vignette: destination color is opaque at the rim and clear in the center.
private struct PerimeterArtworkBlend: View {
    let destination: ArtworkBlendDestination

    var body: some View {
        let color = destination.color
        let inset = ArtworkBlendRecipe.perimeterInset

        ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [color, color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .containerRelativeFrame(.vertical) { height, _ in height * inset }

                Spacer(minLength: 0)

                LinearGradient(
                    colors: [color.opacity(0), color],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .containerRelativeFrame(.vertical) { height, _ in height * inset }
            }

            HStack(spacing: 0) {
                LinearGradient(
                    colors: [color, color.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .containerRelativeFrame(.horizontal) { width, _ in width * inset }

                Spacer(minLength: 0)

                LinearGradient(
                    colors: [color.opacity(0), color],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .containerRelativeFrame(.horizontal) { width, _ in width * inset }
            }
        }
    }
}

public extension View {
    /// Blends artwork toward a semantic surface. The default preserves the source unchanged.
    func trinketArtworkBlend(_ blend: ArtworkBlend = .none) -> some View {
        modifier(ArtworkBlendModifier(blend: blend))
    }
}
