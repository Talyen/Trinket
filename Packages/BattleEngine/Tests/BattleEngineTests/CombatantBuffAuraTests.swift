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
        (Effect.nextStrikeDouble, CombatantBuffAuraKind.shadowstep),
        (.evadeNextHit, .shadowstep),
        (.nextStrikeCritical, .predatorsFocus),
        (.onHitDamage(.freeze, 2), .glacialWard),
        (.freezeNextAttacker, .glacialWard),
        (.onHitDamage(.burn, 3), .moltenBulwark),
        (.thorns(3), .thorns),
        (.nextHolyStrike, .avatar),
        (.avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), .avatar),
        (.damageKeywordOverride(.holy, 3, 2), .avatar),
        (.marked(3, 6), .marked),
        (.recurringDamage(.freeze, 3, 2), .blizzard),
        (.recurringDamage(.stun, 4, 2), .earthquake),
    ])
    func `single qualifying effect yields aura`(effect: Effect, expected: CombatantBuffAuraKind) {
        let effects = [
            ActiveEffect(id: 1, effect: effect, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == expected)
    }

    @Test func `either shadowstep flag is enough`() {
        let both = [
            ActiveEffect(id: 1, effect: .nextStrikeDouble, remainingTurns: 0),
            ActiveEffect(id: 2, effect: .evadeNextHit, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: both) == .shadowstep)
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

    @Test func `priority hierarchy`() {
        let effects = [
            ActiveEffect(id: 1, effect: .recurringDamage(.stun, 4, 2), remainingTurns: 2),
            ActiveEffect(id: 2, effect: .recurringDamage(.freeze, 3, 2), remainingTurns: 2),
            ActiveEffect(id: 3, effect: .marked(3, 6), remainingTurns: 6),
            ActiveEffect(id: 4, effect: .avatar(holyDamage: 6, blockPerTurn: 4, turns: 1), remainingTurns: 1),
            ActiveEffect(id: 5, effect: .thorns(2), remainingTurns: 0),
            ActiveEffect(id: 6, effect: .onHitDamage(.burn, 3), remainingTurns: 0),
            ActiveEffect(id: 7, effect: .onHitDamage(.freeze, 2), remainingTurns: 0),
            ActiveEffect(id: 8, effect: .nextStrikeCritical, remainingTurns: 0),
            ActiveEffect(id: 9, effect: .nextStrikeDouble, remainingTurns: 0),
        ]
        #expect(CombatantBuffAura.kind(from: effects) == .shadowstep)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(1))) == .predatorsFocus)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(2))) == .glacialWard)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(3))) == .moltenBulwark)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(4))) == .thorns)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(5))) == .avatar)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(6))) == .marked)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(7))) == .blizzard)
        #expect(CombatantBuffAura.kind(from: Array(effects.dropLast(8))) == .earthquake)
    }
}
