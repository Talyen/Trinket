import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealthThresholdSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `Grizzly Guard rewards a surviving lethal hit but not a final defeat`(finallyDefeated: Bool) throws {
        let bear = try BattleTestFixtures.catalogBuild(combatantID: "bear", talents: "bear_block_t2_1")
        var battle = BattleStateTestFactory.makeBattle(
            companion: bear.combatant,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: bear.modifiers,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let hero = battle.hero
        battle.roster.mutateRuntime(for: hero) { $0.hasConsumedDeathsDoor = finallyDefeated }
        #expect(battle.roster.health(for: hero) * 2 >= battle.roster.maxHealth(for: hero))

        let hit = battle.resolveDamage(DamageRequest(
            amount: battle.roster.maxHealth(for: hero) + 100,
            target: hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(accuracy: .unavoidable),
        ))

        #expect(battle.roster.health(for: hero) == (finallyDefeated ? 0 : 1))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: hero)) == (finallyDefeated ? 0 : 6))
        #expect(hit.events.count(where: { $0.abilityName == "Grizzly Guard" }) == (finallyDefeated ? 0 : 1))
    }

    @Test(arguments: [false, true])
    func `Redline prepares the next Bleed after lethal survival but not a final defeat`(finallyDefeated: Bool) throws {
        let panther = try BattleTestFixtures.catalogBuild(combatantID: "panther", talents: "panther_bleed_t4_2")
        var battle = BattleStateTestFactory.makeBattle(
            companion: panther.combatant,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: panther.modifiers,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let companion = battle.companion
        battle.roster.mutateRuntime(for: companion) { $0.hasConsumedDeathsDoor = finallyDefeated }
        #expect(battle.roster.health(for: companion) * 2 >= battle.roster.maxHealth(for: companion))

        _ = battle.resolveDamage(DamageRequest(
            amount: battle.roster.maxHealth(for: companion) + 100,
            target: companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(accuracy: .unavoidable),
        ))

        #expect(battle.roster.health(for: companion) == (finallyDefeated ? 0 : 1))
        #expect((battle.roster.companion.talents.pending.doubleNextBleedAttack != nil) == !finallyDefeated)
        if !finallyDefeated {
            let first = bleedAttack(from: companion, in: &battle)
            let second = bleedAttack(from: companion, in: &battle)

            #expect(first.healthLost == 20)
            #expect(second.healthLost == 10)
            #expect(battle.roster.companion.talents.pending.doubleNextBleedAttack == nil)
        }
    }

    private func bleedAttack(from source: Combatant, in battle: inout BattleState) -> CombatOutcome {
        battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .bleed, sourceActorID: source.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
    }
}
