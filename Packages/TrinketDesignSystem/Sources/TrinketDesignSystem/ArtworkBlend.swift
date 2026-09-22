import SwiftUI

private struct BottomArtworkBlend: View {
    @Environment(\.trinketCanvasColor) private var canvasColor
    let color: Color?
    private let clearInset: CGFloat = 0.22

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 1 - clearInset),
                .init(color: color ?? canvasColor, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom,
        )
    }
}

public extension View {
    func trinketBottomArtworkBlend(color: Color? = nil) -> some View {
        overlay {
            BottomArtworkBlend(color: color).allowsHitTesting(false)
        }
    }
}
