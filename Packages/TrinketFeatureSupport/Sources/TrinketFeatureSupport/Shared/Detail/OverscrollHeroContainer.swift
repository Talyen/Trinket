import SwiftUI
import TrinketDesignSystem

struct OverscrollHeroContainer<Art: View, Overlay: View>: View {
    let baseHeight: CGFloat
    let alignment: Alignment
    let artworkBlend: ArtworkBlend
    @ViewBuilder let art: () -> Art
    @ViewBuilder let overlay: () -> Overlay

    init(
        baseHeight: CGFloat,
        alignment: Alignment = .bottomLeading,
        artworkBlend: ArtworkBlend = .none,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder overlay: @escaping () -> Overlay,
    ) {
        self.baseHeight = baseHeight
        self.alignment = alignment
        self.artworkBlend = artworkBlend
        self.art = art
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { geometry in
            let rawOverscroll = max(geometry.frame(in: .scrollView(axis: .vertical)).minY, 0)
            let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: baseHeight, overscroll: rawOverscroll)
            let overscroll = metrics.offsetY == 0 ? rawOverscroll : -metrics.offsetY
            let height = metrics.height

            ZStack(alignment: alignment) {
                art()
                    .frame(width: geometry.size.width, height: height)
                    .trinketArtworkBlend(artworkBlend)
                    .backgroundExtensionEffect()
                    .allowsHitTesting(false)

                overlay()
                    .frame(width: geometry.size.width, height: height, alignment: alignment)
            }
            .frame(width: geometry.size.width, height: height)
            .clipped()
            .offset(y: -overscroll)
        }
        .frame(height: baseHeight)
    }
}
