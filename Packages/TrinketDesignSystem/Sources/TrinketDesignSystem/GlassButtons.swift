import SwiftUI

private struct GlassButtonModifier: ViewModifier {
    let controlSize: ControlSize
    let tint: Color
    let labelColor: Color?
    let isProminent: Bool
    let accessibilityIdentifier: String?
    var borderShape: ButtonBorderShape = .roundedRectangle

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
        .buttonBorderShape(borderShape)
        .trinketAccessibilityIdentifier(accessibilityIdentifier)
    }

    private struct ForegroundModifier: ViewModifier {
        @Environment(\.isEnabled) private var isEnabled

        let color: Color?
        func body(content: Content) -> some View {
            if let color, isEnabled {
                content.foregroundStyle(color)
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
        containerRelativeFrame(.horizontal) { width, _ in width * TrinketDesign.Layout.singlePrimaryActionWidthFraction }
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

    func trinketIconButton(accessibilityIdentifier: String? = nil) -> some View {
        labelStyle(.iconOnly)
            .modifier(GlassButtonModifier(
                controlSize: .large,
                tint: TrinketDesign.Colors.Overlay.paper,
                labelColor: TrinketDesign.Colors.Overlay.paper,
                isProminent: false,
                accessibilityIdentifier: accessibilityIdentifier,
                borderShape: .circle,
            ))
    }

    func trinketArtworkCardButtonStyle(
        pressedScale: CGFloat = TrinketMotion.Interaction.artworkCardPressedScale,
    ) -> some View {
        buttonStyle(TrinketPressButtonStyle(pressedScale: pressedScale))
    }
}
