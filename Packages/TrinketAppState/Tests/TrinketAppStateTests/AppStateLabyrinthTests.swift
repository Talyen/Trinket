import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
import TrinketTestSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct AppStateLabyrinthTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func enterLabyrinthCreatesMapAndReusesItOnRepeat() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let message = state.labyrinth.enter()
        #expect(message == nil)
        #expect(state.playerSave.labyrinth.hasMap)
        #expect(!state.playerSave.labyrinth.reachableNodeIDs().isEmpty)
        let firstMap = state.playerSave.labyrinth

        let reuseMessage = state.labyrinth.enter()
        #expect(reuseMessage == nil)
        #expect(state.playerSave.labyrinth.hasMap)
        #expect(state.playerSave.labyrinth == firstMap)
    }

    @Test func unchangedLabyrinthInputsReusePreparedBattles() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        _ = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let battle = try #require(context.lastBattle)

        state.labyrinth.prepareReachableBattles()
        let preparedRevision = battle.preparedBattlePresentationRevision

        state.labyrinth.prepareReachableBattles()

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
    }

    @Test func relevantLabyrinthInputChangeReplacesPreparedBattles() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        _ = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let battle = try #require(context.lastBattle)
        state.labyrinth.prepareReachableBattles()
        let preparedRevision = battle.preparedBattlePresentationRevision

        var homestead = state.playerSave.homestead
        homestead.nodeTiers[.agilityTraining] = 1
        state.playerSave.homestead = homestead
        state.labyrinth.prepareReachableBattles()

        #expect(battle.preparedBattlePresentationRevision > preparedRevision)
    }

    @Test func returningFromBattlePreparesUnchangedLabyrinthInputsAgain() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let battle = try #require(context.lastBattle)
        state.labyrinth.prepareReachableBattles()
        let preparedRevision = battle.preparedBattlePresentationRevision

        _ = state.labyrinth.startBattle(nodeID: combatNodeID)
        state.endBattleReturningToOrigin()
        state.labyrinth.prepareReachableBattles()

        #expect(battle.lifecyclePhase == .prepared)
        #expect(battle.preparedBattlePresentationRevision > preparedRevision)
    }

    @Test func startLabyrinthBattleSetsConfigurationAndInMemoryOrigin() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let node = try #require(state.playerSave.labyrinth.nodes[combatNodeID])
        let expectedModifiers = LabyrinthCatalog.modifiers(ids: node.modifierIDs)
        let message = state.labyrinth.startBattle(nodeID: combatNodeID)
        #expect(message == nil)
        let battle = try #require(state.battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: battle.runKey))
        #expect(presentation.hasProgressionRewards)
        #expect(presentation.defeatPrimaryAction == .retreat)
        #expect(presentation.labyrinthModifiers == expectedModifiers)
        #expect(!presentation.labyrinthModifiers.isEmpty)
        #expect(battle.runKey == PlayBattleOrigin.labyrinth(nodeID: combatNodeID).runKey)
    }

    @Test func completeActiveBattleClearsLabyrinthNode() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        _ = state.labyrinth.startBattle(nodeID: combatNodeID)
        let configuration = try #require(state.battle.activeBattle)
        state.completeActiveBattle(configuration, battleEarnedGold: 3)
        #expect(state.playerSave.labyrinth.nodes[combatNodeID]?.isCleared == true)
        #expect(state.battle.activeBattle == nil)
    }

    @Test(arguments: [LabyrinthNodeType.shop, .mystery, .rest])
    func labyrinthEncounterFinishClearsNode(nodeType: LabyrinthNodeType) throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: nodeType, in: state))

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        switch nodeType {
        case .shop:
            let session = try #require(state.encounters.activeShopEncounter)
            #expect(session.labyrinthNodeID == nodeID)
            #expect(!session.offers.isEmpty)
            state.encounters.finishActiveShopEncounter()
            #expect(state.encounters.activeShopEncounter == nil)
        case .mystery:
            let session = try #require(state.encounters.activeMysteryEncounter)
            #expect(session.labyrinthNodeID == nodeID)
            state.encounters.finishActiveMysteryEncounter()
            #expect(state.encounters.activeMysteryEncounter == nil)
        case .rest:
            let session = try #require(state.labyrinth.activeNodeSession)
            #expect(session.kind == .rest)
            #expect(session.nodeID == nodeID)
            #expect(state.labyrinth.finishActiveRest())
            #expect(state.labyrinth.activeNodeSession == nil)
        default:
            Issue.record("Unexpected labyrinth encounter type \(nodeType)")
            return
        }

        #expect(state.playerSave.labyrinth.nodes[nodeID]?.isCleared == true)
    }

    @Test func shopEncounterCompletesJourneyOriginFromEncounterOwner() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.encounters.activeShopEncounter?.origin == .journey(stage: stage))
        #expect(state.encounters.finishActiveShopEncounter())
        #expect(state.encounters.activeShopEncounter == nil)
    }

    @Test func recruitNodeUsesConcealedRecruitEvent() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let event = try #require(GameContent.recruitEvents.first(where: { event in
            guard let combatantID = event.unlockCombatantID else { return false }
            return !state.playerSave.roster.unlockedHeroIDs.contains(combatantID)
                && !state.playerSave.roster.unlockedCompanionIDs.contains(combatantID)
        }))
        let nodeID = try #require(state.playerSave.labyrinth.reachableNodeIDs().first)
        let node = try #require(state.playerSave.labyrinth.nodes[nodeID])
        var labyrinth = state.playerSave.labyrinth
        labyrinth.nodes[nodeID] = LabyrinthNode(
            id: node.id,
            type: .recruit,
            depth: node.depth,
            clusterID: node.clusterID,
            gridPosition: node.gridPosition,
            modifierIDs: node.modifierIDs,
            recruitEventID: event.id,
            outgoingIDs: node.outgoingIDs,
            isRevealed: true
        )
        state.playerSave.labyrinth = labyrinth

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.event.id == event.id)
        #expect(state.encounters.activeMysteryEncounter?.event.isRecruit == true)
    }

    @Test func recruitNodeFallsBackToMysteryOnlyForCompletedRoster() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(state.playerSave.labyrinth.reachableNodeIDs().first)
        let node = try #require(state.playerSave.labyrinth.nodes[nodeID])
        var labyrinth = state.playerSave.labyrinth
        labyrinth.nodes[nodeID] = LabyrinthNode(
            id: node.id,
            type: .recruit,
            depth: node.depth,
            clusterID: node.clusterID,
            gridPosition: node.gridPosition,
            modifierIDs: node.modifierIDs,
            recruitEventID: "recruit-bear",
            outgoingIDs: node.outgoingIDs,
            isRevealed: true
        )
        state.playerSave.labyrinth = labyrinth
        state.playerSave.roster = .testSeed

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.event.isRecruit == false)
    }

    #if DEBUG
    @Test(arguments: ["shop", "rest", "craft"] as [String])
    func labyrinthEncounterFinishKeepsSessionOpenWhenPersistFails(kind: String) throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.labyrinth.enter()

        switch kind {
        case "shop":
            let shopNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .shop, in: state))
            #expect(state.labyrinth.handleNodeAction(nodeID: shopNodeID) == nil)
            #expect(state.encounters.activeShopEncounter != nil)

            playerSave.forcesNextSaveFailure = true
            #expect(!state.encounters.finishActiveShopEncounter())
            #expect(state.encounters.activeShopEncounter != nil)
            #expect(state.encounters.activeShopEncounter?.leaveFailureMessage != nil)
            #expect(state.playerSave.labyrinth.nodes[shopNodeID]?.isCleared == false)

            #expect(state.encounters.finishActiveShopEncounter())
            #expect(state.encounters.activeShopEncounter == nil)
            #expect(state.playerSave.labyrinth.nodes[shopNodeID]?.isCleared == true)
        case "rest":
            let restNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .rest, in: state))
            #expect(state.labyrinth.handleNodeAction(nodeID: restNodeID) == nil)
            #expect(state.labyrinth.activeNodeSession?.kind == .rest)

            playerSave.forcesNextSaveFailure = true
            #expect(!state.labyrinth.finishActiveRest())
            #expect(state.labyrinth.activeNodeSession != nil)
            #expect(state.labyrinth.activeNodeSession?.failureMessage != nil)
            #expect(state.playerSave.labyrinth.nodes[restNodeID]?.isCleared == false)

            #expect(state.labyrinth.finishActiveRest())
            #expect(state.labyrinth.activeNodeSession == nil)
            #expect(state.playerSave.labyrinth.nodes[restNodeID]?.isCleared == true)
        case "craft":
            let craftNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .craft, in: state))
            #expect(state.labyrinth.handleNodeAction(nodeID: craftNodeID) == nil)
            let session = try #require(state.labyrinth.activeNodeSession)
            #expect(session.kind == .craft)

            playerSave.forcesNextSaveFailure = true
            #expect(!state.labyrinth.leaveActiveCraftWithoutForging())
            #expect(state.labyrinth.activeNodeSession != nil)
            #expect(session.failureMessage != nil)
            #expect(state.playerSave.labyrinth.nodes[craftNodeID]?.isCleared == false)

            #expect(state.labyrinth.leaveActiveCraftWithoutForging())
            #expect(state.labyrinth.activeNodeSession == nil)
            #expect(state.playerSave.labyrinth.nodes[craftNodeID]?.isCleared == true)
        default:
            Issue.record("Unexpected encounter kind \(kind)")
        }
    }
    #endif

    @Test func labyrinthMysteryRecruitClearsNodeOnUnlockSoRelaunchCannotDoubleGrant() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.labyrinth.enter()
        let mysteryNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .mystery, in: state))

        #expect(state.labyrinth.handleNodeAction(nodeID: mysteryNodeID) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.labyrinthNodeID == mysteryNodeID)
        let event = session.event
        guard let unlockID = event.unlockCombatantID else {
            // Non-recruit mystery: resolve still completes in-transaction; skip double-grant probe.
            #expect(state.encounters.resolveActiveMysteryChoice())
            #expect(state.playerSave.labyrinth.nodes[mysteryNodeID]?.isCleared == true)
            return
        }

        #expect(state.playerSave.roster.isCombatantUnlocked(id: unlockID))
        #expect(state.encounters.activeMysteryEncounter?.phase == .revealing)
        // Labyrinth recruits clear the node with the unlock so kill/relaunch cannot re-roll.
        #expect(state.playerSave.labyrinth.nodes[mysteryNodeID]?.isCleared == true)

        let unlockedCountAfterFirst = state.playerSave.roster.unlockedHeroIDs.count
            + state.playerSave.roster.unlockedCompanionIDs.count

        // Simulate app kill before Recruit confirm: session is gone, save remains.
        let relaunched = try context.makePlaySession(playerSave: playerSave)
        #expect(relaunched.encounters.activeMysteryEncounter == nil)
        #expect(relaunched.playerSave.labyrinth.nodes[mysteryNodeID]?.isCleared == true)
        #expect(relaunched.playerSave.roster.isCombatantUnlocked(id: unlockID))
        let blocked = relaunched.labyrinth.handleNodeAction(nodeID: mysteryNodeID)
        #expect(blocked != nil)
        #expect(relaunched.encounters.activeMysteryEncounter == nil)
        let unlockedCountAfterRelaunch = relaunched.playerSave.roster.unlockedHeroIDs.count
            + relaunched.playerSave.roster.unlockedCompanionIDs.count
        #expect(unlockedCountAfterRelaunch == unlockedCountAfterFirst)
    }

    @Test func labyrinthRestGoldCrumbMatchesHomesteadAdjustedGrant() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        var homestead = state.playerSave.homestead
        homestead.nodeTiers[.wishingWell] = 2
        state.playerSave.homestead = homestead
        _ = state.labyrinth.enter()
        let restNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .rest, in: state))
        let node = try #require(state.playerSave.labyrinth.node(id: restNodeID))
        let rawGold = LabyrinthCompletion.nonCombatGoldStipend(
            for: node,
            effects: state.playerSave.labyrinth.effects(for: restNodeID)
        )
        let expected = state.playerSave.homestead.effects.adjustedGold(rawGold)

        #expect(state.labyrinth.handleNodeAction(nodeID: restNodeID) == nil)
        let session = try #require(state.labyrinth.activeNodeSession)
        #expect(session.kind == .rest)
        #expect(session.goldAmount == expected)
    }

    @Test func labyrinthCraftForgeClearsNodeWhenAffordable() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let craftNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .craft, in: state))

        var roster = state.playerSave.roster
        roster.grantGold(200)
        state.playerSave.roster = roster

        #expect(state.labyrinth.handleNodeAction(nodeID: craftNodeID) == nil)
        #expect(state.labyrinth.activeNodeSession?.kind == .craft)
        #expect(state.labyrinth.forgeActiveCraft())
        #expect(state.labyrinth.activeNodeSession == nil)
        #expect(state.playerSave.labyrinth.nodes[craftNodeID]?.isCleared == true)
    }

    @Test func legacyEventNodeRoutesToMystery() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let reachableID = try #require(state.playerSave.labyrinth.reachableNodeIDs().first)
        var labyrinth = state.playerSave.labyrinth
        var node = try #require(labyrinth.nodes[reachableID], "Missing reachable node")
        node = LabyrinthNode(
            id: node.id,
            type: .event,
            enemyID: nil,
            depth: node.depth,
            clusterID: node.clusterID,
            outgoingIDs: node.outgoingIDs,
            isCleared: false,
            isRevealed: true
        )
        labyrinth.nodes[reachableID] = node
        state.playerSave.labyrinth = labyrinth

        #expect(state.labyrinth.handleNodeAction(nodeID: reachableID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.labyrinthNodeID == reachableID)
    }
}
