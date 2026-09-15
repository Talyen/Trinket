import SwiftUI
import TrinketContent
import TrinketFeatureSupport

struct FullGameOfferArtwork: View {
    let imageName: String
    let focalPoint: ArtFocalPoint

    var body: some View {
        GeometryReader { geometry in
            Image.preparedAsset(named: imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(cropOffset(in: geometry.size))
                .decorativePreparedArtwork()
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private func cropOffset(in container: CGSize) -> CGSize {
        guard let source = PreparedArtworkCache.shared.image(named: imageName)?.size,
              source.width > 0, source.height > 0 else {
            return .zero
        }
        let scale = max(container.width / source.width, container.height / source.height)
        let overflowX = max(source.width * scale - container.width, 0)
        let overflowY = max(source.height * scale - container.height, 0)
        return CGSize(
            width: (0.5 - focalPoint.x) * overflowX,
            height: (0.5 - focalPoint.y) * overflowY,
        )
    }
}
