import Foundation
import TrinketContent
import TrinketCore

public struct MysteryEffectResult: Equatable, Sendable {
    public var grantedGold: Int
    public var grantedMaterials: [ResourceAmount]
    public var heroGrantedExperience: Int
    public var companionGrantedExperience: Int
    public var heroProgressionBefore: CombatantProgression?
    public var heroProgressionAfter: CombatantProgression?
    public var companionProgressionBefore: CombatantProgression?
    public var companionProgressionAfter: CombatantProgression?
    public var grantedItems: [InventoryItem]
    public var unlockedCombatantIDs: [String]

    public init(
        grantedGold: Int = 0,
        grantedMaterials: [ResourceAmount] = [],
        heroGrantedExperience: Int = 0,
        companionGrantedExperience: Int = 0,
        heroProgressionBefore: CombatantProgression? = nil,
        heroProgressionAfter: CombatantProgression? = nil,
        companionProgressionBefore: CombatantProgression? = nil,
        companionProgressionAfter: CombatantProgression? = nil,
        grantedItems: [InventoryItem] = [],
        unlockedCombatantIDs: [String] = [],
    ) {
        self.grantedGold = grantedGold
        self.grantedMaterials = grantedMaterials
        self.heroGrantedExperience = heroGrantedExperience
        self.companionGrantedExperience = companionGrantedExperience
        self.heroProgressionBefore = heroProgressionBefore
        self.heroProgressionAfter = heroProgressionAfter
        self.companionProgressionBefore = companionProgressionBefore
        self.companionProgressionAfter = companionProgressionAfter
        self.grantedItems = grantedItems
        self.unlockedCombatantIDs = unlockedCombatantIDs
    }

    public var hasGrantedExperience: Bool {
        heroGrantedExperience > 0 || companionGrantedExperience > 0
    }

    public var isEmpty: Bool {
        grantedGold == 0
            && grantedMaterials.isEmpty
            && !hasGrantedExperience
            && grantedItems.isEmpty
            && unlockedCombatantIDs.isEmpty
    }
}

public enum MysteryEffectApplier {
    /// Applies the prepared offer, converting any additional Gold overflow at claim.
    public static func apply(
        _ offer: MysteryOffer, save: inout PlayerSave, at date: Date = Date(),
        goldOverflowExperience: Int = 0, allowOwnedItem: Bool = false,
    ) -> MysteryEffectResult {
        guard allowOwnedItem || isAvailable(offer.item, in: save.inventory),
              MysteryRewardResolver(save: save, at: date).hasCurrentHomesteadReward(offer) else { return MysteryEffectResult() }
        var result = MysteryEffectResult()
        consumeHomesteadReward(offer.homesteadReward, save: &save)
        append(offer.item, save: &save, result: &result)
        switch offer.bonus {
        case let .gold(amount):
            applyPinnedGold(
                amount, pinnedExperience: 0, nominalGold: amount,
                fullOverflowExperience: goldOverflowExperience,
                save: &save, result: &result, at: date,
            )
        case let .goldAndExperience(gold, experience, nominalGold, fullOverflowExperience):
            applyPinnedGold(
                gold, pinnedExperience: experience, nominalGold: nominalGold,
                fullOverflowExperience: fullOverflowExperience,
                save: &save, result: &result, at: date,
            )
        default:
            apply(offer.bonus, save: &save, result: &result, at: date)
        }
        return result
    }

    private static func applyPinnedGold(
        _ amount: Int, pinnedExperience: Int, nominalGold: Int, fullOverflowExperience: Int,
        save: inout PlayerSave, result: inout MysteryEffectResult, at date: Date,
    ) {
        let granted = save.grantGold(amount, at: date)
        result.grantedGold = SaturatedArithmetic.saturatingAdd(result.grantedGold, granted)
        let converted = RewardSettlementPolicy.overflowExperience(
            fullOverflowExperience, overflow: max(0, amount - granted), gains: nominalGold,
        )
        let experience = SaturatedArithmetic.saturatingAdd(pinnedExperience, converted)
        if experience > 0 {
            apply(.experience(experience), save: &save, result: &result, at: date)
        }
    }

    static func apply(
        _ effects: [MysteryEffect],
        stageID: String,
        choiceID: String,
        encounterLevel: Int,
        rewardLevel: Int,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        goldFoundPercent: Int = 0,
        experienceEarnedPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        at grantDate: Date = Date(),
    ) -> MysteryEffectResult {
        save.homestead.settleProduction(at: grantDate, gold: save.roster.gold)
        var result = MysteryEffectResult()
        for effect in effects {
            let resolver = MysteryRewardResolver(save: save, at: grantDate)
            switch effect {
            case let .gainItem(pool):
                let item = resolver.generateItem(
                    pool: pool,
                    rewardLevel: rewardLevel,
                    id: "\(stageID)-\(choiceID)-\(result.grantedItems.count)",
                    using: &randomNumberGenerator,
                )
                append(item, save: &save, result: &result)
            case let .unlockCombatant(id):
                if save.roster.unlockCombatant(id: id) {
                    result.unlockedCombatantIDs.append(id)
                }
            case .gainGold, .gainMaterial, .gainExperience:
                if let reward = resolver.resolveReward(
                    effect,
                    encounterLevel: encounterLevel,
                    goldPercent: goldFoundPercent,
                    experiencePercent: experienceEarnedPercent,
                    materialsPercent: materialsFoundPercent,
                ) {
                    let settled = resolver.settledBonus(
                        reward.bonus,
                        encounterLevel: encounterLevel,
                        experiencePercent: experienceEarnedPercent,
                    )
                    consumeHomesteadReward(reward.homestead, save: &save)
                    apply(settled, save: &save, result: &result, at: grantDate)
                }
            case .corruptItem, .leave:
                break
            }
        }
        return result
    }

    static func isAvailable(_ item: InventoryItem, in inventory: PlayerInventoryState) -> Bool {
        !InventoryDuplicatePolicy.containsDuplicate(of: item, in: inventory.items)
    }

    private static func consumeHomesteadReward(_ reward: HomesteadMysteryReward?, save: inout PlayerSave) {
        guard let reward else { return }
        var remainders = save.homestead.rewardRemainders ?? .zero
        _ = reward.resolve(remainders: &remainders)
        save.homestead.rewardRemainders = remainders == .zero ? nil : remainders
    }

    private static func append(_ item: InventoryItem, save: inout PlayerSave, result: inout MysteryEffectResult) {
        guard isAvailable(item, in: save.inventory) else { return }
        save.inventory.appendUniqueItem(item)
        result.grantedItems.append(item)
    }

    private static func apply(
        _ bonus: MysteryRewardBonus,
        save: inout PlayerSave,
        result: inout MysteryEffectResult,
        at date: Date = Date(),
    ) {
        switch bonus {
        case let .gold(amount):
            result.grantedGold += save.grantGold(amount, at: date)
        case let .goldAndExperience(gold, experience, _, _):
            result.grantedGold += save.grantGold(gold, at: date)
            apply(.experience(experience), save: &save, result: &result, at: date)
        case let .material(resource, amount):
            result.grantedMaterials += save.grantMaterials([ResourceAmount(resource, amount)], at: date)
        case let .experience(amount):
            let hero = save.roster.activeHero
            let companion = save.roster.activeCompanion
            let award = RewardExperiencePolicy.sharedAward(amount, roster: save.roster)
            result.heroProgressionBefore = result.heroProgressionBefore ?? save.roster.progression(for: hero)
            result.companionProgressionBefore = result.companionProgressionBefore ?? save.roster.progression(for: companion)
            result.heroGrantedExperience += save.roster.grantExperience(award, to: hero)
            result.companionGrantedExperience += save.roster.grantExperience(award, to: companion)
            result.heroProgressionAfter = save.roster.progression(for: hero)
            result.companionProgressionAfter = save.roster.progression(for: companion)
        }
    }
}
