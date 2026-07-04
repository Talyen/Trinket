import SwiftUI


struct OverscrollHeroContainer<Art: View, Overlay: View>: View {
    let baseHeight: CGFloat
    let coordinateSpaceName: String
    let alignment: Alignment
    @ViewBuilder let art: () -> Art
    @ViewBuilder let overlay: () -> Overlay

    init(
        baseHeight: CGFloat,
        coordinateSpaceName: String,
        alignment: Alignment = .bottomLeading,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.baseHeight = baseHeight
        self.coordinateSpaceName = coordinateSpaceName
        self.alignment = alignment
        self.art = art
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { geometry in
            let pullDistance = max(geometry.frame(in: .named(coordinateSpaceName)).minY, 0)
            let height = baseHeight + pullDistance

            ZStack(alignment: alignment) {
                art()
                    .frame(width: geometry.size.width, height: height)

                overlay()
                    .frame(width: geometry.size.width, height: height, alignment: alignment)
            }
            .frame(width: geometry.size.width, height: height)
            .clipped()
            .offset(y: -pullDistance)
        }
        .frame(height: baseHeight)
    }
}
