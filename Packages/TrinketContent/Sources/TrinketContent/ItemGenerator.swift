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
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let eligibleAffixes = affixDefinitions.filter { definition in
            guard definition.isEligible(for: baseType) else { return false }
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
            using: &randomNumberGenerator,
        )

        return InventoryItem(
            id: id,
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: baseType.name,
            affixes: selectedDefinitions.map { $0.resolved(for: rarity) },
            affixPowers: selectedDefinitions.map { definition in
                let catalog = definition.power(for: rarity)
                guard definition.basic != definition.astral else { return catalog }
                return catalog.rolled(using: &randomNumberGenerator)
            },
        )
    }

    public static func affixCount(
        for rarity: Rarity,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Int {
        let roll = Int.random(in: 1 ... 100, using: &randomNumberGenerator)

        switch rarity {
        case .basic:
            return roll <= 80 ? 1 : 2
        case .astral:
            return roll <= 75 ? 3 : 4
        case .unique:
            preconditionFailure("Unique affix counts are authored in the catalog.")
        }
    }

    private static func weightedSample(
        _ definitions: [ItemAffixDefinition],
        count: Int,
        keywordBias: Set<Keyword> = [],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> [ItemAffixDefinition] {
        var pool = definitions
        var selected: [ItemAffixDefinition] = []

        while selected.count < count, !pool.isEmpty {
            let totalWeight = pool.reduce(0) { partial, definition in
                partial + adjustedWeight(for: definition, keywordBias: keywordBias)
            }
            guard totalWeight > 0 else { break }

            let targetRoll = Int.random(in: 1 ... totalWeight, using: &randomNumberGenerator)
            var currentWeight = 0
            var selectedIndex = 0
            for (index, definition) in pool.enumerated() {
                currentWeight += adjustedWeight(for: definition, keywordBias: keywordBias)
                if currentWeight >= targetRoll {
                    selectedIndex = index
                    break
                }
            }

            selected.append(pool.remove(at: selectedIndex))
        }

        return selected
    }

    private static func adjustedWeight(
        for definition: ItemAffixDefinition,
        keywordBias: Set<Keyword>,
    ) -> Int {
        let baseWeight = max(0, definition.weight)
        guard baseWeight > 0, !keywordBias.isEmpty else { return baseWeight }
        let overlap = definition.keywords.intersection(keywordBias).count
        guard overlap > 0 else { return baseWeight }
        return baseWeight * (2 + overlap)
    }
}

public enum ItemRewardGenerator {
    private struct RewardContext {
        let keywordBias: Set<Keyword>
        let fallbackBaseType: ItemBaseType?
        let guaranteedAffixIDs: [String]
        let baseTypes: [ItemBaseType]
        let itemGenerator: ItemGenerator
    }

    public static func generate(
        id: String,
        tier: ItemDropTier,
        ownedTrinketIDs: Set<String>,
        ownedUniqueIDs: Set<String>,
        reservedTrinketIDs: Set<String> = [],
        keywordBias: Set<Keyword> = [],
        eligibleTrinketIDs: Set<String>? = nil,
        fallbackBaseType: ItemBaseType? = nil,
        guaranteedAffixIDs: [String] = [],
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        itemGenerator: ItemGenerator = ItemGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let context = RewardContext(
            keywordBias: keywordBias,
            fallbackBaseType: fallbackBaseType,
            guaranteedAffixIDs: guaranteedAffixIDs,
            baseTypes: baseTypes,
            itemGenerator: itemGenerator,
        )
        switch tier {
        case .unique:
            var uniques = GameContent.uniqueItems.filter {
                !ownedUniqueIDs.contains($0.templateID)
            }
            if !keywordBias.isEmpty {
                uniques = uniques.filter { !$0.keywords.isDisjoint(with: keywordBias) }
            }
            if let unique = uniques.randomElement(using: &randomNumberGenerator) {
                return unique
            }
            return trinketOrGenerated(
                id: id,
                rarity: .astral,
                ownedTrinketIDs: ownedTrinketIDs,
                reservedTrinketIDs: reservedTrinketIDs,
                eligibleTrinketIDs: eligibleTrinketIDs,
                context: context,
                using: &randomNumberGenerator,
            )
        case .trinket:
            return trinketOrGenerated(
                id: id,
                rarity: .astral,
                ownedTrinketIDs: ownedTrinketIDs,
                reservedTrinketIDs: reservedTrinketIDs,
                eligibleTrinketIDs: eligibleTrinketIDs,
                context: context,
                using: &randomNumberGenerator,
            )
        case .astral, .basic:
            return generated(
                id: id,
                rarity: tier == .astral ? .astral : .basic,
                context: context,
                using: &randomNumberGenerator,
            )
        }
    }

    private static func trinketOrGenerated(
        id: String,
        rarity: Rarity,
        ownedTrinketIDs: Set<String>,
        reservedTrinketIDs: Set<String>,
        eligibleTrinketIDs: Set<String>?,
        context: RewardContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        var trinkets = GameContent.trinketItems.filter {
            !ownedTrinketIDs.contains($0.templateID)
                && !reservedTrinketIDs.contains($0.templateID)
        }
        if let eligibleTrinketIDs {
            trinkets = trinkets.filter { eligibleTrinketIDs.contains($0.templateID) }
        }
        if !context.keywordBias.isEmpty {
            trinkets = trinkets.filter { !$0.keywords.isDisjoint(with: context.keywordBias) }
        }
        if !trinkets.isEmpty, let trinket = trinkets.randomElement(using: &randomNumberGenerator) {
            return trinket
        }
        return generated(id: id, rarity: rarity, context: context, using: &randomNumberGenerator)
    }

    private static func generated(
        id: String,
        rarity: Rarity,
        context: RewardContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let normalBases = context.fallbackBaseType.map { [$0] }
            ?? context.baseTypes.filter { $0.slot != .trinket }
        precondition(!normalBases.isEmpty, "Item rewards require at least one non-Trinket base type.")
        let biasedBases = context.keywordBias.isEmpty
            ? normalBases
            : normalBases.filter { !$0.keywordAffinities.isDisjoint(with: context.keywordBias) }
        let pool = biasedBases.isEmpty ? normalBases : biasedBases
        let baseType = pool.randomElement(using: &randomNumberGenerator) ?? pool[0]
        return context.itemGenerator.generate(
            id: id,
            templateID: "\(baseType.id)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            keywordBias: context.keywordBias,
            guaranteedAffixIDs: context.guaranteedAffixIDs,
            using: &randomNumberGenerator,
        )
    }
}
