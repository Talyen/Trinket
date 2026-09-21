import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence
@testable import BattleEngine
@testable import TrinketAppState
@testable import TrinketBattleFeature

@MainActor
struct DefeatCompletionTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test(arguments: [BattleDefeatAction.retry, .leave], [false, true])
    func `defeat claims once and does not complete encounter`(action: BattleDefeatAction, retreat: Bool) throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let configuration = try #require(battle.activeBattle)
        try resolveDefeat(battle, retreat: retreat)
        let settlement = try #require(play.settleDefeatRewards(configuration))
        let before = play.playerSave.currentSave
        #expect(settlement.award.heroExperience > 0)
        #expect(battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: action))
        #expect(play.playerSave.roster.progression(for: configuration.hero.combatant) == settlement.heroProgressionAfter)
        #expect(play.playerSave.roster.progression(for: configuration.companion.combatant) == settlement.companionProgressionAfter)
        #expect(play.playerSave.currentSave.journey == before.journey)
        #expect(play.playerSave.currentSave.inventory == before.inventory)
        #expect(play.playerSave.roster.gold == before.roster.gold)
        let claimed = play.playerSave.currentSave
        #expect(!battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: .leave))
        #expect(play.playerSave.currentSave == claimed)
        switch action {
        case .retry:
            let next = try #require(battle.activeBattle)
            #expect(next.id != configuration.id)
            #expect(next.hero.progression == settlement.heroProgressionAfter)
            #expect(next.companion.progression == settlement.companionProgressionAfter)
            #expect(battle.engineState?.defeatProgress.depletedFraction == 0)
            #expect(battle.resolvedDefeatProgress == nil)
            #expect(battle.outcome == nil)
        case .leave:
            #expect(battle.activeBattle == nil)
            #expect(play.shellSession.playPath == [.campaign])
        }
        battle.endBattle()
    }

    @Test(arguments: [BattleDefeatAction.retry, .leave], [false, true])
    func `total write failure retries the chosen action without another tap`(action: BattleDefeatAction, retreat: Bool) async throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let configuration = try #require(battle.activeBattle)
        try resolveDefeat(battle, retreat: retreat)
        let settlement = try #require(play.settleDefeatRewards(configuration))
        play.playerSave.forcesNextSaveFailure = true
        #expect(!battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: action))
        try await PlayBattleLaunchTestSupport.awaitSaveQuiescence { battle.activeBattle?.id == configuration.id }
        #expect(battle.activeBattle?.id != configuration.id)
        #expect(play.playerSave.roster.progression(for: configuration.hero.combatant) == settlement.heroProgressionAfter)
        #expect(!play.playerSave.isRetryingSaveAction)
        battle.endBattle()
    }

    @Test func `failed save and stale settlement remain recoverable`() throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let configuration = try #require(battle.activeBattle)
        try resolveDefeat(battle)
        let settlement = try #require(play.settleDefeatRewards(configuration))
        let before = play.playerSave.currentSave
        play.playerSave.forcesNextSaveFailure = true
        #expect(!battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: .retry))
        #expect(play.playerSave.currentSave == before)
        #expect(battle.activeBattle?.id == configuration.id)
        #expect(play.playerSave.isRetryingSaveAction)
        try play.playerSave.performBatchMutation { save in
            save.roster.grantExperience(1, to: configuration.hero.combatant)
        }
        #expect(!battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: .leave))
        guard case let .defeat(refreshed) = battle.spectacle.outcomePresentation else {
            Issue.record("Expected refreshed defeat settlement")
            return
        }
        #expect(refreshed.inputs.heroProgression != settlement.inputs.heroProgression)
        #expect(battle.claimDefeat(configurationID: configuration.id, settlement: refreshed, action: .leave))
        #expect(play.playerSave.roster.progression(for: configuration.hero.combatant) == refreshed.heroProgressionAfter)
    }

    @Test func `claimed defeat can leave after failed restart without another award`() throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let configuration = try #require(battle.activeBattle)
        try resolveDefeat(battle)
        let settlement = try #require(play.settleDefeatRewards(configuration))
        let progression = try #require(battle.progression)
        battle.progression = BattleProgression(
            presentation: { candidate in
                candidate.id == configuration.id ? progression.presentation(candidate) : nil
            },
            settleRewards: progression.settleRewards,
            settleDefeat: progression.settleDefeat,
            completeDefeat: progression.completeDefeat,
            finishPresentation: progression.finishPresentation,
            completeVictory: progression.completeVictory,
        )
        #expect(!battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: .retry))
        #expect(battle.activeBattle?.id == configuration.id)
        #expect(play.playerSave.roster.progression(for: configuration.hero.combatant) == settlement.heroProgressionAfter)
        let claimed = play.playerSave.currentSave
        #expect(battle.claimDefeat(configurationID: configuration.id, settlement: settlement, action: .leave))
        #expect(play.playerSave.currentSave == claimed)
        #expect(battle.activeBattle == nil)
    }

    @Test func `talent points earned on retry are offered when leaving later`() throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let hero = play.playerSave.roster.activeHero
        let companion = play.playerSave.roster.activeCompanion
        try play.playerSave.performBatchMutation { save in
            let before = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
            save.roster.progressions[hero.id] = before
            save.roster.progressions[companion.id] = before
        }
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let first = try #require(battle.activeBattle)
        try resolveDefeat(battle)
        let award = try #require(play.settleDefeatRewards(first))
        #expect(battle.claimDefeat(configurationID: first.id, settlement: award, action: .retry))
        #expect(play.playerSave.roster.progression(for: hero).level == 2)
        #expect(play.currentPostBattleTalentCombatantID == nil)
        let next = try #require(battle.activeBattle)
        try resolveDefeat(battle)
        let nextAward = try #require(play.settleDefeatRewards(next))
        #expect(battle.claimDefeat(configurationID: next.id, settlement: nextAward, action: .leave))
        #expect(play.currentPostBattleTalentCombatantID == hero.id)
    }

    @Test func `unfinished battle cannot claim defeat`() throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let configuration = try #require(play.battle.activeBattle)
        #expect(play.settleDefeatRewards(configuration) == nil)
        let before = play.playerSave.currentSave
        play.endBattleReturningToOrigin()
        #expect(play.playerSave.currentSave == before)
    }

    private func resolveDefeat(_ battle: BattleSession, retreat: Bool = false) throws {
        var state = try #require(battle.engineState)
        state.roster.enemy.currentHealth = max(1, state.roster.enemy.maxHealth / 10)
        if retreat {
            battle.engineState = state
            #expect(battle.retreatFromBattle())
            return
        }
        state.roster.hero.currentHealth = 0
        state.roster.companion.currentHealth = 0
        battle.engineState = state
        battle.outcomePresentationDelayOverride = .zero
        battle.handleOutcomeIfNeeded(at: .now)
        #expect(battle.resolvedDefeatProgress != nil)
    }
}
