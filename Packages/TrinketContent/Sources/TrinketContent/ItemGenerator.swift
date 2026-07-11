import Foundation
import TrinketCore

public struct ItemGenerator: Sendable {
    public var affixDefinitions: [ItemAffixDefinition]

    public init(affixDefinitions: [ItemAffixDefinition] = GameContent.itemAffixDefinitions) {
        self.affixDefinitions = affixDefinitions
    }

    public func generate(
        id: String,
        templateID: String? = nil,
        baseType: ItemBaseType,
        rarity: Rarity,
        fixedAffixCount: Int? = nil,
        keywordBias: Set<Keyword> = [],
        requireBuildAlignment: Bool = false,
        guaranteedAffixIDs: [String] = [],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> InventoryItem {
        let eligibleAffixes = affixDefinitions.filter { definition in
            guard definition.slot == baseType.slot,
                  !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            else { return false }
            if requireBuildAlignment {
                return definition.isAligned(withBuildKeywords: keywordBias)
            }
            return true
        }

        let guaranteedDefinitions = guaranteedAffixIDs.compactMap { affixID in
            eligibleAffixes.first { $0.id == affixID }
        }

        let rolledCount = fixedAffixCount ?? Self.affixCount(for: rarity, using: &randomNumberGenerator)
        let affixCount = max(rolledCount, guaranteedDefinitions.count)
        let remainingCount = max(0, affixCount - guaranteedDefinitions.count)
        let remainingPool = eligibleAffixes.filter { definition in
            !guaranteedDefinitions.contains { $0.id == definition.id }
        }
        let selectedDefinitions = guaranteedDefinitions + Self.weightedSample(
            remainingPool,
            count: remainingCount,
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

    public static func affixCount(
        for rarity: Rarity,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Int {
        let roll = Int.random(in: 1 ... 100, using: &randomNumberGenerator)

        switch rarity {
        case .basic:
            return roll <= 80 ? 1 : 2
        case .astral:
            return roll <= 75 ? 3 : 4
        }
    }

    private static func weightedSample(
        _ definitions: [ItemAffixDefinition],
        count: Int,
        keywordBias: Set<Keyword> = [],
        using randomNumberGenerator: inout some RandomNumberGenerator
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
