import SwiftUI

struct ChapterStageSelectView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let chapter: Chapter
    let progress: JourneyProgressState
    let onStageTap: (Stage) -> Void

    var body: some View {
        GeometryReader { geometry in
            let headerHeight = Self.headerHeight(for: geometry.size.height)

            VStack(spacing: 0) {
                ChapterHeroHeader(
                    chapter: chapter,
                    height: headerHeight
                )

                StageDeckView(
                    deck: visibleDeck,
                    scrollAnimation: scrollAnimation,
                    onStageTap: onStageTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TrinketDesign.Colors.appBackground)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(TrinketDesign.Colors.appBackground)
            .accessibilityIdentifier(AccessibilityID.Screen.play)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var visibleDeck: VisibleStageDeck {
        VisibleStageDeck(
            chapters: GameContent.chapters,
            chapter: chapter,
            progress: progress
        )
    }

    private var scrollAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.45)
    }

    private static func headerHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.66, 390), 560)
    }
}
