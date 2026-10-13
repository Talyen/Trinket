import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingEchoCadenceTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Living Archive stops later echoes when the first echo wins`(laterRecipient: BattleParticipant) {
        var profile = CombatModifierProfile.zero
        profile.triggers.onHealDealHoly = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 10, enemyHealth: 1,
            companionModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.enemy.hasConsumedDeathsDoor = true
        let sourceID = battle.companion.id
        battle.roster.hero.talents.pending.healingEchoes = [HealingEcho(amount: 1, sourceActorID: sourceID)]
        let laterTarget = battle.roster[laterRecipient].combatant
        battle.roster.mutateRuntime(for: laterTarget) {
            $0.talents.pending.healingEchoes.append(HealingEcho(amount: 3, sourceActorID: sourceID))
        }

        _ = CombatExecutor.run { await HealingEngine.resolveHealingEchoes(in: &battle) }

        #expect(battle.isEnemyDefeated)
        #expect(battle.health(of: battle.hero) == 11)
        #expect(battle.health(of: battle.companion) == 10)
    }
}
