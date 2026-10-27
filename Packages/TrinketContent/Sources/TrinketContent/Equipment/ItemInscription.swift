import TrinketCore

public struct ItemInscriptionPlan: Sendable {
    public let original: InventoryItem
    public let item: InventoryItem
    public let cost: [ResourceAmount]

    public static func isEligible(_ item: InventoryItem) -> Bool {
        !item.isTrinket && item.rarity != .unique && !item.affixes.isEmpty
            && item.affixes.allSatisfy { GameContent.itemAffixDefinition(matching: $0.id) != nil }
    }

    public static func cost(for item: InventoryItem) -> [ResourceAmount] {
        let multiplier = item.rarity == .astral ? 2 : 1
        return [ResourceAmount(.iron, 8 * multiplier), ResourceAmount(.gems, 4 * multiplier)]
    }

    public static func choices(for item: InventoryItem, index: Int) -> [ItemAffixDefinition] {
        guard canSelectAffix(for: item, index: index) else { return [] }
        let occupied = Set(item.affixes.enumerated().lazy.filter { $0.offset != index }.map(\.element.id))
        return GameContent.itemAffixDefinitions.filter { $0.isEligible(for: item.baseType) && !occupied.contains($0.id) }
    }

    private static func canSelectAffix(for item: InventoryItem, index: Int) -> Bool {
        item.affixes.indices.contains(index)
            && (item.inscribedAffixIndex == nil || item.inscribedAffixIndex == index)
            && isEligible(item)
    }

    public static func prepare(
        item: InventoryItem, index: Int, affixID: String,
        using random: inout some RandomNumberGenerator,
    ) -> Self? {
        guard canSelectAffix(for: item, index: index),
              let definition = GameContent.itemAffixDefinition(matching: affixID),
              definition.isEligible(for: item.baseType),
              !item.affixes.enumerated().contains(where: { $0.offset != index && $0.element.id == affixID })
        else { return nil }
        var affixes = item.affixes
        var powers = item.affixes.indices.compactMap { item.unscaledPower(at: $0) }
        guard powers.count == item.affixes.count else { return nil }
        let catalogPower = definition.power(for: item.rarity)
        let power = catalogPower.rolled(using: &random)
        affixes[index] = ItemAffix(
            id: definition.id,
            title: definition.title,
            description: power.description,
            keywords: definition.keywords,
        )
        powers[index] = power
        return Self(original: item, item: InventoryItem(
            id: item.id, templateID: item.templateID, baseType: item.baseType, rarity: item.rarity,
            displayName: item.displayName, affixes: affixes, isCorrupted: item.isCorrupted,
            affixPowers: powers, inscribedAffixIndex: index,
        ), cost: cost(for: item))
    }
}
