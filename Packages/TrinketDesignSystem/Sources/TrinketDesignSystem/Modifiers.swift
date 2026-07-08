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

    @ScaledMetric(relativeTo: .body) private var iconScale: CGFloat = 1.0
    @ScaledMetric(relativeTo: .caption) private var textScale: CGFloat = 1.0

    public func body(content: Content) -> some View {
        if isLocked {
            content
                .blur(radius: 1.0)
                .saturation(0.20)
                .overlay {
                    Color.black.opacity(0.25)
                        .clipShape(TrinketDesign.cardShape)
                }
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text != nil ? "Locked. \(text!)" : "Locked")
                .overlay {
                    GeometryReader { proxy in
                        let shortSide = min(proxy.size.width, proxy.size.height)
                        let iconSize = min(max(shortSide * 0.25, 16), 48) * iconScale
                        let textSize = min(max(shortSide * 0.10, 11), 18) * textScale
                        let spacing = min(max(shortSide * 0.04, 5), 9)
                        let horizontalPadding = min(max(shortSide * 0.09, 8), 20)

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
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1.5)
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
            .buttonStyle(.glassProminent)
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
