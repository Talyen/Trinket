import SwiftUI

public struct ThemePalette: Sendable {
    public let appBackground: Color
    public let secondaryBackground: Color
    public let elevatedBackground: Color
    public let panelSurface: Color
    public let overlayScrim: Color
    public let subtleStroke: Color
    public let ambientGlow: Color
    public let accent: Color
    public let shadow: ShadowStyle
    public let textureOpacity: Double

    public init(
        appBackground: Color,
        secondaryBackground: Color,
        elevatedBackground: Color,
        panelSurface: Color,
        overlayScrim: Color,
        subtleStroke: Color,
        ambientGlow: Color,
        accent: Color,
        shadow: ShadowStyle,
        textureOpacity: Double
    ) {
        self.appBackground = appBackground
        self.secondaryBackground = secondaryBackground
        self.elevatedBackground = elevatedBackground
        self.panelSurface = panelSurface
        self.overlayScrim = overlayScrim
        self.subtleStroke = subtleStroke
        self.ambientGlow = ambientGlow
        self.accent = accent
        self.shadow = shadow
        self.textureOpacity = textureOpacity
    }

    public static let darkTabletop = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemBackground),
        overlayScrim: Color.black.opacity(0.46),
        subtleStroke: Color(red: 0.62, green: 0.60, blue: 0.56).opacity(0.32),
        ambientGlow: Color(red: 0.72, green: 0.70, blue: 0.66),
        accent: Color(red: 0.58, green: 0.56, blue: 0.52),
        shadow: .elevated,
        textureOpacity: 0
    )

    public static let warmParchment = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemBackground),
        overlayScrim: Color(red: 0.20, green: 0.17, blue: 0.13).opacity(0.18),
        subtleStroke: Color(red: 0.58, green: 0.53, blue: 0.45).opacity(0.30),
        ambientGlow: Color(red: 0.78, green: 0.74, blue: 0.66),
        accent: Color(red: 0.55, green: 0.49, blue: 0.40),
        shadow: .subtle,
        textureOpacity: 0
    )

    public static let arcaneNight = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemBackground),
        overlayScrim: Color.black.opacity(0.52),
        subtleStroke: Color(red: 0.66, green: 0.66, blue: 0.68).opacity(0.34),
        ambientGlow: Color(red: 0.82, green: 0.82, blue: 0.80),
        accent: Color(red: 0.68, green: 0.68, blue: 0.66),
        shadow: .elevated,
        textureOpacity: 0
    )

    public static let forestAlchemy = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemBackground),
        overlayScrim: Color(red: 0.16, green: 0.15, blue: 0.13).opacity(0.38),
        subtleStroke: Color(red: 0.60, green: 0.57, blue: 0.50).opacity(0.30),
        ambientGlow: Color(red: 0.76, green: 0.72, blue: 0.62),
        accent: Color(red: 0.57, green: 0.53, blue: 0.45),
        shadow: .elevated,
        textureOpacity: 0
    )

    public func systemCanvasPalette() -> ThemePalette {
        ThemePalette(
            appBackground: Color(.systemBackground),
            secondaryBackground: Color(.secondarySystemBackground),
            elevatedBackground: Color(.tertiarySystemBackground),
            panelSurface: Color(.secondarySystemBackground),
            overlayScrim: overlayScrim,
            subtleStroke: subtleStroke,
            ambientGlow: ambientGlow,
            accent: accent,
            shadow: shadow,
            textureOpacity: 0
        )
    }
}

public struct ShadowStyle: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat

    public static let none = ShadowStyle(color: .clear, radius: 0, y: 0)
    public static let subtle = ShadowStyle(color: .black.opacity(0.08), radius: 4, y: 2)
    public static let elevated = ShadowStyle(color: .black.opacity(0.18), radius: 12, y: 5)
}

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

private struct TrinketThemeKey: EnvironmentKey {
    static let defaultValue = TrinketDesign.AppTheme.default
}

public extension EnvironmentValues {
    var trinketTheme: TrinketDesign.AppTheme {
        get { self[TrinketThemeKey.self] }
        set { self[TrinketThemeKey.self] = newValue }
    }
}

public struct TrinketScreenBackground: View {
    @Environment(\.trinketTheme) private var theme

    private let mode: BackgroundMode
    private let elementTint: Color?

    public init(mode: BackgroundMode = .standard, elementTint: Color? = nil) {
        self.mode = mode
        self.elementTint = elementTint
    }

    public var body: some View {
        let palette = theme.palette

        palette.appBackground
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
    @Environment(\.trinketTheme) private var theme

    let role: SurfaceRole
    let isPressed: Bool

    public func body(content: Content) -> some View {
        let style = SurfaceStyle(role: role, palette: theme.palette)

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
    @Environment(\.trinketTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let role: MaterialRole
    let shape: RoundedRectangle

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(theme.palette.panelSurface, in: shape)
                .overlay {
                    shape.stroke(theme.palette.subtleStroke, lineWidth: 1)
                }
        } else {
            content
                .background(material, in: shape)
                .overlay {
                    shape.stroke(theme.palette.subtleStroke, lineWidth: 1)
                }
        }
    }

    private var material: Material {
        switch role {
        case .toolbar, .bottomBar, .popover:
            return .thinMaterial
        case .modal, .rewardReveal:
            return .regularMaterial
        case .subtleOverlay:
            return .ultraThinMaterial
        }
    }
}

public struct TypographyModifier: ViewModifier {
    let role: TypographyRole

    public func body(content: Content) -> some View {
        content.font(role.font)
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
}
