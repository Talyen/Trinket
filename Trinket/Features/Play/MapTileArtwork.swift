import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct MapTileArtwork: View {
    let art: any PreparedArtworkReference
    var prefersThumbnail = false

    var body: some View {
        Image.preparedAsset(
            art,
            displaySize: prefersThumbnail ? .compact : .full,
        )
        .resizable()
        .scaledToFill()
        .decorativePreparedArtwork()
    }
}

struct MapTilePlaceholder: View {
    let tint: Color
    let icon: GameIcon

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 42

    var body: some View {
        ZStack {
            tint.opacity(0.14)
            GameIconImage(icon)
                // UIStyleCheck: allow - Game icon glyph sizing, not copy
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}
