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

    @Test func `chip holds after pop before rising and fading`() throws {
        let item = try makeItem()
        for elapsed in [0, BattleMotion.chipPopPeakTime, BattleMotion.chipPopEndTime, BattleMotion.chipHoldEndTime] {
            let state = CombatFeedbackMotionSampler.state(for: item, at: item.firstScheduledAt.addingTimeInterval(elapsed))
            #expect(state.riseProgress == 0)
            #expect(state.opacity == 1)
        }
        let held = CombatFeedbackMotionSampler.state(for: item, at: item.firstScheduledAt.addingTimeInterval(0.25))
        #expect(held.scale == Double(BattleMotion.chipPopHoldScale))
        let rising = CombatFeedbackMotionSampler.state(for: item, at: item.firstScheduledAt.addingTimeInterval(0.5))
        #expect(rising.riseProgress > 0 && rising.riseProgress < 1)
        #expect(rising.scale < held.scale)
        let expired = CombatFeedbackMotionSampler.state(for: item, at: item.expiresAt.addingTimeInterval(0.01))
        #expect(expired.riseProgress == 1)
        #expect(expired.opacity == 0)
    }

    @Test(arguments: [0.05, 0.25, 0.5])
    func `handoff releases held text without jumping or restarting motion`(elapsed: TimeInterval) throws {
        let original = try makeItem()
        let handoff = original.firstScheduledAt.addingTimeInterval(elapsed)
        var retiring = original
        retiring.retiringAt = handoff
        retiring.expiresAt = handoff.addingTimeInterval(BattleMotion.feedbackHandoffDuration)
        let before = CombatFeedbackMotionSampler.state(for: original, at: handoff)
        let after = CombatFeedbackMotionSampler.state(for: retiring, at: handoff)
        #expect(after.riseProgress == before.riseProgress)
        #expect(after.scale == before.scale)
        let later = handoff.addingTimeInterval(0.05)
        let moving = CombatFeedbackMotionSampler.state(for: retiring, at: later)
        let uninterrupted = CombatFeedbackMotionSampler.state(for: original, at: later)
        #expect(moving.riseProgress > after.riseProgress)
        #expect(moving.scale == uninterrupted.scale)
        if elapsed >= BattleMotion.chipHoldEndTime {
            #expect(moving.riseProgress == uninterrupted.riseProgress)
        }
        #expect(moving.opacity < after.opacity)
    }

    private func makeItem() throws -> CombatFeedbackItem {
        let event = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .abilityDamage, amount: 4, keyword: .physical,
        )
        return try #require(CombatFeedbackPresenter.makeItems(from: [event], at: Date(timeIntervalSince1970: 1000)).first)
    }

    @Test func `chip pop scale phases`() {
        #expect(BattleMotion.chipScale(elapsed: 0) == BattleMotion.chipPopStartScale)
        #expect(
            abs(BattleMotion.chipScale(elapsed: BattleMotion.chipPopPeakTime) - BattleMotion
                .chipPopOvershootScale) < 0.001,
        )
    }
}
