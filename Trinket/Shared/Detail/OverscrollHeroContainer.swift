import SwiftUI
import TrinketDesignSystem

struct OverscrollHeroContainer<Art: View, Overlay: View>: View {
    let baseHeight: CGFloat
    let overscroll: CGFloat
    let alignment: Alignment
    let artworkBlend: ArtworkBlend
    @ViewBuilder let art: () -> Art
    @ViewBuilder let overlay: () -> Overlay

    init(
        baseHeight: CGFloat,
        overscroll: CGFloat,
        alignment: Alignment = .bottomLeading,
        artworkBlend: ArtworkBlend = .none,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.baseHeight = baseHeight
        self.overscroll = overscroll
        self.alignment = alignment
        self.artworkBlend = artworkBlend
        self.art = art
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: baseHeight, overscroll: overscroll)

            ZStack(alignment: alignment) {
                art()
                    .frame(width: geometry.size.width, height: metrics.height)
                    .trinketArtworkBlend(artworkBlend)

                overlay()
                    .frame(width: geometry.size.width, height: metrics.height, alignment: alignment)
            }
            .frame(width: geometry.size.width, height: metrics.height)
            .clipped()
            .offset(y: metrics.offsetY)
        }
        .frame(height: baseHeight)
    }
}
