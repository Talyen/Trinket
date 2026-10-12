import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct BattleHandLayoutTests {
    @Test func `resting hand leaves party resource bars visible through compact and expanded resizing`() {
        for size in [
            CGSize(width: 402, height: 874),
            CGSize(width: 669, height: 951),
            CGSize(width: 951, height: 669),
            CGSize(width: 874, height: 402),
            CGSize(width: 744, height: 1000),
            CGSize(width: 820, height: 1104),
            CGSize(width: 1024, height: 1280),
        ] {
            let battlefield = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size))
            let partyBottom = battlefield.enemySize.height + battlefield.cardSpacing + battlefield.partySize.height
            let handFrame = BattleHandLayout.frame(in: size)
            let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: handFrame.height)

            #expect(hand.cardWidth <= BattleHandLayout.maxCardWidth)
            #expect(hand.cardWidth > 0)
            #expect(hand.cardHeight == hand.cardWidth * BattleHandLayout.aspectRatio)

            for index in 0 ..< 3 {
                let center = BattleHandLayout.restingCenter(
                    index: index,
                    metrics: hand,
                    cardCount: 3,
                    handFrame: handFrame,
                )
                let bottomAnchoredCard = CGRect(
                    x: -hand.cardWidth / 2,
                    y: -hand.cardHeight,
                    width: hand.cardWidth,
                    height: hand.cardHeight,
                )
                let rotatedCard = bottomAnchoredCard.applying(CGAffineTransform(
                    rotationAngle: BattleHandLayout.rotation(index: index, cardCount: 3) * .pi / 180,
                ))
                let restingTop = center.y + hand.cardHeight / 2 + rotatedCard.minY
                #expect(partyBottom < restingTop)
                let restingBottom = center.y + hand.cardHeight / 2 + rotatedCard.maxY
                #expect(restingBottom <= size.height)
                #expect(center.x + rotatedCard.minX >= 0)
                #expect(center.x + rotatedCard.maxX <= size.width)
            }
        }
    }
}
