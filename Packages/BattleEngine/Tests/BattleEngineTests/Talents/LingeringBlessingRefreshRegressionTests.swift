import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct LingeringBlessingRefreshRegressionTests {
    @Test func `ordinary turn Mana healing preserves the due blessing and queues its own repeat`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onGainManaHealFlat = 2
        profile.triggers.healthRestorationRepeatNextTurnChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 1, companionMana: 0, companionModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.talents.timed.lingeringBlessing = LingeringBlessing(
            amount: 3, sourceActorID: battle.companion.id, turnsRemaining: 1,
        )
        battle.turnCount = 1
        battle.turnState = .drawing([])

        let first = battle.finalizeTurnStart()

        #expect(battle.roster.companion.currentMana == 1)
        #expect(battle.health(of: battle.companion) == 6)
        #expect(first.filter { $0.abilityName == "Lingering Blessing" }.map(\.amount) == [3])
        #expect(battle.roster.companion.talents.timed.lingeringBlessing?.amount == 2)
        #expect(battle.roster.companion.talents.timed.lingeringBlessing?.turnsRemaining == 1)
        #expect(battle.finalizeTurnStart().isEmpty)

        battle.turnCount = 2
        battle.turnState = .drawing([])
        let next = battle.finalizeTurnStart()

        #expect(battle.health(of: battle.companion) == 8)
        #expect(next.filter { $0.abilityName == "Lingering Blessing" }.map(\.amount) == [2])
        #expect(battle.roster.companion.talents.timed.lingeringBlessing == nil)
    }

    @Test func `verdant renewal refresh survives replay of the due lingering blessing`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["pixie_health_t2_1"])
        let renewal = try #require(GameContent.itemAffixDefinition(matching: "groves_favor"))
        renewal.basic.triggers.apply(to: &profile, abilityName: renewal.title)
        profile.triggers.healthRestorationRepeatNextTurnChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
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
