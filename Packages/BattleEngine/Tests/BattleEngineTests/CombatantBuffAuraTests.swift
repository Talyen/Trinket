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

    @Test(arguments: [
        (Effect.nextStrikeDouble, CombatantBuffAuraKind.shadowstep),
        (.evadeNextHit, .shadowstep),
        (.nextHolyStrike, .avatar),
        (.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), .avatar),
        (.damageKeywordOverride(.holy, 3, 2), .avatar),
    ])
    func singleQualifyingEffectYieldsAura(effect: Effect, expected: CombatantBuffAuraKind) {
        let effects = [
            ActiveEffect(id: 1, effect: effect, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == expected)
    }

    @Test func eitherShadowstepFlagIsEnough() {
        let both = [
            ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0),
            ActiveEffect(id: 2, effect: .evadeNextHit, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: both) == .shadowstep)
    }

    @Test func shadowstepBeatsAvatar() {
        let effects = [
            ActiveEffect(id: 1, effect: .nextHolyStrike, remainingTurns: 0),
            ActiveEffect(id: 2, effect: .nextStrikeDouble, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .shadowstep)
    }

    @Test func holyRecurringDamageOwnEffectsDoNotYieldAvatar() {
        let effects = [
            ActiveEffect(id: 1, effect: .recurringDamage(.holy, 6, 1), remainingTurns: 1),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == nil)
    }
}
