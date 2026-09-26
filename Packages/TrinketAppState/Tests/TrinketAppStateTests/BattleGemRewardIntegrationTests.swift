import Foundation
import Testing
import TrinketContent
import TrinketPersistence
@testable import TrinketAppState
@testable import TrinketBattleFeature

@MainActor
struct BattleGemRewardIntegrationTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test(arguments: [false, true])
    func `settled gem reward claims once and exits victory`(passesDisplayedMaterialsAsOverride: Bool) throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let seed = try #require((1 ... 64).first { candidate in
            StageCompletion.resolveLoot(for: stage, worldSeed: UInt64(candidate)).materials.contains { $0.resource == .gems }
        })
        #expect(state.playerSave.persistBatch(logging: "Test setup") { save in
            save.worldSeed = UInt64(seed)
            save.homestead.nodeTiers[.moonlitSanctum] = 1
            save.homestead.lastProductionAt = .now
        })

        #expect(state.journey.startBattle(for: stage) == nil)
        let battle = try #require(state.battle as? BattleSession)
        let configuration = try #require(battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: configuration.runKey))
        let baseGems = try #require(presentation.materialRewards.first { $0.resource == .gems }).quantity
        let startingGems = state.playerSave.homestead.resources[.gems, default: 0]
        battle.presentLaunchVictory()
        let summary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        let awardedGems = try #require(summary.materialRewards.first { $0.resource == .gems }).quantity
        #expect(awardedGems == baseGems + 1)

        let didClaim = if passesDisplayedMaterialsAsOverride {
            state.completeActiveBattle(
                configuration, battleGold: summary.goldFlow,
                materialRewards: summary.materialRewards, settlement: summary.settlement,
                defersPresentationExit: true,
            ).didComplete
        } else {
            battle.claimVictory(configurationID: configuration.id, summary: summary, defersPresentationExit: true)
        }
        #expect(didClaim)
        #expect(state.playerSave.journey.hasClaimedRewards(for: stage))
        #expect(state.playerSave.homestead.resources[.gems, default: 0] == startingGems + awardedGems)
        let claimedSave = state.playerSave.currentSave
        #expect(!battle.claimVictory(configurationID: configuration.id, summary: summary, defersPresentationExit: true))
        #expect(state.playerSave.currentSave == claimedSave)
        battle.finishVictoryPresentation(configurationID: configuration.id)
        #expect(battle.activeBattle == nil)
        #expect(state.shellSession.playPath == [.campaign])
    }
}
