import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    var isLabyrinthUnlocked: Bool {
        LabyrinthUnlock.isUnlocked(journey: journey.current, aspects: aspects.current)
    }

    @discardableResult
    func enterLabyrinth() -> StageMapMessage? {
        guard ModesUnlock.isUnlocked(journey: journey.current) else {
            return StageMapMessage(title: "Modes Locked", message: ModesUnlock.unlockHint)
        }
        guard isLabyrinthUnlocked else {
            return StageMapMessage(
                title: "Labyrinth Locked",
                message: LabyrinthUnlock.unlockHint(journey: journey.current, aspects: aspects.current)
            )
        }
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
        case .battle, .elite, .warden, .gate:
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

    func finishActiveLabyrinthRest() {
        guard let session = activeLabyrinthRest else { return }
        activeLabyrinthRest = nil
        completeLabyrinthNode(nodeID: session.nodeID)
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
                    pet: save.roster.activePet,
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

    func leaveActiveLabyrinthCraftWithoutForging() {
        guard let session = activeLabyrinthCraft else { return }
        activeLabyrinthCraft = nil
        completeLabyrinthNode(nodeID: session.nodeID)
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
        activateBattle(
            resumeToken: .labyrinth(nodeID: nodeID),
            hero: roster.activeHero,
            pet: roster.activePet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: rewards
        )
        return nil
    }

    @discardableResult
    func completeLabyrinthNode(
        nodeID: String,
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil
    ) -> Bool {
        let resolvedHero = hero ?? roster.activeHero
        let resolvedPet = pet ?? roster.activePet
        do {
            try playerSave.performBatchMutation { save in
                LabyrinthCompletion.complete(
                    nodeID: nodeID,
                    hero: resolvedHero,
                    pet: resolvedPet,
                    battleEarnedGold: battleEarnedGold,
                    materialRewards: materialRewards,
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
