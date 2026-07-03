import SwiftUI

@available(iOS 26.0, *)
public struct FloatingGlassControlButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .buttonStyle(.glass)
    }
}

@available(iOS 26.0, *)
public struct FloatingGlassToggleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .toggleStyle(.button)
            .buttonStyle(.glass)
    }
}

public struct CardSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

public struct CardLabelSpaceModifier: ViewModifier {
    public let isReserved: Bool

    public func body(content: Content) -> some View {
        if isReserved {
            content
                .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        } else {
            content
        }
    }
}

public struct PrimaryActionButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle)
    }
}

@available(iOS 26.0, *)
public extension View {
    public func trinketFloatingGlassControl() -> some View {
        modifier(FloatingGlassControlButtonModifier())
    }

    public func trinketFloatingGlassToggle() -> some View {
        modifier(FloatingGlassToggleModifier())
    }
}

public extension View {
    public func trinketCardSurface() -> some View {
        modifier(CardSurfaceModifier())
    }

    public func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }

    public func trinketPrimaryActionButton() -> some View {
        modifier(PrimaryActionButtonModifier())
    }
}

public extension Color {
    static let trinketDestructive = TrinketDesign.Colors.destructive
}
