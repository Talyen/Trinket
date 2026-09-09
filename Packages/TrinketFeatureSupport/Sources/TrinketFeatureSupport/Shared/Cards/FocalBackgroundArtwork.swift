import SwiftUI
import TrinketContent

public struct FocalBackgroundArtwork: View {
    public let art: BackgroundArtReference
    public var displaySize: Image.PreparedArtworkDisplaySize
    public var interpolation: Image.Interpolation

    private var sourceAspectRatio: CGFloat {
        art.sourceAspectRatio
    }

    public init(
        art: BackgroundArtReference,
        displaySize: Image.PreparedArtworkDisplaySize = .full,
        interpolation: Image.Interpolation = .medium,
    ) {
        self.art = art
        self.displaySize = displaySize
        self.interpolation = interpolation
    }

    public var body: some View {
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
