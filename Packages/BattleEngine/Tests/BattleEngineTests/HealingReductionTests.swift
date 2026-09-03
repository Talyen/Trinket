import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HealingReductionTests {
    @Test func `serrated edge reduces enemy healing`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.serratedEdge]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.roster.enemy.combatant) { $0.currentHealth = 10 }
        _ = BattleTurnEngine.performAction(
            ability: .serratedEdge,
            actor: battle.roster.hero.combatant,
            abilityTarget: battle.roster.enemy.combatant,
            context: &battle,
        )
        let outcome = battle.resolveHeal(
            HealRequest(
                amount: 8,
                target: battle.roster.enemy.combatant,
                sourceActorID: battle.roster.enemy.id,
                logAs: .silent,
                skipFightPacing: true,
            ),
        )
        #expect(outcome.healthRestored == 6)
        #expect(battle.roster.health(for: battle.roster.enemy.combatant) == 14)
    }

    @Test func `serrated edge leaves ally healing alone`() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.serratedEdge]),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40),
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) { $0.currentHealth = 10 }
        _ = BattleTurnEngine.performAction(
            ability: .serratedEdge,
            actor: battle.roster.hero.combatant,
            abilityTarget: battle.roster.enemy.combatant,
            context: &battle,
        )
        let outcome = battle.resolveHeal(
            HealRequest(
                amount: 8,
                target: battle.roster.hero.combatant,
                sourceActorID: battle.roster.hero.id,
                logAs: .silent,
                skipFightPacing: true,
            ),
        )
        #expect(outcome.healthRestored == 8)
    }
}
