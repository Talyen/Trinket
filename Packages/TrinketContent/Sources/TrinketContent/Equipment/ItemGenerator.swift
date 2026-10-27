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
        partyBias: PartyLootBias = PartyLootBias(),
        requireBuildAlignment: Bool = false,
        guaranteedAffixIDs: [String] = [],
        requiredKeyword: Keyword? = nil,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        if let fixedAffixCount, fixedAffixCount <= 0, guaranteedAffixIDs.isEmpty, requiredKeyword == nil {
            return Self.emptyItem(id: id, templateID: templateID, baseType: baseType, rarity: rarity)
        }
        let eligibleAffixes = affixDefinitions.filter { definition in
            definition.isEligible(for: baseType)
                && (!requireBuildAlignment || definition.isAligned(withBuildKeywords: keywordBias))
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

        if let requiredKeyword, baseType.keywordAffinities.contains(requiredKeyword),
           !guaranteedDefinitions.contains(where: { $0.keywords.contains(requiredKeyword) }) {
            // Content drift can leave a keyword with no eligible affix; the
            // item still generates without the guarantee instead of trapping.
            let matching = eligibleAffixes.filter { $0.keywords.contains(requiredKeyword) && $0.weight > 0 }
            if let guaranteed = Self.weightedSample(matching, count: 1, using: &randomNumberGenerator).first {
                guaranteedDefinitions.append(guaranteed)
                guaranteedIDs.insert(guaranteed.id)
            }
        }

        let rolledCount = fixedAffixCount ?? Self.affixCount(for: rarity, using: &randomNumberGenerator)
        let affixCount = max(rolledCount, guaranteedDefinitions.count)
        let remainingCount = max(0, affixCount - guaranteedDefinitions.count)
        let remainingPool: [ItemAffixDefinition] = if remainingCount == 0 {
            []
        } else if guaranteedIDs.isEmpty {
            eligibleAffixes
        } else {
            eligibleAffixes.filter { !guaranteedIDs.contains($0.id) }
        }
        let selectedDefinitions = guaranteedDefinitions + Self.weightedSample(
            remainingPool,
            count: remainingCount,
            keywordBias: keywordBias,
            partyBias: partyBias,
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
                guard definition.slot != .trinket else { return catalog }
                return catalog.rolled(using: &randomNumberGenerator)
            },
        )
    }

    private static func emptyItem(id: String, templateID: String?, baseType: ItemBaseType, rarity: Rarity) -> InventoryItem {
        InventoryItem(
            id: id, templateID: templateID, baseType: baseType, rarity: rarity,
            displayName: baseType.name, affixes: [], affixPowers: [],
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
            // Unique counts are authored in the catalog; a direct roll keeps
            // only guaranteed affixes instead of trapping.
            return 0
        }
    }

    private static func weightedSample(
        _ definitions: [ItemAffixDefinition],
        count: Int,
        keywordBias: Set<Keyword> = [],
        partyBias: PartyLootBias = PartyLootBias(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> [ItemAffixDefinition] {
        guard count > 0 else { return [] }
        var totalWeight = 0
        let hasPartyBias = !partyBias.isEmpty
        var pool = definitions.map { definition in
            let baseWeight = adjustedWeight(for: definition, keywordBias: keywordBias)
            let weight = hasPartyBias ? baseWeight * partyBias.weight(for: definition.keywords) : baseWeight
            totalWeight += weight
            return (definition: definition, weight: weight)
        }
        var selected: [ItemAffixDefinition] = []

        while selected.count < count, totalWeight > 0 {
            guard let selectedIndex = WeightedLootSelection.index(
                in: pool, totalWeight: totalWeight, weight: { $0.weight }, using: &randomNumberGenerator,
            ) else {
                // All remaining weights are zero; return the partial selection
                // instead of trapping the live reward.
                break
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
        let overlap = definition.keywords.count(where: keywordBias.contains)
        guard overlap > 0 else { return baseWeight }
        return baseWeight * (2 + overlap)
    }
}
