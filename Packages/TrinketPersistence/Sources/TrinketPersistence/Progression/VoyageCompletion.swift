import TrinketContent
import TrinketCore

public struct VoyageResolvedLoot: Sendable {
    public let primary: BattleLootResult
    public let additionalItem: InventoryItem?
}

public enum VoyageCompletion {
    public static func resolveLoot(node: VoyageNode, encounterLevel: Int, save: PlayerSave) -> BattleLootResult {
        let ownership = RewardOwnership(save)
        let effects = LabyrinthModifierEffects.combining(ownership.modifiers(ids: node.modifierIDs))
        return VictoryRewardApplier.resolveLoot(
            .voyage(node: node, rewardLevel: ContractsCompletion.campaignRewardLevel(in: save), effects: effects),
            encounterLevel: encounterLevel, enemyIsBoss: node.type == .boss,
            worldSeed: save.worldSeed, ownership: ownership,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
    }

    public static func resolveFinalLoot(
        node: VoyageNode, offer: VoyageOffer, encounterLevel: Int, save: PlayerSave,
    ) -> VoyageResolvedLoot {
        let ownership = RewardOwnership(save)
        let effects = LabyrinthModifierEffects.combining(ownership.modifiers(ids: node.modifierIDs))
        let destination = offer.rewardModifier.resolved(
            ownedTrinketIDs: ownership.ownedTrinketIDs, ownedUniqueIDs: ownership.ownedUniqueIDs,
        )
        var primary = VictoryRewardApplier.resolveLoot(
            .voyage(
                node: node, rewardLevel: ContractsCompletion.campaignRewardLevel(in: save),
                effects: effects, additionalRewardModifier: destination,
            ),
            encounterLevel: encounterLevel, enemyIsBoss: true,
            worldSeed: save.worldSeed, ownership: ownership,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
        guard effects.rewardModifier?.isItemFocused == true, destination.isItemFocused else {
            return VoyageResolvedLoot(primary: primary, additionalItem: nil)
        }
        var secondOwnership = ownership
        if primary.item.isTrinket {
            secondOwnership.ownedTrinketIDs.insert(primary.item.templateID)
        }
        if primary.item.rarity == .unique {
            secondOwnership.ownedUniqueIDs.insert(primary.item.templateID)
        }
        let secondModifier = destination.resolved(
            ownedTrinketIDs: secondOwnership.ownedTrinketIDs,
            ownedUniqueIDs: secondOwnership.ownedUniqueIDs,
        )
        guard secondModifier.isItemFocused else {
            let gold = SaturatedArithmetic.saturatingAdd(
                primary.gold,
                max(0, CombatRounding.scaled(primary.gold, byPercent: RewardModifier.bonusPercent) - primary.gold),
            )
            primary = BattleLootResult(item: primary.item, gold: gold, materials: primary.materials)
            return VoyageResolvedLoot(primary: primary, additionalItem: nil)
        }
        let second = VictoryRewardApplier.resolveLoot(
            LootRequest(
                rewardLevel: ContractsCompletion.campaignRewardLevel(in: save),
                seedSalt: "\(node.id)-destination", itemID: "voyage-\(node.id)-destination",
                rewardModifier: secondModifier,
            ),
            encounterLevel: encounterLevel, enemyIsBoss: true,
            worldSeed: save.worldSeed, ownership: secondOwnership,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )
        return VoyageResolvedLoot(primary: primary, additionalItem: second.item)
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
        rewards: (settled: BattleRewardSettlement, earned: BattleRewardAward, encounterLevel: Int),
        save: inout PlayerSave, access: ContentAccessPolicy,
    ) -> EncounterCompletion {
        guard save.voyage.isPlayable(runID: runID, nodeID: nodeID),
              let node = save.voyage.node(runID: runID, nodeID: nodeID), node.type.isCombat else { return .unavailable }
        let earned = rewards.earned
        VictoryRewardApplier.apply(rewards.settled, hero: hero, companion: companion, save: &save)
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
        }
        return .completed
    }
}
