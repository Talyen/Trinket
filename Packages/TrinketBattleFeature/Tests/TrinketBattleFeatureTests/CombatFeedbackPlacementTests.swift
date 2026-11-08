import CoreGraphics
import Testing
@testable import TrinketBattleFeature

struct CombatFeedbackPlacementTests {
    @Test func `larger portraits enlarge every feedback region`() throws {
        let phone = CGRect(x: 0, y: 0, width: 180, height: 240)
        let tablet = CGRect(x: 0, y: 0, width: 360, height: 480)
        for region in CombatFeedbackRegion.allCases {
            let small = try #require(CombatFeedbackPlacement.resolve(
                size: CGSize(width: 40, height: 20), region: region, bounds: phone, bottomInset: 20,
            ))
            let large = try #require(CombatFeedbackPlacement.resolve(
                size: CGSize(width: 40, height: 20), region: region, bounds: tablet, bottomInset: 20,
            ))
            #expect(large.fitScale > small.fitScale * 1.8)
        }
    }

    @Test func `large corner labels remain separated and clear resource bars`() throws {
        let bounds = CGRect(x: 0, y: 0, width: 312, height: 416)
        let size = CGSize(width: 160, height: 40)
        let benefit = try #require(CombatFeedbackPlacement.resolve(size: size, region: .benefit, bounds: bounds, bottomInset: 40))
        let setback = try #require(CombatFeedbackPlacement.resolve(size: size, region: .setback, bounds: bounds, bottomInset: 40))
        let footprintScale = 1.2 * CombatFeedbackMotionSampler.statusSizeScale * CombatFeedbackMotionSampler.statusPeakScale
        func footprint(_ placement: CombatFeedbackPlacement) -> CGRect {
            let width = size.width * placement.fitScale * footprintScale
            let height = size.height * placement.fitScale * footprintScale
            return CGRect(x: placement.center.x - width / 2, y: placement.center.y - height / 2, width: width, height: height)
        }
        let left = footprint(benefit)
        let right = footprint(setback)
        #expect(left.minX >= 8 - 0.001)
        #expect(right.maxX <= bounds.maxX - 8 + 0.001)
        #expect(right.minX - left.maxX >= 8 - 0.001)
        #expect(left.maxY <= bounds.maxY - 48 + 0.001)
        #expect(right.maxY <= bounds.maxY - 48 + 0.001)
    }
}
