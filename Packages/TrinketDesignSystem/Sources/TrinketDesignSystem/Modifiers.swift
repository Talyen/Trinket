import SwiftUI

struct CardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = TrinketDesign.Corners.card

    func body(content: Content) -> some View {
        // Single source of truth is `trinketSurface(.card)` (VisualFoundation).
        // This modifier remains for call sites that need a custom cornerRadius override.
        content.trinketSurface(.card)
    }
}

struct LockedCardEffectModifier: ViewModifier {
    let isLocked: Bool
    let cornerRadius: CGFloat

    @ScaledMetric(relativeTo: .body)
    private var lockIconSize: CGFloat = 34

    private static let lockedBlurRadius: CGFloat = 1
    private static let lockedSaturation: Double = 0.35

    init(
        isLocked: Bool,
        cornerRadius: CGFloat = TrinketDesign.Corners.card
    ) {
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
        let ink = TrinketDesign.Colors.Overlay.ink
        return Image(systemName: "lock.fill")
            .font(.system(size: lockIconSize))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            .shadow(color: ink.opacity(0.95), radius: 0, x: 0, y: 1)
            .shadow(color: ink.opacity(0.9), radius: 0, x: 0, y: -1)
            .shadow(color: ink.opacity(0.9), radius: 0, x: 1, y: 0)
            .shadow(color: ink.opacity(0.9), radius: 0, x: -1, y: 0)
            .shadow(color: ink.opacity(0.55), radius: 3, x: 0, y: 1.5)
            .drawingGroup()
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

private struct GlassActionButtonModifier: ViewModifier {
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
        .modifier(OptionalForegroundModifier(color: labelColor))
        .controlSize(controlSize)
        .buttonBorderShape(.roundedRectangle)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

private struct OptionalForegroundModifier: ViewModifier {
    let color: Color?
    func body(content: Content) -> some View {
        if let color {
            content.foregroundStyle(color)
        } else {
            content
        }
    }
}

struct PrimaryActionButtonModifier: ViewModifier {
    let controlSize: ControlSize
    let tint: Color
    let labelColor: Color
    let accessibilityIdentifier: String?

    func body(content: Content) -> some View {
        content.modifier(GlassActionButtonModifier(
            controlSize: controlSize,
            tint: tint,
            labelColor: labelColor,
            isProminent: true,
            accessibilityIdentifier: accessibilityIdentifier
        ))
    }
}

struct SecondaryActionButtonModifier: ViewModifier {
    let controlSize: ControlSize
    let tint: Color
    let accessibilityIdentifier: String?

    func body(content: Content) -> some View {
        content.modifier(GlassActionButtonModifier(
            controlSize: controlSize,
            tint: tint,
            labelColor: nil,
            isProminent: false,
            accessibilityIdentifier: accessibilityIdentifier
        ))
    }
}

private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

/// Tap target with no press chrome and no system dimming.
///
/// Prefer this over `.buttonStyle(.plain)` for artwork and other custom content
/// inside scroll views. `.plain` still flashes while the finger is down during a
/// scroll drag; this style keeps `Button` semantics (including tap-to-open) and
/// ignores `isPressed` for visuals.
struct QuietTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
    /// Applies `accessibilityIdentifier` when non-nil. Prefer this over a local
    /// optional-identifier copy; glass CTAs still apply IDs after button styles.
    func trinketAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(OptionalAccessibilityIdentifierModifier(identifier: identifier))
    }

    /// Selection stroke for 3:4 artwork picker tiles (loadout / party grids).
    func trinketArtworkPickerSelectionBorder(
        isSelected: Bool,
        color: Color = TrinketDesign.Colors.accent,
        lineWidth: CGFloat = 3
    ) -> some View {
        overlay {
            TrinketDesign.cardShape.strokeBorder(
                isSelected ? color : .clear,
                lineWidth: isSelected ? lineWidth : 0
            )
        }
    }

    func trinketCardSurface(cornerRadius: CGFloat = TrinketDesign.Corners.card) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius))
    }

    func trinketLockedCardEffect(
        isLocked: Bool,
        cornerRadius: CGFloat = TrinketDesign.Corners.card
    ) -> some View {
        modifier(LockedCardEffectModifier(isLocked: isLocked, cornerRadius: cornerRadius))
    }

    func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }

    func trinketPrimaryActionButton(
        controlSize: ControlSize = .large,
        tint: Color = TrinketDesign.Colors.accent,
        labelColor: Color = TrinketDesign.Colors.canvas,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        modifier(PrimaryActionButtonModifier(
            controlSize: controlSize,
            tint: tint,
            labelColor: labelColor,
            accessibilityIdentifier: accessibilityIdentifier
        ))
    }

    /// Half-width, horizontally centered layout for a lone screen primary action.
    func trinketCenteredPrimaryAction() -> some View {
        containerRelativeFrame(.horizontal) { width, _ in
            width * TrinketDesign.Metrics.singlePrimaryActionWidthFraction
        }
        .frame(maxWidth: .infinity)
    }

    /// Quieter glass chrome for secondary actions (not the screen's primary CTA).
    func trinketSecondaryActionButton(
        controlSize: ControlSize = .large,
        tint: Color = TrinketDesign.Colors.accent,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        modifier(SecondaryActionButtonModifier(
            controlSize: controlSize,
            tint: tint,
            accessibilityIdentifier: accessibilityIdentifier
        ))
    }

    func trinketQuietTapButtonStyle() -> some View {
        buttonStyle(QuietTapButtonStyle())
    }

    /// Subtle touch-down feedback for large, stationary artwork navigation cards.
    func trinketArtworkCardButtonStyle() -> some View {
        buttonStyle(TrinketPressButtonStyle(
            pressedScale: TrinketMotion.Interaction.artworkCardPressedScale
        ))
    }

    /// Nearly imperceptible touch-down feedback for stationary selection tiles.
    func trinketSelectionCardButtonStyle() -> some View {
        buttonStyle(TrinketPressButtonStyle(
            pressedScale: TrinketMotion.Interaction.selectionCardPressedScale
        ))
    }

    /// Gates system sensory feedback on the Options haptics toggle.
    func trinketSensoryFeedback(
        _ feedback: SensoryFeedback,
        trigger: some Equatable,
        enabled: Bool
    ) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }

    @ViewBuilder
    func optionalMatchedTransitionSource<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
