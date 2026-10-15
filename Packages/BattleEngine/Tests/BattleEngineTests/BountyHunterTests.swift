import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct BountyHunterTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Bounty Hunter rewards only the owner of the critical killing blow`(killer: BattleParticipant) {
        var battle = makeBattle()
        let source = battle.roster[killer].combatant
        let damage = battle.resolveTestDamage(
            10,
            to: battle.enemy,
            keyword: .physical,
            sourceActorID: source.id,
            options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true),
        )
        #expect(damage.isCritical)
        #expect(battle.roster.isEnemyDefeated)
        let rewards = battle.recordingEvents { battle in await battle.appendDefeatMilestonesIfNeeded() }
            .filter { $0.abilityName == "Bounty Hunter" }
        #expect(battle.gold == (killer == .hero ? 10 : 0))
        #expect(rewards.count == (killer == .hero ? 1 : 0))
        if killer == .hero {
            #expect(rewards.first?.targetID == source.id)
        }
    }

    @Test func `Bounty Hunter does not reward a noncritical killing blow`() {
        var battle = makeBattle()
        let damage = battle.resolveTestDamage(10, options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable))
        #expect(!damage.isCritical)
        #expect(battle.roster.isEnemyDefeated)
        let rewards = battle.recordingEvents { battle in await battle.appendDefeatMilestonesIfNeeded() }
            .filter { $0.abilityName == "Bounty Hunter" }
        #expect(battle.gold == 0)
        #expect(rewards.isEmpty)
    }

    private func makeBattle() -> BattleState {
        var profile = CombatantTalentCatalog.profile(for: ["rogue_gold_t3_1"])
        profile.triggers.criticalChanceBonus = -1
        return BattleStateTestFactory.makeMinimalBattle(
            enemyHealth: 5,
            heroModifiers: profile, appliesFightPacing: false,
        )
    }
}
