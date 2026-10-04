import BattleEngine
import Testing
import TrinketCore

struct CombatantBuffAuraTests {
    @Test func `empty effects yield no aura`() {
        #expect(CombatantBuffAura.kind(from: []) == nil)
    }

    @Test func `ignores unrelated buffs and control`() {
        let effects = [
            ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 6),
            ActiveEffect(id: 2, effect: .controlMeter(.stun, 10, 10), remainingTurns: 0),
            ActiveEffect(id: 3, effect: .burn(4), remainingTurns: 0),
            ActiveEffect(id: 4, effect: .deathsDoor, remainingTurns: 4),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == nil)
    }

    @Test(arguments: [
        (Effect.evadeNextHit, CombatantBuffAuraKind.shadowstep),
        (.freezeNextAttacker, .glacialWard),
        (.nextHolyStrike, .avatar),
        (.damageKeywordOverride(.holy, 3, 2), .avatar),
        (.recurringDamage(.stun, 4, 2), .earthquake),
    ])
    func `alternate and lowest priority effects yield aura`(effect: Effect, expected: CombatantBuffAuraKind) {
        let effects = [
            ActiveEffect(id: 1, effect: effect, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == expected)
    }

    @Test func `zero thorns yields no aura`() {
        let effects = [
            ActiveEffect(id: 1, effect: .thorns(0), remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == nil)
    }

    @Test func `burn and holy recurring damage yield no aura`() {
        let effects = [
            ActiveEffect(id: 1, effect: .recurringDamage(.burn, 3, 2), remainingTurns: 2),
            ActiveEffect(id: 2, effect: .recurringDamage(.holy, 6, 1), remainingTurns: 1),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == nil)
    }

    @Test(arguments: [
        (Effect.nextStrikeDouble, Effect.nextStrikeCritical, CombatantBuffAuraKind.shadowstep),
        (.nextStrikeCritical, .onHitDamage(.freeze, 2), .predatorsFocus),
        (.onHitDamage(.freeze, 2), .onHitDamage(.burn, 3), .glacialWard),
        (.onHitDamage(.burn, 3), .thorns(2), .moltenBulwark),
        (.thorns(2), .avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), .thorns),
        (.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), .marked(3, 6), .avatar),
        (.marked(3, 6), .recurringDamage(.freeze, 3, 2), .marked),
        (.recurringDamage(.freeze, 3, 2), .recurringDamage(.stun, 4, 2), .blizzard),
    ])
    func `higher priority aura wins in either effect order`(
        higher: Effect,
        lower: Effect,
        expected: CombatantBuffAuraKind,
    ) {
        let effects = [
            ActiveEffect(id: 1, effect: higher, remainingTurns: 0),
            ActiveEffect(id: 2, effect: lower, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == expected)
        #expect(CombatantBuffAura.kind(from: Array(effects.reversed())) == expected)
    }
}
