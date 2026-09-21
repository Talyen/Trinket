import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import TrinketBattleFeature

struct CombatFeedbackMotionTests {
    @Test func `typography tiers match feedback classes`() {
        #expect(CombatFeedbackClass.critical.typographyTier == .emphasis)
        #expect(CombatFeedbackClass.deathsDoor.typographyTier == .emphasis)
        #expect(CombatFeedbackClass.directDamage.typographyTier == .normal)
        #expect(CombatFeedbackClass.heal.typographyTier == .normal)
        #expect(CombatFeedbackClass.block.typographyTier == .normal)

        let critStyle = CombatFeedbackChipStyle.forClass(.critical)
        #expect(critStyle.fontWeight == .heavy)
        #expect(critStyle.textStyle == .largeTitle)

        let damageStyle = CombatFeedbackChipStyle.forClass(.directDamage)
        #expect(damageStyle.fontWeight == .bold)
        #expect(damageStyle.textStyle == .title)
    }

    @Test func `hit recoil direction calculates offsets and scales`() {
        let up = CombatantHitRecoilDirection.up
        let down = CombatantHitRecoilDirection.down

        #expect(up.impactOffset(magnitude: 12) == CGSize(width: 0, height: -12))
        #expect(down.impactOffset(magnitude: 12) == CGSize(width: 0, height: 12))

        let upScales = up.impactScales(scaleX: 0.9, scaleY: 1.1)
        #expect(upScales.x == 1.1)
        #expect(upScales.y == 0.9)

        let downScales = down.impactScales(scaleX: 0.9, scaleY: 1.1)
        #expect(downScales.x == 0.9)
        #expect(downScales.y == 1.1)
    }

    @Test func `combat feedback unit noise is bounded and deterministic`() {
        for seed in [0, 1, 42, 100, 9999, -5] {
            let noise1 = CombatFeedbackLayout.unitNoise(seed: seed)
            let noise2 = CombatFeedbackLayout.unitNoise(seed: seed)
            #expect(noise1 == noise2)
            #expect(noise1 >= 0 && noise1 <= 1)
        }
    }

    @Test @MainActor func `corner feedback stays still with a smaller pop and the central fade`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 4, keyword: .physical),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .effect, effectKind: .cleanseApplied, amount: 1, keyword: .poison),
        ], at: start)
        let hit = try #require(lane.activeItems.first { $0.region == .impact })
        let status = try #require(lane.activeItems.first { $0.region == .benefit })
        for elapsed in [0.0, 0.07, 0.14, 0.2, 0.4, 0.6, 0.92] {
            let date = start.addingTimeInterval(elapsed)
            let main = CombatFeedbackMotionSampler.state(for: hit, at: date)
            let lower = CombatFeedbackMotionSampler.state(for: status, at: date)
            #expect(lower.scale < main.scale)
            #expect(lower.scale <= 1.2 * 0.8 * CombatFeedbackMotionSampler.statusPeakScale)
            #expect(lower.riseProgress == 0)
            #expect(lower.opacity == main.opacity && lower.shineProgress == main.shineProgress)
        }
        #expect(CombatFeedbackMotionSampler.state(for: hit, at: start.addingTimeInterval(0.4)).riseProgress > 0)
    }
}
