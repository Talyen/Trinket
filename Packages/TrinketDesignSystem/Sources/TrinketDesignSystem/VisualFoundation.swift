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
    case modal
    case popover
    case homesteadPanel
}

public enum MaterialRole: Sendable {
    case toolbar
    case bottomBar
    case modal
    case popover
    case rewardReveal
    case subtleOverlay
    case homesteadFooter
}

public enum TypographyRole: Sendable {
    /// Serif large title for cinematic heroes on art (Campaign, Homestead, detail heroes).
    case screenDisplay
    /// Serif title2 for featured section names on themed surfaces.
    case sectionDisplay
    /// SF large title for system-style screen titles (Apple-native UI chrome).
    case screenTitle
    /// SF title2 for list/shelf section headers (Apple-native UI chrome).
    case sectionTitle
    /// SF title3 for prominent row labels beneath section headers.
    case rowTitle
    /// SF headline for card and row primary labels.
    case cardTitle
    /// Small uppercase-capable label above a hero title (role, rarity, chapter index).
    case eyebrow
    case body
    case secondaryBody
    case caption
    case footnote
    case badge
    case button
    case statValue
    case tooltip
    case navigation
    /// Serif headline for compact journey/list row titles.
    case rowDisplay
    /// Medium subheadline under collection/card art.
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
        case .tooltip: .caption
        case .navigation: .headline.weight(.semibold)
        case .rowDisplay: .system(.headline, design: .serif).weight(.semibold)
        case .cardLabel: .subheadline.weight(.medium)
        }
    }
}

enum HomesteadPalette {
    static let accent = TrinketDesign.Colors.accent
    static let success = TrinketDesign.Colors.success
    static let walletPanel = TrinketDesign.Colors.panel

    static let background = TrinketDesign.Colors.canvas
    static let panel = TrinketDesign.Colors.panel
    static let elevatedPanel = TrinketDesign.Colors.elevated
    static let stroke = TrinketDesign.Colors.subtleStroke
    static let mutedText = Color.secondary
}

struct TrinketScreenBackground: View {
    var body: some View {
        ThemePalette.trinket.appBackground
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

    func body(content: Content) -> some View {
        let style = SurfaceStyle(role: role, palette: ThemePalette.trinket)

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
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .secondary:
            fill = palette.secondaryBackground
            stroke = palette.subtleStroke.opacity(0.7)
            strokeWidth = 1
            padding = TrinketDesign.Metrics.snugSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .elevated:
            fill = palette.elevatedBackground
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .card:
            fill = palette.panelSurface
            stroke = .clear
            strokeWidth = 0
            padding = 0
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .denseRow:
            fill = palette.secondaryBackground
            stroke = .clear
            strokeWidth = 0
            padding = TrinketDesign.Metrics.mediumSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .selected:
            fill = palette.elevatedBackground
            stroke = palette.accent.opacity(0.72)
            strokeWidth = 1.5
            padding = TrinketDesign.Metrics.snugSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = ShadowStyle(color: palette.accent.opacity(0.18), radius: 10, y: 2)
        case .disabled:
            fill = palette.secondaryBackground
            stroke = palette.subtleStroke.opacity(0.45)
            strokeWidth = 1
            padding = TrinketDesign.Metrics.snugSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .warning:
            fill = palette.warning.opacity(0.12)
            stroke = palette.warning.opacity(0.65)
            strokeWidth = 1
            padding = TrinketDesign.Metrics.snugSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        case .reward:
            fill = palette.elevatedBackground
            stroke = palette.accent.opacity(0.70)
            strokeWidth = 1.25
            padding = TrinketDesign.Metrics.largeSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = ShadowStyle(color: palette.accent.opacity(0.20), radius: 14, y: 4)
        case .modal:
            fill = palette.panelSurface
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = TrinketDesign.Metrics.homesteadBodySpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .popover:
            fill = palette.elevatedBackground
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = TrinketDesign.Metrics.sectionHeaderSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = palette.shadow
        case .homesteadPanel:
            fill = palette.panelSurface
            stroke = palette.subtleStroke
            strokeWidth = 1
            padding = TrinketDesign.Metrics.mediumSpacing
            cornerRadius = TrinketDesign.Corners.card
            shadow = .none
        }
    }

    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct MaterialRoleModifier: ViewModifier {
    let role: MaterialRole
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
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
                    shape.stroke(ThemePalette.trinket.subtleStroke, lineWidth: 1)
                }
        case .ultraThinMaterial:
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(ThemePalette.trinket.subtleStroke, lineWidth: 1)
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
        let palette = ThemePalette.trinket
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
        case .homesteadFooter:
            self = .glass(
                glass: .regular,
                solidFill: palette.panelSurface
            )
        }
    }
}

struct TrinketGlassBackgroundModifier<S: Shape>: ViewModifier {
    let glass: Glass
    let shape: S
    let solidFill: Color

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
    let role: ChipChromeRole

    init(role: ChipChromeRole = .standard) {
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
                solidFill: ThemePalette.trinket.elevatedBackground
            ))
    }
}

extension ChipChromeRole {
    var horizontalPadding: CGFloat {
        switch self {
        case .standard: TrinketDesign.Metrics.chipPaddingHorizontal
        case .compact: TrinketDesign.Metrics.chipCompactPaddingHorizontal
        case .emphasis: TrinketDesign.Metrics.chipEmphasisPaddingHorizontal
        case .utility: TrinketDesign.Metrics.chipUtilityPaddingHorizontal
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .standard: TrinketDesign.Metrics.chipPaddingVertical
        case .compact: TrinketDesign.Metrics.chipCompactPaddingVertical
        case .emphasis: TrinketDesign.Metrics.chipEmphasisPaddingVertical
        case .utility: TrinketDesign.Metrics.chipUtilityPaddingVertical
        }
    }
}

/// Dark outline + soft bloom so floating combat numbers stay readable on busy art.
struct CombatFloatTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: TrinketDesign.Colors.Overlay.ink.opacity(0.95), radius: 0, x: 0, y: 1)
            .shadow(color: TrinketDesign.Colors.Overlay.ink.opacity(0.9), radius: 0, x: 0, y: -1)
            .shadow(color: TrinketDesign.Colors.Overlay.ink.opacity(0.9), radius: 0, x: 1, y: 0)
            .shadow(color: TrinketDesign.Colors.Overlay.ink.opacity(0.9), radius: 0, x: -1, y: 0)
            .shadow(color: TrinketDesign.Colors.Overlay.ink.opacity(0.55), radius: 3, x: 0, y: 1.5)
            .drawingGroup()
    }
}

struct WalletPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, TrinketDesign.Metrics.chipPaddingHorizontal)
            .padding(.vertical, TrinketDesign.Metrics.chipPaddingVertical)
            .modifier(TrinketGlassBackgroundModifier(
                glass: .regular,
                shape: Capsule(style: .continuous),
                solidFill: ThemePalette.trinket.secondaryBackground
            ))
    }
}

public extension View {
    func trinketScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
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

    func trinketGlassChip(_ role: ChipChromeRole = .standard) -> some View {
        modifier(GlassChipModifier(role: role))
    }

    func trinketCombatFloatText() -> some View {
        modifier(CombatFloatTextModifier())
    }

    func trinketWalletPill() -> some View {
        modifier(WalletPillModifier())
    }
}
