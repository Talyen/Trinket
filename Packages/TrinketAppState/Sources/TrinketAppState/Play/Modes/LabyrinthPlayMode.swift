import BattleEngine
import Foundation
import Observation
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

@MainActor
@Observable
public final class LabyrinthPlayMode {
    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        encounters: EncounterPlayMode,
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    @discardableResult
    func beginMysteryEncounter(
        nodeID: String,
        forcedEventID: String? = nil,
    ) -> StageMapMessage? {
        encounters.beginMysteryEncounter(
            origin: .labyrinth(nodeID: nodeID),
            forcedEventID: forcedEventID,
        )
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        if playerSave.labyrinth.isMapPayloadUnreadable {
            return StageMapMessage(
                title: "Labyrinth Error",
                message: "Couldn't read the Labyrinth map. Progress is preserved. Try again later.",
            )
        }
        guard playerSave.persistBatch(logging: "Failed to enter Labyrinth", { save in
            LabyrinthCompletion.enter(save: &save, access: playerSave.contentAccess)
        }) else {
            return StageMapMessage(title: "Labyrinth Error", message: "Could not open Labyrinth.")
        }
        return nil
    }

    @discardableResult
    public func handleNodeAction(nodeID: String) -> StageMapMessage? {
        if let restriction = playerSave.accessRestriction(for: .labyrinth(nodeID: nodeID)) {
            return restriction
        }
        guard encounters.canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID) else {
            return StageMapMessage(title: "Path Missing", message: "This path is not ready yet.")
        }
        guard labyrinth.isNodeReachable(nodeID) else {
            return StageMapMessage(title: "Path Closed", message: "Clear another path to reach this node.")
        }

        switch node.type {
        case .battle, .boss:
            return startBattle(nodeID: nodeID)
        case .shop:
            return encounters.beginShopOrAutoComplete(
                origin: .labyrinth(nodeID: nodeID),
            )
        case .mystery:
            return beginMysteryEncounter(nodeID: nodeID)
        case .recruit:
            let resolution = resolveRecruitEncounter(for: node)
            return beginMysteryEncounter(
                nodeID: nodeID,
                forcedEventID: resolution.event.id,
            )
        case .entrance:
            return nil
        }
    }

    public func resolvedEncounter(for node: LabyrinthNode) -> ScaledEncounter? {
        PlayBattlePreparation.labyrinthEncounter(
            for: node,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    func startBattle(nodeID: String) -> StageMapMessage? {
        // No access pre-check here: PlayBattleLaunch.startBattle owns the
        // gate and returns the restriction first. handleNodeAction keeps its
        // own check so the paywall takes precedence over reachability messages.
        battleLaunch.startBattle(
            origin: .labyrinth(nodeID: nodeID),
            encounters: encounters,
            busyMessage: nil, // Map taps swallow a busy battle.
            resolve: {
                let labyrinth = playerSave.labyrinth
                guard let node = labyrinth.node(id: nodeID), node.type.isCombat,
                      let encounter = resolvedEncounter(for: node) else { return .missing }
                let request = combatRequest(node: node, labyrinth: labyrinth, encounter: encounter)
                return .ready(input: request.input, route: request.route)
            },
        )
    }

    public func previewMysteryEvent(for node: LabyrinthNode) -> MysteryEvent? {
        switch node.type {
        case .mystery:
            return encounters.previewMysteryEvent(origin: .labyrinth(nodeID: node.id))
        case .recruit:
            if case let .mystery(event) = resolveRecruitEncounter(for: node) {
                return event
            }
            return nil
        default:
            return nil
        }
    }

    private func resolveRecruitEncounter(for node: LabyrinthNode) -> RecruitEncounterResolution {
        let roster = playerSave.roster
        return GameContent.resolveRecruitEncounter(
            configuredEventID: node.recruitEventID,
            encounterID: node.id,
            worldSeed: playerSave.worldSeed,
            unlockedHeroIDs: roster.unlockedHeroIDs,
            unlockedCompanionIDs: roster.unlockedCompanionIDs,
            access: playerSave.contentAccess,
        )
    }

    public func prepareReachableBattles() {
        guard battle.lifecyclePhase != .active else { return }
        let labyrinth = playerSave.labyrinth
        var preparedKeys: Set<BattleRunKey> = []
        for nodeID in labyrinth.reachableNodeIDs() {
            guard playerSave.accessRestriction(for: .labyrinth(nodeID: nodeID)) == nil else { continue }
            guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { continue }
            if prepareBattle(node: node, labyrinth: labyrinth) {
                preparedKeys.insert(PlayBattleOrigin.labyrinth(nodeID: nodeID).runKey)
            }
        }
        battleLaunch.keepPreparedRuns(preparedKeys, preservingWhere: { !$0.isLabyrinth })
    }

    private func prepareBattle(
        node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState,
    ) -> Bool {
        guard let encounter = resolvedEncounter(for: node) else { return false }
        guard battle.lifecyclePhase != .active else { return false }
        let request = combatRequest(node: node, labyrinth: labyrinth, encounter: encounter)
        return battleLaunch.prepareCombat(request.input, route: request.route)
    }
}

extension LabyrinthPlayMode {
    private func combatRequest(
        node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState,
        encounter: ScaledEncounter,
    ) -> (input: BattleLaunchInput, route: PlayBattleRoute) {
        let loot = battleLoot(for: node, labyrinth: labyrinth, encounterLevel: encounter.level)
        let modifiers = ModeBattleModifiers(
            definitions: RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs),
        )
        let input = ModeBattleSpec.launchInput(
            origin: .labyrinth(nodeID: node.id),
            encounter: encounter,
            loot: loot,
            roster: playerSave.roster,
            modifiers: modifiers,
        )
        return (input, .labyrinth(nodeID: node.id, access: playerSave.contentAccess))
    }

    private func battleLoot(
        for node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState,
        encounterLevel: Int,
    ) -> BattleLootResult {
        let loot = BattleLootContext(playerSave: playerSave)
        let effects = labyrinth.effects(for: node.id)
        return BattleLoot.resolve(
            .labyrinth(node: node, effects: effects),
            encounterLevel: encounterLevel,
            enemyIsBoss: VictoryRewardApplier.isBoss(enemyID: node.enemyID),
            worldSeed: loot.worldSeed,
            ownership: loot.ownership,
            astralChanceBonusPercent: loot.astralChanceBonusPercent,
        )
    }
}
