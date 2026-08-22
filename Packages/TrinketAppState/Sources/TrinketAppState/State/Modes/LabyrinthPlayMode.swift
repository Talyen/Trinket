import BattleEngine
import Foundation
import Observation
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketPersistence

/// Labyrinth map flow: enter, node routing, rest/craft, and node completion writes.
@MainActor
@Observable
public final class LabyrinthPlayMode {
    private struct CombatPrepNode: Equatable {
        let nodeID: String
        let combatantID: String
        let encounterLevel: Int
        let modifierIDs: [LabyrinthModifierID]
    }

    private struct PreparationInputs: Equatable {
        let combatNodes: [CombatPrepNode]
        let roster: PlayerRosterState
        let inventory: PlayerInventoryState
        let homestead: PlayerHomesteadState
    }

    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparedInputs: PreparationInputs?

    public var activeNodeSession: LabyrinthNodeSession?

    init(
        playerSave: PlayerSaveStore,
        battle: any BattleRuntime,
        battleLaunch: PlayBattleLaunch,
        encounters: EncounterPlayMode
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
        self.encounters = encounters
    }

    private var canBeginTransientEncounter: Bool {
        encounters.canBeginTransientEncounter && activeNodeSession == nil
    }

    @discardableResult
    func beginMysteryEncounter(
        nodeID: String,
        forcedEventID: String? = nil
    ) -> StageMapMessage? {
        encounters.beginMysteryEncounter(
            origin: .labyrinth(nodeID: nodeID),
            forcedEventID: forcedEventID
        )
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        if playerSave.labyrinth.isMapPayloadUnreadable {
            return StageMapMessage(
                title: "Labyrinth Error",
                message: "Couldn't read the Labyrinth map. Progress is preserved — try again later."
            )
        }
        guard playerSave.persistBatch(logging: "Failed to enter Labyrinth", { save in
            LabyrinthCompletion.enter(save: &save)
        }) else {
            return StageMapMessage(title: "Labyrinth Error", message: "Could not open Labyrinth.")
        }
        return nil
    }

    @discardableResult
    public func handleNodeAction(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID) else {
            return StageMapMessage(title: "Path Missing", message: "This path is not ready yet.")
        }
        guard labyrinth.isNodeReachable(nodeID) else {
            return StageMapMessage(title: "Path Closed", message: "Clear another path to reach this node.")
        }

        let roster = playerSave.roster
        switch node.type.canonical {
        case .battle, .boss:
            return startBattle(nodeID: nodeID)
        case .shop:
            switch encounters.beginShopEncounter(origin: .labyrinth(nodeID: nodeID)) {
            case .autoCompleted:
                if let failure = completeNodeOrPersistFailure(nodeID: nodeID) {
                    return failure
                }
                return encounters.emptyShopClosedMessage(identifier: nodeID)
            case .opened, .unavailable:
                return nil
            }
        case .mystery, .event, .craft:
            return beginMysteryEncounter(nodeID: nodeID)
        case .recruit:
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: node.recruitEventID,
                encounterID: node.id,
                worldSeed: playerSave.worldSeed,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs
            )
            return beginMysteryEncounter(
                nodeID: nodeID,
                forcedEventID: resolution.event.id
            )
        case .rest:
            return beginRest(nodeID: nodeID)
        case .entrance:
            return nil
        }
    }

    @discardableResult
    func beginRest(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .rest else {
            return StageMapMessage(title: "Shrine Missing", message: "This path is not ready yet.")
        }
        activeNodeSession = LabyrinthNodeSession.rest(
            node: node,
            homestead: playerSave.homestead
        )
        return nil
    }

    @discardableResult
    public func finishActiveRest() -> Bool {
        guard let sessionNode = activeNodeSession else { return false }
        sessionNode.clearFailure()
        guard playerSave.persistBatch(logging: "Failed to finish Labyrinth rest", { save in
            LabyrinthCompletion.complete(
                nodeID: sessionNode.nodeID,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                save: &save
            )
        }) else {
            sessionNode.markFailed("Couldn't save progress. Stay here and try Rest again.")
            return false
        }
        activeNodeSession = nil
        return true
    }

    public func resolvedEncounter(for node: LabyrinthNode) -> (combatant: Combatant, level: Int)? {
        Self.resolvedEncounter(for: node)
    }

    @discardableResult
    func startBattle(nodeID: String) -> StageMapMessage? {
        guard battle.lifecyclePhase != .active else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = resolvedEncounter(for: node) else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }

        let origin = PlayBattleOrigin.labyrinth(nodeID: nodeID)
        let activated = battleLaunch.activateCombat(
            origin: origin,
            encounter: encounter,
            route: battleRoute(nodeID: nodeID),
            loot: battleLoot(for: node, labyrinth: labyrinth),
            universalModifiers: Self.combatModifiers(from: effects),
            labyrinthModifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs)
        )
        if activated {
            preparedInputs = nil
        }
        return activated ? nil : PlayBattleLaunch.activationFailureMessage
    }

    public func previewMysteryEvent(for node: LabyrinthNode) -> MysteryEvent? {
        switch node.type.canonical {
        case .mystery, .event:
            return encounters.previewMysteryEvent(origin: .labyrinth(nodeID: node.id))
        case .recruit:
            let roster = playerSave.roster
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: node.recruitEventID,
                encounterID: node.id,
                worldSeed: playerSave.worldSeed,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs
            )
            if case let .mystery(event) = resolution {
                return event
            }
            return nil
        default:
            return nil
        }
    }

    public func prepareReachableBattles() {
        guard battle.lifecyclePhase != .active else { return }
        let labyrinth = playerSave.labyrinth
        let inputs = preparationInputs(labyrinth: labyrinth)
        guard inputs != preparedInputs || battle.lifecyclePhase == .idle else { return }

        var preparedAll = true
        var preparedKeys: Set<BattleRunKey> = []
        for nodeID in labyrinth.reachableNodeIDs() {
            guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { continue }
            preparedKeys.insert(PlayBattleOrigin.labyrinth(nodeID: nodeID).runKey)
            if !prepareBattle(node: node, labyrinth: labyrinth) {
                preparedAll = false
            }
        }
        battleLaunch.keepPreparedRuns(preparedKeys)
        if preparedAll {
            preparedInputs = inputs
        }
    }

    private func preparationInputs(labyrinth: PlayerLabyrinthState) -> PreparationInputs {
        let combatNodes = labyrinth.reachableNodeIDs().compactMap { nodeID -> CombatPrepNode? in
            guard let node = labyrinth.node(id: nodeID), node.type.isCombat,
                  let encounter = resolvedEncounter(for: node)
            else { return nil }
            return CombatPrepNode(
                nodeID: nodeID,
                combatantID: encounter.combatant.id,
                encounterLevel: encounter.level,
                modifierIDs: node.modifierIDs
            )
        }
        return PreparationInputs(
            combatNodes: combatNodes,
            roster: playerSave.roster,
            inventory: playerSave.inventory,
            homestead: playerSave.homestead
        )
    }

    private func prepareBattle(
        node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState
    ) -> Bool {
        let effects = labyrinth.effects(for: node.id)
        guard let encounter = resolvedEncounter(for: node) else { return false }

        let origin = PlayBattleOrigin.labyrinth(nodeID: node.id)
        return battleLaunch.prepareCombat(
            origin: origin,
            encounter: encounter,
            route: battleRoute(nodeID: node.id),
            loot: battleLoot(for: node, labyrinth: labyrinth),
            universalModifiers: Self.combatModifiers(from: effects),
            labyrinthModifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs)
        )
    }

    /// Completes a Labyrinth node, returning a save-failure message when persistence fails.
    func completeNodeOrPersistFailure(nodeID: String) -> StageMapMessage? {
        guard completeNode(nodeID: nodeID) else {
            return StageMapMessage(
                title: "Couldn't Save Progress",
                message: "This path wasn't saved. Try again."
            )
        }
        return nil
    }

    @discardableResult
    func completeNode(
        nodeID: String,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
        let roster = playerSave.roster
        let resolvedHero = hero ?? roster.activeHero
        let resolvedCompanion = companion ?? roster.activeCompanion
        return playerSave.persistBatch(logging: "Failed to persist Labyrinth node") { save in
            LabyrinthCompletion.complete(
                nodeID: nodeID,
                hero: resolvedHero,
                companion: resolvedCompanion,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: rewardItem,
                save: &save
            )
        }
    }
}

extension LabyrinthPlayMode {
    static func resolvedEncounter(
        for node: LabyrinthNode
    ) -> (combatant: Combatant, level: Int)? {
        guard let enemyID = node.enemyID,
              let catalogEnemy = GameContent.enemy(matching: enemyID)
        else { return nil }
        let level = EncounterLevelResolver.labyrinthEnemyLevel(for: node)
        return (CombatantLevelScaler.scale(enemy: catalogEnemy, level: level), level)
    }

    private static func combatModifiers(
        from effects: LabyrinthModifierEffects
    ) -> [AffixModifier] {
        var modifiers: [AffixModifier] = effects.damageDealtBonus
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageDealt($0.key, $0.value) }
        modifiers += effects.damageTakenReduction
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { .damageTakenPercent($0.key, Double($0.value) / 100) }
        if effects.blockGainedBonus != 0 {
            modifiers.append(.blockGained(effects.blockGainedBonus))
        }
        if effects.leechGainedPercent != 0 {
            modifiers.append(.leechGainedPercent(Double(effects.leechGainedPercent) / 100))
        }
        return modifiers
    }

    private func battleLoot(
        for node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState
    ) -> BattleLootPackage? {
        Self.resolveBattleLoot(
            for: node,
            effects: labyrinth.effects(for: node.id),
            worldSeed: playerSave.worldSeed,
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent
        )
    }

    static func resolveBattleLoot(
        for node: LabyrinthNode,
        effects: LabyrinthModifierEffects,
        worldSeed: UInt64,
        ownedTrinketIDs: Set<String> = [],
        astralChanceBonusPercent: Int = 0
    ) -> BattleLootPackage? {
        LabyrinthCompletion.resolveCombatLoot(
            for: node,
            effects: effects,
            worldSeed: worldSeed,
            ownedTrinketIDs: ownedTrinketIDs,
            astralChanceBonusPercent: astralChanceBonusPercent
        )
    }

    func battleRoute(nodeID: String) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.labyrinth(nodeID: nodeID)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards in
            guard let self else { return false }
            return completeNode(
                nodeID: nodeID,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem
            )
        }
    }
}
