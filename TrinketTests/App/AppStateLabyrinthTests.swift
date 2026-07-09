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
        // Clear non-combat reachable nodes until a combat node is available.
        for _ in 0 ..< 8 {
            if let combatID = state.labyrinth.reachableNodeIDs().first(where: { id in
                state.labyrinth.node(id: id)?.type.isCombat == true
            }) {
                return combatID
            }
            guard let next = state.labyrinth.reachableNodeIDs().first else { return nil }
            state.completeLabyrinthNode(nodeID: next)
        }
        return nil
    }
}
