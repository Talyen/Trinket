import BattleEngine
import Testing
import TrinketCore
import TrinketTestSupport

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

    @Test func nextHolyStrikeYieldsAvatar() {
        let effects = [
            ActiveEffect(id: 1, effect: .nextHolyStrike, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .avatar)
    }

    @Test func avatarSelfBuffYieldsAvatar() {
        let effects = [
            ActiveEffect(id: 1, effect: .avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), remainingTurns: 1),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .avatar)
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let state = BattleState(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy),
            activeHeroEffects: effects,
            dealOpeningHand: false
        )
        #expect(CombatantBuffAura.kind(for: hero, in: state) == .avatar)
    }

    @Test func holyKeywordOverrideYieldsAvatar() {
        let effects = [
            ActiveEffect(id: 1, effect: .damageKeywordOverride(.holy, 3, 2), remainingTurns: 2),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .avatar)
    }

    @Test func holyRecurringDamageOwnEffectsDoNotYieldAvatar() {
        let effects = [
            ActiveEffect(id: 1, effect: .recurringDamage(.holy, 6, 1), remainingTurns: 1),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == nil)
    }
}
