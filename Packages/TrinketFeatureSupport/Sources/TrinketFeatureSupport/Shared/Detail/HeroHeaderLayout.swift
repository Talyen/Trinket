import CoreGraphics

public enum HeroHeaderLayout {
    public enum HeightPolicy: Equatable {
        case portrait
        case square
        case cinematicLandscape
        case talentTree

        public func height(in containerSize: CGSize) -> CGFloat {
            let width = max(0, containerSize.width)
            let height = max(0, containerSize.height)
            return switch self {
            case .portrait:
                min(max(width * HeroHeaderLayout.headerAspectRatio, HeroHeaderLayout.minimumHeaderHeight), height * 0.60)
            case .square:
                min(max(width, HeroHeaderLayout.minimumHeaderHeight), height * 0.60)
            case .cinematicLandscape:
                min(max(width * 0.78, 288), 344, height * 0.45)
            case .talentTree:
                height * 0.40
            }
        }
    }

    static let minimumHeaderHeight: CGFloat = 300
    static let headerAspectRatio: CGFloat = 4.0 / 3.0

    static func titleOpacity(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat,
        headerHeight: CGFloat,
    ) -> CGFloat {
        // Bottom rubber-banding should not reveal a title beyond the reachable scroll range.
        let scrollableDistance = max(0, contentHeight + topInset + bottomInset - viewportHeight)
        let offset = min(max(offsetY + topInset, 0), scrollableDistance)
        return min(max((offset - (headerHeight - topInset)) / 32, 0), 1)
    }
}
