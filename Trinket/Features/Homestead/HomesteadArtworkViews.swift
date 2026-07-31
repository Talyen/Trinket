import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct HomesteadBuildingArtwork: View {
    enum Variant: Equatable {
        case full
        case thumbnail
    }

    let definition: HomesteadNodeDefinition
    var variant: Variant = .full

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 36

    var body: some View {
        ZStack {
            if let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] {
                // Backgrounds ship full-only; row thumbs scale the same asset.
                HomesteadFocalArtwork(
                    art: art,
                    interpolation: variant == .thumbnail ? .low : .medium
                )
            } else {
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [definition.tint.opacity(0.18), TrinketDesign.Colors.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: definition.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(definition.tint)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous))
    }
}

struct HomesteadFocalArtwork: View {
    let art: BackgroundArtReference
    var imageName: String?
    var interpolation: Image.Interpolation = .medium

    /// Mode, chapter, and homestead art share a 4:3 source crop. Catalog focal
    /// points keep subjects stable across portrait and regular-width layouts.
    private let sourceAspectRatio: CGFloat = 4.0 / 3.0

    init(
        art: BackgroundArtReference,
        imageName: String? = nil,
        interpolation: Image.Interpolation = .medium
    ) {
        self.art = art
        self.imageName = imageName
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

            Image.preparedAsset(named: imageName ?? art.imageName)
                .resizable()
                .interpolation(interpolation)
                .scaledToFill()
                .frame(width: container.width, height: container.height)
                .decorativePreparedArtwork()
                .offset(x: offsetX, y: offsetY)
        }
        .clipped()
    }
}
