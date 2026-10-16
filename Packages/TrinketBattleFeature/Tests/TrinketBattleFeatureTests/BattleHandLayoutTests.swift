import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct BattleHandLayoutTests {
    @Test func `held card and cast origin stay clear of either side bar without changing upward drag distance`() {
        let size = CGSize(width: 150, height: 200)
        let scale: CGFloat = 1.035
        for frame in [CGRect(x: 0, y: 350, width: 382, height: 280), CGRect(x: 84, y: 350, width: 382, height: 280)] {
            let resting = CGPoint(x: frame.midX, y: frame.midY)
            for x in [CGFloat(-1000), 0, 1000] {
                for angle in [CGFloat(-22), 0, 22] {
                    let radians = angle * .pi / 180
                    let translation = CGSize(width: x, height: -120)
                    let center = BattleHandLayout.releaseCenter(
                        restingCenter: resting,
                        dragTranslation: translation,
                        cardSize: size,
                        rotation: radians,
                        scale: scale,
                        in: frame,
                    )
                    for corner in [.zero, CGPoint(x: size.width, y: 0),
                                   CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)] {
                        let relative = CGPoint(
                            x: (corner.x - size.width / 2) * scale,
                            y: (corner.y - size.height / 2) * scale - size.height / 2,
                        ).applying(CGAffineTransform(rotationAngle: radians))
                        #expect(center.x + relative.x >= frame.minX + BattleHandLayout.horizontalInset - 0.001)
                        #expect(center.x + relative.x <= frame.maxX - BattleHandLayout.horizontalInset + 0.001)
                    }
                    #expect(center.y == resting.y - 120)
                }
            }
        }
    }

    @Test func `resting hand leaves party resource bars visible through compact and expanded resizing`() {
        for size in [
            CGSize(width: 402, height: 874),
            CGSize(width: 669, height: 951),
            CGSize(width: 951, height: 669),
            CGSize(width: 874, height: 402),
            // Duo's wide viewports after native side chrome and safe-area reductions.
            CGSize(width: 618, height: 422),
            CGSize(width: 891, height: 625),
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
