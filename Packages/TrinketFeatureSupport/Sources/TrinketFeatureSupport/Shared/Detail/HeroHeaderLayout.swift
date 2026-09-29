import CoreGraphics

public enum HeroHeaderLayout {
    public enum HeightPolicy: Equatable {
        case portrait
        case square
        case cinematicLandscape
        case talentTree

        public func height(forWidth width: CGFloat) -> CGFloat {
            switch self {
            case .portrait:
                max(width * HeroHeaderLayout.headerAspectRatio, HeroHeaderLayout.minimumHeaderHeight)
            case .square:
                max(width, HeroHeaderLayout.minimumHeaderHeight)
            case .cinematicLandscape:
                min(max(width * 0.78, 288), 344)
            case .talentTree:
                min(max(width * 0.92, 336), 392)
            }
        }
    }

    static let minimumHeaderHeight: CGFloat = 300
    static let headerAspectRatio: CGFloat = 4.0 / 3.0
}
