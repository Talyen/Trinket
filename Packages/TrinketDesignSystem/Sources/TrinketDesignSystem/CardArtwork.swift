import SwiftUI

public struct CardArtworkSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .clipShape(TrinketDesign.cardShape)
            .overlay { TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1) }
    }
}

public extension View {
    func cardArtworkSurface() -> some View {
        modifier(CardArtworkSurfaceModifier())
    }
}
