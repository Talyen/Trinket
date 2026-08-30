import CoreGraphics
import TrinketFeatureSupport

enum BattleCardGridLayout {
    static let enemyAspectRatio: CGFloat = 4.0 / 3.0
    static let partyAspectRatio: CGFloat = 3.0 / 4.0
    static let outerPadding: CGFloat = 0
    static let cardSpacing: CGFloat = 12
    static let combatantScale: CGFloat = 0.90
    static let handReservedHeight: CGFloat = 224
    static let handOverlapAllowance: CGFloat = 56

    struct Metrics: Equatable {
        let enemySize: CGSize
        let partySize: CGSize
        let outerPadding: CGFloat
        let cardSpacing: CGFloat
        let handReservedHeight: CGFloat
    }

    struct FeedbackAnchors: Equatable {
        let enemy: CGPoint
        let hero: CGPoint
        let companion: CGPoint
    }

    static func feedbackAnchors(containerWidth: CGFloat, layout: Metrics) -> FeedbackAnchors {
        let centerX = containerWidth / 2
        let partyCenterY = layout.enemySize.height
            + layout.cardSpacing
            + layout.partySize.height / 2
        let partyCenterOffset = (layout.partySize.width + layout.cardSpacing) / 2
        return FeedbackAnchors(
            enemy: CGPoint(x: centerX, y: layout.enemySize.height / 2),
            hero: CGPoint(x: centerX - partyCenterOffset, y: partyCenterY),
            companion: CGPoint(x: centerX + partyCenterOffset, y: partyCenterY),
        )
    }

    static func metrics(in containerSize: CGSize, handReservedHeight: CGFloat = handReservedHeight) -> Metrics {
        let innerWidth = max(containerSize.width - 2 * outerPadding, 0)
        let innerHeight = max(
            containerSize.height - 2 * outerPadding - handReservedHeight + handOverlapAllowance,
            0,
        )
        guard innerWidth > 0, innerHeight > 0 else {
            return Metrics(
                enemySize: .zero,
                partySize: .zero,
                outerPadding: outerPadding,
                cardSpacing: cardSpacing,
                handReservedHeight: handReservedHeight,
            )
        }

        let maxPartyWidthForAvailableWidth = max((innerWidth - cardSpacing) / 2, 0)
        let maxPartyWidthForAvailableHeight = max(
            (
                innerHeight - cardSpacing * (1 + 1 / enemyAspectRatio)
            ) / (
                2 / enemyAspectRatio + 1 / partyAspectRatio
            ),
            0,
        )
        let fullPartyWidth = min(maxPartyWidthForAvailableWidth, maxPartyWidthForAvailableHeight)
        let fullPartyRowWidth = min(innerWidth, 2 * fullPartyWidth + cardSpacing)
        let rowWidth = fullPartyRowWidth * combatantScale
        let partyWidth = max((rowWidth - cardSpacing) / 2, 0)
        let partyHeight = partyWidth / partyAspectRatio

        return Metrics(
            enemySize: CGSize(width: rowWidth, height: rowWidth / enemyAspectRatio),
            partySize: CGSize(width: partyWidth, height: partyHeight),
            outerPadding: outerPadding,
            cardSpacing: cardSpacing,
            handReservedHeight: handReservedHeight,
        )
    }
}
