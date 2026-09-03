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
    private struct CombatPrepNode: Equatable {
        let nodeID: String
        let combatantID: String
        let encounterLevel: Int
        let modifierIDs: [LabyrinthModifierID]
    }

    private struct PreparationInputs: Equatable {
        let combatNodes: [CombatPrepNode]
        let party: PlayBattlePartySnapshot
    }

    public let playerSave: PlayerSaveStore
    public let battle: any BattleRuntime
    private let battleLaunch: PlayBattleLaunch
    private let encounters: EncounterPlayMode
    private var preparationTracker = PlayBattlePreparationTracker<PreparationInputs>()

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

    private var canBeginTransientEncounter: Bool {
        encounters.canBeginTransientEncounter
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
            return PlayShopEncounterRouting.handle(
                encounters: encounters,
                origin: .labyrinth(nodeID: nodeID),
                identifier: nodeID,
                onAutoComplete: { completeNodeOrPersistFailure(nodeID: nodeID) },
            )
        case .mystery, .event, .craft:
            return beginMysteryEncounter(nodeID: nodeID)
        case .recruit:
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: node.recruitEventID,
                encounterID: node.id,
                worldSeed: playerSave.worldSeed,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs,
            )
            return beginMysteryEncounter(
                nodeID: nodeID,
                forcedEventID: resolution.event.id,
            )
        case .entrance, .rest:
            return nil
        }
    }

    public func resolvedEncounter(for node: LabyrinthNode) -> (combatant: Combatant, level: Int)? {
        Self.resolvedEncounter(
            for: node,
            partyAverageLevel: playerSave.roster.activePartyAverageLevel,
        )
    }

    @discardableResult
    func startBattle(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = resolvedEncounter(for: node) else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }

        let request = combatRequest(node: node, labyrinth: labyrinth, encounter: encounter, effects: effects)
        guard battle.lifecyclePhase != .active, canBeginTransientEncounter else {
            return PlayBattleLaunch.activationFailureMessage
        }
        let activated = battleLaunch.activateCombat(request)
        if activated {
            preparationTracker.invalidate()
            return nil
        }
        return PlayBattleLaunch.activationFailureMessage
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
                unlockedCompanionIDs: roster.unlockedCompanionIDs,
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
        let missingPreparedRun = labyrinth.reachableNodeIDs().contains { nodeID in
            guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return false }
            return !battle.hasPreparedRun(PlayBattleOrigin.labyrinth(nodeID: nodeID).runKey)
        }
        guard preparationTracker.shouldPrepare(
            for: inputs,
            lifecycle: battle.lifecyclePhase,
            hasPreparedRun: !missingPreparedRun,
        ) else { return }

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
            preparationTracker.notePrepared(inputs)
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
                modifierIDs: node.modifierIDs,
            )
        }
        return PreparationInputs(
            combatNodes: combatNodes,
            party: PlayBattlePartySnapshot(playerSave: playerSave),
        )
    }

    private func prepareBattle(
        node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState,
    ) -> Bool {
        let effects = labyrinth.effects(for: node.id)
        guard let encounter = resolvedEncounter(for: node) else { return false }
        guard battle.lifecyclePhase != .active else { return false }
        let request = combatRequest(node: node, labyrinth: labyrinth, encounter: encounter, effects: effects)
        return battleLaunch.prepareCombat(request)
    }

    func completeNodeOrPersistFailure(nodeID: String) -> StageMapMessage? {
        guard completeNode(nodeID: nodeID) else {
            return StageMapMessage(
                title: "Couldn't Save Progress",
                message: "This path wasn't saved. Try again.",
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
        rewardItem: InventoryItem? = nil,
        loot: BattleLootResult? = nil,
        enemyEncounterLevel: Int? = nil,
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
                loot: loot,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save,
            )
        }
    }
}

extension LabyrinthPlayMode {
    static func resolvedEncounter(
        for node: LabyrinthNode,
        partyAverageLevel: Int,
    ) -> (combatant: Combatant, level: Int)? {
        PlayBattlePreparation.scaledEncounter(
            enemyID: node.enemyID,
            authoredLevel: EncounterLevelResolver.labyrinthEnemyLevel(for: node),
            partyAverageLevel: partyAverageLevel,
        )
    }

    private static func combatModifiers(
        from effects: LabyrinthModifierEffects,
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

    private func combatRequest(
        node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState,
        encounter: (combatant: Combatant, level: Int),
        effects: LabyrinthModifierEffects,
    ) -> PlayCombatRequest {
        PlayCombatRequest(
            origin: .labyrinth(nodeID: node.id),
            encounter: encounter,
            route: battleRoute(nodeID: node.id),
            loot: battleLoot(for: node, labyrinth: labyrinth, encounterLevel: encounter.level),
            stageRewardsAlreadyClaimed: false,
            universalModifiers: Self.combatModifiers(from: effects),
            labyrinthModifiers: LabyrinthCatalog.modifiers(ids: node.modifierIDs),
        )
    }

    private func battleLoot(
        for node: LabyrinthNode,
        labyrinth: PlayerLabyrinthState,
        encounterLevel: Int,
    ) -> BattleLootResult? {
        LabyrinthCompletion.resolveCombatLoot(
            for: node,
            effects: labyrinth.effects(for: node.id),
            encounterLevel: encounterLevel,
            worldSeed: playerSave.worldSeed,
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
            astralChanceBonusPercent: playerSave.homestead.effects.astralChanceBonusPercent,
        )
    }

    func battleRoute(nodeID: String) -> PlayBattleRoute {
        let origin = PlayBattleOrigin.labyrinth(nodeID: nodeID)
        return PlayBattleRoute(origin: origin) { [weak self] configuration, presentation, battleEarnedGold, materialRewards, loot in
            guard let self else { return false }
            return completeNode(
                nodeID: nodeID,
                hero: configuration.hero.combatant,
                companion: configuration.companion.combatant,
                battleEarnedGold: battleEarnedGold,
                materialRewards: materialRewards,
                rewardItem: presentation?.pendingRewardItem,
                loot: loot,
                enemyEncounterLevel: configuration.enemyEncounterLevel,
            )
        }
    }
}
