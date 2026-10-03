import TrinketCore

public enum ItemRewardGenerator {
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
        let rarity: Rarity
        switch ItemLootPolicy.roll(probabilities: probabilities, using: &randomNumberGenerator) {
        case .unique:
            return uniques[Int.random(in: uniques.indices, using: &randomNumberGenerator)]
        case .trinket:
            return trinkets[Int.random(in: trinkets.indices, using: &randomNumberGenerator)]
        case .astral: rarity = .astral
        case .basic: rarity = .basic
        }
        let baseType = rewardBaseType(
            baseTypes: baseTypes, fallbackBaseType: fallbackBaseType,
            requiredKeyword: requiredKeyword, keywordBias: keywordBias,
            itemGenerator: itemGenerator, using: &randomNumberGenerator,
        )
        return itemGenerator.generate(
            id: id,
            templateID: "\(baseType.id)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            keywordBias: keywordBias,
            guaranteedAffixIDs: guaranteedAffixIDs,
            requiredKeyword: requiredKeyword,
            using: &randomNumberGenerator,
        )
    }

    private static func rewardBaseType(
        baseTypes: [ItemBaseType],
        fallbackBaseType: ItemBaseType?,
        requiredKeyword: Keyword?,
        keywordBias: Set<Keyword>,
        itemGenerator: ItemGenerator,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType {
        // Degraded basic-gear fallback must not trap when the caller passed
        // trinket-only baseTypes with no fallback: use the default gear pool
        // for base selection so the degrade path stays total.
        let effectiveBases = baseTypes.contains(where: { $0.slot != .trinket })
            || fallbackBaseType != nil
            ? baseTypes : GameContent.itemBaseTypes
        let baseType: ItemBaseType
        if let keyword = requiredKeyword {
            let candidates = effectiveBases.filter { base in
                base.slot != .trinket && base.keywordAffinities.contains(keyword)
                    && itemGenerator.affixDefinitions.contains {
                        $0.weight > 0 && $0.keywords.contains(keyword) && $0.isEligible(for: base)
                    }
            }
            guard let selected = candidates.randomElement(using: &randomNumberGenerator) else {
                preconditionFailure("Required keyword must have a matching equipment pool")
            }
            baseType = selected
        } else {
            baseType = ItemBasePolicy.uniformFallbackBase(
                from: effectiveBases, keywordBias: keywordBias, fallback: fallbackBaseType,
                using: &randomNumberGenerator,
            )
        }
        return baseType
    }
}
