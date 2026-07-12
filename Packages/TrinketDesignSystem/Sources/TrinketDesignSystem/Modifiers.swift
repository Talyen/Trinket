import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .trinketSurface(.card)
            .clipShape(TrinketDesign.cardShape)
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

    func body(content: Content) -> some View {
        content
            .buttonStyle(.glassProminent)
            .controlSize(controlSize)
            .buttonBorderShape(.roundedRectangle)
    }
}

/// Shared press treatment for navigation rows. Feature views provide only the
/// row content; the design system owns the surface, feedback, and motion.
public struct NavigationRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                configuration.isPressed ? HomesteadPalette.pressedFill(for: colorScheme) : .clear,
                in: RoundedRectangle(cornerRadius: TrinketDesign.Corners.small, style: .continuous)
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
    func trinketCardSurface() -> some View {
        modifier(CardSurfaceModifier())
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

    func trinketPrimaryActionButton(controlSize: ControlSize = .large) -> some View {
        modifier(PrimaryActionButtonModifier(controlSize: controlSize))
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
