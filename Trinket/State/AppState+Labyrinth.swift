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
        if let message = enterLabyrinth() {
            return message
        }
        guard let node = labyrinth.node(id: nodeID) else {
            return StageMapMessage(title: "Path Missing", message: "This path is not ready yet.")
        }
        guard labyrinth.isNodeReachable(nodeID) else {
            return StageMapMessage(title: "Path Closed", message: "Clear another path to reach this node.")
        }

        switch node.type {
        case .battle, .elite, .warden, .gate:
            return startLabyrinthBattle(nodeID: nodeID)
        case .shop:
            return beginShopEncounter(labyrinthNodeID: nodeID)
        case .mystery:
            return beginMysteryEncounter(labyrinthNodeID: nodeID)
        case .rest, .event, .craft:
            completeLabyrinthNode(nodeID: nodeID)
            return nil
        }
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
        battle.preview = nil
        battle.activeBattle = makeActiveBattleConfiguration(
            stageID: nil,
            hero: roster.activeHero,
            pet: roster.activePet,
            enemy: encounter.combatant,
            enemyEncounterLevel: encounter.level,
            stageReward: rewards,
            aspectBattle: nil,
            labyrinthBattle: .init(nodeID: nodeID)
        )
        battle.isPaused = selectedTab != .play
        syncBattleTickLoop()
        return nil
    }

    func completeLabyrinthNode(
        nodeID: String,
        hero: Combatant? = nil,
        pet: Combatant? = nil,
        battleEarnedGold: Int = 0,
        materialRewards: [ResourceAmount]? = nil
    ) {
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
        } catch {
            appStateLogger.error(
                "Failed to persist Labyrinth node: \(error.localizedDescription, privacy: .public)"
            )
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
