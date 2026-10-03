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
        requiredKeyword: Keyword? = nil,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let eligibleAffixes = affixDefinitions.filter { definition in
            guard definition.isEligible(for: baseType) else { return false }
            if requireBuildAlignment {
                return definition.isAligned(withBuildKeywords: keywordBias)
            }
            return true
        }

        var guaranteedDefinitions: [ItemAffixDefinition] = []
        var guaranteedIDs: Set<String> = []
        var droppedGuaranteedIDs: [String] = []
        for affixID in guaranteedAffixIDs where guaranteedIDs.insert(affixID).inserted {
            if let definition = eligibleAffixes.first(where: { $0.id == affixID }) {
                guaranteedDefinitions.append(definition)
            } else {
                droppedGuaranteedIDs.append(affixID)
            }
        }
        if !droppedGuaranteedIDs.isEmpty {
            assertionFailure("Guaranteed affixes dropped for \(id): unknown or slot-ineligible IDs \(droppedGuaranteedIDs).")
        }

        if let requiredKeyword {
            precondition(baseType.keywordAffinities.contains(requiredKeyword), "Required keyword must match the item base")
            if !guaranteedDefinitions.contains(where: { $0.keywords.contains(requiredKeyword) }) {
                let matching = eligibleAffixes.filter { $0.keywords.contains(requiredKeyword) && $0.weight > 0 }
                guard let guaranteed = Self.weightedSample(matching, count: 1, using: &randomNumberGenerator).first else {
                    preconditionFailure("Required keyword must have an eligible base and affix")
                }
                guaranteedDefinitions.append(guaranteed)
                guaranteedIDs.insert(guaranteed.id)
            }
        }

        let rolledCount = fixedAffixCount ?? Self.affixCount(for: rarity, using: &randomNumberGenerator)
        let affixCount = max(rolledCount, guaranteedDefinitions.count)
        let remainingCount = max(0, affixCount - guaranteedDefinitions.count)
        let remainingPool = eligibleAffixes.filter { definition in
            !guaranteedIDs.contains(definition.id)
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
            return roll <= LootTuning.basicSingleAffixPercent ? LootTuning.basicAffixCounts.single : LootTuning.basicAffixCounts.double
        case .astral:
            return roll <= LootTuning.astralTripleAffixPercent ? LootTuning.astralAffixCounts.triple : LootTuning.astralAffixCounts.quad
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
        guard count > 0 else { return [] }
        var pool = definitions.map { (definition: $0, weight: adjustedWeight(for: $0, keywordBias: keywordBias)) }
        var totalWeight = pool.reduce(0) { $0 + $1.weight }
        var selected: [ItemAffixDefinition] = []

        while selected.count < count, totalWeight > 0 {
            var roll = Int.random(in: 1 ... totalWeight, using: &randomNumberGenerator)
            guard let selectedIndex = pool.firstIndex(where: { candidate in
                roll -= candidate.weight
                return roll <= 0
            }) else {
                preconditionFailure("Affix roll must select a positive-weight candidate")
            }
            let candidate = pool.remove(at: selectedIndex)
            totalWeight -= candidate.weight
            selected.append(candidate.definition)
        }

        return selected
    }

    private static func adjustedWeight(
        for definition: ItemAffixDefinition,
        keywordBias: Set<Keyword>,
    ) -> Int {
        let baseWeight = max(0, definition.weight)
        guard baseWeight > 0, !keywordBias.isEmpty else { return baseWeight }
        let overlap = definition.keywords.reduce(0) { count, keyword in
            count + (keywordBias.contains(keyword) ? 1 : 0)
        }
        guard overlap > 0 else { return baseWeight }
        return baseWeight * (LootTuning.biasWeightBase + overlap)
    }
}
