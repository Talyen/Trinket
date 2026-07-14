import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import Trinket
@testable import TrinketPersistence

@MainActor
struct AppStateLabyrinthTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func enterLabyrinthIsAvailableFromFreshState() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let message = state.enterLabyrinth()
        #expect(message == nil)
        #expect(state.labyrinth.hasMap)
        #expect(!state.labyrinth.reachableNodeIDs().isEmpty)
    }

    @Test func enterLabyrinthReusesExistingMap() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        #expect(state.enterLabyrinth() == nil)
        let firstMap = state.labyrinth
        let message = state.enterLabyrinth()
        #expect(message == nil)
        #expect(state.labyrinth.hasMap)
        #expect(state.labyrinth == firstMap)
    }

    @Test func startLabyrinthBattleSetsConfigurationAndInMemoryOrigin() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let combatNodeID = try #require(firstReachableCombatNodeID(in: state))
        let message = state.startLabyrinthBattle(nodeID: combatNodeID)
        #expect(message == nil)
        let battle = try #require(state.battle.activeBattle)
        #expect(battle.labyrinthBattle?.nodeID == combatNodeID)
        #expect(battle.hasProgressionRewards)
        #expect(battle.resumeToken == .labyrinth(nodeID: combatNodeID))
    }

    @Test func completeLabyrinthNodeAdvancesMap() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let nodeID = try #require(state.labyrinth.reachableNodeIDs().first)
        state.completeLabyrinthNode(nodeID: nodeID)
        #expect(state.labyrinth.nodes[nodeID]?.isCleared == true)
    }

    @Test func completeActiveBattleClearsLabyrinthNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let combatNodeID = try #require(firstReachableCombatNodeID(in: state))
        _ = state.startLabyrinthBattle(nodeID: combatNodeID)
        let configuration = try #require(state.battle.activeBattle)
        state.completeActiveBattle(configuration, battleEarnedGold: 3)
        #expect(state.labyrinth.nodes[combatNodeID]?.isCleared == true)
        #expect(state.battle.activeBattle == nil)
    }

    @Test(arguments: [LabyrinthNodeType.shop, .mystery, .rest])
    func labyrinthEncounterFinishClearsNode(nodeType: LabyrinthNodeType) throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let nodeID = try #require(firstReachableNodeID(of: nodeType, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: nodeID) == nil)
        switch nodeType {
        case .shop:
            let session = try #require(state.activeShopEncounter)
            #expect(session.labyrinthNodeID == nodeID)
            #expect(session.offers.count == ShopOfferGenerator.offerCount)
            state.finishActiveShopEncounter()
            #expect(state.activeShopEncounter == nil)
        case .mystery:
            let session = try #require(state.activeMysteryEncounter)
            #expect(session.labyrinthNodeID == nodeID)
            state.finishActiveMysteryEncounter()
            #expect(state.activeMysteryEncounter == nil)
        case .rest:
            let session = try #require(state.activeLabyrinthRest)
            #expect(session.nodeID == nodeID)
            #expect(state.finishActiveLabyrinthRest())
            #expect(state.activeLabyrinthRest == nil)
        default:
            Issue.record("Unexpected labyrinth encounter type \(nodeType)")
            return
        }

        #expect(state.labyrinth.nodes[nodeID]?.isCleared == true)
    }

    #if DEBUG
    @Test func finishActiveShopEncounterKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.enterLabyrinth()
        let shopNodeID = try #require(firstReachableNodeID(of: .shop, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: shopNodeID) == nil)
        #expect(state.activeShopEncounter != nil)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.finishActiveShopEncounter())
        #expect(state.activeShopEncounter != nil)
        #expect(state.activeShopEncounter?.leaveFailureMessage != nil)
        #expect(state.labyrinth.nodes[shopNodeID]?.isCleared == false)

        #expect(state.finishActiveShopEncounter())
        #expect(state.activeShopEncounter == nil)
        #expect(state.labyrinth.nodes[shopNodeID]?.isCleared == true)
    }
    #endif

    @Test func labyrinthShopDismissDoesNotClearNode() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let shopNodeID = try #require(firstReachableNodeID(of: .shop, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: shopNodeID) == nil)
        #expect(state.activeShopEncounter != nil)

        state.dismissActiveShopEncounterWithoutCompleting()

        #expect(state.activeShopEncounter == nil)
        #expect(state.labyrinth.nodes[shopNodeID]?.isCleared == false)
    }

    #if DEBUG
    @Test func finishActiveLabyrinthRestKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.enterLabyrinth()
        let restNodeID = try #require(firstReachableNodeID(of: .rest, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: restNodeID) == nil)
        #expect(state.activeLabyrinthRest != nil)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.finishActiveLabyrinthRest())
        #expect(state.activeLabyrinthRest != nil)
        #expect(state.activeLabyrinthRest?.failureMessage != nil)
        #expect(state.labyrinth.nodes[restNodeID]?.isCleared == false)

        #expect(state.finishActiveLabyrinthRest())
        #expect(state.activeLabyrinthRest == nil)
        #expect(state.labyrinth.nodes[restNodeID]?.isCleared == true)
    }

    @Test func leaveActiveLabyrinthCraftWithoutForgingKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.enterLabyrinth()
        let craftNodeID = try #require(firstReachableNodeID(of: .craft, in: state))

        #expect(state.handleLabyrinthNodeAction(nodeID: craftNodeID) == nil)
        let session = try #require(state.activeLabyrinthCraft)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.leaveActiveLabyrinthCraftWithoutForging())
        #expect(state.activeLabyrinthCraft != nil)
        #expect(session.failureMessage != nil)
        #expect(state.labyrinth.nodes[craftNodeID]?.isCleared == false)

        #expect(state.leaveActiveLabyrinthCraftWithoutForging())
        #expect(state.activeLabyrinthCraft == nil)
        #expect(state.labyrinth.nodes[craftNodeID]?.isCleared == true)
    }
    #endif

    @Test func labyrinthCraftForgeClearsNodeWhenAffordable() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let craftNodeID = try #require(firstReachableNodeID(of: .craft, in: state))

        var roster = state.roster
        roster.grantGold(200)
        state.roster = roster

        #expect(state.handleLabyrinthNodeAction(nodeID: craftNodeID) == nil)
        #expect(state.activeLabyrinthCraft != nil)
        #expect(state.forgeActiveLabyrinthCraft())
        #expect(state.activeLabyrinthCraft == nil)
        #expect(state.labyrinth.nodes[craftNodeID]?.isCleared == true)
    }

    @Test func legacyEventNodeRoutesToMystery() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        _ = state.enterLabyrinth()
        let reachableID = try #require(state.labyrinth.reachableNodeIDs().first)
        var labyrinth = state.labyrinth
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
