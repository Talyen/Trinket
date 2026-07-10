import SwiftUI

public struct CardSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .trinketSurface(.card)
            .clipShape(TrinketDesign.cardShape)
    }
}

public struct LockedCardEffectModifier: ViewModifier {
    public let isLocked: Bool
    public let text: String?
    public let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let lockedBlurRadius: CGFloat = 1
    private static let lockedSaturation: Double = 0.35

    public init(
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

    public func body(content: Content) -> some View {
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
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .trinketGlassChip(.compact)
    }
}

public struct CardLabelSpaceModifier: ViewModifier {
    public let isReserved: Bool

    @ScaledMetric(relativeTo: .subheadline)
    private var reservedHeight: CGFloat = TrinketDesign.Metrics.cardLabelReservedHeight

    public func body(content: Content) -> some View {
        if isReserved {
            content
                .frame(minHeight: reservedHeight, alignment: .center)
        } else {
            content
        }
    }
}

public struct PrimaryActionButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle)
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

    func trinketPrimaryActionButton() -> some View {
        modifier(PrimaryActionButtonModifier())
    }

    /// Gates system sensory feedback on the Options haptics toggle.
    func trinketSensoryFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T,
        enabled: Bool
    ) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}
