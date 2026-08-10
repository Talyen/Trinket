import BattleEngine
import Testing
import TrinketCore

struct CombatantBuffAuraTests {
    @Test func emptyEffectsYieldNoAura() {
        #expect(CombatantBuffAura.kind(from: []) == nil)
    }

    @Test func ignoresUnrelatedBuffsAndControl() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 6),
            ActiveEffect(id: 2, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ActiveEffect(id: 3, effect: .burn(4), remainingTurns: 0),
            ActiveEffect(id: 4, effect: .deathsDoor, remainingTurns: 4),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == nil)
    }

    @Test func nextStrikeDoubleYieldsShadowstep() {
        let effects = [
            ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .shadowstep)
    }

    @Test func evadeNextHitYieldsShadowstep() {
        let effects = [
            ActiveEffect(id: 1, effect: .evadeNextHit, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .shadowstep)
    }

    @Test func eitherShadowstepFlagIsEnough() {
        let both = [
            ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0),
            ActiveEffect(id: 2, effect: .evadeNextHit, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: both) == .shadowstep)
    }
}
