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
        playerSave.performSaveAction(key: SaveRetryKey.voyageEnter) { [weak self] _ -> SaveActionAttempt<StageMapMessage?> in
            guard let self else { return SaveActionAttempt(nil) }
            if playerSave.voyage.activeRun?.isComplete == true {
                dismissCompleted()
            }
            guard encounters.canBeginTransientEncounter else { return SaveActionAttempt(nil) }
            guard !playerSave.voyage.isUnreadable else {
                return SaveActionAttempt(StageMapMessage(
                    title: "Voyage Unavailable",
                    message: "Your Voyage could not be read. Your progress is preserved.",
                ))
            }
            return playerSave.prepareVoyage().map { _ in nil }
        }
    }

    public func refresh() {
        mutateVoyage(key: SaveRetryKey.voyageRefresh) { $0.refreshVoyage() }
    }

    public func embark(offerID: String) {
        mutateVoyage(key: SaveRetryKey.voyageEmbark(offerID)) { $0.embarkVoyage(offerID: offerID) }
    }

    public func abandon(runID: String) {
        mutateVoyage(key: SaveRetryKey.voyageAbandon(runID)) { [weak self] store in
            let result = store.abandonVoyage(runID: runID)
            self?.prunePrepared()
            return result
        }
    }

    public func dismissCompleted() {
        mutateVoyage(key: SaveRetryKey.voyageCompleted) { $0.dismissCompletedVoyage() }
    }

    private func mutateVoyage(key: String, _ mutate: @escaping (PlayerSaveStore) -> SaveActionAttempt<Bool>) {
        playerSave.performSaveAction(key: key) { [weak self] _ in
            guard let self, encounters.canBeginTransientEncounter else { return SaveActionAttempt(false) }
            return mutate(playerSave)
        }
    }

    public func resolvedEncounter(for node: VoyageNode) -> ScaledEncounter? {
        guard let run = playerSave.voyage.activeRun else { return nil }
        return PlayBattlePreparation.scaledEncounter(
            enemyID: node.enemyID,
            scaling: .voyage(run.offer.difficulty),
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    public func previewMysteryEvent(for node: VoyageNode, runID: String? = nil) -> MysteryEvent? {
        guard node.type == .mystery else { return nil }
        guard let resolvedRunID = runID ?? playerSave.voyage.activeRun?.id, !resolvedRunID.isEmpty else { return nil }
        return encounters.previewMysteryEvent(origin: .voyage(runID: resolvedRunID, nodeID: node.id))
    }

    @discardableResult
    public func handleNode(runID: String, nodeID: String) -> StageMapMessage? {
        playerSave.performSaveAction(key: SaveRetryKey.voyageNode(
            runID: runID,
            nodeID: nodeID,
        )) { [weak self] _ -> SaveActionAttempt<StageMapMessage?> in
            guard let self else { return SaveActionAttempt(nil) }
            guard encounters.canBeginTransientEncounter,
                  playerSave.voyage.isPlayable(runID: runID, nodeID: nodeID) else { return SaveActionAttempt(nil) }
            let origin = PlayBattleOrigin.voyage(runID: runID, nodeID: nodeID)
            if let restriction = playerSave.accessRestriction(for: origin) {
                return SaveActionAttempt(restriction)
            }
            let prepared = playerSave.prepareVoyage()
            guard prepared.value else { return prepared.map { _ in nil } }
            guard let node = playerSave.voyage.node(runID: runID, nodeID: nodeID) else { return SaveActionAttempt(nil) }
            let encounterOrigin = PlayEncounterOrigin.voyage(runID: runID, nodeID: nodeID)
            switch node.type {
            case .battle, .boss:
                prepareNextBattle()
                return SaveActionAttempt(battleCoordinator.startBattle(origin: origin, encounters: encounters, busyMessage: nil, resolve: {
                    guard let request = request(runID: runID, node: node) else { return .missing }
                    return .ready(input: request.input, route: request.route)
                }))
            case .shop:
                return SaveActionAttempt(encounters.beginShopOrAutoComplete(origin: encounterOrigin))
            case .mystery, .recruit:
                return SaveActionAttempt(encounters.beginMysteryEncounter(origin: encounterOrigin))
            case .entrance:
                return SaveActionAttempt(nil)
            }
        }
    }

    public func prepareNextBattle() {
        guard encounters.canBeginTransientEncounter, let run = playerSave.voyage.activeRun,
              let node = run.nextNode, node.type.isCombat, let request = request(runID: run.id, node: node) else {
            prunePrepared()
            return
        }
        battleCoordinator.prepareCombat(request.input, route: request.route)
        let warmKey = PlayBattleOrigin.voyage(runID: run.id, nodeID: node.id).runKey
        battleCoordinator.prunePreparedRuns(for: .voyage, keeping: [warmKey])
    }

    private func request(runID: String, node: VoyageNode) -> (input: BattleLaunchInput, route: PlayBattleRoute)? {
        guard let run = playerSave.voyage.activeRun, run.id == runID,
              let encounter = resolvedEncounter(for: node) else { return nil }
        let modifiers = ModeBattleModifiers(
            definitions: RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs, enemyIsBoss: node.type == .boss),
        )
        let lootContext = BattleLootContext(playerSave: playerSave)
        let finalLoot = node.type == .boss ? lootContext.finalVoyage(node: node, offer: run.offer, encounterLevel: encounter.level) : nil
        let loot = finalLoot?.primary
            ?? lootContext.voyage(node: node, encounterLevel: encounter.level)
        let origin = PlayBattleOrigin.voyage(runID: runID, nodeID: node.id)
        let input = ModeBattleSpec.launchInput(
            origin: origin, encounter: encounter, loot: loot, roster: playerSave.roster,
            victoryOnlyExperienceBonusPercent: node.type == .boss ? lootContext.ownership.resolved(run.offer.rewardModifier)
                .experienceBonusPercent : 0,
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
        battleCoordinator.prunePreparedRuns(for: .voyage)
    }
}
