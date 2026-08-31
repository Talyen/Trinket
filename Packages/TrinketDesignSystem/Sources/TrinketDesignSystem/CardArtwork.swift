import SwiftUI

public struct CardArtworkSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape.strokeBorder(
                    TrinketDesign.Colors.subtleStroke,
                    lineWidth: 1,
                )
            }
    }
}

public extension View {
    func cardArtworkSurface() -> some View {
        modifier(CardArtworkSurfaceModifier())
    }

    func cardArtworkPlaceholderBackground(_ style: TrinketDesign.CardPlaceholderStyle) -> some View {
        background(style.color)
    }
}

public struct CardArtworkPlaceholder: View {
    let style: TrinketDesign.CardPlaceholderStyle

    public init(style: TrinketDesign.CardPlaceholderStyle) {
        self.style = style
    }

    public var body: some View {
        ZStack {
            style.color
            Image(systemName: style.symbolName)
                // UIStyleCheck: allow - SF Symbol glyph sizing, not copy
                .font(.system(size: TrinketDesign.Metrics.cardPlaceholderIconPointSize))
                .foregroundStyle(TrinketDesign.Colors.Overlay.paper.opacity(0.85))
        }
        .cardArtworkSurface()
    }
}
