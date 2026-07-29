import Foundation
import Observation
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence

/// Labyrinth map flow: enter, node routing, rest/craft, and labyrinth battle victory.
@MainActor
@Observable
public final class LabyrinthPlayMode {
    private let playerSave: PlayerSaveStore
    private let battle: BattleSession
    private let battleLaunch: PlayBattleLaunch
    private var encounters: EncounterPlayMode?

    public var activeNodeSession: LabyrinthNodeSession?

    init(
        playerSave: PlayerSaveStore,
        battle: BattleSession,
        battleLaunch: PlayBattleLaunch
    ) {
        self.playerSave = playerSave
        self.battle = battle
        self.battleLaunch = battleLaunch
    }

    func bind(encounters: EncounterPlayMode) {
        self.encounters = encounters
    }

    private var boundEncounters: EncounterPlayMode {
        guard let encounters else {
            preconditionFailure("LabyrinthPlayMode used before encounters bind")
        }
        return encounters
    }

    private var canBeginTransientEncounter: Bool {
        battle.activeBattle == nil
            && boundEncounters.activeShopEncounter == nil
            && boundEncounters.activeMysteryEncounter == nil
            && activeNodeSession == nil
    }

    @discardableResult
    public func enter() -> StageMapMessage? {
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.enter(save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to enter Labyrinth: \(error.localizedDescription, privacy: .public)"
            )
            return StageMapMessage(title: "Labyrinth Error", message: "Could not open Labyrinth.")
        }
        return nil
    }

    @discardableResult
    public func handleNodeAction(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        if let message = enter() {
            return message
        }
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
            return boundEncounters.beginShopEncounter(labyrinthNodeID: nodeID)
        case .mystery, .event:
            return boundEncounters.beginMysteryEncounter(labyrinthNodeID: nodeID)
        case .recruit:
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: node.recruitEventID,
                encounterID: node.id,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs
            )
            return boundEncounters.beginMysteryEncounter(
                labyrinthNodeID: nodeID,
                forcedEventID: resolution.event.id
            )
        case .rest:
            return beginRest(nodeID: nodeID)
        case .craft:
            return beginCraft(nodeID: nodeID)
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
            effects: labyrinth.effects(for: nodeID),
            homestead: playerSave.homestead
        )
        return nil
    }

    @discardableResult
    func beginCraft(nodeID: String) -> StageMapMessage? {
        guard canBeginTransientEncounter else { return nil }
        let labyrinth = playerSave.labyrinth
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .craft else {
            return StageMapMessage(title: "Altar Missing", message: "This path is not ready yet.")
        }
        activeNodeSession = LabyrinthNodeSession.craft(node: node)
        return nil
    }

    @discardableResult
    public func finishActiveRest() -> Bool {
        guard let sessionNode = activeNodeSession, sessionNode.kind == .rest else { return false }
        sessionNode.clearFailure()
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: sessionNode.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to finish Labyrinth rest: \(error.localizedDescription, privacy: .public)"
            )
            sessionNode.markFailed("Couldn't save progress. Stay here and try Rest again.")
            return false
        }
        activeNodeSession = nil
        return true
    }

    public func dismissActiveNodeSessionWithoutCompleting() {
        activeNodeSession = nil
    }

    @discardableResult
    public func forgeActiveCraft() -> Bool {
        guard let sessionNode = activeNodeSession, sessionNode.kind == .craft else { return false }
        sessionNode.clearFailure()
        var forged = false
        do {
            try playerSave.performBatchMutation { save in
                forged = LabyrinthCompletion.forgeAtAltar(
                    nodeID: sessionNode.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to forge at Labyrinth altar: \(error.localizedDescription, privacy: .public)"
            )
            sessionNode.markFailed("The altar stays cold. Try again.")
            return false
        }
        if forged {
            activeNodeSession = nil
            return true
        }
        sessionNode.markFailed("Not enough Gold.")
        return false
    }

    @discardableResult
    public func leaveActiveCraftWithoutForging() -> Bool {
        guard let sessionNode = activeNodeSession, sessionNode.kind == .craft else { return false }
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: sessionNode.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to leave Labyrinth craft: \(error.localizedDescription, privacy: .public)"
            )
            sessionNode.markFailed("The altar stays cold. Try again.")
            return false
        }
        activeNodeSession = nil
        return true
    }

    @discardableResult
    func startBattle(nodeID: String) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }
        let labyrinth = playerSave.labyrinth
        let roster = playerSave.roster
        let homestead = playerSave.homestead
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(for: node) else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .labyrinth(nodeID: nodeID),
            labyrinth: labyrinth,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        battleLaunch.activateBattle(
            resumeToken: .labyrinth(nodeID: nodeID),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            universalModifiers: ActiveBattleConfiguration.labyrinthCombatModifiers(from: effects)
        )
        return nil
    }

    public func prepareReachableBattles() {
        guard battle.activeBattle == nil else { return }
        for nodeID in playerSave.labyrinth.reachableNodeIDs() {
            prepareBattle(nodeID: nodeID)
        }
    }

    private func prepareBattle(nodeID: String) {
        let labyrinth = playerSave.labyrinth
        let roster = playerSave.roster
        let homestead = playerSave.homestead
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(for: node) else { return }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .labyrinth(nodeID: nodeID),
            labyrinth: labyrinth,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        battle.prepareBattleRun(battleLaunch.makeBattleConfiguration(
            resumeToken: .labyrinth(nodeID: nodeID),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            pendingRewardItem: loot?.item,
            universalModifiers: ActiveBattleConfiguration.labyrinthCombatModifiers(from: effects)
        ))
    }

    func persistVictory(
        for configuration: ActiveBattleConfiguration,
        hero: Combatant,
        companion: Combatant,
        battleEarnedGold: Int,
        materialRewards: [ResourceAmount]?
    ) -> Bool {
        guard case let .labyrinth(nodeID) = configuration.resumeToken else { return false }
        return completeNode(
            nodeID: nodeID,
            hero: hero,
            companion: companion,
            battleEarnedGold: battleEarnedGold,
            materialRewards: materialRewards,
            rewardItem: configuration.pendingRewardItem
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
        do {
            try playerSave.performBatchMutation { save in
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
            return true
        } catch {
            appStateLogger.error(
                "Failed to persist Labyrinth node: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
