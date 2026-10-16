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
                min(max(width * 0.92, 336), 392)
            }
        }
    }

    static let minimumHeaderHeight: CGFloat = 300
    static let headerAspectRatio: CGFloat = 4.0 / 3.0
}
