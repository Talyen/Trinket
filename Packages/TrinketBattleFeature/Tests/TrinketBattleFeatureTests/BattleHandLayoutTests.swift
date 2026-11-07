import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct BattleHandLayoutTests {
    @Test func `iPad fills the battlefield above a larger bottom anchored hand through resizing`() {
        for size in [
            CGSize(width: 744, height: 1000),
            CGSize(width: 820, height: 1104),
            CGSize(width: 1032, height: 1304),
            CGSize(width: 1376, height: 960),
            CGSize(width: 507, height: 1000),
            CGSize(width: 320, height: 700),
        ] {
            let frame = BattleHandLayout.frame(in: size, isPad: true)
            let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: frame.height, isPad: true)
            let center = BattleHandLayout.restingCenter(index: 1, metrics: hand, cardCount: 3, handFrame: frame)
            #expect(abs(center.y + hand.cardHeight / 2 - size.height - 2) < 0.001)
            if size.width >= 744 {
                let originalFrame = BattleHandLayout.frame(in: size)
                let originalHand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: originalFrame.height)
                #expect(hand.cardWidth > originalHand.cardWidth)
            }

            let field = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size, isPad: true), scale: 1)
            let partyBottom = field.enemySize.height + field.cardSpacing + field.partySize.height
            var lowestHandTop = CGFloat.greatestFiniteMagnitude
            for index in 0 ..< 3 {
                let resting = BattleHandLayout.restingCenter(index: index, metrics: hand, cardCount: 3, handFrame: frame)
                let bounds = CGRect(x: -hand.cardWidth / 2, y: -hand.cardHeight, width: hand.cardWidth, height: hand.cardHeight)
                    .applying(CGAffineTransform(rotationAngle: BattleHandLayout.rotation(index: index, cardCount: 3) * .pi / 180))
                lowestHandTop = min(lowestHandTop, resting.y + hand.cardHeight / 2 + bounds.minY)
                #expect(resting.x + bounds.minX >= 0)
                #expect(resting.x + bounds.maxX <= size.width)
            }
            let gap = lowestHandTop - partyBottom
            #expect(gap >= 8 - 0.001)
            #expect(gap <= 8 + 0.001 || abs(field.enemySize.width - size.width) < 0.001)
        }
    }

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

    @Test func `middle hand card barely clips the bottom on every canvas`() {
        for size in Self.canvases {
            for isPad in [false, true] {
                let frame = BattleHandLayout.frame(in: size, isPad: isPad)
                for count in [1, 3] {
                    let hand = BattleHandLayout.metrics(
                        containerWidth: size.width,
                        cardCount: count,
                        handHeight: frame.height,
                        isPad: isPad,
                    )
                    let center = BattleHandLayout.restingCenter(index: count / 2, metrics: hand, cardCount: count, handFrame: frame)
                    #expect(abs(center.x - size.width / 2) < 0.001)
                    #expect(abs(center.y + hand.cardHeight / 2 - size.height - 2) < 0.001)
                }
            }
        }
    }

    @Test func `stacked combatants fill the space above the rotated fan without overlap`() {
        for size in Self.canvases {
            for isPad in [false, true] {
                let scale = BattleCardGridLayout.scale(in: size, isPad: isPad)
                let field = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size, isPad: isPad), scale: scale)
                let partyBottom = field.enemySize.height + field.cardSpacing + field.partySize.height
                let frame = BattleHandLayout.frame(in: size, isPad: isPad)
                let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: frame.height, isPad: isPad)
                #expect(hand.cardWidth > 0)
                #expect(hand.cardWidth <= (isPad ? BattleHandLayout.maxPadCardWidth : BattleHandLayout.maxCardWidth))
                var lowestHandTop = CGFloat.greatestFiniteMagnitude
                for index in 0 ..< 3 {
                    let center = BattleHandLayout.restingCenter(index: index, metrics: hand, cardCount: 3, handFrame: frame)
                    let bounds = CGRect(x: -hand.cardWidth / 2, y: -hand.cardHeight, width: hand.cardWidth, height: hand.cardHeight)
                        .applying(CGAffineTransform(rotationAngle: BattleHandLayout.rotation(index: index, cardCount: 3) * .pi / 180))
                    lowestHandTop = min(lowestHandTop, center.y + hand.cardHeight / 2 + bounds.minY)
                    #expect(center.x + bounds.minX >= -0.001)
                    #expect(center.x + bounds.maxX <= size.width + 0.001)
                }
                let gap = lowestHandTop - partyBottom
                #expect(gap >= 8 - 0.001)
                // The stack fills height unless its existing horizontal margin limits width.
                #expect(gap <= 8 + 0.001 || abs(field.enemySize.width - size.width * scale) < 0.001)
                #expect(abs(field.enemySize.width / field.enemySize.height - 4.0 / 3.0) < 0.001)
                #expect(abs(field.partySize.width / field.partySize.height - 3.0 / 4.0) < 0.001)
            }
        }
    }

    @Test func `landscape combatants grow within the existing enemy over party composition`() {
        let cases: [(CGSize, CGFloat)] = [
            (CGSize(width: 951, height: 669), 268.20),
            (CGSize(width: 874, height: 402), 159.64),
            (CGSize(width: 618, height: 422), 167.77),
            (CGSize(width: 891, height: 625), 250.31),
        ]
        for (size, previousEnemyWidth) in cases {
            let field = BattleCardGridLayout.metrics(
                in: BattleHandLayout.battlefieldSize(in: size),
                scale: BattleCardGridLayout.scale(in: size, isPad: false),
            )
            #expect(field.enemySize.width > previousEnemyWidth * 1.15)
            #expect(abs(field.enemySize.width - (2 * field.partySize.width + field.cardSpacing)) < 0.001)
        }
    }

    @Test func `ordinary portrait phone keeps its hand card size`() {
        let size = CGSize(width: 393, height: 740)
        let frame = BattleHandLayout.frame(in: size)
        let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: frame.height)
        #expect(abs(hand.cardWidth - 176.85) < 0.001)
        #expect(abs(hand.cardHeight - 235.8) < 0.001)
    }

    private static let canvases: [CGSize] = [
        CGSize(width: 320, height: 480),
        CGSize(width: 375, height: 573),
        CGSize(width: 393, height: 740),
        CGSize(width: 430, height: 839),
        CGSize(width: 499, height: 700),
        CGSize(width: 501, height: 700),
        CGSize(width: 669, height: 869),
        CGSize(width: 669, height: 951),
        CGSize(width: 669, height: 669),
        CGSize(width: 951, height: 669),
        CGSize(width: 874, height: 402),
        CGSize(width: 618, height: 422),
        CGSize(width: 891, height: 625),
        CGSize(width: 744, height: 1000),
        CGSize(width: 1032, height: 1304),
        CGSize(width: 1376, height: 960),
    ]
}
