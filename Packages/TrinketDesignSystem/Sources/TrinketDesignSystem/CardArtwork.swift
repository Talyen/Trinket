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
                .font(.system(size: TrinketDesign.Metrics.cardPlaceholderIconPointSize))
                // UIStyleCheck: allow - placeholder glyph needs white contrast
                .foregroundStyle(Color(white: 1).opacity(0.85))
        }
        .cardArtworkSurface()
    }
}
