import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct CombatantSliceCrackTests {
    @Test func interiorVerticesStayWithinCard() {
        for point in CombatantSliceCrack.points.dropFirst().dropLast() {
            #expect((0 ... 1).contains(point.x))
            #expect((0 ... 1).contains(point.y))
        }
    }

    @Test func endpointsExtendBeyondCard() {
        let points = CombatantSliceCrack.points
        let onBoundary = { (p: CGPoint) in
            abs(p.x) < 0.0001 || abs(p.x - 1) < 0.0001
                || abs(p.y) < 0.0001 || abs(p.y - 1) < 0.0001
        }
        #expect(!onBoundary(points[0]))
        #expect(!onBoundary(points[points.count - 1]))
    }

    @Test func crackZigzagsAcrossBaseDiagonal() {
        let interior = CombatantSliceCrack.points.dropFirst().dropLast()
        #expect(interior.count >= 3)
        let angle = CombatantSliceGeometry.angleRadians
        let normal = CGVector(dx: cos(angle), dy: -sin(angle))
        var previousSign: CGFloat?
        for point in interior {
            // Signed aspect-space offset from the base diagonal.
            let dx = (point.x - 0.5) * CombatantSliceCrack.aspectWidth
            let dy = (point.y - 0.5) * CombatantSliceCrack.aspectHeight
            let sign: CGFloat = (dx * normal.dx + dy * normal.dy) >= 0 ? 1 : -1
            if let previousSign {
                #expect(
                    sign * previousSign < 0,
                    "interior crack vertices should alternate sides of the base diagonal"
                )
            }
            previousSign = sign
        }
    }

    @Test func sideClassifiesCardCorners() {
        // Top-right sits on the +normal (secondary) side; bottom-left on primary.
        #expect(CombatantSliceCrack.side(of: CGPoint(x: 0.95, y: 0.05)) > 0)
        #expect(CombatantSliceCrack.side(of: CGPoint(x: 0.05, y: 0.95)) < 0)
    }

    @Test func pointAtFractionAdvancesAlongCrack() {
        let start = CombatantSliceCrack.points[0]
        let low = CombatantSliceCrack.point(atFraction: 0.2)
        let high = CombatantSliceCrack.point(atFraction: 0.8)
        let distance = { (p: CGPoint) in hypot(p.x - start.x, p.y - start.y) }
        #expect(distance(high) > distance(low))
    }

    @Test func cardFractionRangeSpansOnCardPortion() {
        let range = CombatantSliceCrack.cardFractionRange
        #expect(range.lowerBound > 0)
        #expect(range.upperBound < 1)
        let nearBoundary = { (p: CGPoint) in
            abs(p.x) < 0.04 || abs(p.x - 1) < 0.04
                || abs(p.y) < 0.04 || abs(p.y - 1) < 0.04
        }
        #expect(nearBoundary(CombatantSliceCrack.point(atFraction: range.lowerBound)))
        #expect(nearBoundary(CombatantSliceCrack.point(atFraction: range.upperBound)))
    }
}
