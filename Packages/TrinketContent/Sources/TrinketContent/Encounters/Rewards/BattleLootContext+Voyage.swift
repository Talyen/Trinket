import TrinketCore

public struct VoyageResolvedLoot: Sendable {
    public let primary: BattleLootResult
    public let additionalItem: InventoryItem?
}

public extension BattleLootContext {
    func finalVoyage(
        node: VoyageNode, offer: VoyageOffer, encounterLevel: Int,
    ) -> VoyageResolvedLoot {
        let effects = NodeModifierEffects.combining(ownership.modifiers(ids: node.modifierIDs, enemyIsBoss: true))
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
        guard destination.isItemFocused else {
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
            let gold = CombatRounding.scaled(primary.gold, byPercent: RewardModifier.bonusPercent)
            primary = BattleLootResult(item: primary.item, gold: gold, materials: primary.materials)
            return VoyageResolvedLoot(primary: primary, additionalItem: nil)
        }
        let request = LootRequest(seedSalt: "\(node.id)-destination", itemID: "voyage-\(node.id)-destination")
        var rng = SeededRandomNumberGenerator(seed: GameContent.encounterSeed(worldSeed, salt: request.seedSalt))
        let item = BattleLoot.rollItem(
            request, modifier: secondModifier, encounterLevel: encounterLevel,
            enemyIsBoss: false, ownership: secondOwnership,
            astralChanceBonusPercent: astralChanceBonusPercent, excludesBasic: true, using: &rng,
        )
        return VoyageResolvedLoot(primary: primary, additionalItem: item)
    }
}
