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
    public let particlesEnabledByDefault: Bool

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
        textureOpacity: Double,
        particlesEnabledByDefault: Bool
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
        self.particlesEnabledByDefault = particlesEnabledByDefault
    }

    public static let darkTabletop = ThemePalette(
        appBackground: Color(red: 0.07, green: 0.06, blue: 0.045),
        secondaryBackground: Color(red: 0.12, green: 0.10, blue: 0.075),
        elevatedBackground: Color(red: 0.18, green: 0.14, blue: 0.10),
        panelSurface: Color(red: 0.14, green: 0.115, blue: 0.085),
        overlayScrim: Color.black.opacity(0.46),
        subtleStroke: Color(red: 0.74, green: 0.56, blue: 0.30).opacity(0.28),
        ambientGlow: Color(red: 0.95, green: 0.58, blue: 0.18),
        accent: Color(red: 0.95, green: 0.68, blue: 0.27),
        shadow: .elevated,
        textureOpacity: 0.075,
        particlesEnabledByDefault: true
    )

    public static let warmParchment = ThemePalette(
        appBackground: Color(red: 0.92, green: 0.86, blue: 0.74),
        secondaryBackground: Color(red: 0.86, green: 0.78, blue: 0.63),
        elevatedBackground: Color(red: 0.98, green: 0.93, blue: 0.82),
        panelSurface: Color(red: 0.95, green: 0.88, blue: 0.73),
        overlayScrim: Color(red: 0.23, green: 0.16, blue: 0.09).opacity(0.20),
        subtleStroke: Color(red: 0.44, green: 0.27, blue: 0.13).opacity(0.30),
        ambientGlow: Color(red: 0.98, green: 0.72, blue: 0.36),
        accent: Color(red: 0.66, green: 0.40, blue: 0.17),
        shadow: .subtle,
        textureOpacity: 0.055,
        particlesEnabledByDefault: false
    )

    public static let arcaneNight = ThemePalette(
        appBackground: Color(red: 0.035, green: 0.045, blue: 0.075),
        secondaryBackground: Color(red: 0.07, green: 0.085, blue: 0.13),
        elevatedBackground: Color(red: 0.105, green: 0.115, blue: 0.18),
        panelSurface: Color(red: 0.075, green: 0.085, blue: 0.13),
        overlayScrim: Color.black.opacity(0.52),
        subtleStroke: Color(red: 0.58, green: 0.48, blue: 0.95).opacity(0.30),
        ambientGlow: Color(red: 0.40, green: 0.31, blue: 0.96),
        accent: Color(red: 0.58, green: 0.48, blue: 0.95),
        shadow: .elevated,
        textureOpacity: 0.06,
        particlesEnabledByDefault: true
    )

    public static let forestAlchemy = ThemePalette(
        appBackground: Color(red: 0.04, green: 0.065, blue: 0.045),
        secondaryBackground: Color(red: 0.075, green: 0.105, blue: 0.065),
        elevatedBackground: Color(red: 0.12, green: 0.16, blue: 0.095),
        panelSurface: Color(red: 0.075, green: 0.105, blue: 0.07),
        overlayScrim: Color.black.opacity(0.46),
        subtleStroke: Color(red: 0.45, green: 0.68, blue: 0.33).opacity(0.28),
        ambientGlow: Color(red: 0.37, green: 0.72, blue: 0.28),
        accent: Color(red: 0.50, green: 0.72, blue: 0.34),
        shadow: .elevated,
        textureOpacity: 0.065,
        particlesEnabledByDefault: true
    )

    public static let systemNative = ThemePalette(
        appBackground: Color(.systemBackground),
        secondaryBackground: Color(.secondarySystemBackground),
        elevatedBackground: Color(.tertiarySystemBackground),
        panelSurface: Color(.secondarySystemBackground),
        overlayScrim: Color.black.opacity(0.24),
        subtleStroke: Color(.separator).opacity(0.45),
        ambientGlow: Color.accentColor,
        accent: Color.accentColor,
        shadow: .subtle,
        textureOpacity: 0,
        particlesEnabledByDefault: false
    )
}

public struct ShadowStyle: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat

    public static let none = ShadowStyle(color: .clear, radius: 0, y: 0)
    public static let subtle = ShadowStyle(color: .black.opacity(0.08), radius: 4, y: 2)
    public static let elevated = ShadowStyle(color: .black.opacity(0.18), radius: 12, y: 5)
}

public enum BackgroundMode: Equatable, Sendable {
    case standard
    case playJourney
    case collection
    case denseList
    case homestead
    case battle
    case modal

    var glowOpacity: Double {
        switch self {
        case .standard: return 0.16
        case .playJourney, .homestead: return 0.24
        case .collection: return 0.18
        case .denseList: return 0.08
        case .battle: return 0.22
        case .modal: return 0.12
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mode: BackgroundMode
    private let elementTint: Color?

    public init(mode: BackgroundMode = .standard, elementTint: Color? = nil) {
        self.mode = mode
        self.elementTint = elementTint
    }

    public var body: some View {
        let palette = theme.palette

        ZStack {
            palette.appBackground

            RadialGradient(
                colors: [
                    palette.ambientGlow.opacity(mode.glowOpacity),
                    palette.ambientGlow.opacity(0)
                ],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 520
            )

            if let elementTint {
                RadialGradient(
                    colors: [
                        elementTint.opacity(0.12),
                        elementTint.opacity(0)
                    ],
                    center: .bottomLeading,
                    startRadius: 24,
                    endRadius: 460
                )
            }

            if palette.textureOpacity > 0 {
                TrinketTextureLayer(opacity: palette.textureOpacity)
            }

            if palette.particlesEnabledByDefault, !reduceMotion, mode != .denseList {
                TrinketAtmosphereLayer(tint: elementTint ?? palette.ambientGlow, mode: mode)
            }
        }
        .ignoresSafeArea()
    }
}

private struct TrinketTextureLayer: View {
    let opacity: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(opacity), .clear, .black.opacity(opacity)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.white.opacity(opacity * 0.45))
                .blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }
}

private struct TrinketAtmosphereLayer: View {
    let tint: Color
    let mode: BackgroundMode

    var body: some View {
        Canvas { context, size in
            let count = mode == .battle ? 14 : 8
            for index in 0 ..< count {
                let x = size.width * CGFloat((index * 37 % 100)) / 100
                let y = size.height * CGFloat((index * 61 % 100)) / 100
                let rect = CGRect(x: x, y: y, width: 2, height: 2)
                context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.18)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
