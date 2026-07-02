import CoreGraphics

enum BattleCardGridLayout {
    static let artAspectRatio: CGFloat = 3.0 / 4.0
    static let gutter: CGFloat = 12
    static let outerPadding: CGFloat = gutter
    static let cardSpacing: CGFloat = gutter

    struct Metrics: Equatable {
        let enemySize: CGSize
        let partySize: CGSize
        let outerPadding: CGFloat
        let cardSpacing: CGFloat
    }

    static func metrics(in containerSize: CGSize) -> Metrics {
        let innerWidth = max(containerSize.width - 2 * outerPadding, 0)
        let innerHeight = max(containerSize.height - 2 * outerPadding, 0)
        guard innerWidth > 0, innerHeight > 0 else {
            return Metrics(enemySize: .zero, partySize: .zero, outerPadding: outerPadding, cardSpacing: cardSpacing)
        }

        let maxPartyWidth = max((innerWidth - cardSpacing) / 2, 0)
        let maxBalancedPartyWidth = max(
            ((innerHeight - cardSpacing) * artAspectRatio - cardSpacing) / 3,
            0
        )
        let partyWidth = min(maxPartyWidth, maxBalancedPartyWidth)
        let partyHeight = partyWidth / artAspectRatio

        let rowWidth = min(innerWidth, 2 * partyWidth + cardSpacing)

        return Metrics(
            enemySize: CGSize(width: rowWidth, height: rowWidth / artAspectRatio),
            partySize: CGSize(width: partyWidth, height: partyHeight),
            outerPadding: outerPadding,
            cardSpacing: cardSpacing
        )
    }
}
