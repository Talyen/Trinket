import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct BattleHandLayoutTests {
    @Test func `resting hand leaves party resource bars visible on wide portrait canvases`() {
        for size in [
            CGSize(width: 744, height: 1000),
            CGSize(width: 820, height: 1104),
            CGSize(width: 1024, height: 1280),
        ] {
            let battlefield = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size))
            let partyBottom = battlefield.enemySize.height + battlefield.cardSpacing + battlefield.partySize.height
            let handFrame = BattleHandLayout.frame(in: size)
            let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3)

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
            }
        }
    }
}
