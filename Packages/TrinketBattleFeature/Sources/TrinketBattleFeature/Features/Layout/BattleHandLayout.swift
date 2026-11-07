import CoreGraphics
import TrinketContent
import TrinketFeatureSupport
import UIKit

enum BattleCoordinateSpace {
    static let field = "trinket.battle.field"
}

enum BattleHandLayout {
    static let minCardWidth: CGFloat = 156
    static let maxCardWidth: CGFloat = 220
    static let maxPadCardWidth: CGFloat = 280
    static let padBottomClip: CGFloat = 2
    static let padBattlefieldClearance: CGFloat = 8
    /// Portrait height-to-width ratio for cards (4:3 portrait, height = width * aspectRatio).
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let widthRatio: CGFloat = 0.45
    static let horizontalInset: CGFloat = 20
    static let maxOverlapRatio: CGFloat = 0.70
    static let fanAngleStep: CGFloat = 9
    static let fanLiftStep: CGFloat = 10
    static let bottomRise: CGFloat = 30
    static let reservedPhoneHeight: CGFloat = 224
    static let restingPhoneYFraction: CGFloat = 0.20
    static let fanClearance: CGFloat = 28
    static let overlapAllowance: CGFloat = 56

    @MainActor static var usesPadSizing: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
        let isPad: Bool
    }

    static func battlefieldSize(in containerSize: CGSize, isPad: Bool = false) -> CGSize {
        let handFrame = frame(in: containerSize, isPad: isPad)
        // Preserve the original compact phone composition.
        if !isPad, containerSize.width <= 500 {
            return CGSize(width: containerSize.width, height: max(0, containerSize.height - reservedPhoneHeight + overlapAllowance))
        }
        let existingHeight = containerSize.height - handFrame.height + overlapAllowance

        // The battlefield must leave the party's resource bars above
        // the resting fan, including its rotation about each card's bottom.
        let metrics = metrics(containerWidth: containerSize.width, cardCount: 3, handHeight: handFrame.height, isPad: isPad)
        let cardBounds = CGRect(
            x: -metrics.cardWidth / 2,
            y: -metrics.cardHeight,
            width: metrics.cardWidth,
            height: metrics.cardHeight,
        )
        let handTop = (0 ..< 3).map { index in
            let center = restingCenter(index: index, metrics: metrics, cardCount: 3, handFrame: handFrame)
            let rotatedBounds = cardBounds.applying(CGAffineTransform(
                rotationAngle: rotation(index: index, cardCount: 3) * .pi / 180,
            ))
            return center.y + metrics.cardHeight / 2 + rotatedBounds.minY
        }.min() ?? handFrame.minY
        if isPad {
            return CGSize(width: containerSize.width, height: max(0, handTop - padBattlefieldClearance))
        }
        return CGSize(width: containerSize.width, height: max(0, min(existingHeight, handTop)))
    }

    static func frame(in containerSize: CGSize, isPad: Bool = false) -> CGRect {
        if !isPad, containerSize.width <= 500 {
            return CGRect(
                x: 0,
                y: containerSize.height - reservedPhoneHeight - bottomRise,
                width: containerSize.width,
                height: reservedPhoneHeight,
            )
        }
        let desiredWidth = min(
            isPad ? maxPadCardWidth : maxCardWidth,
            max(minCardWidth, containerSize.width * (isPad ? 0.30 : widthRatio)),
        )
        let heightRatio: CGFloat = containerSize.width > containerSize.height ? 0.36 : 0.42
        let height = min(desiredWidth * aspectRatio + fanClearance, max(0, containerSize.height * heightRatio))
        return CGRect(
            x: 0,
            y: containerSize.height - height + (isPad ? padBottomClip : -bottomRise),
            width: containerSize.width,
            height: height,
        )
    }

    static func metrics(
        containerWidth: CGFloat,
        cardCount: Int,
        handHeight: CGFloat,
        isPad: Bool = false,
    ) -> Metrics {
        if !isPad, containerWidth <= 500 {
            let cardWidth = min(maxCardWidth, max(minCardWidth, containerWidth * widthRatio))
            let overlap = cardCount > 1
                ? min(cardWidth * 0.45, (containerWidth - cardWidth - horizontalInset * 2) / CGFloat(cardCount - 1))
                : 0
            let totalWidth = cardWidth + overlap * CGFloat(max(cardCount - 1, 0))
            return Metrics(
                cardWidth: cardWidth,
                cardHeight: cardWidth * aspectRatio,
                overlap: overlap,
                startX: (containerWidth - totalWidth) / 2,
                isPad: false,
            )
        }
        let cardWidth = max(0, min(
            isPad ? maxPadCardWidth : maxCardWidth,
            max(0, containerWidth - horizontalInset * 2),
            max(minCardWidth, containerWidth * (isPad ? 0.30 : widthRatio)),
            (handHeight - fanClearance) / aspectRatio,
        ))
        let cardHeight = cardWidth * aspectRatio
        let rotationAngle = fanAngleStep * .pi / 180
        let rotationInset = cardHeight * sin(rotationAngle) + cardWidth / 2 * (1 - cos(rotationAngle))
        let edgeInset = max(horizontalInset, rotationInset)
        let spreadRatio = min(maxOverlapRatio, max(0.45, containerWidth / 1000))
        let overlap: CGFloat = cardCount > 1
            ? max(0, min(
                cardWidth * spreadRatio,
                (containerWidth - cardWidth - edgeInset * 2) / CGFloat(cardCount - 1),
            ))
            : 0
        let totalWidth = cardWidth + overlap * CGFloat(max(cardCount - 1, 0))
        let startX = (containerWidth - totalWidth) / 2
        return Metrics(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            overlap: overlap,
            startX: startX,
            isPad: isPad,
        )
    }

    static func cardOffsetX(index: Int, metrics: Metrics, containerWidth: CGFloat) -> CGFloat {
        metrics.startX + CGFloat(index) * metrics.overlap - containerWidth / 2 + metrics.cardWidth / 2
    }

    static func restingCenter(
        index: Int,
        metrics: Metrics,
        cardCount: Int,
        handFrame: CGRect,
    ) -> CGPoint {
        let baseOffsetY = restingOffsetY(index: index, cardCount: cardCount)
            + (metrics.isPad ? 0 : restingLowering(cardHeight: metrics.cardHeight, handFrame: handFrame))
        return CGPoint(
            x: handFrame.midX + cardOffsetX(
                index: index,
                metrics: metrics,
                containerWidth: handFrame.width,
            ),
            y: handFrame.maxY - metrics.cardHeight / 2 + baseOffsetY,
        )
    }

    private static func restingLowering(cardHeight: CGFloat, handFrame: CGRect) -> CGFloat {
        if handFrame.width <= 500 {
            return cardHeight * restingPhoneYFraction
        }
        // Keep regular-width and rotated compositions. Ease the phone lowering
        // out between 680 and 720 points, and as the field approaches square.
        let widthWeight = min(1, max(0, (720 - handFrame.width) / 40))
        // Hand frames are in field coordinates, with their bottom raised by bottomRise.
        let fieldHeight = handFrame.maxY + bottomRise
        let portraitWeight = min(1, max(0, (fieldHeight / handFrame.width - 1) / 0.15))
        return cardHeight * restingPhoneYFraction * widthWeight * portraitWeight
    }

    static func releaseCenter(
        restingCenter: CGPoint,
        dragTranslation: CGSize,
        cardSize: CGSize,
        rotation: CGFloat,
        scale: CGFloat,
        in handFrame: CGRect,
    ) -> CGPoint {
        // Scale about the center, then rotate about the bottom, matching the held card.
        let bounds = CGRect(
            x: -cardSize.width * scale / 2,
            y: -cardSize.height * (1 + scale) / 2,
            width: cardSize.width * scale,
            height: cardSize.height * scale,
        ).applying(CGAffineTransform(rotationAngle: rotation))
        let minX = handFrame.minX + horizontalInset - bounds.minX
        let maxX = handFrame.maxX - horizontalInset - bounds.maxX
        let x = restingCenter.x + dragTranslation.width
        return CGPoint(
            x: minX <= maxX ? min(max(x, minX), maxX) : handFrame.midX,
            y: restingCenter.y + dragTranslation.height,
        )
    }

    static func rotation(
        index: Int,
        cardCount: Int,
        fanAngleStep: CGFloat = Self.fanAngleStep,
    ) -> CGFloat {
        guard cardCount > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanAngleStep
    }

    static func restingOffsetY(
        index: Int,
        cardCount: Int,
        fanLiftStep: CGFloat = Self.fanLiftStep,
    ) -> CGFloat {
        abs(CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanLiftStep
    }
}
