import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = TrinketDesign.Corners.card

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let palette = ThemePalette.trinket
        content
            .background(palette.panelSurface, in: shape)
            .shadow(color: palette.shadow.color, radius: palette.shadow.radius, y: palette.shadow.y)
            .clipShape(shape)
    }
}

struct LockedCardEffectModifier: ViewModifier {
    let isLocked: Bool
    let text: String?
    let cornerRadius: CGFloat

    @ScaledMetric(relativeTo: .body)
    private var lockIconSize: CGFloat = 25.5

    private static let lockedBlurRadius: CGFloat = 1
    private static let lockedSaturation: Double = 0.35

    init(
        isLocked: Bool,
        text: String? = nil,
        cornerRadius: CGFloat = TrinketDesign.Corners.card
    ) {
        self.isLocked = isLocked
        self.text = text
        self.cornerRadius = cornerRadius
    }

    private var clipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        if isLocked {
            content
                .saturation(Self.lockedSaturation)
                .clipShape(clipShape)
                .compositingGroup()
                .blur(
                    radius: Self.lockedBlurRadius,
                    opaque: true
                )
                .clipShape(clipShape)
                .disabled(true)
                .overlay {
                    lockBadgeOverlay
                }
        } else {
            content
        }
    }

    private var lockBadgeOverlay: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: lockIconSize))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
    }
}

struct CardLabelSpaceModifier: ViewModifier {
    let isReserved: Bool

    @ScaledMetric(relativeTo: .subheadline)
    private var reservedHeight: CGFloat = TrinketDesign.Metrics.cardLabelReservedHeight

    func body(content: Content) -> some View {
        if isReserved {
            content
                .frame(minHeight: reservedHeight, alignment: .center)
        } else {
            content
        }
    }
}

struct PrimaryActionButtonModifier: ViewModifier {
    let controlSize: ControlSize
    let tint: Color
    let labelColor: Color

    func body(content: Content) -> some View {
        content
            .buttonStyle(.glassProminent)
            .tint(tint)
            .foregroundStyle(labelColor)
            .controlSize(controlSize)
            .buttonBorderShape(.roundedRectangle)
    }
}

/// Shared press treatment for navigation rows. Feature views provide only the
/// row content; the design system owns the surface, feedback, and motion.
public struct NavigationRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                configuration.isPressed ? HomesteadPalette.pressedFill : .clear,
                in: RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(
                TrinketMotion.Homestead.rowPress,
                value: configuration.isPressed
            )
    }
}

/// Press treatment for full-bleed artwork navigation cards.
///
/// Feature screens own the artwork and copy; the design system owns the
/// immediate touch-down response so mode cards feel consistent with other
/// navigation controls.
public struct ArtworkNavigationCardButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)

        configuration.label
            .contentShape(shape)
            .overlay {
                shape
                    .fill(TrinketDesign.Colors.Overlay.ink.opacity(configuration.isPressed ? 0.12 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(
                TrinketMotion.Play.modeCardPress,
                value: configuration.isPressed
            )
    }
}

public extension View {
    func trinketCardSurface(cornerRadius: CGFloat = TrinketDesign.Corners.card) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius))
    }

    func trinketLockedCardEffect(
        isLocked: Bool,
        text: String? = nil,
        cornerRadius: CGFloat = TrinketDesign.Corners.card
    ) -> some View {
        modifier(LockedCardEffectModifier(isLocked: isLocked, text: text, cornerRadius: cornerRadius))
    }

    func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }

    func trinketPrimaryActionButton(
        controlSize: ControlSize = .large,
        tint: Color = TrinketDesign.Colors.accent,
        labelColor: Color = TrinketDesign.Colors.canvas
    ) -> some View {
        modifier(PrimaryActionButtonModifier(
            controlSize: controlSize,
            tint: tint,
            labelColor: labelColor
        ))
    }

    func trinketNavigationRowButtonStyle() -> some View {
        buttonStyle(NavigationRowButtonStyle())
    }

    func trinketArtworkNavigationCardButtonStyle() -> some View {
        buttonStyle(ArtworkNavigationCardButtonStyle())
    }

    /// Gates system sensory feedback on the Options haptics toggle.
    func trinketSensoryFeedback(
        _ feedback: SensoryFeedback,
        trigger: some Equatable,
        enabled: Bool
    ) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}
