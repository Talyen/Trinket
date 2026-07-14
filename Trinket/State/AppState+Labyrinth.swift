import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @discardableResult
    func enterLabyrinth() -> StageMapMessage? {
        do {
            try playerSave.performBatchMutation { save in
                save.labyrinth.ensureMap()
            }
        } catch {
            appStateLogger.error(
                "Failed to enter Labyrinth: \(error.localizedDescription, privacy: .public)"
            )
            return StageMapMessage(title: "Labyrinth Error", message: "Could not open the Labyrinth.")
        }
        return nil
    }

    @discardableResult
    func handleLabyrinthNodeAction(nodeID: String) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }
        guard activeShopEncounter == nil, activeMysteryEncounter == nil else { return nil }
        guard activeLabyrinthRest == nil, activeLabyrinthCraft == nil else { return nil }
        if let message = enterLabyrinth() {
            return message
        }
        guard let node = labyrinth.node(id: nodeID) else {
            return StageMapMessage(title: "Path Missing", message: "This path is not ready yet.")
        }
        guard labyrinth.isNodeReachable(nodeID) else {
            return StageMapMessage(title: "Path Closed", message: "Clear another path to reach this node.")
        }

        switch node.type.canonical {
        case .battle, .warden, .gate:
            return startLabyrinthBattle(nodeID: nodeID)
        case .shop:
            return beginShopEncounter(labyrinthNodeID: nodeID)
        case .mystery, .event:
            return beginMysteryEncounter(labyrinthNodeID: nodeID)
        case .rest:
            return beginLabyrinthRest(nodeID: nodeID)
        case .craft:
            return beginLabyrinthCraft(nodeID: nodeID)
        }
    }

    @discardableResult
    func beginLabyrinthRest(nodeID: String) -> StageMapMessage? {
        guard activeLabyrinthRest == nil, activeLabyrinthCraft == nil else { return nil }
        guard activeShopEncounter == nil, activeMysteryEncounter == nil else { return nil }
        guard battle.activeBattle == nil else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .rest else {
            return StageMapMessage(title: "Shrine Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        let reward = LabyrinthCompletion.rewards(for: node, effects: effects)
        activeLabyrinthRest = LabyrinthRestSession(
            nodeID: nodeID,
            goldCrumb: reward.gold,
            depth: node.depth
        )
        return nil
    }

    @discardableResult
    func beginLabyrinthCraft(nodeID: String) -> StageMapMessage? {
        guard activeLabyrinthCraft == nil, activeLabyrinthRest == nil else { return nil }
        guard activeShopEncounter == nil, activeMysteryEncounter == nil else { return nil }
        guard battle.activeBattle == nil else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .craft else {
            return StageMapMessage(title: "Altar Missing", message: "This path is not ready yet.")
        }
        activeLabyrinthCraft = LabyrinthCraftSession(
            nodeID: nodeID,
            goldCost: LabyrinthCompletion.craftAltarCost(for: node),
            depth: node.depth
        )
        return nil
    }

    @discardableResult
    func finishActiveLabyrinthRest() -> Bool {
        guard let session = activeLabyrinthRest else { return false }
        guard completeLabyrinthNode(nodeID: session.nodeID) else { return false }
        activeLabyrinthRest = nil
        return true
    }

    func dismissActiveLabyrinthRestWithoutCompleting() {
        activeLabyrinthRest = nil
    }

    @discardableResult
    func forgeActiveLabyrinthCraft() -> Bool {
        guard let session = activeLabyrinthCraft else { return false }
        session.clearFailure()
        var forged = false
        do {
            try playerSave.performBatchMutation { save in
                forged = LabyrinthCompletion.forgeAtAltar(
                    nodeID: session.nodeID,
                    hero: save.roster.activeHero,
                    companion: save.roster.activeCompanion,
                    save: &save
                )
            }
        } catch {
            appStateLogger.error(
                "Failed to forge at Labyrinth altar: \(error.localizedDescription, privacy: .public)"
            )
            session.markFailed("The altar stays cold. Try again.")
            return false
        }
        if forged {
            activeLabyrinthCraft = nil
            return true
        }
        session.markFailed("Not enough Gold.")
        return false
    }

    @discardableResult
    func leaveActiveLabyrinthCraftWithoutForging() -> Bool {
        guard let session = activeLabyrinthCraft else { return false }
        guard completeLabyrinthNode(nodeID: session.nodeID) else {
            session.markFailed("The altar stays cold. Try again.")
            return false
        }
        activeLabyrinthCraft = nil
        return true
    }

    func dismissActiveLabyrinthCraftWithoutCompleting() {
        activeLabyrinthCraft = nil
    }

    @discardableResult
    func startLabyrinthBattle(nodeID: String) -> StageMapMessage? {
        guard battle.activeBattle == nil else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(
            for: node,
            effects: effects
        ) else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }

        let rewards = LabyrinthCompletion.rewards(for: node, effects: effects)
        let pendingRewardItem = LabyrinthCompletion.pendingCombatRewardItem(
            for: node,
            effects: effects,
            worldSeed: labyrinth.worldSeed,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        activateBattle(
            resumeToken: .labyrinth(nodeID: nodeID),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: rewards,
            experienceBonusPercent: effects.xpPercent,
            pendingRewardItem: pendingRewardItem
        )
        return nil
    }

    @discardableResult
    func completeLabyrinthNode(
        nodeID: String,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil,
        rewardItem: InventoryItem? = nil
    ) -> Bool {
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

    func recordLabyrinthDefeat(nodeID: String) {
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.recordDefeat(nodeID: nodeID, save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to record Labyrinth defeat: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
