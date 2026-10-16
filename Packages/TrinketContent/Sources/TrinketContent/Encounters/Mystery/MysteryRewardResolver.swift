import TrinketCore

/// Mystery reward rules use a captured wallet, party, Homestead, and ownership.
/// Persistence owns encounter admission, pinned payloads, and applying the result.
public struct MysteryRewardResolver: Sendable {
    private let homesteadEffects: HomesteadEffects
    private let ownership: RewardOwnership
    private let inputs: RewardSettlementInputs

    public init(homesteadEffects: HomesteadEffects, ownership: RewardOwnership, inputs: RewardSettlementInputs) {
        self.homesteadEffects = homesteadEffects
        self.ownership = ownership
        self.inputs = inputs
    }

    public static func materialQuantity(forLevel level: Int) -> Int {
        let level = max(1, level)
        // 14/49 reduces to 2/7; split before multiplying to preserve the exact quotient at large depths.
        return 4 + (level / 7) * 2 + ((level % 7) * 2) / 7
    }

    /// Failable by design: choices without an item pool or secondary
    /// reward (leave, corrupt-only, unlock-only) have no offer to resolve.
    /// Callers skip nils instead of trapping so mixed events stay openable.
    public func resolveOffer(
        choice: MysteryChoice,
        encounterID: String,
        encounterLevel: Int,
        rewardLevel: Int,
        bonuses: NodeModifierEffects = .zero,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> MysteryOffer? {
        guard let pool = choice.itemPool,
              let bonusEffect = choice.effects.first(where: { effect in
                  switch effect {
                  case .gainGold, .gainMaterial, .gainExperience: true
                  default: false
                  }
              }),
              let reward = resolveReward(
                  bonusEffect,
                  encounterLevel: encounterLevel,
                  goldPercent: bonuses.goldFoundPercent,
                  experiencePercent: bonuses.experienceEarnedPercent,
                  materialsPercent: bonuses.materialsFoundPercent,
              )
        else {
            return nil
        }
        return MysteryOffer(
            choiceID: choice.id,
            item: generateItem(
                pool: pool,
                rewardLevel: rewardLevel, id: "\(encounterID)-\(choice.id)",
                using: &randomNumberGenerator,
            ),
            bonus: reward.bonus,
            homesteadReward: reward.homestead,
        )
    }

    public func generateItem(
        pool: MysteryItemPool,
        rewardLevel: Int, id: String,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        guard let base = GameContent.itemBaseType(matching: pool.baseTypeID), base.slot != .trinket else {
            preconditionFailure("Mystery item pools require a known gear base")
        }
        return ItemRewardGenerator.generate(
            id: id,
            rewardLevel: rewardLevel,
            astralChanceBonusPercent: homesteadEffects.astralChanceBonusPercent,
            collectibleChancePercent: 50,
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: ownership.ownedUniqueIDs,
            eligibleTrinketIDs: pool.trinketIDs,
            eligibleUniqueIDs: pool.uniqueIDs,
            fallbackBaseType: base,
            guaranteedAffixIDs: pool.guaranteedAffixIDs,
            using: &randomNumberGenerator,
        )
    }

    private func homesteadReward(
        _ effect: MysteryEffect, encounterLevel: Int,
        goldPercent: Int, materialsPercent: Int,
    ) -> HomesteadMysteryReward? {
        switch effect {
        case let .gainGold(amount) where homesteadEffects.goldFindPercent > 0:
            HomesteadMysteryReward(
                resource: .gold, amount: CombatRounding.scaled(amount, byPercent: goldPercent),
                percent: homesteadEffects.goldFindPercent,
            )
        case .gainMaterial(.gems) where homesteadEffects.gemsFindPercent > 0:
            HomesteadMysteryReward(
                resource: .gems,
                amount: CombatRounding.scaled(Self.materialQuantity(forLevel: encounterLevel), byPercent: materialsPercent),
                percent: homesteadEffects.gemsFindPercent,
            )
        default: nil
        }
    }

    public func resolveReward(
        _ effect: MysteryEffect,
        encounterLevel: Int,
        goldPercent: Int,
        experiencePercent: Int,
        materialsPercent: Int,
    ) -> (bonus: MysteryRewardBonus, homestead: HomesteadMysteryReward?)? {
        let reward = homesteadReward(
            effect, encounterLevel: encounterLevel,
            goldPercent: goldPercent, materialsPercent: materialsPercent,
        )
        if let reward {
            var remainders = inputs.rewardRemainders
            return (reward.resolve(remainders: &remainders), reward)
        }
        let bonus: MysteryRewardBonus
        switch effect {
        case let .gainGold(amount):
            bonus = .gold(SaturatedArithmetic.saturatingAdd(
                CombatRounding.scaled(amount, byPercent: SaturatedArithmetic.saturatingAdd(
                    goldPercent, homesteadEffects.goldFindPercent,
                )),
                amount > 0 ? homesteadEffects.goldFindFlat : 0,
            ))
        case let .gainMaterial(resource):
            bonus = .material(
                resource,
                SaturatedArithmetic.saturatingAdd(
                    CombatRounding.scaled(Self.materialQuantity(forLevel: encounterLevel), byPercent: materialsPercent),
                    resource == .gems ? homesteadEffects.gemsFindBonus : 0,
                ),
            )
        case .gainExperience:
            bonus = .experience(SaturatedArithmetic.saturatingAdd(
                RewardExperiencePolicy.encounterAward(
                    encounterLevel: encounterLevel,
                    hero: inputs.heroProgression, companion: inputs.companionProgression,
                    percent: SaturatedArithmetic.saturatingAdd(experiencePercent, homesteadEffects.experienceBonusPercent),
                ),
                homesteadEffects.experienceBonus,
            ))
        default:
            return nil
        }
        return (bonus, nil)
    }

    /// Resolves receivable bonuses for offer preparation and claim validation.
    /// Direct effects use the same wallet-cap replacement and shared-XP limits.
    public func settledBonus(
        _ bonus: MysteryRewardBonus,
        encounterLevel: Int,
        experiencePercent: Int = 0,
    ) -> MysteryRewardBonus {
        RewardSettlementPolicy.settle(
            bonus,
            inputs: inputs,
            replacementExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel,
                hero: inputs.heroProgression, companion: inputs.companionProgression,
                percent: experiencePercent,
            ),
        )
    }

    public func hasCurrentHomesteadReward(_ offer: MysteryOffer) -> Bool {
        guard let reward = offer.homesteadReward else { return true }
        var remainders = inputs.rewardRemainders
        switch (reward.resolve(remainders: &remainders), offer.bonus) {
        case let (.gold(current), .gold(pinned)): return current == pinned
        case let (.gold(current), .goldAndExperience(_, _, nominalGold, _)): return current == nominalGold
        case let (.material(resource, current), .material(pinnedResource, pinned)):
            return resource == pinnedResource && current == pinned
        case (.gold, .experience): return true
        default: return false
        }
    }
}
