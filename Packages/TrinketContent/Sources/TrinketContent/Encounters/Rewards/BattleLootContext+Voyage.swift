import TrinketCore

public struct VoyageResolvedLoot: Sendable {
    public let primary: BattleLootResult
    public let additionalItem: InventoryItem?
}

public extension BattleLootContext {
    func finalVoyage(
        node: VoyageNode, offer: VoyageOffer, encounterLevel: Int,
    ) -> VoyageResolvedLoot {
        let effects = NodeModifierEffects.combining(ownership.modifiers(ids: node.modifierIDs))
        let destination = ownership.resolved(offer.rewardModifier)
        var primary = BattleLoot.resolve(
            .voyage(
                node: node,
                effects: effects, additionalRewardModifier: destination,
            ),
            encounterLevel: encounterLevel, enemyIsBoss: true,
            worldSeed: worldSeed, ownership: ownership,
            astralChanceBonusPercent: astralChanceBonusPercent,
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
        let secondModifier = secondOwnership.resolved(destination)
        guard secondModifier.isItemFocused else {
            let gold = SaturatedArithmetic.saturatingAdd(
                primary.gold,
                max(0, CombatRounding.scaled(primary.gold, byPercent: RewardModifier.bonusPercent) - primary.gold),
            )
            primary = BattleLootResult(item: primary.item, gold: gold, materials: primary.materials)
            return VoyageResolvedLoot(primary: primary, additionalItem: nil)
        }
        let second = BattleLoot.resolve(
            LootRequest(
                seedSalt: "\(node.id)-destination", itemID: "voyage-\(node.id)-destination",
                rewardModifier: secondModifier,
            ),
            encounterLevel: encounterLevel, enemyIsBoss: true,
            worldSeed: worldSeed, ownership: secondOwnership,
            astralChanceBonusPercent: astralChanceBonusPercent,
        )
        return VoyageResolvedLoot(primary: primary, additionalItem: second.item)
    }
}
