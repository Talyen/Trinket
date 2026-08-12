import Foundation
import Testing
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
import TrinketTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct AppStatePlayFlowTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func preparedJourneyBattleActivatesConfigurationAndState() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        state.shellSession.selectedTab = .options

        state.journey.prepareBattle(for: stage)

        #expect(state.battle.activeBattle == nil)
        #expect(state.shellSession.selectedTab == .options)

        #expect(state.journey.startBattle(for: stage) == nil)

        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.journey(stageID: stage.id).runKey)
        #expect(state.shellSession.selectedTab == .play)
        let battle = try #require(context.lastBattle)
        #expect(battle.hasActiveSimulation)
    }

    @Test func unchangedJourneyInputsReuseLaunchPreparedBattle() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)

        state.journey.prepareBattle(for: stage)
        let preparedRevision = battle.preparedBattlePresentationRevision

        state.journey.prepareBattle(for: stage)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
    }

    @Test func journeyRewardClaimChangeReplacesLaunchPreparedBattle() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey

        state.journey.prepareBattle(for: stage)
        let preparedRevision = battle.preparedBattlePresentationRevision
        #expect(state.battlePresentation(for: runKey)?.stageRewardsAlreadyClaimed == false)

        try state.playerSave.performBatchMutation { save in
            save.journey.markRewardsClaimed(for: stage)
        }
        state.journey.prepareBattle(for: stage)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision + 1)
        #expect(state.battlePresentation(for: runKey)?.stageRewardsAlreadyClaimed == true)
    }

    @Test func freshJourneyBattleActivationSelectsPlayTab() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        state.shellSession.selectedTab = .options

        #expect(state.journey.startBattle(for: stage) == nil)

        #expect(state.battle.activeBattle != nil)
        #expect(state.shellSession.selectedTab == .play)
    }

    @Test(arguments: ["journey", "spire", "labyrinth"] as [String])
    func battleActivationFailureReturnsRetryableMessage(mode: String) throws {
        let runtime = RejectingBattleRuntime()
        let arguments = mode == "labyrinth" ? ["-reset-state"] : []
        let state = try context.makePlaySession(
            arguments: arguments,
            battleRuntime: runtime
        )

        let message: StageMapMessage?
        switch mode {
        case "journey":
            let stage = try #require(GameContent.chapters[0].stages.first)
            message = state.journey.startBattle(for: stage)
        case "spire":
            let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
            message = state.spires.startBattle(for: floor)
        case "labyrinth":
            _ = state.labyrinth.enter()
            let nodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
            message = state.labyrinth.startBattle(nodeID: nodeID)
        default:
            Issue.record("Unexpected mode \(mode)")
            return
        }

        #expect(message?.title == "Battle Unavailable")
        #expect(message?.message == "Could not start this battle. Try again.")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func failedPreparedJourneyActivationRetainsPreparedInputs() throws {
        let runtime = PreparedThenRejectingBattleRuntime()
        let state = try context.makePlaySession(battleRuntime: runtime)
        let stage = try #require(GameContent.chapters[0].stages.first)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey

        state.journey.prepareBattle(for: stage)
        #expect(runtime.prepareCount == 1)
        #expect(state.battlePresentation(for: runKey) != nil)
        #expect(state.journey.startBattle(for: stage)?.title == "Battle Unavailable")
        #expect(state.battlePresentation(for: runKey) != nil)

        runtime.shouldRejectActivation = false
        #expect(state.journey.startBattle(for: stage) == nil)

        #expect(runtime.prepareCount == 1)
        #expect(state.battle.activeBattle?.runKey == runKey)
        #expect(state.battlePresentation(for: runKey) != nil)
    }

    @Test func completeActiveBattleWithStageCompletesJourneyIdempotently() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let initialGold = state.playerSave.roster.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.journey.completedStageIDs.contains(stage.id))
        #expect(state.playerSave.roster.gold > initialGold + 4)

        let goldAfterFirstContinue = state.playerSave.roster.gold
        state.completeActiveBattle(configuration, battleEarnedGold: 5)

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.roster.gold == goldAfterFirstContinue)
        let loot = BattleLoot.resolveJourney(
            stage: stage,
            encounterLevel: configuration.enemyEncounterLevel ?? 1,
            enemyIsBoss: false
        )
        #expect(state.playerSave.roster.gold == initialGold + 5 + loot.gold)
    }

    @Test func completeActiveBattleWithoutStageGrantsGoldOnly() throws {
        let state = try context.makePlaySession()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            enemy: enemy
        )
        _ = state.battle.activate(configuration)
        let journeyBefore = state.playerSave.journey
        let initialGold = state.playerSave.roster.gold

        state.completeActiveBattle(configuration, battleEarnedGold: 10)

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey == journeyBefore)
        #expect(state.playerSave.roster.gold == initialGold + 10)
    }

    @Test func completeActiveBattleWithoutStageRespectsPendingGoldReservation() throws {
        let state = try context.makePlaySession()
        var save = state.playerSave.currentSave
        save.roster.gold = PlayerRosterState.maxGoldBalance - 4
        save.homestead.pendingProduction[.gold] = 1
        try state.playerSave.performBatchMutation { $0 = save }

        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try BattleRunConfigurationTestSupport.make(
            rngSeed: 0,
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            enemy: enemy
        )
        _ = state.battle.activate(configuration)

        state.completeActiveBattle(configuration, battleEarnedGold: 10)

        #expect(state.playerSave.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        #expect(state.playerSave.homestead.pendingProduction[.gold] == 1)
    }

    @Test func unknownBattleRouteFailsClosedWithoutGrantingGold() throws {
        let state = try context.makePlaySession()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = try BattleRunConfigurationTestSupport.make(
            runKey: BattleRunKey("future-mode|run-1"),
            rngSeed: 0,
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            enemy: enemy
        )
        _ = state.battle.activate(configuration)
        let initialGold = state.playerSave.roster.gold

        let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 10)

        #expect(!didPersist)
        #expect(state.battle.activeBattle != nil)
        #expect(state.playerSave.roster.gold == initialGold)
    }

    #if DEBUG
    @Test(arguments: ["persist", "missing-stage", "missing-spire"] as [String])
    func completeActiveBattleKeepsBattleOpenOnFailure(mode: String) throws {
        switch mode {
        case "persist":
            let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
            let state = try context.makePlaySession(playerSave: playerSave)
            let stage = try #require(GameContent.chapters[0].stages.first)
            _ = state.journey.startBattle(for: stage)
            let configuration = try #require(state.battle.activeBattle)

            playerSave.forcesNextSaveFailure = true
            let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 0)

            #expect(!didPersist)
            #expect(state.battle.activeBattle != nil)
            #expect(state.playerSave.journey.activeStageID == stage.id)
        case "missing-stage":
            let state = try context.makePlaySession()
            let enemy = try #require(GameContent.enemies.first?.combatant)
            let configuration = try BattleRunConfigurationTestSupport.make(
                origin: .journey(stageID: "missing-stage-bug-hunt-audit"),
                rngSeed: 0,
                hero: state.playerSave.roster.activeHero,
                companion: state.playerSave.roster.activeCompanion,
                enemy: enemy
            )
            _ = state.battle.activate(configuration)
            let goldBefore = state.playerSave.roster.gold

            let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 5)

            #expect(!didPersist)
            #expect(state.battle.activeBattle != nil)
            #expect(state.playerSave.roster.gold == goldBefore)
        case "missing-spire":
            let state = try context.makePlaySession()
            let enemy = try #require(GameContent.enemies.first?.combatant)
            let configuration = try BattleRunConfigurationTestSupport.make(
                origin: .spire(spireID: .ironVein, floor: 9999),
                rngSeed: 0,
                hero: state.playerSave.roster.activeHero,
                companion: state.playerSave.roster.activeCompanion,
                enemy: enemy
            )
            _ = state.battle.activate(configuration)

            let didPersist = state.completeActiveBattle(configuration, battleEarnedGold: 5)

            #expect(!didPersist)
            #expect(state.battle.activeBattle != nil)
        default:
            Issue.record("Unexpected failure mode \(mode)")
        }
    }
    #endif

    @Test func unlockAllContentClearsActiveBattleAndPreservesTab() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.play.journey.startBattle(for: stage)

        #expect(state.unlockAllContent())

        #expect(state.play.battle.activeBattle == nil)
        #expect(state.play.shellSession.selectedTab == .play)
    }

    @Test(arguments: ["journey", "spire", "labyrinth"] as [String])
    func endBattleReturningToOriginQueuesExpectedDeepLink(origin: String) throws {
        switch origin {
        case "journey":
            let state = try context.makePlaySession()
            let stage = try #require(GameContent.chapters[0].stages.first)
            _ = state.journey.startBattle(for: stage)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.consumePendingDestination() == .campaign)
        case "spire":
            let state = try makeProgressedStateForReturnTests()
            try attunePhysicalPartyForReturnTests(on: state)

            let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
            #expect(state.spires.startBattle(for: floor) == nil)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.consumePendingDestination() == .spireClimb(.ironVein))
        case "labyrinth":
            let state = try context.makePlaySession(arguments: ["-reset-state"])
            _ = state.labyrinth.enter()
            let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
            #expect(state.labyrinth.startBattle(nodeID: combatNodeID) == nil)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.consumePendingDestination() == .labyrinthMap)
        default:
            Issue.record("Unexpected origin \(origin)")
        }
    }

    @Test func completeActiveBattleQueuesSpireReturnDestination() throws {
        let state = try makeProgressedStateForReturnTests()
        try attunePhysicalPartyForReturnTests(on: state)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 1))
        #expect(state.consumePendingDestination() == .spireClimb(.ironVein))
    }

    @Test func completeActiveBattleGoldMatchesVictorySummaryWhenHomesteadBonusActive() throws {
        let state = try context.makePlaySession()
        var homestead = state.playerSave.homestead
        homestead.nodeTiers[.wishingWell] = 2
        homestead.lastProductionAt = Date()
        state.playerSave.homestead = homestead

        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        // Loot All must pass raw mid-battle gold (summary.rawBattleEarnedGold),
        // not the homestead-adjusted display split (summary.battleGold). The
        // expected total is pinned so a shared regression in both the loot math
        // and the completion wiring cannot pass in lockstep.
        let rawBattleEarnedGold = 20
        let pinnedTotal = 26
        let initialGold = state.playerSave.roster.gold

        #expect(state.completeActiveBattle(
            configuration,
            battleEarnedGold: rawBattleEarnedGold
        ))
        #expect(state.playerSave.roster.gold == initialGold + pinnedTotal)
    }

    @Test func presentBattleLogShowsLogWithoutChangingTabs() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        state.shellSession.selectedTab = .options

        let battle = try #require(context.lastBattle)
        battle.presentBattleLog()

        #expect(state.shellSession.selectedTab == .options)
        #expect(battle.isShowingBattleLog)
        #expect(state.battle.activeBattle != nil)
    }

    private func makeProgressedStateForReturnTests() throws -> PlaySession {
        try context.makePlaySession(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5",
        ])
    }

    private func attunePhysicalPartyForReturnTests(on state: PlaySession) throws {
        var roster = state.playerSave.roster
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        roster.unlock(rogue)
        roster.unlock(lizard)
        roster.setActiveHero(rogue)
        roster.setActiveCompanion(lizard)
        state.playerSave.roster = roster
    }
}

@MainActor
private class RejectingBattleRuntime: BattleRuntime {
    var activeBattle: BattleRunConfiguration?
    var lifecyclePhase: BattleLifecyclePhase = .idle
    var isSuspendedForScenePhase = false

    func prepareBattleRun(_: BattleRunConfiguration) -> Bool {
        false
    }

    func activatePreparedBattle(
        runKey _: BattleRunKey,
        heroID _: String,
        companionID _: String,
        enemyID _: String?
    ) -> Bool {
        false
    }

    func activate(_: BattleRunConfiguration) -> Bool {
        false
    }

    func restart(_: BattleRunConfiguration) -> Bool {
        false
    }

    func endBattle() {}

    func setSuspendedForScenePhase(_ suspended: Bool) {
        isSuspendedForScenePhase = suspended
    }

    func trimMemoryFootprint(releaseBattleLog _: Bool) {}
}

@MainActor
private final class PreparedThenRejectingBattleRuntime: RejectingBattleRuntime {
    private(set) var prepareCount = 0
    var shouldRejectActivation = true
    private var preparedConfiguration: BattleRunConfiguration?

    override func prepareBattleRun(_ configuration: BattleRunConfiguration) -> Bool {
        prepareCount += 1
        preparedConfiguration = configuration
        lifecyclePhase = .prepared
        return true
    }

    override func activatePreparedBattle(
        runKey _: BattleRunKey,
        heroID _: String,
        companionID _: String,
        enemyID _: String?
    ) -> Bool {
        guard !shouldRejectActivation, let preparedConfiguration else { return false }
        activeBattle = preparedConfiguration
        lifecyclePhase = .active
        return true
    }

    override func activate(_ configuration: BattleRunConfiguration) -> Bool {
        guard !shouldRejectActivation else { return false }
        activeBattle = configuration
        lifecyclePhase = .active
        return true
    }
}
