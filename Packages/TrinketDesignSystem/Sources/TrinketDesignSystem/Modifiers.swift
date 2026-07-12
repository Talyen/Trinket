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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                    radius: reduceTransparency ? 0 : Self.lockedBlurRadius,
                    opaque: true
                )
                .clipShape(clipShape)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text.map { "Locked. \($0)" } ?? "Locked")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                configuration.isPressed ? HomesteadPalette.pressedFill : .clear,
                in: RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(
                reduceMotion ? TrinketMotion.Homestead.reduceMotion : TrinketMotion.Homestead.rowPress,
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

    /// Gates system sensory feedback on the Options haptics toggle.
    func trinketSensoryFeedback(
        _ feedback: SensoryFeedback,
        trigger: some Equatable,
        enabled: Bool
    ) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}
