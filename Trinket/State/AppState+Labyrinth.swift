import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @discardableResult
    func enterLabyrinth() -> StageMapMessage? {
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
        case .battle, .boss:
            return startLabyrinthBattle(nodeID: nodeID)
        case .shop:
            return beginShopEncounter(labyrinthNodeID: nodeID)
        case .mystery, .event:
            return beginMysteryEncounter(labyrinthNodeID: nodeID)
        case .recruit:
            let resolution = GameContent.resolveRecruitEncounter(
                configuredEventID: node.recruitEventID,
                encounterID: node.id,
                unlockedHeroIDs: roster.unlockedHeroIDs,
                unlockedCompanionIDs: roster.unlockedCompanionIDs
            )
            return beginMysteryEncounter(
                labyrinthNodeID: nodeID,
                forcedEventID: resolution.event.id
            )
        case .rest:
            return beginLabyrinthRest(nodeID: nodeID)
        case .craft:
            return beginLabyrinthCraft(nodeID: nodeID)
        case .entrance:
            return nil
        }
    }

    @discardableResult
    func beginLabyrinthRest(nodeID: String) -> StageMapMessage? {
        guard canBeginLabyrinthNodeEncounter() else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .rest else {
            return StageMapMessage(title: "Shrine Missing", message: "This path is not ready yet.")
        }
        activeLabyrinthNodeSession = LabyrinthNodeSession.rest(
            node: node,
            effects: labyrinth.effects(for: nodeID),
            homestead: homestead
        )
        return nil
    }

    @discardableResult
    func beginLabyrinthCraft(nodeID: String) -> StageMapMessage? {
        guard canBeginLabyrinthNodeEncounter() else { return nil }
        guard let node = labyrinth.node(id: nodeID), node.type.canonical == .craft else {
            return StageMapMessage(title: "Altar Missing", message: "This path is not ready yet.")
        }
        activeLabyrinthNodeSession = LabyrinthNodeSession.craft(node: node)
        return nil
    }

    @discardableResult
    func finishActiveLabyrinthRest() -> Bool {
        guard let session = activeLabyrinthNodeSession, session.kind == .rest else { return false }
        session.clearFailure()
        do {
            try playerSave.performBatchMutation { save in
                _ = session.finishRest(save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to finish Labyrinth rest: \(error.localizedDescription, privacy: .public)"
            )
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
                forged = session.forge(save: &save)
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
        do {
            try playerSave.performBatchMutation { save in
                _ = session.leaveWithoutForging(save: &save)
            }
        } catch {
            appStateLogger.error(
                "Failed to leave Labyrinth craft: \(error.localizedDescription, privacy: .public)"
            )
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
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(for: node) else {
            return StageMapMessage(title: "Encounter Missing", message: "This path is not ready yet.")
        }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .labyrinth(nodeID: nodeID),
            labyrinth: labyrinth,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        activateBattle(
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

    func prepareReachableLabyrinthBattles() {
        guard battle.activeBattle == nil else { return }
        for nodeID in labyrinth.reachableNodeIDs() {
            prepareLabyrinthBattle(nodeID: nodeID)
        }
    }

    private func prepareLabyrinthBattle(nodeID: String) {
        guard let node = labyrinth.node(id: nodeID), node.type.isCombat else { return }
        let effects = labyrinth.effects(for: nodeID)
        guard let encounter = ActiveBattleConfiguration.resolvedLabyrinthEncounter(for: node) else { return }

        let loot = ActiveBattleConfiguration.lootPackage(
            for: .labyrinth(nodeID: nodeID),
            labyrinth: labyrinth,
            astralChanceBonusPercent: homestead.effects.astralChanceBonusPercent
        )
        battle.prepareBattleRun(makeBattleConfiguration(
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

    private func canBeginLabyrinthNodeEncounter() -> Bool {
        battle.activeBattle == nil
            && activeShopEncounter == nil
            && activeMysteryEncounter == nil
            && activeLabyrinthNodeSession == nil
    }
}
