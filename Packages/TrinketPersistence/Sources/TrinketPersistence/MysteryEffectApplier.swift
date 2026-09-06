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

    public static func experienceAward(
        encounterLevel: Int,
        roster: PlayerRosterState,
        percent: Int = 0,
    ) -> Int {
        let base = ExperienceScaling.baseBattleAward(forPlayerLevel: max(1, encounterLevel))
        return sharedExperience(CombatRounding.scaled(base, byPercent: percent), roster: roster)
    }

    public static func resolvedEncounterLevel(
        stage: Stage,
        labyrinthNodeID: String?,
        save: PlayerSave,
    ) -> Int {
        StageCompletion.partyAdjustedEncounterLevel(
            for: stage,
            labyrinthNodeID: labyrinthNodeID,
            save: save,
        )
    }

    public static func resolveOffer(
        choice: MysteryChoice,
        encounterID: String,
        encounterLevel: Int,
        save: PlayerSave,
        bonuses: LabyrinthModifierEffects = .zero,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> MysteryOffer {
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
            preconditionFailure("Ordinary Mystery choices require an item pool and a secondary reward")
        }
        return MysteryOffer(
            choiceID: choice.id,
            item: generateItem(
                pool: pool,
                id: "\(encounterID)-\(choice.id)",
                save: save,
                using: &randomNumberGenerator,
            ),
            bonus: bonus,
        )
    }

    public static func apply(_ offer: MysteryOffer, save: inout PlayerSave, at date: Date = Date()) -> MysteryEffectResult {
        guard isAvailable(offer.item, in: save.inventory) else { return MysteryEffectResult() }
        var result = MysteryEffectResult()
        append(offer.item, save: &save, result: &result)
        apply(offer.bonus, save: &save, result: &result, at: date)
        return result
    }

    public static func apply(
        _ effects: [MysteryEffect],
        stageID: String,
        choiceID: String,
        encounterLevel: Int,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        goldFoundPercent: Int = 0,
        experienceEarnedPercent: Int = 0,
        materialsFoundPercent: Int = 0,
    ) -> MysteryEffectResult {
        var result = MysteryEffectResult()
        for effect in effects {
            switch effect {
            case let .gainItem(pool):
                let item = generateItem(
                    pool: pool,
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
                    apply(bonus, save: &save, result: &result)
                }
            case .corruptItem, .leave:
                break
            }
        }
        return result
    }

    static func isAvailable(_ item: InventoryItem, in inventory: PlayerInventoryState) -> Bool {
        if item.isTrinket {
            return !inventory.ownedTrinketIDs.contains(item.templateID)
        }
        if item.rarity == .unique {
            return !inventory.ownedUniqueIDs.contains(item.templateID)
        }
        return !inventory.items.contains { $0.id == item.id }
    }

    static func sharedExperience(_ amount: Int, roster: PlayerRosterState) -> Int {
        min(
            ExperienceScaling.cappedAward(amount, for: roster.progression(for: roster.activeHero)),
            ExperienceScaling.cappedAward(amount, for: roster.progression(for: roster.activeCompanion)),
        )
    }

    private static func generateItem(
        pool: MysteryItemPool,
        id: String,
        save: PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem {
        guard let base = GameContent.itemBaseType(matching: pool.baseTypeID), base.slot != .trinket else {
            preconditionFailure("Mystery item pools require a known gear base")
        }
        let tier = MysteryItemRarity.roll(
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
            using: &randomNumberGenerator,
        )
        return ItemRewardGenerator.generate(
            id: id,
            tier: tier,
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
            .gold(CombatRounding.scaled(amount, byPercent: goldPercent + save.homestead.effects.goldFindPercent))
        case let .gainMaterial(resource):
            .material(resource, CombatRounding.scaled(materialQuantity(forLevel: encounterLevel), byPercent: materialsPercent))
        case .gainExperience:
            .experience(experienceAward(encounterLevel: encounterLevel, roster: save.roster, percent: experiencePercent))
        default:
            nil
        }
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
        case let .material(resource, amount):
            result.grantedMaterials += save.grantMaterials([ResourceAmount(resource, amount)], at: date)
        case let .experience(amount):
            let hero = save.roster.activeHero
            let companion = save.roster.activeCompanion
            let award = sharedExperience(amount, roster: save.roster)
            result.heroProgressionBefore = save.roster.progression(for: hero)
            result.companionProgressionBefore = save.roster.progression(for: companion)
            result.heroGrantedExperience += save.roster.grantExperience(award, to: hero)
            result.companionGrantedExperience += save.roster.grantExperience(award, to: companion)
            result.heroProgressionAfter = save.roster.progression(for: hero)
            result.companionProgressionAfter = save.roster.progression(for: companion)
        }
    }
}
