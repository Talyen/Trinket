import TrinketCore

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
        var available = requiredKeyword == nil ? allowedTiers : allowedTiers.intersection([.basic, .astral])
        if requiredKeyword != nil {
            precondition(!available.isEmpty, "Keyword rewards require Basic or Astral equipment")
        }
        let trinkets = available.contains(.trinket) ? GameContent.trinketItems.filter {
            !ownedTrinketIDs.contains($0.templateID)
                && !reservedTrinketIDs.contains($0.templateID)
                && (eligibleTrinketIDs?.contains($0.templateID) ?? true)
                && (keywordBias.isEmpty || !$0.keywords.isDisjoint(with: keywordBias))
        } : []
        let uniques = available.contains(.unique) ? GameContent.uniqueItems.filter {
            !ownedUniqueIDs.contains($0.templateID)
                && (eligibleUniqueIDs?.contains($0.templateID) ?? true)
                && (keywordBias.isEmpty || !$0.keywords.isDisjoint(with: keywordBias))
        } : []
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
