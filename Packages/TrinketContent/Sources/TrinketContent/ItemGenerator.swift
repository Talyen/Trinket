import Foundation
import TrinketCore

public struct ItemGenerator: Sendable {
    public var affixDefinitions: [ItemAffixDefinition]

    public init(affixDefinitions: [ItemAffixDefinition] = GameContent.itemAffixDefinitions) {
        self.affixDefinitions = affixDefinitions
    }

    public func generate<RNG: RandomNumberGenerator>(
        id: String,
        templateID: String? = nil,
        baseType: ItemBaseType,
        rarity: Rarity,
        using randomNumberGenerator: inout RNG
    ) -> InventoryItem {
        let affixCount = Self.affixCount(for: rarity, using: &randomNumberGenerator)
        let eligibleAffixes = affixDefinitions.filter { definition in
            definition.slot == baseType.slot &&
                !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
        }
        let selectedDefinitions = Self.weightedSample(
            eligibleAffixes,
            count: affixCount,
            using: &randomNumberGenerator
        )

        return InventoryItem(
            id: id,
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: baseType.name,
            affixes: selectedDefinitions.map { $0.resolved(for: rarity) }
        )
    }

    public static func affixCount<RNG: RandomNumberGenerator>(
        for rarity: Rarity,
        using randomNumberGenerator: inout RNG
    ) -> Int {
        let roll = Int.random(in: 1 ... 100, using: &randomNumberGenerator)

        switch rarity {
        case .basic:
            return roll <= 80 ? 1 : 2
        case .astral:
            return roll <= 75 ? 3 : 4
        }
    }

    private static func weightedSample<RNG: RandomNumberGenerator>(
        _ definitions: [ItemAffixDefinition],
        count: Int,
        using randomNumberGenerator: inout RNG
    ) -> [ItemAffixDefinition] {
        var pool = definitions
        var selected: [ItemAffixDefinition] = []

        while selected.count < count, !pool.isEmpty {
            let totalWeight = pool.reduce(0) { $0 + max(0, $1.weight) }
            guard totalWeight > 0 else { break }

            var roll = Int.random(in: 1 ... totalWeight, using: &randomNumberGenerator)
            let selectedIndex = pool.firstIndex { definition in
                roll -= max(0, definition.weight)
                return roll <= 0
            } ?? 0

            selected.append(pool.remove(at: selectedIndex))
        }

        return selected
    }
}
