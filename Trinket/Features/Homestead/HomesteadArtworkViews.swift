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

    var body: some View {
        // Homestead projects require authored art; the catalog invariant test
        // fails if a node is ever added without it.
        HomesteadFocalArtwork(
            art: art,
            displaySize: variant == .thumbnail ? .compact : .full,
            interpolation: variant == .thumbnail ? .low : .medium
        )
        .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous))
    }

    private var art: BackgroundArtReference {
        guard let art = ArtCatalog.backgroundArtByID[definition.id.rawValue] else {
            preconditionFailure("Missing Homestead artwork for \(definition.id.rawValue)")
        }
        return art
    }
}

struct HomesteadFocalArtwork: View {
    let art: BackgroundArtReference
    var displaySize: Image.PreparedArtworkDisplaySize = .full
    var interpolation: Image.Interpolation = .medium

    /// Mode, chapter, and homestead art share a 4:3 source crop. Catalog focal
    /// points keep subjects stable across portrait and regular-width layouts.
    private let sourceAspectRatio: CGFloat = 4.0 / 3.0

    init(
        art: BackgroundArtReference,
        displaySize: Image.PreparedArtworkDisplaySize = .full,
        interpolation: Image.Interpolation = .medium
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
    }
}
