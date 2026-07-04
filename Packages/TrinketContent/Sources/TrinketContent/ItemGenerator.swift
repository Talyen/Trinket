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
        fixedAffixCount: Int? = nil,
        keywordBias: Set<Keyword> = [],
        using randomNumberGenerator: inout RNG
    ) -> InventoryItem {
        let affixCount = fixedAffixCount ?? Self.affixCount(for: rarity, using: &randomNumberGenerator)
        let eligibleAffixes = affixDefinitions.filter { definition in
            definition.slot == baseType.slot &&
                !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
        }
        let selectedDefinitions = Self.weightedSample(
            eligibleAffixes,
            count: affixCount,
            keywordBias: keywordBias,
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
        keywordBias: Set<Keyword> = [],
        using randomNumberGenerator: inout RNG
    ) -> [ItemAffixDefinition] {
        var pool = definitions
        var selected: [ItemAffixDefinition] = []

        while selected.count < count, !pool.isEmpty {
            let totalWeight = pool.reduce(0) { partial, definition in
                partial + adjustedWeight(for: definition, keywordBias: keywordBias)
            }
            guard totalWeight > 0 else { break }

            var roll = Int.random(in: 1 ... totalWeight, using: &randomNumberGenerator)
            let selectedIndex = pool.firstIndex { definition in
                roll -= adjustedWeight(for: definition, keywordBias: keywordBias)
                return roll <= 0
            } ?? 0

            selected.append(pool.remove(at: selectedIndex))
        }

        return selected
    }

    private static func adjustedWeight(
        for definition: ItemAffixDefinition,
        keywordBias: Set<Keyword>
    ) -> Int {
        let baseWeight = max(0, definition.weight)
        guard baseWeight > 0, !keywordBias.isEmpty else { return baseWeight }
        let overlap = definition.keywords.intersection(keywordBias).count
        guard overlap > 0 else { return baseWeight }
        return baseWeight * (2 + overlap)
    }
}
