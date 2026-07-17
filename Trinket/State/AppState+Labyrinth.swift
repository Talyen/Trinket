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
        guard canBeginLabyrinthNodeEncounter() else { return nil }
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
        case .battle, .boss, .gate:
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
        guard canBeginLabyrinthNodeEncounter() else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .rest else {
            return StageMapMessage(title: "Shrine Missing", message: "This path is not ready yet.")
        }
        let effects = labyrinth.effects(for: nodeID)
        let rewardGold = LabyrinthCompletion.nonCombatGoldStipend(for: node, effects: effects)
        activeLabyrinthNodeSession = LabyrinthNodeSession(
            kind: .rest,
            nodeID: nodeID,
            goldAmount: homestead.effects.adjustedGold(rewardGold),
            depth: node.depth
        )
        return nil
    }

    @discardableResult
    func beginLabyrinthCraft(nodeID: String) -> StageMapMessage? {
        guard canBeginLabyrinthNodeEncounter() else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .craft else {
            return StageMapMessage(title: "Altar Missing", message: "This path is not ready yet.")
        }
        activeLabyrinthNodeSession = LabyrinthNodeSession(
            kind: .craft,
            nodeID: nodeID,
            goldAmount: LabyrinthCompletion.craftAltarCost(for: node),
            depth: node.depth
        )
        return nil
    }

    @discardableResult
    func finishActiveLabyrinthRest() -> Bool {
        guard let session = activeLabyrinthNodeSession, session.kind == .rest else { return false }
        session.clearFailure()
        guard completeLabyrinthNode(nodeID: session.nodeID) else {
            session.markFailed("Couldn't save progress. Stay here and try Rest again.")
            return false
        }
        activeLabyrinthNodeSession = nil
        return true
    }

    func dismissActiveLabyrinthNodeSessionWithoutCompleting() {
        activeLabyrinthNodeSession = nil
    }

    @discardableResult
    func forgeActiveLabyrinthCraft() -> Bool {
        guard let session = activeLabyrinthNodeSession, session.kind == .craft else { return false }
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
            activeLabyrinthNodeSession = nil
            return true
        }
        session.markFailed("Not enough Gold.")
        return false
    }

    @discardableResult
    func leaveActiveLabyrinthCraftWithoutForging() -> Bool {
        guard let session = activeLabyrinthNodeSession, session.kind == .craft else { return false }
        guard completeLabyrinthNode(nodeID: session.nodeID) else {
            session.markFailed("The altar stays cold. Try again.")
            return false
        }
        activeLabyrinthNodeSession = nil
        return true
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

        let loot = LabyrinthCompletion.resolveCombatLoot(
            for: node,
            effects: effects,
            worldSeed: labyrinth.worldSeed
        )
        activateBattle(
            resumeToken: .labyrinth(nodeID: nodeID),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            experienceBonusPercent: effects.xpPercent,
            pendingRewardItem: loot?.item
        )
        return nil
    }

    func prepareReachableLabyrinthBattles() {
        guard battle.activeBattle == nil else { return }
        for nodeID in labyrinth.reachableNodeIDs() {
            prepareLabyrinthBattle(nodeID: nodeID)
        }
    }

    private func prepareLabyrinthBattle(nodeID: String) {
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(
            for: node,
            effects: effects
        ) else { return }

        let loot = LabyrinthCompletion.resolveCombatLoot(
            for: node,
            effects: effects,
            worldSeed: labyrinth.worldSeed
        )
        battle.prepareBattleRun(makeBattleConfiguration(
            resumeToken: .labyrinth(nodeID: nodeID),
            hero: roster.activeHero,
            companion: roster.activeCompanion,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: loot?.asStageReward ?? .empty,
            experienceBonusPercent: effects.xpPercent,
            pendingRewardItem: loot?.item
        ))
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

    private func canBeginLabyrinthNodeEncounter() -> Bool {
        battle.activeBattle == nil
            && activeShopEncounter == nil
            && activeMysteryEncounter == nil
            && activeLabyrinthNodeSession == nil
    }
}
