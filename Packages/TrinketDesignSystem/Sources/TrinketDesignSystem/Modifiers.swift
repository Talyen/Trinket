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
            .overlay {
                shape.strokeBorder(palette.subtleStroke, lineWidth: 1)
            }
    }
}

struct LockedCardEffectModifier: ViewModifier {
    let isLocked: Bool
    let text: String?
    let cornerRadius: CGFloat

    @ScaledMetric(relativeTo: .body)
    private var lockIconSize: CGFloat = 34

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
    let accessibilityIdentifier: String?

    func body(content: Content) -> some View {
        // Apply the test selector *after* `.glassProminent`. Identifiers attached before
        // the glass style are dropped from the XCUITest tree (label remains, id does not).
        content
            .buttonStyle(.glassProminent)
            .tint(tint)
            .foregroundStyle(labelColor)
            .controlSize(controlSize)
            .buttonBorderShape(.roundedRectangle)
            .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
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
public struct QuietTapButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

public extension View {
    /// Selection stroke for 3:4 artwork picker tiles (loadout / party grids).
    func trinketArtworkPickerSelectionBorder(
        isSelected: Bool,
        color: Color = TrinketDesign.Colors.selection,
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

    func trinketQuietTapButtonStyle() -> some View {
        buttonStyle(QuietTapButtonStyle())
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
