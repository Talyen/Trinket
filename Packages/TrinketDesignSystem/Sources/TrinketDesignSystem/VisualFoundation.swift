import SwiftUI

public enum SurfaceRole: Equatable, Sendable {
    case secondary
    case card
    case denseRow
}

public enum MaterialRole: Sendable {
    case bottomBar
    case subtleOverlay
}

public enum GlassChipRole: String, CaseIterable, Sendable, Equatable {
    case standard
    case emphasis
}

public enum TypographyRole: Sendable {
    case screenDisplay
    case sectionDisplay
    case screenTitle
    case sectionTitle
    case rowTitle
    case cardTitle
    case eyebrow
    case body
    case secondaryBody
    case caption
    case footnote
    case badge
    case button
    case statValue
    case rowDisplay
    case cardLabel

    var font: Font {
        switch self {
        case .screenDisplay: .system(.largeTitle, design: .serif).weight(.semibold)
        case .sectionDisplay: .system(.title2, design: .serif).weight(.semibold)
        case .screenTitle: .largeTitle.weight(.bold)
        case .sectionTitle: .title2.weight(.semibold)
        case .rowTitle: .title3.weight(.semibold)
        case .cardTitle: .headline.weight(.semibold)
        case .eyebrow: .caption.weight(.bold)
        case .body: .body
        case .secondaryBody: .subheadline
        case .caption: .caption
        case .footnote: .footnote
        case .badge: .caption.weight(.semibold)
        case .button: .body.weight(.semibold)
        case .statValue: .body.monospacedDigit().weight(.semibold)
        case .rowDisplay: .system(.headline, design: .serif).weight(.semibold)
        case .cardLabel: .subheadline.weight(.medium)
        }
    }
}

struct TrinketScreenBackground: View {
    var body: some View {
        TrinketDesign.Colors.canvas.ignoresSafeArea()
    }
}

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background { TrinketScreenBackground() }
    }
}

struct SurfaceModifier: ViewModifier {
    let role: SurfaceRole
    let isPressed: Bool
    let cornerRadiusOverride: CGFloat?

    init(role: SurfaceRole, isPressed: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.role = role
        self.isPressed = isPressed
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    func body(content: Content) -> some View {
        let style = SurfaceStyle(role: role, cornerRadiusOverride: cornerRadiusOverride)
        content
            .padding(style.padding)
            .background(style.fill, in: style.shape)
            .overlay { style.shape.stroke(style.stroke, lineWidth: style.strokeWidth) }
            .modifier(SurfaceShadowModifier(shadow: style.shadow))
            .scaleEffect(isPressed ? TrinketMotion.Interaction.surfacePressedScale : 1)
    }
}

private struct SurfaceShadowModifier: ViewModifier {
    let shadow: SurfaceShadow?
    func body(content: Content) -> some View {
        if let shadow {
            content.shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
        } else {
            content
        }
    }
}

private struct SurfaceStyle {
    let fill: Color
    let stroke: Color
    let strokeWidth: CGFloat
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadow: SurfaceShadow?

    init(role: SurfaceRole, cornerRadiusOverride: CGFloat? = nil) {
        let spec = Self.spec(for: role)
        fill = spec.fill
        stroke = spec.stroke
        strokeWidth = spec.strokeWidth
        padding = spec.padding
        cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
        shadow = spec.shadow
    }

    var shape: RoundedRectangle {
        TrinketDesign.shape(cornerRadius: cornerRadius)
    }

    private struct Spec {
        var fill: Color = TrinketDesign.Colors.panel
        var stroke: Color = TrinketDesign.Colors.subtleStroke
        var strokeWidth: CGFloat = 1
        var padding: CGFloat = TrinketDesign.Spacing.large
        var shadow: SurfaceShadow?

        /// Dimmed stroke for the secondary surface; single-use, so private.
        static let secondaryStrokeOpacity: Double = 0.7
    }

    private static func spec(for role: SurfaceRole) -> Spec {
        switch role {
        case .secondary:
            Spec(fill: TrinketDesign.Colors.surface, stroke: TrinketDesign.Colors.subtleStroke.opacity(Spec.secondaryStrokeOpacity))
        case .card:
            Spec(stroke: .clear, strokeWidth: 0, padding: 0)
        case .denseRow:
            Spec(
                fill: TrinketDesign.Colors.surface,
                stroke: .clear,
                strokeWidth: 0,
                padding: TrinketDesign.Spacing.medium,
            )
        }
    }
}

private struct SurfaceShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

struct MaterialRoleModifier: ViewModifier {
    let role: MaterialRole
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        switch role {
        case .bottomBar:
            content.glassEffect(.regular, in: shape)
        case .subtleOverlay:
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.stroke(TrinketDesign.Colors.subtleStroke, lineWidth: 1) }
        }
    }
}

struct TypographyModifier: ViewModifier {
    let role: TypographyRole

    func body(content: Content) -> some View {
        content.font(role.font)
    }
}

struct GlassChipModifier: ViewModifier {
    let role: GlassChipRole

    init(role: GlassChipRole = .standard) {
        self.role = role
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, role.horizontalPadding)
            .padding(.vertical, role.verticalPadding)
            .overlay {
                if role == .emphasis {
                    Capsule(style: .continuous).strokeBorder(
                        Color.primary.opacity(TrinketDesign.Opacity.chipEmphasisStroke),
                        lineWidth: 1,
                    )
                }
            }
            .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}

extension GlassChipRole {
    var horizontalPadding: CGFloat {
        switch self {
        case .standard: TrinketDesign.Layout.chipPaddingHorizontal
        case .emphasis: TrinketDesign.Layout.chipEmphasisPaddingHorizontal
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .standard: TrinketDesign.Layout.chipPaddingVertical
        case .emphasis: TrinketDesign.Layout.chipEmphasisPaddingVertical
        }
    }
}

public extension View {
    func trinketScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }

    func trinketSurface(_ role: SurfaceRole, isPressed: Bool = false, cornerRadiusOverride: CGFloat? = nil) -> some View {
        modifier(SurfaceModifier(role: role, isPressed: isPressed, cornerRadiusOverride: cornerRadiusOverride))
    }

    func trinketMaterial(
        _ role: MaterialRole,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
    ) -> some View {
        modifier(MaterialRoleModifier(role: role, shape: TrinketDesign.shape(cornerRadius: cornerRadius)))
    }

    func trinketTypography(_ role: TypographyRole) -> some View {
        modifier(TypographyModifier(role: role))
    }

    func trinketGlassChip(_ role: GlassChipRole = .standard) -> some View {
        modifier(GlassChipModifier(role: role))
    }

    func trinketCollectionShelfCardWidth() -> some View {
        containerRelativeFrame(.horizontal) { length, _ in
            let margin = TrinketDesign.Layout.collectionShelfHorizontalMargin
            let spacing = TrinketDesign.Layout.collectionShelfCardSpacing
            let peek = TrinketDesign.Layout.collectionShelfPeekRatio
            return (length - 2 * margin - spacing) / (TrinketDesign.Layout.collectionShelfVisibleCardCount + peek)
        }
    }
}
