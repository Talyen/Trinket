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
}
