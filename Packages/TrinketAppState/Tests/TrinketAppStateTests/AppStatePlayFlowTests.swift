import BattleEngine
import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct AppStatePlayFlowTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `prepared journey battle activates configuration and state`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)
        state.shellSession.selectedTab = .options

        state.journey.prepareBattle(for: stage)

        #expect(state.battle.activeBattle == nil)
        #expect(state.shellSession.selectedTab == .options)
        let preparedRevision = battle.preparedBattlePresentationRevision

        #expect(state.journey.startBattle(for: stage) == nil)

        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.journey(stageID: stage.id).runKey)
        #expect(state.shellSession.selectedTab == .play)
        #expect(battle.lifecyclePhase == .active)
        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
    }

    @Test func `unchanged journey inputs reuse launch prepared battle`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)

        state.journey.prepareBattle(for: stage)
        let preparedRevision = battle.preparedBattlePresentationRevision

        state.journey.prepareBattle(for: stage)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
    }

    @Test func `journey reward claim change refreshes metadata and retains prepared battle`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey

        state.journey.prepareBattle(for: stage)
        let preparedRevision = battle.preparedBattlePresentationRevision
        let prepared = try #require(state.battleCoordinator.preparedRuns[runKey])
        #expect(state.battlePresentation(for: runKey)?.stageRewardsAlreadyClaimed == false)

        try state.playerSave.performFixtureMutation { save in
            save.journey.markRewardsClaimed(for: stage)
        }
        state.journey.prepareBattle(for: stage)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
        let refreshed = try #require(state.battleCoordinator.preparedRuns[runKey])
        #expect(refreshed.handle === prepared.handle)
        #expect(refreshed.registration.launch.configuration.id == prepared.registration.launch.configuration.id)
        #expect(state.battlePresentation(for: runKey)?.stageRewardsAlreadyClaimed == true)
    }

    @Test func `changing companion re prepares journey battle`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let battle = try #require(context.lastBattle)
        let otherCompanion = try #require(
            GameContent.companions.first { $0.id != state.playerSave.roster.activeCompanionID },
        )

        state.journey.prepareBattle(for: stage)
        let preparedRevision = battle.preparedBattlePresentationRevision

        PlayBattleLaunchTestSupport.setActiveCompanion(otherCompanion, in: state)
        state.journey.prepareBattle(for: stage)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision + 1)
    }

    @Test(arguments: [PlayBattleMode.journey, .spire, .labyrinth])
    func `battle activation failure shows unavailable message`(mode: PlayBattleMode) throws {
        let runtime = RejectingBattleRuntime()
        let arguments = mode == .labyrinth ? ["-reset-state"] : []
        let state = try context.makePlaySession(
            arguments: arguments,
            battleRuntime: runtime,
        )

        let message: StageMapMessage?
        switch mode {
        case .journey:
            let stage = try #require(GameContent.chapters[0].stages.first)
            message = state.journey.startBattle(for: stage)
        case .spire:
            let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
            message = state.spires.startBattle(for: floor)
        case .labyrinth:
            _ = state.labyrinth.enter()
            let nodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
            message = state.labyrinth.startBattle(nodeID: nodeID)
        case .contract, .voyage:
            return
        }

        let shown = try #require(message)
        #expect(shown.title == PlayBattleCoordinator.activationFailureMessage.title)
        #expect(state.battle.activeBattle == nil)
    }

    @Test func `failed prepared journey activation retains prepared inputs`() throws {
        let runtime = PreparedThenRejectingBattleRuntime()
        let state = try context.makePlaySession(battleRuntime: runtime)
        let stage = try #require(GameContent.chapters[0].stages.first)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey

        state.journey.prepareBattle(for: stage)
        #expect(runtime.prepareCount == 1)
        #expect(state.battlePresentation(for: runKey) != nil)
        #expect(state.journey.startBattle(for: stage)?.title == PlayBattleCoordinator.activationFailureMessage.title)
        #expect(state.battle.activeBattle == nil)
        #expect(state.battlePresentation(for: runKey) != nil)

        runtime.shouldRejectActivation = false
        #expect(state.journey.startBattle(for: stage) == nil)

        #expect(runtime.prepareCount == 1)
        #expect(state.battle.activeBattle?.runKey == runKey)
        #expect(state.battlePresentation(for: runKey) != nil)
    }

    @Test func `journey launch refreshes selected party while direct activation rejects mismatches`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        let otherHero = try #require(
            GameContent.heroes.first { $0.id != state.playerSave.roster.activeHeroID },
        )
        let otherCompanion = try #require(
            GameContent.companions.first { $0.id != state.playerSave.roster.activeCompanionID },
        )

        state.journey.prepareBattle(for: stage)
        let prepared = try #require(state.battleCoordinator.registration(for: runKey))

        try PlayBattleLaunchTestSupport.setActiveParty(
            heroID: otherHero.id, companionID: otherCompanion.id, in: state,
        )
        var mismatchedInput = prepared.launch.inputs.launch
        mismatchedInput.hero = state.playerSave.roster.activeHero
        mismatchedInput.companion = state.playerSave.roster.activeCompanion

        #expect(!state.battleCoordinator.activateBattle(mismatchedInput, route: prepared.route))
        #expect(state.battle.activeBattle == nil)
        #expect(state.battleCoordinator.registration(for: runKey)?.launch.configuration.id == prepared.launch.configuration.id)

        #expect(state.journey.startBattle(for: stage) == nil)
        let active = try #require(state.battle.activeBattle)
        #expect(active.hero.combatant.id == otherHero.id)
        #expect(active.companion.combatant.id == otherCompanion.id)
        #expect(active.id != prepared.launch.configuration.id)
        #expect(active.rngSeed == prepared.launch.configuration.rngSeed)
    }

    @Test func `complete active battle with stage completes journey idempotently`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: configuration.runKey))
        let initialGold = state.playerSave.roster.gold
        let expectedGold = presentation.rewardPlan.resolve(battleGold: .init(gained: 5)).goldDelta

        state.completeActiveBattle(configuration, battleGold: .init(gained: 5))

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.journey.completedStageIDs.contains(stage.id))
        #expect(state.playerSave.roster.gold > initialGold + 4)

        let goldAfterFirstContinue = state.playerSave.roster.gold
        state.completeActiveBattle(configuration, battleGold: .init(gained: 5))

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-2")
        #expect(state.playerSave.roster.gold == goldAfterFirstContinue)
        #expect(state.playerSave.roster.gold == initialGold + expectedGold)

        let reloaded = try PlayerSaveStore(
            storeURL: SaveTestSupport.makeStoreURL(directoryURL: context.directoryURL),
            disableCloudSync: true,
        )
        #expect(reloaded.journey.completedStageIDs.contains(stage.id))
        #expect(reloaded.journey.activeStageID == "chapter-1-stage-2")
        #expect(reloaded.roster.gold == goldAfterFirstContinue)
    }

    @Test(arguments: [PlayBattleMode.journey, .labyrinth, .spire])
    func `duplicate route delivery reports unavailable without paying twice`(origin: PlayBattleMode) throws {
        switch origin {
        case .journey:
            let state = try context.makePlaySession()
            let stage = try #require(GameContent.chapters[0].stages.first)
            _ = state.journey.startBattle(for: stage)
            try checkDuplicateDelivery(state: state)
        case .labyrinth:
            let state = try context.makePlaySession(arguments: ["-reset-state"])
            let combatNodeID = try LabyrinthTestSupport.enterAndFindCombatNode(in: state)
            _ = state.labyrinth.startBattle(nodeID: combatNodeID)
            try checkDuplicateDelivery(state: state)
        case .spire:
            let state = try context.makePlaySession()
            let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
            _ = state.spires.startBattle(for: floor)
            try checkDuplicateDelivery(state: state)
        case .contract, .voyage:
            break
        }
    }

    private func checkDuplicateDelivery(state: PlaySession) throws {
        let configuration = try #require(state.battle.activeBattle)
        let registration = try #require(state.battleCoordinator.registration(for: configuration.runKey))
        let settlement = try #require(state.settleBattleRewards(configuration, battleGold: .init(gained: 5)))

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 5)).didComplete)
        let saveAfterVictory = state.playerSave.currentSave
        guard case .rejected(.unavailable) = state.playerSave.completeBattle(
            registration.rewardClaim, award: settlement, enemyEncounterLevel: configuration.enemyEncounterLevel,
        ) else {
            Issue.record("A completed registration must reject another reward claim")
            return
        }
        #expect(state.playerSave.currentSave == saveAfterVictory)
    }

    @Test func `complete active battle without stage grants gold only`() throws {
        let state = try context.makePlaySession()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        #expect(state.battleCoordinator.activateBattle(BattleLaunchInput(
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            encounter: ScaledEncounter(combatant: enemy, level: state.playerSave.roster.activePartyAverageLevel),
        )))
        let configuration = try #require(state.battle.activeBattle)
        let journeyBefore = state.playerSave.journey
        let initialGold = state.playerSave.roster.gold

        state.completeActiveBattle(configuration, battleGold: .init(gained: 10))

        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.journey == journeyBefore)
        #expect(state.playerSave.roster.gold == initialGold + 10)
    }

    @Test func `complete active battle without stage grants fitting gold around reserved production`() throws {
        let state = try context.makePlaySession()
        var save = state.playerSave.currentSave
        save.roster.gold = PlayerRosterState.maxGoldBalance - 4
        save.homestead.pendingProduction[.gold] = 1
        try state.playerSave.performFixtureMutation { $0 = save }

        let enemy = try #require(GameContent.enemies.first?.combatant)
        #expect(state.battleCoordinator.activateBattle(BattleLaunchInput(
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            encounter: ScaledEncounter(combatant: enemy, level: state.playerSave.roster.activePartyAverageLevel),
        )))
        let configuration = try #require(state.battle.activeBattle)

        state.completeActiveBattle(configuration, battleGold: .init(gained: 10))

        #expect(state.playerSave.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        #expect(state.playerSave.homestead.pendingProduction[.gold] == 1)
    }

    @Test func `unregistered battle cannot activate or grant rewards`() throws {
        let state = try context.makePlaySession()
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let configuration = PlayBattleLaunchTestSupport.make(
            origin: .journey(stageID: "unregistered-stage"),
            rngSeed: 0,
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion,
            enemy: enemy,
        )
        #expect(!state.battleCoordinator.activatePrepared(configuration))
        let initialGold = state.playerSave.roster.gold

        let didPersist = state.completeActiveBattle(configuration, battleGold: .init(gained: 10)).didComplete

        #expect(!didPersist)
        #expect(state.battle.activeBattle == nil)
        #expect(state.playerSave.roster.gold == initialGold)
    }

    @Test func `unlock all content clears active battle and preserves tab`() throws {
        let state = try context.makeAppState()
        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.play.journey.startBattle(for: stage)

        #expect(state.unlockAllContent().value)

        #expect(state.play.battle.activeBattle == nil)
        #expect(state.play.shellSession.selectedTab == .play)
    }

    @Test(arguments: [PlayBattleMode.journey, .spire, .labyrinth])
    func `end battle restores the origin path without a deferred deep link`(origin: PlayBattleMode) throws {
        switch origin {
        case .journey:
            let state = try context.makePlaySession()
            let stage = try #require(GameContent.chapters[0].stages.first)
            _ = state.journey.startBattle(for: stage)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.shellSession.playPath == [.campaign])
            #expect(state.consumePendingDestination() == nil)
        case .spire:
            let state = try makeProgressedStateForReturnTests(context)
            try attunePhysicalPartyForReturnTests(on: state)

            let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
            #expect(state.spires.startBattle(for: floor) == nil)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.shellSession.playPath == [.explore, .spiresHub, .spireClimb(.ironVein)])
            #expect(state.consumePendingDestination() == nil)
        case .labyrinth:
            let state = try context.makePlaySession(arguments: ["-reset-state"])
            _ = state.labyrinth.enter()
            let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
            #expect(state.labyrinth.startBattle(nodeID: combatNodeID) == nil)
            state.shellSession.selectedTab = .options

            state.endBattleReturningToOrigin()

            #expect(state.battle.activeBattle == nil)
            #expect(state.shellSession.selectedTab == .play)
            #expect(state.shellSession.playPath == [.explore, .labyrinthMap])
            #expect(state.consumePendingDestination() == nil)
        case .contract, .voyage:
            break
        }
    }

    @Test func `complete active battle restores the spire path without a deferred deep link`() throws {
        let state = try makeProgressedStateForReturnTests(context)
        try attunePhysicalPartyForReturnTests(on: state)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 1)).didComplete)
        #expect(state.shellSession.playPath == [.explore, .spiresHub, .spireClimb(.ironVein)])
        #expect(state.consumePendingDestination() == nil)
    }

    @Test func `complete active battle gold matches victory summary when homestead bonus active`() throws {
        let state = try context.makePlaySession()
        var homestead = state.playerSave.homestead
        homestead.nodeTiers[.wishingWell] = 2
        homestead.lastProductionAt = Date()
        #expect(state.playerSave.persistFixtureBatch(logging: "Test setup") { $0.homestead = homestead })

        let stage = try #require(GameContent.chapters[0].stages.first)
        _ = state.journey.startBattle(for: stage)
        let configuration = try #require(state.battle.activeBattle)
        let rawBattleEarnedGold = 20
        let presentation = try #require(state.battlePresentation(for: configuration.runKey))
        let expectedTotal = presentation.rewardPlan.resolve(battleGold: .init(gained: rawBattleEarnedGold)).goldDelta
        let initialGold = state.playerSave.roster.gold

        #expect(state.completeActiveBattle(
            configuration,
            battleGold: .init(gained: rawBattleEarnedGold),
        ).didComplete)
        #expect(state.playerSave.roster.gold == initialGold + expectedTotal)
    }

    @Test func `present battle log shows log without changing tabs`() throws {
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
}

extension AppStatePlayFlowTests {
    @Test func `revisiting A prepared journey stage preserves its battle and seed`() throws {
        let state = try context.makePlaySession()
        let stage = try PlayBattleLaunchTestSupport.firstJourneyStage()
        let siblingStage = try #require(GameContent.chapters.flatMap(\.stages).first {
            $0.encounter.isCombat && $0.id != stage.id
        })
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        var seedDraws = 0
        state.battleCoordinator.nextCombatSeed = {
            seedDraws += 1
            return UInt64(seedDraws)
        }
        state.journey.prepareBattle(for: stage)
        let original = try #require(state.battleCoordinator.registration(for: runKey))
        state.journey.prepareBattle(for: siblingStage)

        state.journey.prepareBattle(for: stage)

        #expect(state.battleCoordinator.registration(for: runKey)?.launch.configuration.id == original.launch.configuration.id)
        #expect(seedDraws == 2)
        #expect(state.journey.startBattle(for: stage) == nil)
        #expect(state.battle.activeBattle?.rngSeed == original.launch.configuration.rngSeed)
    }

    @Test func `preparation refresh preserves seed and refreshes saved party inputs`() throws {
        let state = try context.makePlaySession()
        let stage = try PlayBattleLaunchTestSupport.firstJourneyStage()
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        var seedDraws = 0
        state.battleCoordinator.nextCombatSeed = {
            seedDraws += 1
            return UInt64(seedDraws)
        }
        state.journey.prepareBattle(for: stage)
        let original = try #require(state.battleCoordinator.registration(for: runKey))
        #expect(state.playerSave.persistFixtureBatch(logging: "Test setup") {
            $0.homestead.nodeTiers[.agilityTraining] = 1
        })

        state.journey.prepareBattle(for: stage)

        let refreshed = try #require(state.battleCoordinator.registration(for: runKey))
        #expect(refreshed.launch.configuration.id != original.launch.configuration.id)
        #expect(refreshed.launch.inputs.party.homestead == state.playerSave.homestead)
        #expect(refreshed.launch.configuration.rngSeed == original.launch.configuration.rngSeed)
        #expect(seedDraws == 1)
        #expect(state.journey.startBattle(for: stage) == nil)
        #expect(state.battle.activeBattle?.id == refreshed.launch.configuration.id)
    }

    @Test func `rejected preparation refresh evicts only its own run and can recover`() throws {
        let runtime = PreparedThenRejectingBattleRuntime()
        let state = try context.makePlaySession(battleRuntime: runtime)
        let stage = try PlayBattleLaunchTestSupport.firstJourneyStage()
        state.journey.prepareBattle(for: stage)
        let runKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        let original = try #require(state.battleCoordinator.registration(for: runKey))
        let siblingStage = try #require(GameContent.chapters.flatMap(\.stages).first {
            $0.encounter.isCombat && $0.id != stage.id
        })
        state.journey.prepareBattle(for: siblingStage)
        let siblingKey = PlayBattleOrigin.journey(stageID: siblingStage.id).runKey
        let sibling = try #require(state.battleCoordinator.registration(for: siblingKey))

        #expect(state.playerSave.persistFixtureBatch(logging: "Test setup") {
            $0.homestead.nodeTiers[.agilityTraining] = 1
        })
        runtime.shouldRejectPreparation = true
        #expect(try !state.battleCoordinator.prepareCombat(original.launch.inputs.launch, route: #require(original.route)))
        #expect(!(state.battleCoordinator.preparedRuns[runKey] != nil))
        #expect(state.battleCoordinator.registration(for: runKey) == nil)
        #expect(state.battleCoordinator.preparedRuns[siblingKey] != nil)
        #expect(state.battleCoordinator.registration(for: siblingKey)?.launch.configuration.id == sibling.launch.configuration.id)

        runtime.shouldRejectPreparation = false
        runtime.shouldRejectActivation = false
        #expect(state.journey.startBattle(for: stage) == nil)
        #expect(state.battle.activeBattle?.runKey == runKey)
        #expect(state.battleCoordinator.preparedRuns[siblingKey] != nil)
        state.endBattleReturningToOrigin()
        #expect(!(state.battleCoordinator.preparedRuns[siblingKey] != nil))
        #expect(state.battleCoordinator.registration(for: siblingKey) == nil)
    }

    @Test func `rejected restart receives presentation without publishing candidate metadata`() throws {
        let runtime = PreparedThenRejectingBattleRuntime()
        let state = try context.makePlaySession(battleRuntime: runtime)
        let stage = try PlayBattleLaunchTestSupport.firstJourneyStage()
        runtime.shouldRejectActivation = false
        #expect(state.journey.startBattle(for: stage) == nil)
        let active = try #require(runtime.activeBattle)
        let original = try #require(state.battlePresentation(for: active))
        defer { runtime.onRestart = nil }
        var lookedUpReplacement = false
        runtime.onRestart = { configuration, presentation in
            lookedUpReplacement = configuration.id != active.id
                && state.battlePresentation(for: configuration) == nil
                && presentation.rewardPlan == original.rewardPlan
        }

        #expect(state.restartActiveBattle()?.title == PlayBattleCoordinator.activationFailureMessage.title)
        #expect(lookedUpReplacement)
        #expect(runtime.activeBattle?.id == active.id)
        #expect(state.battleCoordinator.registration(for: active.runKey)?.launch.configuration.id == active.id)
        #expect(state.battlePresentation(for: active)?.rewardPlan == original.rewardPlan)
    }

    @Test func `mode scoped pruning preserves sibling prepared runs`() throws {
        let state = try context.makePlaySession()
        let stage = try #require(GameContent.chapters[0].stages.first)
        let journeyKey = PlayBattleOrigin.journey(stageID: stage.id).runKey

        state.journey.prepareBattle(for: stage)
        #expect(state.battleCoordinator.preparedRuns[journeyKey] != nil)

        let labyrinthNodeID = "test-node-1"
        let labyrinthKey = PlayBattleOrigin.labyrinth(nodeID: labyrinthNodeID).runKey
        let hero = try #require(GameContent.heroes.first)
        let companion = try #require(GameContent.companions.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)

        let labyrinthLaunch = PlayBattleLaunchTestSupport.assemble(
            input: BattleLaunchInput(
                origin: .labyrinth(nodeID: labyrinthNodeID),
                hero: hero,
                companion: companion,
                encounter: ScaledEncounter(combatant: enemy, level: state.playerSave.roster.activePartyAverageLevel),
            ),
            rngSeed: 1,
            rosterState: state.playerSave.roster,
            inventoryState: state.playerSave.inventory,
        )
        let labyrinthRoute = PlayBattleRoute.labyrinth(nodeID: labyrinthNodeID, access: .free)
        #expect(state.battleCoordinator.prepare(labyrinthLaunch, route: labyrinthRoute))
        #expect(state.battleCoordinator.preparedRuns[labyrinthKey] != nil)
        #expect(state.battleCoordinator.preparedRuns[journeyKey] != nil)

        // Pruning for .labyrinth with empty survivors drops labyrinth runs
        // while preserving sibling modes (journey).
        state.battleCoordinator.prunePreparedRuns(for: .labyrinth, keeping: [])
        #expect(!(state.battleCoordinator.preparedRuns[labyrinthKey] != nil))
        #expect(state.battleCoordinator.preparedRuns[journeyKey] != nil)
    }
}

@MainActor
private func makeProgressedStateForReturnTests(_ context: AppTestContext) throws -> PlaySession {
    try context.makePlaySession(arguments: [
        "-reset-state",
        "-seed-test-progress",
        "-completed-stages",
        "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5",
    ])
}

@MainActor
private func attunePhysicalPartyForReturnTests(on state: PlaySession) throws {
    try PlayBattleLaunchTestSupport.setActiveParty(heroID: "rogue", companionID: "lizard_scout", in: state)
}

extension AppStatePlayFlowTests {
    @Test(arguments: [false, true])
    func `external save generation invalidates prepared and active battles`(activates: Bool) throws {
        let state = try context.makePlaySession()
        // Exercise the generation fence before presentation cleanup removes stale runs.
        state.playerSave.onExternalProgressChange = nil
        let stage = try PlayBattleLaunchTestSupport.firstJourneyStage()
        let key = PlayBattleOrigin.journey(stageID: stage.id).runKey
        state.journey.prepareBattle(for: stage)
        let prepared = try #require(state.battleCoordinator.registration(for: key))
        let configuration = prepared.launch.configuration
        if activates {
            try #require(state.battleCoordinator.activatePrepared(configuration))
        }
        var incoming = state.playerSave.currentSave
        incoming.corruptionAltarCooldownRemaining += 1
        // Keep all party/launch inputs identical; replacing progress changes generation.
        try state.playerSave.commitCloudState(state.playerSave.cloudDeviceState, replacing: incoming)
        let before = state.playerSave.currentSave
        #expect(state.battleCoordinator.registration(for: key)?.launch.configuration.id == configuration.id)
        if activates {
            #expect(state.settleBattleRewards(configuration, battleGold: .init()) == nil)
            #expect(!state.completeActiveBattle(configuration, battleGold: .init()).didComplete)
            #expect(!state.battleCoordinator.restartActiveBattle(configuration))
            #expect(state.playerSave.currentSave == before)
        } else {
            #expect(!state.battleCoordinator.activatePrepared(configuration))
            state.journey.prepareBattle(for: stage)
            let refreshed = try #require(state.battleCoordinator.registration(for: key))
            #expect(refreshed.launch.configuration.id != configuration.id)
            #expect(refreshed.launch.configuration.rngSeed == configuration.rngSeed)
            #expect(state.battleCoordinator.activatePrepared(refreshed.launch.configuration))
        }
    }
}

extension AppStatePlayFlowTests {
    @Test func `a delayed forge completion refreshes a conflicting battle reward before claiming`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let recipe = try #require(EquipmentRecipe.all.first { recipe in
            GameContent.uniqueItems.contains { $0.baseType.id == recipe.baseID }
        })
        try state.playerSave.performFixtureMutation { save in
            save.inventory.items = []
            save.homestead.nodeTiers[recipe.buildingID] = 4
            for resource in HomesteadResource.allCases where resource != .gold {
                save.homestead.resources[resource] = 999
            }
        }
        let beforeForge = state.playerSave.currentSave
        var planned: BlacksmithForgePlan?
        for seed in UInt64(1) ... 4096 {
            var random = SeededRandomNumberGenerator(seed: seed)
            if case let .success(plan) = BlacksmithForgePlan.prepare(
                recipeID: recipe.id, rewardLevel: 40, inventory: beforeForge.inventory.items,
                homestead: beforeForge.homestead, gold: beforeForge.roster.gold, using: &random,
            ), plan.item.rarity == .unique {
                planned = plan
                break
            }
        }
        let forge = try #require(planned)
        let battleItem = InventoryItem(
            id: "battle-unique-instance", templateID: forge.item.templateID, baseType: forge.item.baseType,
            rarity: forge.item.rarity, displayName: forge.item.displayName, affixes: forge.item.affixes,
            isCorrupted: forge.item.isCorrupted, affixPowers: forge.item.affixPowers,
        )
        let input = BattleLaunchInput(
            origin: .journey(stageID: stage.id), hero: beforeForge.roster.activeHero,
            companion: beforeForge.roster.activeCompanion, encounter: ScaledEncounter(combatant: enemy, level: 1),
            stageReward: StageReward(gold: 10, itemTemplateIDs: []), pendingRewardItem: battleItem,
        )
        #expect(state.battleCoordinator.activateBattle(input, route: .journey(stage)))
        let configuration = try #require(state.battle.activeBattle)
        let original = try #require(state.settleBattleRewards(configuration, battleGold: .init()))
        #expect(original.award.items == [battleItem])

        // A pending Forge owns its roll before the player starts this battle.
        // Its successful retry commits that same plan after battle activation.
        try state.playerSave.performFixtureMutation { save in
            let result = forge.apply(inventory: &save.inventory.items, homestead: &save.homestead, gold: &save.roster.gold)
            if case .failure = result {
                Issue.record("The pending Forge must commit")
            }
        }
        guard case let .staleSettlement(refreshed) = state.completeActiveBattle(
            configuration, battleGold: .init(), settlement: original,
        ) else {
            Issue.record("A newly owned reward must refresh the reveal")
            return
        }
        #expect(refreshed.award.items.isEmpty)
        #expect(refreshed.award.goldDelta > original.award.goldDelta)
        let goldBeforeClaim = state.playerSave.roster.gold
        #expect(state.completeActiveBattle(configuration, battleGold: .init(), settlement: refreshed).didComplete)
        #expect(state.playerSave.roster.gold == goldBeforeClaim + refreshed.award.goldDelta)
        #expect(state.playerSave.inventory.items.count(where: { $0.templateID == forge.item.templateID }) == 1)
    }
}
