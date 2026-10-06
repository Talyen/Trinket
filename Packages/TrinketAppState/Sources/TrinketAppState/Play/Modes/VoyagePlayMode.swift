import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class VoyagePlayMode {
    public let playerSave: PlayerSaveStore
    private let battle: any BattleRuntime
    private let battleCoordinator: PlayBattleCoordinator
    private let encounters: EncounterPlayMode

    init(playerSave: PlayerSaveStore, battle: any BattleRuntime, battleCoordinator: PlayBattleCoordinator, encounters: EncounterPlayMode) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleCoordinator = battleCoordinator
        self.encounters = encounters
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        if playerSave.voyage.activeRun?.isComplete == true {
            dismissCompleted()
        }
        guard encounters.canBeginTransientEncounter else { return nil }
        guard !playerSave.voyage.isUnreadable else {
            return StageMapMessage(title: "Voyage Unavailable", message: "Your Voyage could not be read. Your progress is preserved.")
        }
        if !playerSave.prepareVoyage() {
            playerSave.retrySaveAction(key: SaveRetryKey.voyageEnter) { [weak self] in
                _ = self?.enter()
            }
        }
        return nil
    }

    public func refresh() {
        guard encounters.canBeginTransientEncounter else { return }
        persist(key: SaveRetryKey.voyageRefresh) { [playerSave] in playerSave.refreshVoyage() }
    }

    public func embark(offerID: String) {
        guard encounters.canBeginTransientEncounter else { return }
        persist(key: SaveRetryKey.voyageEmbark(offerID)) { [playerSave] in playerSave.embarkVoyage(offerID: offerID) }
    }

    public func abandon(runID: String) {
        guard encounters.canBeginTransientEncounter else { return }
        persist(key: SaveRetryKey.voyageAbandon(runID)) { [playerSave] in playerSave.abandonVoyage(runID: runID) }
        prunePrepared()
    }

    public func dismissCompleted() {
        guard encounters.canBeginTransientEncounter else { return }
        persist(key: SaveRetryKey.voyageCompleted) { [playerSave] in playerSave.dismissCompletedVoyage() }
    }

    public func resolvedEncounter(for node: VoyageNode) -> ScaledEncounter? {
        guard let run = playerSave.voyage.activeRun else { return nil }
        return PlayBattlePreparation.scaledEncounter(
            enemyID: node.enemyID,
            level: run.offer.difficulty.encounterLevel(partyLevel: playerSave.roster.activePartyAverageLevel),
        )
    }

    public func previewMysteryEvent(for node: VoyageNode, runID: String? = nil) -> MysteryEvent? {
        guard node.type == .mystery else { return nil }
        guard let resolvedRunID = runID ?? playerSave.voyage.activeRun?.id, !resolvedRunID.isEmpty else { return nil }
        return encounters.previewMysteryEvent(origin: .voyage(runID: resolvedRunID, nodeID: node.id))
    }

    @discardableResult
    public func handleNode(runID: String, nodeID: String) -> StageMapMessage? {
        guard encounters.canBeginTransientEncounter,
              playerSave.voyage.isPlayable(runID: runID, nodeID: nodeID) else { return nil }
        let origin = PlayBattleOrigin.voyage(runID: runID, nodeID: nodeID)
        if let restriction = playerSave.accessRestriction(for: origin) {
            return restriction
        }
        guard playerSave.prepareVoyage() else {
            playerSave.retrySaveAction(key: SaveRetryKey.voyageNode(runID: runID, nodeID: nodeID)) { [weak self] in
                _ = self?.handleNode(runID: runID, nodeID: nodeID)
            }
            return nil
        }
        guard let node = playerSave.voyage.node(runID: runID, nodeID: nodeID) else { return nil }
        let encounterOrigin = PlayEncounterOrigin.voyage(runID: runID, nodeID: nodeID)
        switch node.type {
        case .battle, .boss:
            prepareNextBattle()
            return battleCoordinator.startBattle(origin: origin, encounters: encounters, busyMessage: nil, resolve: {
                guard let request = request(runID: runID, node: node) else { return .missing }
                return .ready(input: request.input, route: request.route)
            })
        case .shop:
            return encounters.beginShopOrAutoComplete(origin: encounterOrigin)
        case .mystery:
            return encounters.beginMysteryEncounter(origin: encounterOrigin)
        case .recruit:
            return encounters.beginMysteryEncounter(origin: encounterOrigin, forcedEventID: node.recruitEventID)
        case .entrance:
            return nil
        }
    }

    public func prepareNextBattle() {
        guard encounters.canBeginTransientEncounter, let run = playerSave.voyage.activeRun,
              let node = run.nextNode, node.type.isCombat, let request = request(runID: run.id, node: node) else {
            prunePrepared()
            return
        }
        battleCoordinator.prepareCombat(request.input, route: request.route)
        battleCoordinator.keepPreparedRuns([PlayBattleOrigin.voyage(runID: run.id, nodeID: node.id).runKey], preservingWhere: {
            if case .voyage = $0 {
                false
            } else {
                true
            }
        })
    }

    private func request(runID: String, node: VoyageNode) -> (input: BattleLaunchInput, route: PlayBattleRoute)? {
        guard let run = playerSave.voyage.activeRun, run.id == runID,
              let encounter = resolvedEncounter(for: node) else { return nil }
        let modifiers = ModeBattleModifiers(
            definitions: RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs),
        )
        let finalLoot = node.type == .boss ? VoyageCompletion.resolveFinalLoot(
            node: node, offer: run.offer, encounterLevel: encounter.level, save: playerSave.currentSave,
        ) : nil
        let loot = finalLoot?.primary
            ?? VoyageCompletion.resolveLoot(node: node, encounterLevel: encounter.level, save: playerSave.currentSave)
        let origin = PlayBattleOrigin.voyage(runID: runID, nodeID: node.id)
        let input = ModeBattleSpec.launchInput(
            origin: origin, encounter: encounter, loot: loot, roster: playerSave.roster,
            victoryOnlyExperienceBonusPercent: node.type == .boss ? run.offer.rewardModifier.resolved(
                ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
                ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
            ).experienceBonusPercent : 0,
            modifiers: modifiers,
            completionBonus: node.type == .boss ? VoyageCompletionBonus(gold: run.earnedGold, materials: run.earnedMaterials) : nil,
            additionalRewardItems: finalLoot?.additionalItem.map { [$0] } ?? [],
        )
        let route = PlayBattleRoute.voyage(
            runID: runID, nodeID: node.id, encounterLevel: encounter.level, access: playerSave.contentAccess,
        )
        return (input, route)
    }

    private func prunePrepared() {
        battleCoordinator.keepPreparedRuns([], preservingWhere: {
            if case .voyage = $0 {
                false
            } else {
                true
            }
        })
    }

    private func persist(key: String, action: @escaping () -> Bool) {
        guard action() else {
            playerSave.retrySaveAction(key: key) { [weak self] in
                self?.persist(key: key, action: action)
            }
            return
        }
    }
}
