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

public enum MysteryEventPinApplier {
    @discardableResult
    public static func pinLabyrinthEvent(
        nodeID: String,
        eventID: String,
        save: inout PlayerSave,
    ) -> Bool {
        guard var node = save.labyrinth.nodes[nodeID] else { return false }
        guard node.mysteryEventID == nil else { return true }
        node.mysteryEventID = eventID
        save.labyrinth.nodes[nodeID] = node
        return true
    }

    @discardableResult
    public static func pinJourneyEvent(
        stageID: String,
        eventID: String,
        save: inout PlayerSave,
    ) -> Bool {
        guard save.journey.pinnedMysteryEventIDs[stageID] == nil else { return true }
        save.journey.pinnedMysteryEventIDs[stageID] = eventID
        return true
    }
}

public enum MysteryEffectApplier {
    public static func materialQuantity(forLevel level: Int) -> Int {
        4 + (max(1, level) * 14) / 49
    }

    public static func resolvedEncounterLevel(
        stage: Stage,
        labyrinthNodeID: String?,
        save: PlayerSave,
    ) -> Int {
        if let labyrinthNodeID, let node = save.labyrinth.nodes[labyrinthNodeID] {
            return EncounterLevelResolver.labyrinthAdjusted(
                EncounterLevelResolver.labyrinthEnemyLevel(for: node),
                partyAverageLevel: save.roster.activePartyAverageLevel,
            )
        }
        return StageCompletion.partyAdjustedEncounterLevel(
            for: stage,
            save: save,
        )
    }

    /// Failable by design: choices without an item pool or secondary
    /// reward (leave, corrupt-only, unlock-only) have no offer to resolve.
    /// Callers skip nils instead of trapping so mixed events stay openable.
    public static func resolveOffer(
        choice: MysteryChoice,
        encounterID: String,
        encounterLevel: Int,
        rewardLevel: Int,
        save: PlayerSave,
        bonuses: LabyrinthModifierEffects = .zero,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> MysteryOffer? {
        guard let pool = choice.itemPool,
              let bonusEffect = choice.effects.first(where: { effect in
                  switch effect {
                  case .gainGold, .gainMaterial, .gainExperience: true
                  default: false
                  }
              }),
              let bonus = resolveBonus(
                  bonusEffect,
                  encounterLevel: encounterLevel,
                  save: save,
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
                save: save,
                using: &randomNumberGenerator,
            ),
            bonus: bonus,
        )
    }

    /// Applies the prepared offer, converting any additional Gold overflow at claim.
    public static func apply(
        _ offer: MysteryOffer, save: inout PlayerSave, at date: Date = Date(),
        goldOverflowExperience: Int = 0, allowOwnedItem: Bool = false,
    ) -> MysteryEffectResult {
        guard allowOwnedItem || isAvailable(offer.item, in: save.inventory) else { return MysteryEffectResult() }
        var result = MysteryEffectResult()
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
        save.homestead.settleProduction(at: grantDate, roster: save.roster)
        var result = MysteryEffectResult()
        for effect in effects {
            switch effect {
            case let .gainItem(pool):
                let item = generateItem(
                    pool: pool,
                    rewardLevel: rewardLevel,
                    id: "\(stageID)-\(choiceID)-\(result.grantedItems.count)",
                    save: save,
                    using: &randomNumberGenerator,
                )
                append(item, save: &save, result: &result)
            case let .unlockCombatant(id):
                if save.roster.unlockCombatant(id: id) {
                    result.unlockedCombatantIDs.append(id)
                }
            case .gainGold, .gainMaterial, .gainExperience:
                if let bonus = resolveBonus(
                    effect,
                    encounterLevel: encounterLevel,
                    save: save,
                    goldPercent: goldFoundPercent,
                    experiencePercent: experienceEarnedPercent,
                    materialsPercent: materialsFoundPercent,
                ) {
                    let settled = settledBonus(
                        bonus,
                        encounterLevel: encounterLevel,
                        save: save,
                        experiencePercent: experienceEarnedPercent,
                        at: grantDate,
                    )
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

    private static func generateItem(
        pool: MysteryItemPool,
        rewardLevel: Int, id: String,
        save: PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        guard let base = GameContent.itemBaseType(matching: pool.baseTypeID), base.slot != .trinket else {
            preconditionFailure("Mystery item pools require a known gear base")
        }
        return ItemRewardGenerator.generate(
            id: id,
            rewardLevel: rewardLevel,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            ownedTrinketIDs: save.inventory.ownedTrinketIDs,
            ownedUniqueIDs: save.inventory.ownedUniqueIDs,
            eligibleTrinketIDs: pool.trinketIDs,
            eligibleUniqueIDs: pool.uniqueIDs,
            fallbackBaseType: base,
            guaranteedAffixIDs: pool.guaranteedAffixIDs,
            using: &randomNumberGenerator,
        )
    }

    private static func resolveBonus(
        _ effect: MysteryEffect,
        encounterLevel: Int,
        save: PlayerSave,
        goldPercent: Int,
        experiencePercent: Int,
        materialsPercent: Int,
    ) -> MysteryRewardBonus? {
        switch effect {
        case let .gainGold(amount):
            .gold(CombatRounding
                .scaled(amount, byPercent: goldPercent + save.homestead.effects.goldFindPercent) +
                (amount > 0 ? save.homestead.effects.goldFindFlat : 0))
        case let .gainMaterial(resource):
            .material(
                resource,
                CombatRounding
                    .scaled(materialQuantity(forLevel: encounterLevel), byPercent: materialsPercent) +
                    (resource == .gems ? save.homestead.effects.gemsFindBonus : 0),
            )
        case .gainExperience:
            .experience(RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel,
                roster: save.roster,
                percent: experiencePercent,
            ) + save.homestead.effects.experienceBonus)
        default:
            nil
        }
    }

    /// Resolves receivable bonuses for offer preparation and claim validation.
    /// Direct effects use the same wallet-cap replacement and shared-XP limits.
    static func settledBonus(
        _ bonus: MysteryRewardBonus,
        encounterLevel: Int,
        save: PlayerSave,
        experiencePercent: Int = 0,
        at date: Date,
    ) -> MysteryRewardBonus {
        RewardSettlementPolicy.settle(
            bonus,
            inputs: RewardSettlementInputs(
                save: save,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                at: date,
            ),
            replacementExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: encounterLevel,
                roster: save.roster,
                percent: experiencePercent,
            ),
        )
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
            result.heroProgressionBefore = save.roster.progression(for: hero)
            result.companionProgressionBefore = save.roster.progression(for: companion)
            result.heroGrantedExperience += save.roster.grantExperience(award, to: hero)
            result.companionGrantedExperience += save.roster.grantExperience(award, to: companion)
            result.heroProgressionAfter = save.roster.progression(for: hero)
            result.companionProgressionAfter = save.roster.progression(for: companion)
        }
    }
}
