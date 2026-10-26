import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ContagiousJoyTests {
    @Test(arguments: [false, true])
    func `Contagious Joy owns its restoration and Cheer Up reaction`(hasOriginalSource: Bool) {
        let profile = CombatantTalentCatalog.profile(for: [
            "golden_retriever_health_t1_1", "golden_retriever_health_t4_1",
        ])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.stab], companionModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 10
        var request = HealRequest(
            amount: 4, target: battle.companion,
            sourceActorID: hasOriginalSource ? battle.hero.id : nil,
        )
        request.amountBasis = .resolved

        let result = battle.recordingResult { context in
            await HealingEngine.resolveHealing(request, in: &context)
        }

        #expect(battle.health(of: battle.hero) == 14)
        #expect(result.value.allocation.transferred == 4)
        #expect(battle.hand.cards.count(where: { $0.owner == .companion }) == 1)
        #expect(result.events.contains {
            $0.abilityName == "Contagious Joy" && $0.actorID == battle.companion.id && $0.amount == 4
        })
        #expect(result.events.contains { $0.abilityName == "Cheer Up" && $0.amount == 1 })
    }

    @Test func `source-less healing cannot borrow Shared Prescription from another combatant`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroHealth: 10,
            heroModifiers: CombatantTalentCatalog.profile(for: ["alchemist_health_t3_1"]),
            appliesFightPacing: false,
        )
        var request = HealRequest(amount: 4, target: battle.companion)
        request.amountBasis = .resolved

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(request, in: &battle) }

        #expect(battle.health(of: battle.hero) == 10)
        #expect(result.allocation.transferred == 0)
        #expect(result.allocation.remaining == 4)
    }
}
