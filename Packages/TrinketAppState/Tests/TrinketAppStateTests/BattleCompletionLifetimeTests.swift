import Foundation
import Observation
import Testing
import TrinketContent
@testable import BattleEngine
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
struct BattleCompletionLifetimeTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    private enum Completion: CaseIterable { case victory, defeatLeave, defeatRetry }

    @Test(arguments: Completion.allCases)
    private func `save publication cannot claim restart or dismiss a replacement battle`(completion: Completion) async throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        defer { play.battleCoordinator.endBattle() }
        let configuration = try #require(battle.activeBattle)
        let progressionBefore = play.playerSave.roster.progression(for: configuration.hero.combatant)
        if completion != .victory {
            var state = try #require(battle.engineState)
            state.roster.enemy.currentHealth = max(1, state.roster.enemy.maxHealth / 10)
            state.roster.hero.currentHealth = 0
            state.roster.companion.currentHealth = 0
            battle.engineState = state
        }
        let probe = CompletionProbe()
        await confirmation("The committed reward publishes while its caller is still running") { published in
            withObservationTracking {
                _ = play.playerSave.roster
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(play.completeActiveBattle(configuration, battleGold: .init()) == .unavailable)
                    #expect(play.restartActiveBattle()?.title == PlayBattleCoordinator.activationFailureMessage.title)
                    play.endBattleReturningToOrigin()
                    #expect(play.journey.startBattle(for: stage) == nil)
                    probe.replacementID = battle.activeBattle?.id
                    published()
                }
            }
            switch completion {
            case .victory:
                #expect(play.battleCoordinator.completeActiveBattle(
                    configuration, battleGold: .init(), defersPresentationExit: true,
                    onFinished: { probe.finishedCount += 1 }, onClaimed: { probe.claimedCount += 1 },
                ).didComplete)
            case .defeatLeave, .defeatRetry:
                guard let settlement = play.settleDefeatRewards(configuration) else {
                    Issue.record("Expected resolved defeat settlement")
                    return
                }
                #expect(play.battleCoordinator.completeDefeat(
                    configuration, settlement: settlement,
                    action: completion == .defeatRetry ? .retry : .leave,
                    onFinished: { probe.finishedCount += 1 },
                ).didComplete)
            }
        }
        let replacementID = try #require(probe.replacementID)
        #expect(replacementID != configuration.id)
        #expect(battle.activeBattle?.id == replacementID)
        let replacement = try #require(play.battleCoordinator.activeBattle)
        guard case .unclaimed = replacement.claimState else {
            Issue.record("The replacement inherited a retired battle's reward claim")
            return
        }
        #expect(probe.finishedCount == 0)
        #expect(probe.claimedCount == 0)
        #expect(play.battleCoordinator.talentProgressionsBefore.isEmpty)
        #expect(play.playerSave.roster.progression(for: configuration.hero.combatant) != progressionBefore)
        play.finishBattleRewardPresentation(configurationID: configuration.id)
        #expect(battle.activeBattle?.id == replacementID)
    }

    @Test func `reward exit is consumed before route restoration and runtime teardown notify observers`() async throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let configuration = try #require(battle.activeBattle)
        let probe = CompletionProbe()
        #expect(play.battleCoordinator.completeActiveBattle(
            configuration, battleGold: .init(), defersPresentationExit: true,
            onFinished: {
                probe.finishedCount += 1
                #expect(play.journey.startBattle(for: stage) == nil)
                #expect(battle.activeBattle == nil)
            }, onClaimed: {},
        ).didComplete)
        play.shellSession.playPath = []
        await confirmation("Route and both runtime exit publications are observed", expectedCount: 3) { published in
            withObservationTracking {
                _ = play.shellSession.playPath
            } onChange: {
                MainActor.assumeIsolated {
                    play.finishBattleRewardPresentation(configurationID: configuration.id)
                    published()
                }
            }
            withObservationTracking {
                _ = battle.activeBattle
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(play.battleCoordinator.activeBattle == nil)
                    play.finishBattleRewardPresentation(configurationID: configuration.id)
                    published()
                }
            }
            withObservationTracking {
                _ = battle.spectacle
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(battle.activeBattle == nil)
                    #expect(play.journey.startBattle(for: stage) == nil)
                    #expect(battle.activeBattle == nil)
                    published()
                }
            }
            play.finishBattleRewardPresentation(configurationID: configuration.id)
        }
        #expect(probe.finishedCount == 1)
        #expect(battle.activeBattle == nil)
        #expect(play.shellSession.playPath == [.campaign])
        #expect(play.journey.startBattle(for: stage) == nil)
        #expect(battle.activeBattle != nil)
        play.battleCoordinator.endBattle()
    }

    @Test func `restart publication cannot claim the outgoing run`() async throws {
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        defer { play.battleCoordinator.endBattle() }
        let configuration = try #require(battle.activeBattle)
        await confirmation("Restart retires the old spectacle before replacing the active configuration") { published in
            withObservationTracking {
                _ = battle.spectacle
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(play.completeActiveBattle(configuration, battleGold: .init()) == .unavailable)
                    published()
                }
            }
            #expect(play.restartActiveBattle() == nil)
        }
        #expect(battle.activeBattle?.id != configuration.id)
        #expect(battle.activeBattle != nil)
        #expect(!play.playerSave.journey.hasClaimedRewards(for: stage))
    }

    @Test func `progress reset during activation invalidates the pending runtime installation`() async throws {
        let app = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)
        let generation = app.playerSave.sessionGeneration
        await confirmation("Activation publishes before returning to the coordinator") { published in
            withObservationTracking {
                _ = battle.activeBattle
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(app.resetGameplayProgress())
                    published()
                }
            }
            #expect(app.play.journey.startBattle(for: stage)?.title == PlayBattleCoordinator.activationFailureMessage.title)
        }
        #expect(app.playerSave.sessionGeneration != generation)
        #expect(battle.activeBattle == nil)
        #expect(battle.presentationContext == nil)
        #expect(!battle.hasActiveSimulation)
        #expect(app.play.battleCoordinator.activeBattle == nil)
        #expect(app.play.battleCoordinator.preparedRuns.isEmpty)
    }
}

@MainActor
private final class CompletionProbe {
    var replacementID: UUID?
    var finishedCount = 0
    var claimedCount = 0
}
