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

    public func body(content: Content) -> some View {
        if isLocked {
            content
                .blur(radius: 1.5)
                .saturation(0.40)
                .overlay {
                    GeometryReader { proxy in
                        let shortSide = min(proxy.size.width, proxy.size.height)
                        let iconSize = min(max(shortSide * 0.20, 13), 40)
                        let textSize = min(max(shortSide * 0.080, 10), 16)
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
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.40), radius: 3, x: 0, y: 1)
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
