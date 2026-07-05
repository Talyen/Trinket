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
        appBackground: Color(red: 0.07, green: 0.06, blue: 0.045),
        secondaryBackground: Color(red: 0.12, green: 0.10, blue: 0.075),
        elevatedBackground: Color(red: 0.18, green: 0.14, blue: 0.10),
        panelSurface: Color(red: 0.14, green: 0.115, blue: 0.085),
        overlayScrim: Color.black.opacity(0.46),
        subtleStroke: Color(red: 0.74, green: 0.56, blue: 0.30).opacity(0.28),
        ambientGlow: Color(red: 0.95, green: 0.58, blue: 0.18),
        accent: Color(red: 0.95, green: 0.68, blue: 0.27),
        shadow: .elevated,
        textureOpacity: 0.075
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
        textureOpacity: 0.055
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
        textureOpacity: 0.06
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
        textureOpacity: 0.065
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
        textureOpacity: 0
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

public enum BackgroundGradientAnchor: String, CaseIterable, Identifiable, Sendable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .topLeading: return "Top Leading"
        case .top: return "Top"
        case .topTrailing: return "Top Trailing"
        case .leading: return "Leading"
        case .center: return "Center"
        case .trailing: return "Trailing"
        case .bottomLeading: return "Bottom Leading"
        case .bottom: return "Bottom"
        case .bottomTrailing: return "Bottom Trailing"
        }
    }

    var unitPoint: UnitPoint {
        switch self {
        case .topLeading: return .topLeading
        case .top: return .top
        case .topTrailing: return .topTrailing
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        case .bottomLeading: return .bottomLeading
        case .bottom: return .bottom
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

public struct BackgroundTuningValues: Equatable, Sendable {
    public var mainGlowOpacity: Double
    public var mainGlowStartRadius: Double
    public var mainGlowEndRadius: Double
    public var mainGlowAnchor: BackgroundGradientAnchor
    public var elementGlowOpacity: Double
    public var elementGlowStartRadius: Double
    public var elementGlowEndRadius: Double
    public var elementGlowAnchor: BackgroundGradientAnchor
    public var textureOpacity: Double

    public init(
        mainGlowOpacity: Double,
        mainGlowStartRadius: Double,
        mainGlowEndRadius: Double,
        mainGlowAnchor: BackgroundGradientAnchor,
        elementGlowOpacity: Double,
        elementGlowStartRadius: Double,
        elementGlowEndRadius: Double,
        elementGlowAnchor: BackgroundGradientAnchor,
        textureOpacity: Double
    ) {
        self.mainGlowOpacity = mainGlowOpacity
        self.mainGlowStartRadius = mainGlowStartRadius
        self.mainGlowEndRadius = mainGlowEndRadius
        self.mainGlowAnchor = mainGlowAnchor
        self.elementGlowOpacity = elementGlowOpacity
        self.elementGlowStartRadius = elementGlowStartRadius
        self.elementGlowEndRadius = elementGlowEndRadius
        self.elementGlowAnchor = elementGlowAnchor
        self.textureOpacity = textureOpacity
    }

    public static let defaultPreview = BackgroundTuningValues(
        mainGlowOpacity: 0.07,
        mainGlowStartRadius: 44,
        mainGlowEndRadius: 640,
        mainGlowAnchor: .topTrailing,
        elementGlowOpacity: 0.04,
        elementGlowStartRadius: 56,
        elementGlowEndRadius: 560,
        elementGlowAnchor: .bottomLeading,
        textureOpacity: 0
    )
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

private struct TrinketBackgroundTuningKey: EnvironmentKey {
    static let defaultValue: BackgroundTuningValues? = nil
}

public extension EnvironmentValues {
    var trinketTheme: TrinketDesign.AppTheme {
        get { self[TrinketThemeKey.self] }
        set { self[TrinketThemeKey.self] = newValue }
    }

    var trinketBackgroundTuning: BackgroundTuningValues? {
        get { self[TrinketBackgroundTuningKey.self] }
        set { self[TrinketBackgroundTuningKey.self] = newValue }
    }
}

public struct TrinketScreenBackground: View {
    @Environment(\.trinketTheme) private var theme
    @Environment(\.trinketBackgroundTuning) private var tuning

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
                gradient: smoothGlowGradient(
                    color: palette.ambientGlow,
                    opacity: tuning?.mainGlowOpacity ?? mode.glowOpacity
                ),
                center: tuning?.mainGlowAnchor.unitPoint ?? .topTrailing,
                startRadius: CGFloat(tuning?.mainGlowStartRadius ?? 12),
                endRadius: CGFloat(tuning?.mainGlowEndRadius ?? 520)
            )

            if let elementTint {
                RadialGradient(
                    gradient: smoothGlowGradient(
                        color: elementTint,
                        opacity: tuning?.elementGlowOpacity ?? 0.12
                    ),
                    center: tuning?.elementGlowAnchor.unitPoint ?? .bottomLeading,
                    startRadius: CGFloat(tuning?.elementGlowStartRadius ?? 24),
                    endRadius: CGFloat(tuning?.elementGlowEndRadius ?? 460)
                )
            }

            let textureOpacity = tuning?.textureOpacity ?? palette.textureOpacity
            if textureOpacity > 0 {
                TrinketTextureLayer(opacity: textureOpacity)
            }
        }
        .ignoresSafeArea()
    }
}

private func smoothGlowGradient(color: Color, opacity: Double) -> Gradient {
    Gradient(stops: [
        Gradient.Stop(color: color.opacity(opacity), location: 0),
        Gradient.Stop(color: color.opacity(opacity * 0.72), location: 0.16),
        Gradient.Stop(color: color.opacity(opacity * 0.38), location: 0.42),
        Gradient.Stop(color: color.opacity(opacity * 0.14), location: 0.70),
        Gradient.Stop(color: color.opacity(0), location: 1)
    ])
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
