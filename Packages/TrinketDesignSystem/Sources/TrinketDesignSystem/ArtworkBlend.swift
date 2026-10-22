import SwiftUI

private struct BottomArtworkBlend: View {
    @Environment(\.trinketCanvasColor) private var canvasColor
    let color: Color?
    let fadeFraction: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 1 - min(max(fadeFraction, 0), 1)),
                .init(color: color ?? canvasColor, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom,
        )
    }
}

public extension View {
    func trinketBottomArtworkBlend(color: Color? = nil, fadeFraction: CGFloat = 0.22) -> some View {
        overlay {
            BottomArtworkBlend(color: color, fadeFraction: fadeFraction).allowsHitTesting(false)
        }
    }
}
