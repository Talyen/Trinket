import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct SharedRootsHealingTests {
    @Test(arguments: [1, 91])
    func `shared roots restores half the actual companion healing without scaling again`(companionHealth: Int) throws {
        var profile = CombatantTalentCatalog.profile(for: ["druid_health_t3_2"])
        profile.healthRestoredBonus = 4
        profile.healthRestoredPercent = 0.5
        profile.triggers.criticalChanceBonus = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 100, companionMaxHealth: 100,
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 10
        battle.roster.companion.currentHealth = companionHealth

        let result = CombatExecutor.run { await HealingEngine.resolveHealing(HealRequest(
            amount: 10, target: battle.companion, sourceActorID: battle.hero.id,
            origin: .restoration(.health),
        ), in: &battle) }

        let expectedRestoration = companionHealth == 1 ? 42 : 9
        let expectedShare = companionHealth == 1 ? 21 : 5
        #expect(result.directRestoration == expectedRestoration)
        #expect(result.isCritical)
        #expect(battle.health(of: battle.companion) == companionHealth + expectedRestoration)
        #expect(battle.health(of: battle.hero) == 10 + expectedShare)
        let share = try #require(result.events.first { $0.abilityName == "Shared Roots" && $0.effectKind == .instantHeal })
        #expect(share.amount == expectedShare)
        #expect(share.targetID == battle.hero.id)
        #expect(!share.isCritical)
    }
}
