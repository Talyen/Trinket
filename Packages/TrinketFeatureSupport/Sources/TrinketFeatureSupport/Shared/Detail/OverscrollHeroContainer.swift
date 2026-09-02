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
        ZStack(alignment: alignment) {
            art()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .trinketArtworkBlend(artworkBlend)
                .backgroundExtensionEffect()
                .allowsHitTesting(false)
                .frame(height: baseHeight)
                .clipped()
                .visualEffect { content, proxy in
                    let rawOverscroll = max(proxy.frame(in: .scrollView(axis: .vertical)).minY, 0)
                    let metrics = HeroHeaderLayout.overscrollMetrics(baseHeight: baseHeight, overscroll: rawOverscroll)
                    let stretch = baseHeight > 0 ? metrics.height / baseHeight : 1
                    return content
                        .scaleEffect(stretch, anchor: .top)
                        .offset(y: metrics.offsetY)
                }

            overlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .frame(height: baseHeight)
                .clipped()
        }
        .frame(height: baseHeight)
    }
}
