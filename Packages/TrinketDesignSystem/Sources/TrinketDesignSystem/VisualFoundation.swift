import SwiftUI

public enum SurfaceRole: Equatable, Sendable {
    case base
    case secondary
    case elevated
    case card
    case denseRow
    case selected
    case disabled
    case warning
    case reward
}

public enum MaterialRole: Sendable {
    case bottomBar
    case rewardReveal
    case subtleOverlay
    case homesteadFooter
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
    case navigation
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
        case .navigation: .headline.weight(.semibold)
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
            .opacity(role == .disabled ? TrinketDesign.Opacity.secondary : 1)
            .scaleEffect(isPressed ? 0.98 : 1)
    }
}

private struct SurfaceShadowModifier: ViewModifier {
    let shadow: SurfaceShadow
    func body(content: Content) -> some View {
        if shadow.radius > 0 {
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
    let shadow: SurfaceShadow

    init(role: SurfaceRole, cornerRadiusOverride: CGFloat? = nil) {
        let spec = Self.specs[role, default: Self.fallbackSpec]
        fill = spec.fill
        stroke = spec.stroke
        strokeWidth = spec.strokeWidth
        padding = spec.padding
        cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
        shadow = spec.shadow
    }

    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private struct Spec {
        let fill: Color
        let stroke: Color
        let strokeWidth: CGFloat
        let padding: CGFloat
        let shadow: SurfaceShadow
    }

    private static let fallbackSpec = Spec(
        fill: TrinketDesign.Colors.panel,
        stroke: TrinketDesign.Colors.subtleStroke,
        strokeWidth: 1,
        padding: TrinketDesign.Spacing.large,
        shadow: .none,
    )

    private static let specs: [SurfaceRole: Spec] = [
        .base: Spec(
            fill: TrinketDesign.Colors.panel,
            stroke: TrinketDesign.Colors.subtleStroke,
            strokeWidth: 1,
            padding: TrinketDesign.Spacing.large,
            shadow: .none,
        ),
        .secondary: Spec(
            fill: TrinketDesign.Colors.surface,
            stroke: TrinketDesign.Colors.subtleStroke.opacity(0.7),
            strokeWidth: 1,
            padding: TrinketDesign.Spacing.large,
            shadow: .none,
        ),
        .elevated: Spec(
            fill: TrinketDesign.Colors.elevated,
            stroke: TrinketDesign.Colors.subtleStroke,
            strokeWidth: 1,
            padding: TrinketDesign.Spacing.large,
            shadow: .none,
        ),
        .card: Spec(fill: TrinketDesign.Colors.panel, stroke: .clear, strokeWidth: 0, padding: 0, shadow: .none),
        .denseRow: Spec(
            fill: TrinketDesign.Colors.surface,
            stroke: .clear,
            strokeWidth: 0,
            padding: TrinketDesign.Spacing.medium,
            shadow: .none,
        ),
        .selected: Spec(
            fill: TrinketDesign.Colors.elevated,
            stroke: TrinketDesign.Colors.accent.opacity(TrinketDesign.Opacity.secondary),
            strokeWidth: 1.5,
            padding: TrinketDesign.Spacing.large,
            shadow: SurfaceShadow(color: TrinketDesign.Colors.accent.opacity(0.18), radius: 10, y: 2),
        ),
        .disabled: Spec(
            fill: TrinketDesign.Colors.surface,
            stroke: TrinketDesign.Colors.subtleStroke.opacity(0.45),
            strokeWidth: 1,
            padding: TrinketDesign.Spacing.large,
            shadow: .none,
        ),
        .warning: Spec(
            fill: TrinketDesign.Colors.warning.opacity(0.12),
            stroke: TrinketDesign.Colors.warning.opacity(0.65),
            strokeWidth: 1,
            padding: TrinketDesign.Spacing.large,
            shadow: .none,
        ),
        .reward: Spec(
            fill: TrinketDesign.Colors.elevated,
            stroke: TrinketDesign.Colors.accent.opacity(0.70),
            strokeWidth: 1.25,
            padding: TrinketDesign.Spacing.large,
            shadow: SurfaceShadow(color: TrinketDesign.Colors.accent.opacity(0.20), radius: 14, y: 4),
        ),
    ]
}

private struct SurfaceShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let none = Self(color: .clear, radius: 0, y: 0)
}

struct MaterialRoleModifier: ViewModifier {
    let role: MaterialRole
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        switch MaterialRoleStyle(role: role) {
        case let .glass(glass):
            content.modifier(TrinketGlassBackgroundModifier(glass: glass, shape: shape))
        case .ultraThinMaterial:
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.stroke(TrinketDesign.Colors.subtleStroke, lineWidth: 1) }
        }
    }
}

enum MaterialRoleStyle {
    case glass(glass: Glass)
    case ultraThinMaterial

    init(role: MaterialRole) {
        switch role {
        case .bottomBar, .homesteadFooter:
            self = .glass(glass: .regular)
        case .rewardReveal:
            self = .glass(glass: .regular.tint(TrinketDesign.Colors.accent))
        case .subtleOverlay:
            self = .ultraThinMaterial
        }
    }
}

struct TrinketGlassBackgroundModifier<S: Shape>: ViewModifier {
    let glass: Glass
    let shape: S

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
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
                    Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                }
            }
            .modifier(TrinketGlassBackgroundModifier(glass: .regular, shape: Capsule(style: .continuous)))
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
        let shape = cornerRadius == TrinketDesign.Corners.card ? TrinketDesign.cardShape : RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous,
        )
        return modifier(MaterialRoleModifier(role: role, shape: shape))
    }

    func trinketTypography(_ role: TypographyRole) -> some View {
        modifier(TypographyModifier(role: role))
    }

    func trinketGlassChip(_ role: GlassChipRole = .standard) -> some View {
        modifier(GlassChipModifier(role: role))
    }

    func collectionShelfCardWidth() -> some View {
        containerRelativeFrame(.horizontal) { length, _ in
            let margin = TrinketDesign.Layout.collectionShelfHorizontalMargin
            let spacing = TrinketDesign.Layout.collectionShelfCardSpacing
            let peek = TrinketDesign.Layout.collectionShelfPeekRatio
            return (length - 2 * margin - spacing) / (1.75 + peek)
        }
    }
}
