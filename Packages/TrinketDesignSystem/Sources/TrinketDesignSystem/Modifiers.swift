import SwiftUI

struct LockedCardEffectModifier: ViewModifier {
    let isLocked: Bool
    let cornerRadius: CGFloat

    @ScaledMetric(relativeTo: .body)
    private var lockIconSize: CGFloat = 34

    private static let lockedBlurRadius: CGFloat = 1
    private static let lockedSaturation: Double = 0.35

    init(isLocked: Bool, cornerRadius: CGFloat = TrinketDesign.Corners.card) {
        self.isLocked = isLocked
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
                .blur(radius: Self.lockedBlurRadius, opaque: true)
                .clipShape(clipShape)
                .disabled(true)
                .overlay { lockBadgeOverlay }
        } else {
            content
        }
    }

    private var lockBadgeOverlay: some View {
        let ink = TrinketDesign.Colors.Overlay.ink
        return Image(systemName: "lock.fill")
            // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
            .font(.system(size: lockIconSize))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            .shadow(color: ink.opacity(0.9), radius: 1.5)
            .shadow(color: ink.opacity(0.55), radius: 3, x: 0, y: 1.5)
    }
}

struct CardLabelSpaceModifier: ViewModifier {
    let isReserved: Bool

    @ScaledMetric(relativeTo: .subheadline)
    private var reservedHeight: CGFloat = TrinketDesign.Metrics.cardLabelReservedHeight

    func body(content: Content) -> some View {
        if isReserved {
            content.frame(minHeight: reservedHeight, alignment: .center)
        } else {
            content
        }
    }
}

private struct GlassButtonModifier: ViewModifier {
    let controlSize: ControlSize
    let tint: Color
    let labelColor: Color?
    let isProminent: Bool
    let accessibilityIdentifier: String?

    func body(content: Content) -> some View {
        Group {
            if isProminent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        }
        .tint(tint)
        .modifier(ForegroundModifier(color: labelColor))
        .controlSize(controlSize)
        .buttonBorderShape(.roundedRectangle)
        .modifier(IdentifierModifier(identifier: accessibilityIdentifier))
    }

    private struct ForegroundModifier: ViewModifier {
        let color: Color?
        func body(content: Content) -> some View {
            if let color {
                content.foregroundStyle(color)
            } else {
                content
            }
        }
    }

    private struct IdentifierModifier: ViewModifier {
        let identifier: String?
        func body(content: Content) -> some View {
            if let identifier {
                content.accessibilityIdentifier(identifier)
            } else {
                content
            }
        }
    }
}

private struct TrinketPressButtonStyle: ButtonStyle {
    let pressedScale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(TrinketMotion.Interaction.press, value: configuration.isPressed)
    }
}

public extension View {
    @ViewBuilder
    func trinketAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    func trinketArtworkPickerSelectionBorder(
        isSelected: Bool,
        color: Color = TrinketDesign.Colors.accent,
        lineWidth: CGFloat = 3,
    ) -> some View {
        overlay {
            TrinketDesign.cardShape.strokeBorder(isSelected ? color : .clear, lineWidth: isSelected ? lineWidth : 0)
        }
    }

    func trinketCardSurface(cornerRadius: CGFloat = TrinketDesign.Corners.card) -> some View {
        trinketSurface(.card, cornerRadiusOverride: cornerRadius)
    }

    func trinketLockedCardEffect(isLocked: Bool, cornerRadius: CGFloat = TrinketDesign.Corners.card) -> some View {
        modifier(LockedCardEffectModifier(isLocked: isLocked, cornerRadius: cornerRadius))
    }

    func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }

    func trinketPrimaryActionButton(
        controlSize: ControlSize = .large,
        tint: Color = TrinketDesign.Colors.accent,
        labelColor: Color = TrinketDesign.Colors.canvas,
        accessibilityIdentifier: String? = nil,
    ) -> some View {
        modifier(GlassButtonModifier(
            controlSize: controlSize,
            tint: tint,
            labelColor: labelColor,
            isProminent: true,
            accessibilityIdentifier: accessibilityIdentifier,
        ))
    }

    func trinketCenteredPrimaryAction() -> some View {
        containerRelativeFrame(.horizontal) { width, _ in width * TrinketDesign.Metrics.singlePrimaryActionWidthFraction }
            .frame(maxWidth: .infinity)
    }

    func trinketSecondaryActionButton(
        controlSize: ControlSize = .large,
        tint: Color = TrinketDesign.Colors.accent,
        accessibilityIdentifier: String? = nil,
    ) -> some View {
        modifier(GlassButtonModifier(
            controlSize: controlSize,
            tint: tint,
            labelColor: nil,
            isProminent: false,
            accessibilityIdentifier: accessibilityIdentifier,
        ))
    }

    func trinketQuietTapButtonStyle() -> some View {
        buttonStyle(.plain)
    }

    func trinketArtworkCardButtonStyle() -> some View {
        buttonStyle(TrinketPressButtonStyle(pressedScale: TrinketMotion.Interaction.artworkCardPressedScale))
    }

    func trinketSelectionCardButtonStyle() -> some View {
        buttonStyle(TrinketPressButtonStyle(pressedScale: TrinketMotion.Interaction.selectionCardPressedScale))
    }

    func trinketSensoryFeedback(_ feedback: SensoryFeedback, trigger: some Equatable, enabled: Bool) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }

    @ViewBuilder
    func optionalMatchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
