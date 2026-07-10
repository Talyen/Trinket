import CoreGraphics

/// Shared sizing rules for full-bleed hero headers, scrims, and compact picker thumbs.
///
/// - Full-bleed detail heroes: width × 4/3, minimum 300 (`headerHeight`).
/// - Bottom scrim on those heroes: ~47% of the minimum header (140pt), not a third competing system.
/// - Picker list thumbs: 3:4 art at ~100pt width → 133pt height (`pickerRowCardHeight`).
enum HeroHeaderLayout {
    /// Minimum full-bleed hero height (also the reference for scrim proportion).
    static let minimumHeaderHeight: CGFloat = 300
    /// Portrait aspect for full-bleed combatant/item heroes.
    static let headerAspectRatio: CGFloat = 4.0 / 3.0
    /// Approximate card width used when sizing compact picker-row thumbs.
    static let pickerRowCardWidth: CGFloat = 100
    /// 3:4 thumb height for ability/item picker rows (`pickerRowCardWidth` × 4/3).
    static let pickerRowCardHeight: CGFloat = pickerRowCardWidth * headerAspectRatio

    struct OverscrollMetrics: Equatable {
        let height: CGFloat
        let offsetY: CGFloat
    }

    static func headerHeight(forWidth width: CGFloat) -> CGFloat {
        max(width * headerAspectRatio, minimumHeaderHeight)
    }

    /// Bottom gradient scrim on full-bleed heroes — proportional to minimum header height.
    static var scrimHeight: CGFloat {
        minimumHeaderHeight * (140.0 / 300.0)
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
