import TrinketContent
import TrinketCore

enum VoyageCompletion {
    @discardableResult
    static func completeNode(runID: String, nodeID: String, save: inout PlayerSave) -> Bool {
        guard save.voyage.isPlayable(runID: runID, nodeID: nodeID),
              let node = save.voyage.node(runID: runID, nodeID: nodeID), !node.type.isCombat else { return false }
        save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.isCleared = true }
        return true
    }

    static func completeBattle(
        runID: String, nodeID: String, party: (hero: Combatant, companion: Combatant),
        rewards: (settled: BattleRewardSettlement, earned: BattleRewardAward, encounterLevel: Int),
        save: inout PlayerSave, access: ContentAccessPolicy,
    ) -> EncounterCompletion {
        let (hero, companion) = party
        guard save.voyage.isPlayable(runID: runID, nodeID: nodeID),
              let node = save.voyage.node(runID: runID, nodeID: nodeID), node.type.isCombat else { return .unavailable }
        let earned = rewards.earned
        VictoryRewardApplier.apply(
            rewards.settled, hero: hero, companion: companion, save: &save,
        )
        save.contracts.recordVictory(encounterLevel: rewards.encounterLevel)
        if var activeRun = save.voyage.activeRun {
            activeRun.earnedGold = SaturatedArithmetic.saturatingAdd(activeRun.earnedGold, earned.goldGained)
            for material in earned.materials {
                let current = activeRun.earnedMaterials[material.resource, default: 0]
                activeRun.earnedMaterials[material.resource] = SaturatedArithmetic.saturatingAdd(current, material.quantity)
            }
            save.voyage.activeRun = activeRun
        }
        save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.isCleared = true }
        if save.voyage.activeRun?.isComplete == true {
            save.voyage.replaceOffer(
                runID: runID, access: access, eligibleModifiers: RewardOwnership(save).eligibleModifiers,
            )
            save.voyage.dismissCompleted()
        }
        return .completed
    }
}
