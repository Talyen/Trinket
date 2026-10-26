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
        collectibleChancePercent: Int = 100,
        wishedTemplateID: String? = nil,
        requiredKeyword: Keyword? = nil,
        ownedTrinketIDs: Set<String>,
        ownedUniqueIDs: Set<String>,
        reservedTrinketIDs: Set<String> = [],
        keywordBias: Set<Keyword> = [],
        partyBias: PartyLootBias = PartyLootBias(),
        eligibleTrinketIDs: Set<String>? = nil,
        eligibleUniqueIDs: Set<String>? = nil,
        fallbackBaseType: ItemBaseType? = nil,
        guaranteedAffixIDs: [String] = [],
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        itemGenerator: ItemGenerator = ItemGenerator(),
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        let availability = rewardAvailability(
            allowedTiers: allowedTiers, requiredKeyword: requiredKeyword,
            ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs,
            reservedTrinketIDs: reservedTrinketIDs, keywordBias: keywordBias,
            eligibleTrinketIDs: eligibleTrinketIDs, eligibleUniqueIDs: eligibleUniqueIDs,
            fallbackBaseType: fallbackBaseType, baseTypes: baseTypes,
        )
        let probabilities = ItemLootPolicy.probabilities(
            level: rewardLevel,
            bossContent: bossContent,
            astralChanceBonusPercent: astralChanceBonusPercent,
            availableTiers: availability.tiers,
            favoredTier: favoredTier,
            tierWeightBonusPercent: tierWeightBonusPercent, collectibleChancePercent: collectibleChancePercent,
        )
        let tier = ItemLootPolicy.roll(probabilities: probabilities, using: &randomNumberGenerator)
        let rarity: Rarity
        switch tier {
        case .unique, .trinket:
            return ItemWish.select(
                from: tier == .unique ? availability.uniques : availability.trinkets,
                wishedTemplateID: wishedTemplateID,
                partyBias: partyBias,
                using: &randomNumberGenerator,
            )
        case .astral: rarity = .astral
        case .basic: rarity = .basic
        }
        let baseType = rewardBaseType(
            baseTypes: availability.hasGearPool ? baseTypes : GameContent.itemBaseTypes, fallbackBaseType: fallbackBaseType,
            requiredKeyword: requiredKeyword, keywordBias: keywordBias,
            itemGenerator: itemGenerator, using: &randomNumberGenerator,
        )
        // A keyword with no eligible base or affix was already degraded to
        // unbiased gear; don't hand the unsatisfiable requirement downstream.
        let effectiveKeyword = requiredKeyword.flatMap {
            Self.supportsKeyword($0, base: baseType, itemGenerator: itemGenerator) ? $0 : nil
        }
        return itemGenerator.generate(
            id: id,
            templateID: "\(baseType.id)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            keywordBias: keywordBias,
            partyBias: partyBias,
            guaranteedAffixIDs: guaranteedAffixIDs,
            requiredKeyword: effectiveKeyword,
            using: &randomNumberGenerator,
        )
    }

    private struct RewardAvailability {
        let tiers: Set<ItemDropTier>
        let trinkets: [InventoryItem]
        let uniques: [InventoryItem]
        let hasGearPool: Bool
    }

    // swiftlint:disable:next function_parameter_count - the tier, ownership, eligibility, and gear inputs must stay together so pool degradation reads as one policy
    private static func rewardAvailability(
        allowedTiers: Set<ItemDropTier>,
        requiredKeyword: Keyword?,
        ownedTrinketIDs: Set<String>,
        ownedUniqueIDs: Set<String>,
        reservedTrinketIDs: Set<String>,
        keywordBias: Set<Keyword>,
        eligibleTrinketIDs: Set<String>?,
        eligibleUniqueIDs: Set<String>?,
        fallbackBaseType: ItemBaseType?,
        baseTypes: [ItemBaseType],
    ) -> RewardAvailability {
        var available = requiredKeyword == nil ? allowedTiers : allowedTiers.intersection([.basic, .astral])
        if requiredKeyword != nil, available.isEmpty {
            // A keyword request against a collectible-only pool degrades to
            // gear instead of trapping; the keyword is dropped below.
            available = [.basic, .astral]
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
        let hasGearPool = fallbackBaseType != nil || baseTypes.contains(where: { $0.slot != .trinket })
        if !hasGearPool {
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
        return RewardAvailability(tiers: available, trinkets: trinkets, uniques: uniques, hasGearPool: hasGearPool)
    }

    private static func supportsKeyword(
        _ keyword: Keyword,
        base: ItemBaseType,
        itemGenerator: ItemGenerator,
    ) -> Bool {
        base.slot != .trinket && base.keywordAffinities.contains(keyword)
            && itemGenerator.affixDefinitions.contains {
                $0.weight > 0 && $0.keywords.contains(keyword) && $0.isEligible(for: base)
            }
    }

    private static func rewardBaseType(
        baseTypes: [ItemBaseType],
        fallbackBaseType: ItemBaseType?,
        requiredKeyword: Keyword?,
        keywordBias: Set<Keyword>,
        itemGenerator: ItemGenerator,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemBaseType {
        if let keyword = requiredKeyword {
            func supports(_ base: ItemBaseType) -> Bool {
                Self.supportsKeyword(keyword, base: base, itemGenerator: itemGenerator)
            }
            if let selected = baseTypes.filter(supports).randomElement(using: &randomNumberGenerator) {
                return selected
            }
            if let fallback = fallbackBaseType, supports(fallback) {
                return fallback
            }
            if let selected = GameContent.itemBaseTypes.filter(supports).randomElement(using: &randomNumberGenerator) {
                return selected
            }
            // Content drift: no base supports the keyword. Fall through to
            // unbiased gear below instead of trapping the live reward.
        }
        // A trinket fallback cannot satisfy a gear roll: it has no eligible
        // affixes, so it would generate a 0-affix item. Fall through to the
        // gear pool instead.
        let normalBases = fallbackBaseType.flatMap { $0.slot != .trinket ? $0 : nil }.map { [$0] }
            ?? baseTypes.filter { $0.slot != .trinket }
        let effectiveBases = normalBases.isEmpty
            ? GameContent.itemBaseTypes.filter { $0.slot != .trinket }
            : normalBases
        // Catalog invariant: at least one gear base ships with the game.
        precondition(!effectiveBases.isEmpty, "Item rewards require at least one non-Trinket base type.")
        let biasedBases = keywordBias.isEmpty
            ? effectiveBases
            : effectiveBases.filter { !$0.keywordAffinities.isDisjoint(with: keywordBias) }
        let pool = biasedBases.isEmpty ? effectiveBases : biasedBases
        return pool.randomElement(using: &randomNumberGenerator) ?? effectiveBases[0]
    }
}
