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

    @Test func `phone retains the archived full width battlefield and lowered fan`() {
        // October 11 phone composition, before the expanded-canvas hand fit changed it.
        let size = CGSize(width: 393, height: 740)
        let field = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size))
        #expect(abs(field.enemySize.width - 353.7) < 0.001)
        #expect(abs(field.partySize.width - 170.85) < 0.001)
        let frame = BattleHandLayout.frame(in: size)
        #expect(frame == CGRect(x: 0, y: 486, width: 393, height: 224))
        let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: frame.height)
        let center = BattleHandLayout.restingCenter(index: 1, metrics: hand, cardCount: 3, handFrame: frame)
        #expect(abs(hand.cardWidth - 176.85) < 0.001)
        #expect(abs(center.y - 639.26) < 0.001)
    }

    @Test func `resting hand leaves party resource bars visible through expanded resizing`() {
        for size in [
            CGSize(width: 669, height: 869),
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
                let allowedBottomOverflow = size.width == 669 ? hand.cardHeight * 0.20 : 0
                #expect(restingBottom <= size.height + allowedBottomOverflow)
                #expect(center.x + rotatedCard.minX >= 0)
                #expect(center.x + rotatedCard.maxX <= size.width)
            }
        }
    }

    @Test func `mid width portrait keeps hand size and uses the original phone lowering`() {
        for size in [CGSize(width: 669, height: 869), CGSize(width: 669, height: 951)] {
            let frame = BattleHandLayout.frame(in: size)
            for count in 1 ... 3 {
                let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: count, handHeight: frame.height)
                #expect(hand.cardWidth == 220)
                #expect(abs(hand.cardHeight - 220 * 4.0 / 3.0) < 0.001)
                for index in 0 ..< count {
                    let center = BattleHandLayout.restingCenter(index: index, metrics: hand, cardCount: count, handFrame: frame)
                    let unloweredY = frame.maxY - hand.cardHeight / 2
                        + BattleHandLayout.restingOffsetY(index: index, cardCount: count)
                    #expect(abs(center.y - unloweredY - hand.cardHeight * 0.20) < 0.001)
                }
            }
            let field = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size))
            let oldEnemyWidth: CGFloat = size.height == 869 ? 341.832893678 : 393.926997839
            #expect(field.enemySize.width > oldEnemyWidth * 1.09)
            #expect(abs(field.enemySize.width / field.enemySize.height - 4.0 / 3.0) < 0.001)
            #expect(abs(field.partySize.width / field.partySize.height - 3.0 / 4.0) < 0.001)
        }
    }

    @Test func `regular and wide compositions keep their original frame and hand placement`() {
        let cases: [(CGSize, CGFloat)] = [
            (CGSize(width: 430, height: 839), 387),
            (CGSize(width: 951, height: 669), 268.20),
            (CGSize(width: 874, height: 402), 159.64),
            (CGSize(width: 618, height: 422), 167.77),
            (CGSize(width: 891, height: 625), 250.31),
            (CGSize(width: 744, height: 1000), 425.06),
            (CGSize(width: 820, height: 1104), 491.13),
            (CGSize(width: 1024, height: 1280), 602.94),
        ]
        for (size, enemyWidth) in cases {
            let field = BattleCardGridLayout.metrics(in: BattleHandLayout.battlefieldSize(in: size))
            #expect(abs(field.enemySize.width - enemyWidth) < 0.01)
            let frame = BattleHandLayout.frame(in: size)
            let hand = BattleHandLayout.metrics(containerWidth: size.width, cardCount: 3, handHeight: frame.height)
            let center = BattleHandLayout.restingCenter(index: 1, metrics: hand, cardCount: 3, handFrame: frame)
            let originalLowering = size.width <= 500 ? hand.cardHeight * 0.20 : 0
            #expect(abs(center.y - (frame.maxY - hand.cardHeight / 2 + originalLowering)) < 0.001)
        }
    }

    @Test func `additional portrait lowering eases out before regular width and square fields`() {
        for size in [CGSize(width: 680, height: 900), CGSize(width: 720, height: 900), CGSize(width: 669, height: 669)] {
            func lowering(in canvas: CGSize) -> CGFloat {
                let frame = BattleHandLayout.frame(in: canvas)
                let hand = BattleHandLayout.metrics(containerWidth: canvas.width, cardCount: 3, handHeight: frame.height)
                let center = BattleHandLayout.restingCenter(index: 1, metrics: hand, cardCount: 3, handFrame: frame)
                // The original portrait/landscape hand-height switch remains unchanged.
                return center.y - (frame.maxY - hand.cardHeight / 2)
            }
            for delta in [CGFloat(-1), 1] {
                #expect(abs(lowering(in: size) - lowering(in: CGSize(width: size.width + delta, height: size.height))) < 2.5)
                #expect(abs(lowering(in: size) - lowering(in: CGSize(width: size.width, height: size.height + delta))) < 2.5)
            }
        }
    }
}
