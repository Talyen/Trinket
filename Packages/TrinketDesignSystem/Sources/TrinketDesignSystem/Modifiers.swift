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
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

public struct LockedCardEffectModifier: ViewModifier {
    public let isLocked: Bool
    public let text: String?

    public func body(content: Content) -> some View {
        if isLocked {
            content
                .blur(radius: 3)
                .saturation(0.15)
                .opacity(0.68)
                .overlay {
                    TrinketDesign.cardShape
                        .fill(.black.opacity(0.36))

                    GeometryReader { proxy in
                        let shortSide = min(proxy.size.width, proxy.size.height)
                        let iconSize = min(max(shortSide * 0.16, 13), 32)
                        let textSize = min(max(shortSide * 0.065, 10), 13)
                        let spacing = min(max(shortSide * 0.035, 4), 7)
                        let horizontalPadding = min(max(shortSide * 0.08, 8), 18)

                        VStack(spacing: spacing) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: iconSize, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)

                            if let text {
                                Text(text)
                                    .font(.system(size: textSize, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)
                                    .padding(.horizontal, horizontalPadding)
                            }
                        }
                        .foregroundStyle(Color(.systemGray3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
        } else {
            content
        }
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
    func trinketFloatingGlassControl() -> some View {
        modifier(FloatingGlassControlButtonModifier())
    }

    func trinketFloatingGlassToggle() -> some View {
        modifier(FloatingGlassToggleModifier())
    }
}

public extension View {
    func trinketCardSurface() -> some View {
        modifier(CardSurfaceModifier())
    }

    func trinketLockedCardEffect(isLocked: Bool, text: String? = nil) -> some View {
        modifier(LockedCardEffectModifier(isLocked: isLocked, text: text))
    }

    func trinketCardLabelSpace(_ isReserved: Bool = true) -> some View {
        modifier(CardLabelSpaceModifier(isReserved: isReserved))
    }

    func trinketPrimaryActionButton() -> some View {
        modifier(PrimaryActionButtonModifier())
    }
}

public extension Color {
    static let trinketDestructive = TrinketDesign.Colors.destructive
}
