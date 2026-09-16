import SwiftUI

private struct BottomArtworkBlend: View {
    let color: Color
    private let clearInset: CGFloat = 0.22

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 1 - clearInset),
                .init(color: color, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom,
        )
    }
}

public extension View {
    func trinketBottomArtworkBlend(color: Color = TrinketDesign.Colors.canvas) -> some View {
        overlay {
            BottomArtworkBlend(color: color).allowsHitTesting(false)
        }
    }
}
