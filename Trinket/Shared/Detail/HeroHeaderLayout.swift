import CoreGraphics

enum HeroHeaderLayout {
    struct OverscrollMetrics: Equatable {
        let height: CGFloat
        let offsetY: CGFloat
    }

    static func headerHeight(forWidth width: CGFloat) -> CGFloat {
        max(width * 4.0 / 3.0, 300)
    }

    static func overscrollScale(baseHeight: CGFloat, pullDistance: CGFloat) -> CGFloat {
        (baseHeight + pullDistance) / baseHeight
    }

    static func overscroll(contentOffsetY: CGFloat, topInset: CGFloat) -> CGFloat {
        max(-(contentOffsetY + topInset), 0)
    }

    /// Keeps the hero artwork pinned to the top while rubber-band scrolling expands the visible frame.
    static func overscrollMetrics(baseHeight: CGFloat, overscroll: CGFloat) -> OverscrollMetrics {
        OverscrollMetrics(
            height: baseHeight + overscroll,
            offsetY: -overscroll
        )
    }
}
