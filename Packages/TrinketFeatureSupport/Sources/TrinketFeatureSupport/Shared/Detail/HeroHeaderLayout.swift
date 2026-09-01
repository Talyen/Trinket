import CoreGraphics

public enum HeroHeaderLayout {
    public enum HeightPolicy: Equatable {
        case portrait
        case cinematicLandscape

        public func height(forWidth width: CGFloat) -> CGFloat {
            switch self {
            case .portrait:
                max(width * HeroHeaderLayout.headerAspectRatio, HeroHeaderLayout.minimumHeaderHeight)
            case .cinematicLandscape:
                min(max(width * 0.78, 288), 344)
            }
        }
    }

    static let minimumHeaderHeight: CGFloat = 300
    static let headerAspectRatio: CGFloat = 4.0 / 3.0
    static let pickerRowCardWidth: CGFloat = 100
    static let pickerRowCardHeight: CGFloat = pickerRowCardWidth * headerAspectRatio

    struct OverscrollMetrics: Equatable {
        let height: CGFloat
        let offsetY: CGFloat
    }

    @available(*, deprecated, renamed: "HeightPolicy.portrait.height(forWidth:)")
    static func headerHeight(forWidth width: CGFloat) -> CGFloat {
        HeightPolicy.portrait.height(forWidth: width)
    }

    static var scrimHeight: CGFloat {
        minimumHeaderHeight * (140.0 / 300.0)
    }

    static let portraitAspect = headerAspectRatio

    static func overscroll(contentOffsetY: CGFloat, topInset: CGFloat) -> CGFloat {
        max(-(contentOffsetY + topInset), 0)
    }

    static func overscrollMetrics(baseHeight: CGFloat, overscroll: CGFloat) -> OverscrollMetrics {
        OverscrollMetrics(
            height: baseHeight + overscroll,
            offsetY: -overscroll,
        )
    }
}
