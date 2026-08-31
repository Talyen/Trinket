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
        case .screenDisplay: .largeTitle.weight(.semibold)
        case .sectionDisplay: .title2.weight(.semibold)
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
        case .rowDisplay: .headline.weight(.semibold)
        case .cardLabel: .subheadline.weight(.medium)
        }
    }
}

struct TrinketScreenBackground: View {
    var body: some View {
        TrinketDesign.Colors.canvas
            .ignoresSafeArea()
    }
}

struct ScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                TrinketScreenBackground()
            }
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
            .overlay {
                style.shape
                    .stroke(style.stroke, lineWidth: style.strokeWidth)
            }
            .shadow(color: style.shadow.color, radius: style.shadow.radius, y: style.shadow.y)
            .opacity(role == .disabled ? 0.72 : 1)
            .scaleEffect(isPressed ? 0.98 : 1)
    }
}

private struct SurfaceStyle {
    let fill: Color
    let stroke: Color
    let strokeWidth: CGFloat
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadow: SurfaceShadow

    // swiftlint:disable:next function_body_length
    init(role: SurfaceRole, cornerRadiusOverride: CGFloat? = nil) {
        switch role {
        case .base:
            fill = TrinketDesign.Colors.panel
            stroke = TrinketDesign.Colors.subtleStroke
            strokeWidth = 1
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .secondary:
            fill = TrinketDesign.Colors.surface
            stroke = TrinketDesign.Colors.subtleStroke.opacity(0.7)
            strokeWidth = 1
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .elevated:
            fill = TrinketDesign.Colors.elevated
            stroke = TrinketDesign.Colors.subtleStroke
            strokeWidth = 1
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .card:
            fill = TrinketDesign.Colors.panel
            stroke = .clear
            strokeWidth = 0
            padding = 0
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .denseRow:
            fill = TrinketDesign.Colors.surface
            stroke = .clear
            strokeWidth = 0
            padding = TrinketDesign.Metrics.mediumSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .selected:
            fill = TrinketDesign.Colors.elevated
            stroke = TrinketDesign.Colors.accent.opacity(0.72)
            strokeWidth = 1.5
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = SurfaceShadow(color: TrinketDesign.Colors.accent.opacity(0.18), radius: 10, y: 2)
        case .disabled:
            fill = TrinketDesign.Colors.surface
            stroke = TrinketDesign.Colors.subtleStroke.opacity(0.45)
            strokeWidth = 1
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .warning:
            fill = TrinketDesign.Colors.warning.opacity(0.12)
            stroke = TrinketDesign.Colors.warning.opacity(0.65)
            strokeWidth = 1
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = .none
        case .reward:
            fill = TrinketDesign.Colors.elevated
            stroke = TrinketDesign.Colors.accent.opacity(0.70)
            strokeWidth = 1.25
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = cornerRadiusOverride ?? TrinketDesign.Corners.card
            shadow = SurfaceShadow(color: TrinketDesign.Colors.accent.opacity(0.20), radius: 14, y: 4)
        }
    }

    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

private struct SurfaceShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let none = Self(color: .clear, radius: 0, y: 0)
    static let elevated = Self(
        color: TrinketDesign.Colors.Overlay.ink.opacity(0.18),
        radius: 12,
        y: 5,
    )
}

struct MaterialRoleModifier: ViewModifier {
    let role: MaterialRole
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        switch MaterialRoleStyle(role: role) {
        case let .glass(glass):
            content.modifier(TrinketGlassBackgroundModifier(
                glass: glass,
                shape: shape,
            ))
        case .ultraThinMaterial:
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
                }
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
        content
            .glassEffect(glass, in: shape)
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
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                }
            }
            .modifier(TrinketGlassBackgroundModifier(
                glass: .regular,
                shape: Capsule(style: .continuous),
            ))
    }
}

extension GlassChipRole {
    var horizontalPadding: CGFloat {
        switch self {
        case .standard: TrinketDesign.Metrics.chipPaddingHorizontal
        case .emphasis: TrinketDesign.Metrics.chipEmphasisPaddingHorizontal
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .standard: TrinketDesign.Metrics.chipPaddingVertical
        case .emphasis: TrinketDesign.Metrics.chipEmphasisPaddingVertical
        }
    }
}

public extension View {
    func trinketScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }

    func trinketSurface(
        _ role: SurfaceRole,
        isPressed: Bool = false,
        cornerRadiusOverride: CGFloat? = nil,
    ) -> some View {
        modifier(SurfaceModifier(role: role, isPressed: isPressed, cornerRadiusOverride: cornerRadiusOverride))
    }

    func trinketMaterial(
        _ role: MaterialRole,
        cornerRadius: CGFloat = TrinketDesign.Corners.card,
    ) -> some View {
        modifier(MaterialRoleModifier(
            role: role,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
        ))
    }

    func trinketTypography(_ role: TypographyRole) -> some View {
        modifier(TypographyModifier(role: role))
    }

    func trinketGlassChip(_ role: GlassChipRole = .standard) -> some View {
        modifier(GlassChipModifier(role: role))
    }
}
