import SwiftUI

public enum BackgroundMode: CaseIterable, Equatable, Identifiable, Sendable {
    case standard
    case playJourney
    case collection
    case denseList
    case homestead
    case battle
    case modal

    public var id: Self {
        self
    }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .playJourney: return "Play"
        case .collection: return "Collection"
        case .denseList: return "Dense List"
        case .homestead: return "Homestead"
        case .battle: return "Battle"
        case .modal: return "Modal"
        }
    }
}

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
    case modal
    case popover
}

public enum MaterialRole: Sendable {
    case toolbar
    case bottomBar
    case modal
    case popover
    case rewardReveal
    case subtleOverlay
}

public enum TypographyRole: Sendable {
    case screenTitle
    case sectionTitle
    case cardTitle
    case body
    case secondaryBody
    case caption
    case badge
    case button
    case statValue
    case tooltip
    case navigation

    var font: Font {
        switch self {
        case .screenTitle: return .largeTitle.weight(.bold)
        case .sectionTitle: return .title3.weight(.semibold)
        case .cardTitle: return .headline.weight(.semibold)
        case .body: return .body
        case .secondaryBody: return .subheadline
        case .caption: return .caption
        case .badge: return .caption.weight(.semibold)
        case .button: return .body.weight(.semibold)
        case .statValue: return .body.monospacedDigit().weight(.semibold)
        case .tooltip: return .caption
        case .navigation: return .headline.weight(.semibold)
        }
    }
}

public struct TrinketScreenBackground: View {
    private let mode: BackgroundMode
    private let elementTint: Color?

    public init(mode: BackgroundMode = .standard, elementTint: Color? = nil) {
        self.mode = mode
        self.elementTint = elementTint
    }

    public var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }
}

public struct ScreenBackgroundModifier: ViewModifier {
    let mode: BackgroundMode
    let elementTint: Color?

    public func body(content: Content) -> some View {
        content
            .background {
                TrinketScreenBackground(mode: mode, elementTint: elementTint)
            }
    }
}

public struct SurfaceModifier: ViewModifier {
    let role: SurfaceRole
    let isPressed: Bool

    public func body(content: Content) -> some View {
        let style = SurfaceStyle(role: role, palette: ThemePalette.apple)

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
    let shadow: ShadowStyle

    // swiftlint:disable:next function_body_length
    init(role: SurfaceRole, palette: ThemePalette) {
        switch role {
        case .base:
            fill = palette.panelSurface
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = 16
            cornerRadius = TrinketDesign.Corners.compact
            shadow = .none
        case .secondary:
            fill = palette.secondaryBackground
            stroke = palette.subtleStroke.opacity(0.7)
            strokeWidth = 1
            padding = 14
            cornerRadius = TrinketDesign.Corners.compact
            shadow = .none
        case .elevated:
            fill = palette.elevatedBackground
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = 16
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .card:
            fill = palette.panelSurface
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = 0
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .denseRow:
            fill = palette.secondaryBackground
            stroke = palette.subtleStroke.opacity(0.55)
            strokeWidth = 1
            padding = 12
            cornerRadius = TrinketDesign.Corners.compact
            shadow = .none
        case .selected:
            fill = palette.elevatedBackground
            stroke = palette.accent.opacity(0.72)
            strokeWidth = 1.5
            padding = 14
            cornerRadius = TrinketDesign.Corners.card
            shadow = ShadowStyle(color: palette.accent.opacity(0.18), radius: 10, y: 2)
        case .disabled:
            fill = palette.secondaryBackground
            stroke = palette.subtleStroke.opacity(0.45)
            strokeWidth = 1
            padding = 14
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .warning:
            fill = Color.red.opacity(0.12)
            stroke = Color.red.opacity(0.52)
            strokeWidth = 1
            padding = 14
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .reward:
            fill = palette.elevatedBackground
            stroke = palette.accent.opacity(0.70)
            strokeWidth = 1.25
            padding = 16
            cornerRadius = TrinketDesign.Corners.card
            shadow = ShadowStyle(color: palette.accent.opacity(0.20), radius: 14, y: 4)
        case .modal:
            fill = palette.panelSurface
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = 18
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .popover:
            fill = palette.elevatedBackground
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = 10
            cornerRadius = TrinketDesign.Corners.small
            shadow = palette.shadow
        }
    }

    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

public struct MaterialRoleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let role: MaterialRole
    let shape: RoundedRectangle

    public func body(content: Content) -> some View {
        switch MaterialRoleStyle(role: role) {
        case .none:
            content
        case let .glass(glass, solidFill):
            content.modifier(TrinketGlassBackgroundModifier(
                glass: glass,
                shape: shape,
                solidFill: solidFill
            ))
        case let .solid(fill):
            content
                .background(fill, in: shape)
                .overlay {
                    shape.stroke(ThemePalette.apple.subtleStroke, lineWidth: 1)
                }
        case .ultraThinMaterial:
            if reduceTransparency {
                content
                    .background(ThemePalette.apple.panelSurface, in: shape)
                    .overlay {
                        shape.stroke(ThemePalette.apple.subtleStroke, lineWidth: 1)
                    }
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape.stroke(ThemePalette.apple.subtleStroke, lineWidth: 1)
                    }
            }
        }
    }
}

enum MaterialRoleStyle {
    case none
    case glass(glass: Glass, solidFill: Color)
    case solid(fill: Color)
    case ultraThinMaterial

    init(role: MaterialRole) {
        let palette = ThemePalette.apple
        switch role {
        case .toolbar:
            self = .none
        case .bottomBar:
            self = .glass(glass: .regular, solidFill: palette.panelSurface)
        case .modal:
            self = .solid(fill: palette.panelSurface)
        case .popover:
            self = .glass(glass: .regular, solidFill: palette.elevatedBackground)
        case .rewardReveal:
            self = .glass(glass: .regular.tint(palette.accent), solidFill: palette.elevatedBackground)
        case .subtleOverlay:
            self = .ultraThinMaterial
        }
    }
}

struct TrinketGlassBackgroundModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let glass: Glass
    let shape: S
    let solidFill: Color

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(solidFill, in: shape)
                .overlay {
                    shape.stroke(ThemePalette.apple.subtleStroke, lineWidth: 1)
                }
        } else {
            content
                .glassEffect(glass, in: shape)
        }
    }
}

public struct TypographyModifier: ViewModifier {
    let role: TypographyRole

    public func body(content: Content) -> some View {
        content.font(role.font)
    }
}

public struct GlassChipModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content.modifier(TrinketGlassBackgroundModifier(
            glass: .regular,
            shape: Capsule(style: .continuous),
            solidFill: ThemePalette.apple.elevatedBackground
        ))
    }
}

public struct StatusBadgeModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content.modifier(TrinketGlassBackgroundModifier(
            glass: .regular,
            shape: Capsule(style: .continuous),
            solidFill: ThemePalette.apple.panelSurface
        ))
    }
}

public struct WalletPillModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content.modifier(TrinketGlassBackgroundModifier(
            glass: .regular,
            shape: Capsule(style: .continuous),
            solidFill: ThemePalette.apple.secondaryBackground
        ))
    }
}

public struct BattleHealthScrimGradient: View {
    public enum Placement {
        case top
        case bottom
    }

    let placement: Placement

    public init(placement: Placement) {
        self.placement = placement
    }

    public var body: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.42), .clear],
            startPoint: placement == .top ? .top : .bottom,
            endPoint: placement == .top ? .bottom : .top
        )
        .frame(height: 54)
    }
}

public extension View {
    func trinketScreenBackground(_ mode: BackgroundMode = .standard, elementTint: Color? = nil) -> some View {
        modifier(ScreenBackgroundModifier(mode: mode, elementTint: elementTint))
    }

    func trinketSurface(_ role: SurfaceRole, isPressed: Bool = false) -> some View {
        modifier(SurfaceModifier(role: role, isPressed: isPressed))
    }

    func trinketMaterial(
        _ role: MaterialRole,
        cornerRadius: CGFloat = TrinketDesign.Corners.card
    ) -> some View {
        modifier(MaterialRoleModifier(
            role: role,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ))
    }

    func trinketTypography(_ role: TypographyRole) -> some View {
        modifier(TypographyModifier(role: role))
    }

    func trinketGlassChip() -> some View {
        modifier(GlassChipModifier())
    }

    func trinketStatusBadge() -> some View {
        modifier(StatusBadgeModifier())
    }

    func trinketWalletPill() -> some View {
        modifier(WalletPillModifier())
    }
}
