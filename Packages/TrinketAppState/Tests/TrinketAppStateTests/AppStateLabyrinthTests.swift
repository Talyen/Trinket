import Foundation
import Testing
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistenceTestSupport
import TrinketTestSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

@MainActor
struct AppStateLabyrinthTests { // swiftlint:disable:this type_body_length
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

    @Test func enterUnreadableMapReturnsErrorAndDoesNotRegenerate() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        state.playerSave.labyrinth = PlayerLabyrinthState(
            worldSeed: 55,
            hasEntered: true,
            isMapPayloadUnreadable: true
        )

        let message = try #require(state.labyrinth.enter())
        #expect(message.title == "Labyrinth Error")
        #expect(!state.playerSave.labyrinth.hasMap)
        #expect(state.playerSave.labyrinth.isMapPayloadUnreadable)
        #expect(state.playerSave.labyrinth.worldSeed == 55)
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

    @Test func labyrinthPrepareDropsUnreachableCombatRuns() throws {
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
            }
        )
        #expect(remainingKeys == reachableCombatKeys)
    }

    @Test func labyrinthPrepareRebuildsWipedJourneyRun() throws {
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
        case .rest:
            let session = try #require(state.labyrinth.activeNodeSession)
            #expect(session.nodeID == nodeID)
            #expect(state.labyrinth.finishActiveRest())
            #expect(state.labyrinth.activeNodeSession == nil)
        default:
            Issue.record("Unexpected labyrinth encounter type \(nodeType)")
            return
        }

        #expect(state.playerSave.labyrinth.nodes[nodeID]?.isCleared == true)
    }

    @Test func finishLabyrinthMysteryIgnoresReadingPhase() throws {
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
        let nodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: event.id, in: state))

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.event.id == event.id)
        #expect(state.encounters.activeMysteryEncounter?.event.isRecruit == true)
    }

    @Test func recruitNodeFallsBackToMysteryOnlyForCompletedRoster() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: "recruit-bear", in: state))
        state.playerSave.roster = .testSeed

        #expect(state.labyrinth.handleNodeAction(nodeID: nodeID) == nil)
        #expect(state.encounters.activeMysteryEncounter?.event.isRecruit == false)
    }

    @Test func recruitNodePreviewFallsBackToMysteryEventWhenPoolIsExhausted() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let nodeID = try #require(LabyrinthTestSupport.installRecruitNode(eventID: "recruit-bear", in: state))
        state.playerSave.roster = .testSeed

        let recruitNode = try #require(state.playerSave.labyrinth.nodes[nodeID])
        let preview = try #require(state.labyrinth.previewMysteryEvent(for: recruitNode))
        #expect(!preview.isRecruit)
    }

    #if DEBUG
    @Test(arguments: ["shop", "rest"] as [String])
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
            #expect(state.labyrinth.activeNodeSession != nil)

            playerSave.forcesNextSaveFailure = true
            #expect(!state.labyrinth.finishActiveRest())
            #expect(state.labyrinth.activeNodeSession != nil)
            #expect(state.labyrinth.activeNodeSession?.failureMessage != nil)
            #expect(state.playerSave.labyrinth.nodes[restNodeID]?.isCleared == false)

            #expect(state.labyrinth.finishActiveRest())
            #expect(state.labyrinth.activeNodeSession == nil)
            #expect(state.playerSave.labyrinth.nodes[restNodeID]?.isCleared == true)
        default:
            Issue.record("Unexpected encounter kind \(kind)")
        }
    }
    #endif

    @Test func labyrinthMysteryRecruitClearsNodeOnUnlockSoRelaunchCannotDoubleGrant() throws {
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

    @Test func labyrinthCampfirePreviewsHealAndFinishingPersistsIt() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let restNodeID = try #require(LabyrinthTestSupport.firstReachableNodeID(of: .rest, in: state))
        let heroID = state.playerSave.roster.activeHeroID

        // Seed mid-run wounds so the campfire has something to restore.
        var labyrinth = state.playerSave.labyrinth
        labyrinth.runHealthByCombatantID = [heroID: 3]
        state.playerSave.labyrinth = labyrinth

        #expect(state.labyrinth.handleNodeAction(nodeID: restNodeID) == nil)
        let session = try #require(state.labyrinth.activeNodeSession)
        #expect(session.nodeID == restNodeID)
        #expect(session.party.map(\.combatantID) == [heroID, state.playerSave.roster.activeCompanionID])

        let heroMember = try #require(session.party.first { $0.combatantID == heroID })
        #expect(heroMember.currentHealth == 3)
        #expect(heroMember.maxHealth > 3)
        #expect(
            heroMember.healedHealth
                == LabyrinthCompletion.campfireRestHealth(current: 3, maxHealth: heroMember.maxHealth)
        )
        #expect(heroMember.healedHealth > 3)

        let healed = session.healedRunHealthByCombatantID
        #expect(state.labyrinth.finishActiveRest())
        #expect(state.labyrinth.activeNodeSession == nil)
        #expect(state.playerSave.labyrinth.nodes[restNodeID]?.isCleared == true)
        #expect(state.playerSave.labyrinth.runHealthByCombatantID == healed)
    }

    @Test func completingLabyrinthBattleCommitsPartyRunHealth() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        _ = state.labyrinth.startBattle(nodeID: combatNodeID)
        let configuration = try #require(state.battle.activeBattle)

        #expect(state.completeActiveBattle(configuration, battleEarnedGold: 3))

        let runHealth = state.playerSave.labyrinth.runHealthByCombatantID
        #expect(
            Set(runHealth.keys)
                == Set([configuration.hero.combatant.id, configuration.companion.combatant.id])
        )
        #expect(runHealth.values.allSatisfy { $0 >= 1 })
    }

    @Test func completeNodeClampsVictoryRunHealthAboveZero() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let combatNodeID = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))

        #expect(
            state.labyrinth.completeNode(
                nodeID: combatNodeID,
                partyRunHealth: ["knight": 0]
            )
        )

        #expect(state.playerSave.labyrinth.runHealthByCombatantID == ["knight": 1])
    }

    @Test func changedRunHealthReplacesPreparedLabyrinthBattles() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        _ = try #require(LabyrinthTestSupport.firstReachableCombatNodeID(in: state))
        let battle = try #require(context.lastBattle)
        state.labyrinth.prepareReachableBattles()
        let preparedRevision = battle.preparedBattlePresentationRevision

        var labyrinth = state.playerSave.labyrinth
        labyrinth.runHealthByCombatantID = [state.playerSave.roster.activeHeroID: 4]
        state.playerSave.labyrinth = labyrinth
        state.labyrinth.prepareReachableBattles()

        #expect(battle.preparedBattlePresentationRevision > preparedRevision)
    }

    @Test func labyrinthMysteryNodesCarryExactlyOneEconomyModifier() throws {
        /// A recruit-eligible floor can shuffle mystery out of its guaranteed
        /// non-combat trio and roll zero of them; re-roll so the invariant below
        /// is exercised on a real generated node.
        func hasUnclearedMysteryNode(_ session: PlaySession) -> Bool {
            session.playerSave.labyrinth.nodes.values.contains {
                $0.type.canonical == .mystery && !$0.isCleared
            }
        }

        var state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        for _ in 0 ..< 8 where !hasUnclearedMysteryNode(state) {
            state = try context.makePlaySession(arguments: ["-reset-state"])
            _ = state.labyrinth.enter()
        }
        let economyIDs: Set<LabyrinthModifierID> = [
            LabyrinthModifierID("bountyMark"),
            LabyrinthModifierID("scholarsToll"),
            LabyrinthModifierID("scavengersLuck"),
        ]
        var checked = 0
        for node in state.playerSave.labyrinth.nodes.values
            where node.type.canonical == .mystery && !node.isCleared {
            let ids = node.modifierIDs
            #expect(ids.count == 1)
            #expect(economyIDs.contains(ids[0]))
            let effects = state.playerSave.labyrinth.effects(for: node.id)
            #expect(effects.goldFoundPercent + effects.experienceEarnedPercent + effects.materialsFoundPercent > 0)
            checked += 1
        }
        #expect(checked > 0, "Expected at least one mystery node on the map")
    }

    @Test func labyrinthShopNodesCarryExactlyOneShopModifier() throws {
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

    @Test func missingLabyrinthNodePinFailsClosed() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        _ = state.labyrinth.enter()
        let message = try #require(
            state.encounters.beginMysteryEncounter(origin: .labyrinth(nodeID: "missing-node"))
        )
        #expect(message.title == "Couldn't Save Progress")
        #expect(state.encounters.activeMysteryEncounter == nil)
    }
}
