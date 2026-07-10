import CoreGraphics

enum BattleCardGridLayout {
    static let enemyAspectRatio: CGFloat = 1
    static let partyAspectRatio: CGFloat = 3.0 / 4.0
    static let gutter: CGFloat = 8
    static let outerPadding: CGFloat = gutter
    static let cardSpacing: CGFloat = gutter
    /// Reserved bottom band for the ability hand (art cards ~2× prior mechanical size).
    static let handReservedHeight: CGFloat = 230
    /// Extra battlefield height reclaimed under the hand so combatants fill side gutters on typical phones.
    static let handOverlapAllowance: CGFloat = 112

    struct Metrics: Equatable {
        let enemySize: CGSize
        let partySize: CGSize
        let outerPadding: CGFloat
        let cardSpacing: CGFloat
        let handReservedHeight: CGFloat
    }

    static func metrics(in containerSize: CGSize, handReservedHeight: CGFloat = handReservedHeight) -> Metrics {
        let innerWidth = max(containerSize.width - 2 * outerPadding, 0)
        let innerHeight = max(
            containerSize.height - 2 * outerPadding - handReservedHeight + handOverlapAllowance,
            0
        )
        guard innerWidth > 0, innerHeight > 0 else {
            return Metrics(
                enemySize: .zero,
                partySize: .zero,
                outerPadding: outerPadding,
                cardSpacing: cardSpacing,
                handReservedHeight: handReservedHeight
            )
        }

        let maxPartyWidthForAvailableWidth = max((innerWidth - cardSpacing) / 2, 0)
        let maxPartyWidthForAvailableHeight = max(
            (
                innerHeight - cardSpacing * (1 + 1 / enemyAspectRatio)
            ) / (
                2 / enemyAspectRatio + 1 / partyAspectRatio
            ),
            0
        )
        let partyWidth = min(maxPartyWidthForAvailableWidth, maxPartyWidthForAvailableHeight)
        let partyHeight = partyWidth / partyAspectRatio

        let partyRowWidth = min(innerWidth, 2 * partyWidth + cardSpacing)

        return Metrics(
            enemySize: CGSize(width: partyRowWidth, height: partyRowWidth / enemyAspectRatio),
            partySize: CGSize(width: partyWidth, height: partyHeight),
            outerPadding: outerPadding,
            cardSpacing: cardSpacing,
            handReservedHeight: handReservedHeight
        )
    }
}
