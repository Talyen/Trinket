import TrinketContent
import TrinketCore

public enum VoyageCompletion {
    public static func resolveLoot(node: VoyageNode, encounterLevel: Int, save: PlayerSave) -> BattleLootResult {
        var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(save.worldSeed, salt: node.id))
        return BattleLoot.resolve(
            encounterLevel: encounterLevel, rewardLevel: ContractsCompletion.campaignRewardLevel(in: save),
            enemyIsBoss: node.type == .boss, itemID: "voyage-\(node.id)",
            ownedTrinketIDs: save.inventory.ownedTrinketIDs, ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            goldFoundPercent: node.effects.goldFoundPercent, materialsFoundPercent: node.effects.materialsFoundPercent,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent, using: &rng,
        )
    }

    @discardableResult
    public static func completeNode(runID: String, nodeID: String, save: inout PlayerSave) -> Bool {
        guard save.voyage.isPlayable(runID: runID, nodeID: nodeID),
              let node = save.voyage.node(runID: runID, nodeID: nodeID), !node.type.isCombat else { return false }
        save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.isCleared = true }
        return true
    }

    public static func completeBattle(
        runID: String, nodeID: String, hero: Combatant, companion: Combatant,
        rewards: (settled: BattleRewardSettlement, earned: BattleRewardAward), save: inout PlayerSave, access: ContentAccessPolicy,
    ) -> EncounterCompletion {
        guard save.voyage.isPlayable(runID: runID, nodeID: nodeID),
              let node = save.voyage.node(runID: runID, nodeID: nodeID), node.type.isCombat else { return .unavailable }
        let earned = rewards.earned
        VictoryRewardApplier.apply(rewards.settled, hero: hero, companion: companion, save: &save)
        save.voyage.activeRun?.earnedGold += earned.goldGained
        for material in earned.materials {
            save.voyage.activeRun?.earnedMaterials[material.resource, default: 0] += material.quantity
        }
        save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.isCleared = true }
        if save.voyage.activeRun?.isComplete == true {
            save.voyage.replaceOffer(runID: runID, access: access)
        }
        return .completed
    }
}
