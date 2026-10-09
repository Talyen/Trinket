import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct LingeringBlessingRefreshRegressionTests {
    @Test func `verdant renewal refresh survives replay of the due lingering blessing`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["pixie_health_t2_1"])
        let renewal = try #require(GameContent.itemAffixDefinition(matching: "groves_favor"))
        renewal.basic.triggers.apply(to: &profile, abilityName: renewal.title)
        profile.triggers.healthRestorationRepeatNextTurnChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.talents.timed.lingeringBlessing = LingeringBlessing(
            amount: 3, sourceActorID: battle.companion.id, turnsRemaining: 1,
        )

        let first = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.health(of: battle.companion) == 6)
        #expect(first.filter { $0.abilityName == "Lingering Blessing" }.map(\.amount) == [3])
        #expect(battle.roster.companion.talents.timed.lingeringBlessing?.amount == 2)
        #expect(battle.roster.companion.talents.timed.lingeringBlessing?.turnsRemaining == 1)

        battle.turnCount = 1
        let next = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.health(of: battle.companion) == 8)
        #expect(next.filter { $0.abilityName == "Lingering Blessing" }.map(\.amount) == [2])
        #expect(battle.roster.companion.talents.timed.lingeringBlessing == nil)
    }
}
