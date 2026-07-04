import CoreGraphics


enum HeroHeaderLayout {
    static func headerHeight(forWidth width: CGFloat) -> CGFloat {
        max(width * 4.0 / 3.0, 300)
    }

    static func overscrollScale(baseHeight: CGFloat, pullDistance: CGFloat) -> CGFloat {
        (baseHeight + pullDistance) / baseHeight
    }
}
