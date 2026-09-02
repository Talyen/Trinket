import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
import TrinketTestSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
struct AppStateLabyrinthTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `enter labyrinth creates map and reuses it on repeat`() throws {
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

    @Test func `unreadable map heals on write and enter succeeds`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        state.playerSave.labyrinth = PlayerLabyrinthState(
            worldSeed: 55,
            hasEntered: true,
            isMapPayloadUnreadable: true,
        )

        #expect(!state.playerSave.labyrinth.isMapPayloadUnreadable)
        #expect(state.playerSave.labyrinth.hasMap)
        #expect(state.labyrinth.enter() == nil)
        #expect(state.playerSave.labyrinth.hasMap)
    }

    @Test func `unchanged labyrinth inputs reuse prepared battles`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        _ = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let battle = try #require(context.lastBattle)

        state.labyrinth.prepareReachableBattles()
        let preparedRevision = battle.preparedBattlePresentationRevision

        state.labyrinth.prepareReachableBattles()

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
    }

    @Test func `relevant labyrinth input change replaces prepared battles`() throws {
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

    @Test func `returning from battle prepares unchanged labyrinth inputs again`() throws {
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

    @Test func `labyrinth prepare drops unreachable combat runs`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let battle = try #require(context.lastBattle)
        state.labyrinth.prepareReachableBattles()
        let clearedKey = PlayBattleOrigin.labyrinth(nodeID: combatNodeID).runKey
        #expect(battle.preparedBattleRun(for: clearedKey) != nil)

        #expect(state.labyrinth.completeNode(nodeID: combatNodeID))
        state.labyrinth.prepareReachableBattles()

        #expect(battle.preparedBattleRun(for: clearedKey) == nil)
        let remainingKeys = Set(battle.preparedBattleRuns.compactMap(\.configuration.runKey))
        let reachableCombatKeys = Set(
            state.playerSave.labyrinth.reachableNodeIDs().compactMap { nodeID -> BattleRunKey? in
                guard let node = state.playerSave.labyrinth.node(id: nodeID), node.type.isCombat else {
                    return nil
                }
                return PlayBattleOrigin.labyrinth(nodeID: nodeID).runKey
            },
        )
        #expect(remainingKeys == reachableCombatKeys)
    }

    @Test func `labyrinth prepare rebuilds wiped journey run`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.chapters[0].stages.first)
        let journeyKey = PlayBattleOrigin.journey(stageID: stage.id).runKey
        let battle = try #require(context.lastBattle)

        state.journey.prepareBattle(for: stage)
        #expect(battle.hasPreparedRun(journeyKey))
        #expect(state.battlePresentation(for: journeyKey) != nil)

        _ = state.labyrinth.enter()
        state.labyrinth.prepareReachableBattles()
        #expect(!battle.hasPreparedRun(journeyKey))
        #expect(state.battlePresentation(for: journeyKey) == nil)

        state.journey.prepareBattle(for: stage)
        #expect(battle.hasPreparedRun(journeyKey))
        #expect(state.battlePresentation(for: journeyKey) != nil)
    }

    @Test func `start labyrinth battle sets configuration and in memory origin`() throws {
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
        #expect(presentation.defeatPrimaryAction == .restart)
        #expect(presentation.labyrinthModifiers == expectedModifiers)
        #expect(!presentation.labyrinthModifiers.isEmpty)
        #expect(battle.runKey == PlayBattleOrigin.labyrinth(nodeID: combatNodeID).runKey)
    }

    @Test func `complete active battle clears labyrinth node`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        _ = state.labyrinth.startBattle(nodeID: combatNodeID)
        let configuration = try #require(state.battle.activeBattle)
        state.completeActiveBattle(configuration, battleEarnedGold: 3)
        #expect(state.playerSave.labyrinth.nodes[combatNodeID]?.isCleared == true)
        #expect(state.battle.activeBattle == nil)
    }

    @Test(arguments: [LabyrinthNodeType.shop, .mystery])
    func `labyrinth encounter finish clears node`(nodeType: LabyrinthNodeType) throws {
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
            if session.phase == .reading {
                #expect(state.encounters.resolveActiveMysteryChoice())
            }
            if session.showsCorruptItemChoice, let itemID = session.corruptibleItems.first?.id {
                #expect(state.encounters.corruptActiveMysteryItem(itemID: itemID))
            }
            if session.showsCorruptionReveal {
                #expect(state.encounters.finishActiveMysteryCorruptionReveal())
            }
            if state.encounters.activeMysteryEncounter != nil {
                #expect(state.encounters.finishActiveMysteryEncounter())
            }
            #expect(state.encounters.activeMysteryEncounter == nil)
        default:
            Issue.record("Unexpected labyrinth encounter type \(nodeType)")
            return
        }

        #expect(state.playerSave.labyrinth.nodes[nodeID]?.isCleared == true)
    }

    @Test func `finish labyrinth mystery ignores reading phase`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .mystery, in: state))

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.phase == .reading)

        #expect(!state.encounters.finishActiveMysteryEncounter())
        #expect(state.encounters.activeMysteryEncounter != nil)
        #expect(state.playerSave.labyrinth.nodes[nodeID]?.isCleared == false)
    }

    @Test func `shop encounter completes journey origin from encounter owner`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-2-stage-8"))

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.encounters.activeShopEncounter?.origin == .journey(stage: stage))
        #expect(state.encounters.finishActiveShopEncounter())
        #expect(state.encounters.activeShopEncounter == nil)
    }

    @Test func `recruit node uses concealed recruit event`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let event = try #require(GameContent.recruitEvents.first(where: { event in
            guard let combatantID = event.unlockCombatantID else { return false }
            return !state.playerSave.roster.unlockedHeroIDs.contains(combatantID)
                && !state.playerSave.roster.unlockedCompanionIDs.contains(combatantID)
        }))
        let nodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: event.id, in: state))

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.event.id == event.id)
        #expect(state.encounters.activeMysteryEncounter?.event.isRecruit == true)
    }

    @Test func `recruit node falls back to mystery only for completed roster`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: "recruit-bear", in: state))
        state.playerSave.roster = .testSeed

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.event.isRecruit == false)
    }

    @Test func `recruit node preview falls back to mystery event when pool is exhausted`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: "recruit-bear", in: state))
        state.playerSave.roster = .testSeed

        let recruitNode = try #require(state.playerSave.labyrinth.nodes[nodeID])
        let preview = try #require(state.labyrinth.previewMysteryEvent(for: recruitNode))
        #expect(!preview.isRecruit)
    }

    #if DEBUG
    @Test func `labyrinth encounter finish keeps session open when persist fails`() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.labyrinth.enter()

        let shopNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .shop, in: state))
        #expect(state.labyrinth.handleNodeAction(nodeID: shopNodeID) == nil)
        #expect(state.encounters.activeShopEncounter != nil)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.encounters.finishActiveShopEncounter())
        #expect(state.encounters.activeShopEncounter != nil)
        #expect(state.encounters.activeShopEncounter?.persistFailureMessage != nil)
        #expect(state.playerSave.labyrinth.nodes[shopNodeID]?.isCleared == false)

        #expect(state.encounters.finishActiveShopEncounter())
        #expect(state.encounters.activeShopEncounter == nil)
        #expect(state.playerSave.labyrinth.nodes[shopNodeID]?.isCleared == true)
    }
    #endif

    @Test func `labyrinth mystery recruit clears node on unlock so relaunch cannot double grant`() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        _ = state.labyrinth.enter()
        let event = try #require(GameContent.recruitEvents.first(where: { event in
            guard let combatantID = event.unlockCombatantID else { return false }
            return !state.playerSave.roster.unlockedHeroIDs.contains(combatantID)
                && !state.playerSave.roster.unlockedCompanionIDs.contains(combatantID)
        }))
        let mysteryNodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: event.id, in: state))

        #expect(state.labyrinth.handleNodeAction(nodeID: mysteryNodeID) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.labyrinthNodeID == mysteryNodeID)
        let unlockID = try #require(session.event.unlockCombatantID)

        let unlockIsIn = { (roster: PlayerRosterState, id: String) in
            roster.unlockedHeroIDs.contains(id) || roster.unlockedCompanionIDs.contains(id)
        }
        #expect(unlockIsIn(state.playerSave.roster, unlockID))
        #expect(state.encounters.activeMysteryEncounter?.phase == .revealing)
        #expect(state.playerSave.labyrinth.nodes[mysteryNodeID]?.isCleared == true)

        let unlockedCountAfterFirst = state.playerSave.roster.unlockedHeroIDs.count
            + state.playerSave.roster.unlockedCompanionIDs.count

        let relaunched = try context.makePlaySession(playerSave: playerSave)
        #expect(relaunched.encounters.activeMysteryEncounter == nil)
        #expect(relaunched.playerSave.labyrinth.nodes[mysteryNodeID]?.isCleared == true)
        #expect(unlockIsIn(relaunched.playerSave.roster, unlockID))
        let blocked = relaunched.labyrinth.handleNodeAction(nodeID: mysteryNodeID)
        #expect(blocked != nil)
        #expect(relaunched.encounters.activeMysteryEncounter == nil)
        let unlockedCountAfterRelaunch = relaunched.playerSave.roster.unlockedHeroIDs.count
            + relaunched.playerSave.roster.unlockedCompanionIDs.count
        #expect(unlockedCountAfterRelaunch == unlockedCountAfterFirst)
    }

    @Test func `labyrinth battle always starts at full baseline health`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        _ = state.labyrinth.startBattle(nodeID: combatNodeID)
        let battle = try #require(state.battle.activeBattle)
        #expect(battle.hero.startingHealth == nil)
        #expect(battle.companion.startingHealth == nil)
    }

    @Test func `completing labyrinth battle clears node without persisting health`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        _ = state.labyrinth.startBattle(nodeID: combatNodeID)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 3))
        #expect(state.playerSave.labyrinth.nodes[combatNodeID]?.isCleared == true)
        #expect(state.playerSave.labyrinth.runHealthByCombatantID.isEmpty)
    }

    @Test func `labyrinth mystery nodes carry exactly one economy modifier`() throws {
        let state = try context.makePlaySession(arguments: ["-test-seed", "-reset-state"])
        _ = state.labyrinth.enter()
        _ = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .mystery, in: state))
        let economyIDs: Set<LabyrinthModifierID> = [
            LabyrinthModifierID("bountyMark"),
            LabyrinthModifierID("scholarsToll"),
            LabyrinthModifierID("scavengersLuck"),
        ]
        let mysteryNodes = state.playerSave.labyrinth.nodes.values
            .filter { $0.type.canonical == .mystery && !$0.isCleared }
        #expect(!mysteryNodes.isEmpty, "Expected at least one mystery node on the map")
        for node in mysteryNodes {
            let ids = node.modifierIDs
            #expect(ids.count == 1)
            #expect(economyIDs.contains(ids[0]))
            let effects = state.playerSave.labyrinth.effects(for: node.id)
            #expect(effects.goldFoundPercent + effects.experienceEarnedPercent + effects.materialsFoundPercent > 0)
        }
    }

    @Test func `labyrinth shop nodes carry exactly one shop modifier`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let shopIDs: Set<LabyrinthModifierID> = [
            LabyrinthModifierID("shopDiscount"),
            LabyrinthModifierID("appraisersEye"),
        ]
        for node in state.playerSave.labyrinth.nodes.values where node.type.canonical == .shop {
            let ids = node.modifierIDs
            #expect(ids.count == 1)
            #expect(shopIDs.contains(ids[0]))
        }
    }

    @Test func `legacy event node routes to mystery`() throws {
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
            isRevealed: true,
        )
        labyrinth.nodes[reachableID] = node
        state.playerSave.labyrinth = labyrinth

        #expect(state.labyrinth.handleNodeAction(nodeID: reachableID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.labyrinthNodeID == reachableID)
    }

    @Test func `missing labyrinth node pin fails closed`() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let message = try #require(
            state.encounters.beginMysteryEncounter(origin: .labyrinth(nodeID: "missing-node")),
        )
        #expect(message.title == "Couldn't Save Progress")
        #expect(state.encounters.activeMysteryEncounter == nil)
    }
}
