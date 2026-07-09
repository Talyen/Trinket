import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import Trinket

@MainActor
struct AppStateLabyrinthTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func enterLabyrinthRequiresUnlock() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        #expect(state.isLabyrinthUnlocked == false)
        let message = state.enterLabyrinth()
        #expect(message != nil)
        #expect(state.labyrinth.hasMap == false)
    }

    @Test func enterLabyrinthCreatesMapWhenUnlocked() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        #expect(state.isLabyrinthUnlocked)
        let message = state.enterLabyrinth()
        #expect(message == nil)
        #expect(state.labyrinth.hasMap)
        #expect(!state.labyrinth.reachableNodeIDs().isEmpty)
    }

    @Test func startLabyrinthBattleSetsConfiguration() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let combatNodeID = try #require(firstReachableCombatNodeID(in: state))
        let message = state.startLabyrinthBattle(nodeID: combatNodeID)
        #expect(message == nil)
        let battle = try #require(state.battle.activeBattle)
        #expect(battle.labyrinthBattle?.nodeID == combatNodeID)
        #expect(battle.hasProgressionRewards)
    }

    @Test func completeLabyrinthNodeAdvancesMap() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let nodeID = try #require(state.labyrinth.reachableNodeIDs().first)
        state.completeLabyrinthNode(nodeID: nodeID)
        #expect(state.labyrinth.nodes[nodeID]?.isCleared == true)
    }

    @Test func completeActiveBattleClearsLabyrinthNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let combatNodeID = try #require(firstReachableCombatNodeID(in: state))
        _ = state.startLabyrinthBattle(nodeID: combatNodeID)
        let configuration = try #require(state.battle.activeBattle)
        state.completeActiveBattle(configuration, battleEarnedGold: 3)
        #expect(state.labyrinth.nodes[combatNodeID]?.isCleared == true)
        #expect(state.battle.activeBattle == nil)
    }

    @Test func labyrinthShopFinishClearsNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let shopNodeID = try #require(firstReachableNodeID(of: .shop, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: shopNodeID) == nil)
        let session = try #require(state.activeShopEncounter)
        #expect(session.labyrinthNodeID == shopNodeID)
        #expect(session.offers.count == ShopOfferGenerator.offerCount)

        state.finishActiveShopEncounter()

        #expect(state.activeShopEncounter == nil)
        #expect(state.labyrinth.nodes[shopNodeID]?.isCleared == true)
    }

    @Test func labyrinthShopDismissDoesNotClearNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let shopNodeID = try #require(firstReachableNodeID(of: .shop, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: shopNodeID) == nil)
        #expect(state.activeShopEncounter != nil)

        state.dismissActiveShopEncounterWithoutCompleting()

        #expect(state.activeShopEncounter == nil)
        #expect(state.labyrinth.nodes[shopNodeID]?.isCleared == false)
    }

    @Test func labyrinthMysteryFinishClearsNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let mysteryNodeID = try #require(firstReachableNodeID(of: .mystery, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: mysteryNodeID) == nil)
        let session = try #require(state.activeMysteryEncounter)
        #expect(session.labyrinthNodeID == mysteryNodeID)

        state.finishActiveMysteryEncounter()

        #expect(state.activeMysteryEncounter == nil)
        #expect(state.labyrinth.nodes[mysteryNodeID]?.isCleared == true)
    }

    @Test func startLabyrinthBattlePersistsResumeToken() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let combatNodeID = try #require(firstReachableCombatNodeID(in: state))
        _ = state.startLabyrinthBattle(nodeID: combatNodeID)
        #expect(state.savedBattleResumeToken == .labyrinth(nodeID: combatNodeID))
        #expect(state.shellSession.activeBattleLabyrinthNodeID == combatNodeID)
    }

    @Test func labyrinthRestFinishClearsNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let restNodeID = try #require(firstReachableNodeID(of: .rest, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: restNodeID) == nil)
        let session = try #require(state.activeLabyrinthRest)
        #expect(session.nodeID == restNodeID)

        state.finishActiveLabyrinthRest()

        #expect(state.activeLabyrinthRest == nil)
        #expect(state.labyrinth.nodes[restNodeID]?.isCleared == true)
    }

    @Test func labyrinthCraftForgeClearsNodeWhenAffordable() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let craftNodeID = try #require(firstReachableNodeID(of: .craft, in: state))

        var roster = state.roster.current
        roster.grantGold(200)
        state.roster.current = roster

        #expect(state.handleLabyrinthNodeAction(nodeID: craftNodeID) == nil)
        #expect(state.activeLabyrinthCraft != nil)
        #expect(state.forgeActiveLabyrinthCraft())
        #expect(state.activeLabyrinthCraft == nil)
        #expect(state.labyrinth.nodes[craftNodeID]?.isCleared == true)
    }

    @Test func legacyEventNodeRoutesToMystery() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        unlockLabyrinth(on: state)
        _ = state.enterLabyrinth()
        let reachableID = try #require(state.labyrinth.reachableNodeIDs().first)
        var labyrinth = state.labyrinth.current
        guard var node = labyrinth.nodes[reachableID] else {
            Issue.record("Missing reachable node")
            return
        }
        node = LabyrinthNode(
            id: node.id,
            type: .event,
            enemyID: nil,
            depth: node.depth,
            clusterID: node.clusterID,
            outgoingIDs: node.outgoingIDs,
            isCleared: false,
            isRevealed: true,
            failCount: 0
        )
        labyrinth.nodes[reachableID] = node
        state.labyrinth = labyrinth

        #expect(state.handleLabyrinthNodeAction(nodeID: reachableID) == nil)
        #expect(state.activeMysteryEncounter?.labyrinthNodeID == reachableID)
    }

    private func unlockLabyrinth(on appState: AppState) {
        var journey = appState.journey.current
        if let chapter = GameContent.chapters.first(where: { $0.id == "chapter-1" }) {
            for stage in chapter.stages {
                journey.completedStageIDs.insert(stage.id)
            }
        }
        appState.journey.current = journey
    }

    private func firstReachableCombatNodeID(in state: AppState) -> String? {
        firstReachableNodeID(where: { $0.type.isCombat }, in: state)
    }

    private func firstReachableNodeID(
        of type: LabyrinthNodeType,
        in state: AppState
    ) -> String? {
        firstReachableNodeID(where: { $0.type == type }, in: state)
    }

    private func firstReachableNodeID(
        where matches: (LabyrinthNode) -> Bool,
        in state: AppState
    ) -> String? {
        // Clear non-matching reachable nodes until a matching node is available.
        for _ in 0 ..< 24 {
            if let matchID = state.labyrinth.reachableNodeIDs().first(where: { id in
                guard let node = state.labyrinth.node(id: id) else { return false }
                return matches(node)
            }) {
                return matchID
            }
            guard let next = state.labyrinth.reachableNodeIDs().first else { return nil }
            state.completeLabyrinthNode(nodeID: next)
        }
        return nil
    }
}
