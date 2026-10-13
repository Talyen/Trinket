import BattleEngine
import Testing
import TrinketContent
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
struct PreparedBattleReuseTests {
    @Test func `wallet inventory and reward changes refresh metadata without discarding prepared combat`() throws {
        let context = try AppTestContext()
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        state.journey.prepareBattle(for: stage)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        let prepared = try #require(state.battleCoordinator.preparedRuns[runKey])
        let battle = try #require(context.lastBattle)
        let revision = battle.preparedBattlePresentationRevision
        let item = try #require(GameContent.sampleInventoryItems.first)
        try state.playerSave.performFixtureMutation { save in
            save.roster.gold = PlayerRosterState.maxGoldBalance
            save.inventory.appendUniqueItem(item)
        }
        let original = prepared.registration.launch.inputs.launch
        // Rewards are application metadata too: a changed payout must reach the
        // active run even though combat and its opening RNG state are unchanged.
        let input = BattleLaunchInput(
            origin: original.origin, hero: original.hero, companion: original.companion,
            encounter: original.encounter, stageReward: StageReward(gold: 17, itemTemplateIDs: []),
            experienceBonusPercent: original.experienceBonusPercent,
            victoryOnlyExperienceBonusPercent: original.victoryOnlyExperienceBonusPercent,
            pendingRewardItem: original.pendingRewardItem, additionalRewardItems: original.additionalRewardItems,
            stageRewardsAlreadyClaimed: original.stageRewardsAlreadyClaimed,
            universalModifiers: original.universalModifiers, nodeModifiers: original.nodeModifiers,
            completionBonus: original.completionBonus,
        )
        let route = try #require(prepared.registration.route)
        #expect(state.battleCoordinator.prepareCombat(input, route: route))
        let refreshed = try #require(state.battleCoordinator.preparedRuns[runKey])
        #expect(refreshed.handle === prepared.handle)
        #expect(refreshed.registration.launch.configuration.id == prepared.registration.launch.configuration.id)
        #expect(battle.preparedBattlePresentationRevision == revision)
        #expect(state.battleCoordinator.activateBattle(input, route: route))
        let active = try #require(state.battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: active))
        #expect(presentation.inventoryItems == state.playerSave.inventory.items)
        let rewardInputs = try #require(presentation.rewardInputs)
        #expect(rewardInputs.gold == PlayerRosterState.maxGoldBalance)
        #expect(presentation.rewardPlan.stageGold == 17)
        let settlement = try #require(state.settleBattleRewards(active, battleGold: .init(gained: 0)))
        #expect(settlement.award.goldGained == 0)
        #expect(settlement.replacementExperience > 0)
        #expect(state.completeActiveBattle(active, battleGold: .init(gained: 0), settlement: settlement).didComplete)
        #expect(state.playerSave.roster.gold == PlayerRosterState.maxGoldBalance)
        #expect(state.playerSave.roster.progression(for: active.hero.combatant) == settlement.heroProgressionAfter)
    }
}
