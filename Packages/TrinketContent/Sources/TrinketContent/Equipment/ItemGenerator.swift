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

        var guaranteedDefinitions = guaranteedAffixIDs.compactMap { affixID in
            eligibleAffixes.first { $0.id == affixID }
        }
        let droppedGuaranteedIDs = guaranteedAffixIDs.filter { affixID in
            !eligibleAffixes.contains { $0.id == affixID }
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
            }
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
        return baseWeight * (LootTuning.biasWeightBase + overlap)
    }
}

public enum ItemRewardGenerator {
    private struct RewardContext {
        let keywordBias: Set<Keyword>
        let requiredKeyword: Keyword?
        let fallbackBaseType: ItemBaseType?
        let guaranteedAffixIDs: [String]
        let baseTypes: [ItemBaseType]
        let itemGenerator: ItemGenerator
    }

    public static func generate(
        id: String,
        rewardLevel: Int,
        bossContent: Bool = false,
        astralChanceBonusPercent: Int = 0,
        allowedTiers: Set<ItemDropTier> = Set(ItemDropTier.allCases),
        favoredTier: ItemDropTier? = nil,
        tierWeightBonusPercent: Int = 0,
        requiredKeyword: Keyword? = nil,
        ownedTrinketIDs: Set<String>,
        ownedUniqueIDs: Set<String>,
        reservedTrinketIDs: Set<String> = [],
        keywordBias: Set<Keyword> = [],
        eligibleTrinketIDs: Set<String>? = nil,
        eligibleUniqueIDs: Set<String>? = nil,
        fallbackBaseType: ItemBaseType? = nil,
        guaranteedAffixIDs: [String] = [],
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        itemGenerator: ItemGenerator = ItemGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let context = RewardContext(
            keywordBias: keywordBias,
            requiredKeyword: requiredKeyword,
            fallbackBaseType: fallbackBaseType,
            guaranteedAffixIDs: guaranteedAffixIDs,
            baseTypes: baseTypes,
            itemGenerator: itemGenerator,
        )
        let trinkets = GameContent.trinketItems.filter {
            !ownedTrinketIDs.contains($0.templateID)
                && !reservedTrinketIDs.contains($0.templateID)
                && (eligibleTrinketIDs?.contains($0.templateID) ?? true)
                && (keywordBias.isEmpty || !$0.keywords.isDisjoint(with: keywordBias))
        }
        let uniques = GameContent.uniqueItems.filter {
            !ownedUniqueIDs.contains($0.templateID)
                && (eligibleUniqueIDs?.contains($0.templateID) ?? true)
                && (keywordBias.isEmpty || !$0.keywords.isDisjoint(with: keywordBias))
        }
        var available = requiredKeyword == nil ? allowedTiers : allowedTiers.intersection([.basic, .astral])
        if requiredKeyword != nil {
            precondition(!available.isEmpty, "Keyword rewards require Basic or Astral equipment")
        }
        if trinkets.isEmpty {
            available.remove(.trinket)
        }
        if uniques.isEmpty {
            available.remove(.unique)
        }
        if fallbackBaseType == nil, !baseTypes.contains(where: { $0.slot != .trinket }) {
            available.subtract([.basic, .astral])
        }
        if available.isEmpty {
            // Degrade to basic gear instead of trapping: live callers
            // (BattleLoot, ShopOfferGenerator, MysteryEffectApplier via
            // fallbackBaseType) all keep a gear path, so this only fires for
            // exhausted trinket-only pools that previously crashed in
            // ItemLootPolicy.probabilities.
            available = [.basic]
        }
        let probabilities = ItemLootPolicy.probabilities(
            level: rewardLevel,
            bossContent: bossContent,
            astralChanceBonusPercent: astralChanceBonusPercent,
            availableTiers: available,
            favoredTier: favoredTier,
            tierWeightBonusPercent: tierWeightBonusPercent,
        )
        switch ItemLootPolicy.roll(probabilities: probabilities, using: &randomNumberGenerator) {
        case .unique:
            return uniques[Int.random(in: uniques.indices, using: &randomNumberGenerator)]
        case .trinket:
            return trinkets[Int.random(in: trinkets.indices, using: &randomNumberGenerator)]
        case .astral:
            return generated(id: id, rarity: .astral, context: context, using: &randomNumberGenerator)
        case .basic:
            return generated(id: id, rarity: .basic, context: context, using: &randomNumberGenerator)
        }
    }

    private static func generated(
        id: String,
        rarity: Rarity,
        context: RewardContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        // Degraded basic-gear fallback must not trap when the caller passed
        // trinket-only baseTypes with no fallback: use the default gear pool
        // for base selection so the degrade path stays total.
        let effectiveBases = context.baseTypes.contains(where: { $0.slot != .trinket })
            || context.fallbackBaseType != nil
            ? context.baseTypes : GameContent.itemBaseTypes
        let baseType: ItemBaseType
        if let keyword = context.requiredKeyword {
            let candidates = effectiveBases.filter { base in
                base.slot != .trinket && base.keywordAffinities.contains(keyword)
                    && context.itemGenerator.affixDefinitions.contains {
                        $0.weight > 0 && $0.keywords.contains(keyword) && $0.isEligible(for: base)
                    }
            }
            guard let selected = candidates.randomElement(using: &randomNumberGenerator) else {
                preconditionFailure("Required keyword must have a matching equipment pool")
            }
            baseType = selected
        } else {
            baseType = ItemBasePolicy.uniformFallbackBase(
                from: effectiveBases, keywordBias: context.keywordBias, fallback: context.fallbackBaseType,
                using: &randomNumberGenerator,
            )
        }
        return context.itemGenerator.generate(
            id: id,
            templateID: "\(baseType.id)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            keywordBias: context.keywordBias,
            guaranteedAffixIDs: context.guaranteedAffixIDs,
            requiredKeyword: context.requiredKeyword,
            using: &randomNumberGenerator,
        )
    }
}
