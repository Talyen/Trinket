import SwiftUI
import TrinketContent
import TrinketFeatureSupport

struct HomesteadFocalArtwork: View {
    let art: BackgroundArtReference
    var displaySize: Image.PreparedArtworkDisplaySize = .full
    var interpolation: Image.Interpolation = .medium

    private var sourceAspectRatio: CGFloat {
        art.sourceAspectRatio
    }

    init(
        art: BackgroundArtReference,
        displaySize: Image.PreparedArtworkDisplaySize = .full,
        interpolation: Image.Interpolation = .medium,
    ) {
        self.art = art
        self.displaySize = displaySize
        self.interpolation = interpolation
    }

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            let scale = max(container.width / sourceAspectRatio, container.height)
            let renderedWidth = sourceAspectRatio * scale
            let renderedHeight = scale
            let overflowX = max(renderedWidth - container.width, 0)
            let overflowY = max(renderedHeight - container.height, 0)
            let offsetX = (0.5 - art.focalPoint.x) * overflowX
            let offsetY = (0.5 - art.focalPoint.y) * overflowY

            Image.preparedAsset(art, displaySize: displaySize)
                .resizable()
                .interpolation(interpolation)
                .scaledToFill()
                .frame(width: container.width, height: container.height)
                .decorativePreparedArtwork()
                .offset(x: offsetX, y: offsetY)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
