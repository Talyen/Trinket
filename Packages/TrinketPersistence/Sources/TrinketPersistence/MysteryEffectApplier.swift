import Foundation
import TrinketContent
import TrinketCore

public struct MysteryEffectApplyResult: Equatable, Sendable {
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
    public static func materialQuantity(forLevel level: Int) -> Int {
        let clamped = max(1, level)
        return 4 + (clamped * 14) / 49
    }

    public static func experienceAward(
        for progression: CombatantProgression,
        highestLevel: Int,
    ) -> Int {
        ExperienceScaling.cappedAward(
            ExperienceScaling.equalBattleAward(
                playerLevel: progression.level,
                highestLevel: highestLevel,
            ),
            for: progression,
        )
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

    public static func apply(
        _ effects: [MysteryEffect],
        stageID: String,
        choiceID: String,
        encounterLevel: Int,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        itemGenerator: ItemGenerator = ItemGenerator(),
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes,
        goldFoundPercent: Int = 0,
        experienceEarnedPercent: Int = 0,
        materialsFoundPercent: Int = 0,
    ) -> MysteryEffectApplyResult {
        var state = ApplyState(
            materialQuantity: scaledQuantity(materialQuantity(forLevel: encounterLevel), percent: materialsFoundPercent),
            goldFoundPercent: goldFoundPercent,
            experienceEarnedPercent: experienceEarnedPercent,
        )
        let hero = save.roster.activeHero
        let companion = save.roster.activeCompanion
        let heroProgressionBefore = save.roster.progression(for: hero)
        let companionProgressionBefore = save.roster.progression(for: companion)
        let itemContext = GeneratedItemContext(
            stageID: stageID,
            choiceID: choiceID,
            itemGenerator: itemGenerator,
            baseTypes: baseTypes,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
        )

        for effect in effects {
            apply(
                effect,
                hero: hero,
                companion: companion,
                save: &save,
                state: &state,
                itemContext: itemContext,
                using: &randomNumberGenerator,
            )
        }
        return finalize(
            &state,
            save: &save,
            hero: hero,
            companion: companion,
            heroProgressionBefore: heroProgressionBefore,
            companionProgressionBefore: companionProgressionBefore,
        )
    }

    private static func finalize(
        _ state: inout ApplyState,
        save: inout PlayerSave,
        hero: Combatant,
        companion: Combatant,
        heroProgressionBefore: CombatantProgression,
        companionProgressionBefore: CombatantProgression,
    ) -> MysteryEffectApplyResult {
        let materials = state.materialTotals.map { ResourceAmount($0.key, $0.value) }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }
        if !materials.isEmpty {
            state.result.grantedMaterials = save.grantMaterials(materials)
        }
        if state.result.hasGrantedExperience {
            state.result.heroProgressionBefore = heroProgressionBefore
            state.result.heroProgressionAfter = save.roster.progression(for: hero)
            state.result.companionProgressionBefore = companionProgressionBefore
            state.result.companionProgressionAfter = save.roster.progression(for: companion)
        }
        return state.result
    }

    private struct GeneratedItemContext {
        let stageID: String
        let choiceID: String
        let itemGenerator: ItemGenerator
        let baseTypes: [ItemBaseType]
        let astralChanceBonusPercent: Int

        var eligibleTrinketIDs: Set<String> {
            GameContent.themedTrinketIDs(forMysteryChoiceID: choiceID) ?? []
        }
    }

    private struct ApplyState {
        var result = MysteryEffectApplyResult()
        var materialTotals: [HomesteadResource: Int] = [:]
        var itemOrdinal = 0
        let materialQuantity: Int
        let goldFoundPercent: Int
        let experienceEarnedPercent: Int
    }

    private static func scaledQuantity(_ quantity: Int, percent: Int) -> Int {
        CombatRounding.scaled(quantity, byPercent: percent)
    }

    private static func scaledAward(
        for progression: CombatantProgression,
        highestLevel: Int,
        percent: Int,
    ) -> Int {
        scaledQuantity(experienceAward(for: progression, highestLevel: highestLevel), percent: percent)
    }

    private static func apply(
        _ effect: MysteryEffect,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
        state: inout ApplyState,
        itemContext: GeneratedItemContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) {
        let ownership = RewardOwnership(
            save.inventory,
            eligibleTrinketIDs: itemContext.eligibleTrinketIDs,
        )
        switch effect {
        case let .gainGold(amount):
            guard amount > 0 else { return }
            let scaled = scaledQuantity(amount, percent: state.goldFoundPercent)
            state.result.grantedGold += save.grantGold(save.homestead.effects.adjustedGold(scaled))

        case let .gainMaterial(resource):
            guard resource != .gold else { return }
            state.materialTotals[resource, default: 0] += state.materialQuantity

        case .gainExperience:
            let heroAward = scaledAward(
                for: save.roster.progression(for: hero),
                highestLevel: save.roster.highestHeroLevel,
                percent: state.experienceEarnedPercent,
            )
            let companionAward = scaledAward(
                for: save.roster.progression(for: companion),
                highestLevel: save.roster.highestCompanionLevel,
                percent: state.experienceEarnedPercent,
            )
            state.result.heroGrantedExperience += save.roster.grantExperience(heroAward, to: hero)
            state.result.companionGrantedExperience += save.roster.grantExperience(
                companionAward,
                to: companion,
            )

        case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs):
            appendThemedItem(
                baseTypeID: baseTypeID,
                guaranteedAffixIDs: guaranteedAffixIDs,
                ownership: ownership,
                state: &state,
                save: &save,
                itemContext: itemContext,
                using: &randomNumberGenerator,
            )

        case .gainRandomItem:
            guard let baseType = itemContext.baseTypes
                .filter({ $0.slot != .trinket })
                .randomElement(using: &randomNumberGenerator) else {
                return
            }
            appendThemedItem(
                baseTypeID: baseType.id,
                guaranteedAffixIDs: [],
                ownership: ownership,
                state: &state,
                save: &save,
                itemContext: itemContext,
                using: &randomNumberGenerator,
            )

        case let .unlockCombatant(combatantID):
            applyUnlock(combatantID, save: &save, result: &state.result)

        case .corruptItem, .leave:
            break
        }
    }

    private static func appendThemedItem(
        baseTypeID: String,
        guaranteedAffixIDs: [String],
        ownership: RewardOwnership,
        state: inout ApplyState,
        save: inout PlayerSave,
        itemContext: GeneratedItemContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) {
        guard let item = makeGeneratedItem(
            baseTypeID: baseTypeID,
            guaranteedAffixIDs: guaranteedAffixIDs,
            ordinal: state.itemOrdinal,
            context: itemContext,
            ownership: ownership,
            using: &randomNumberGenerator,
        ) else {
            return
        }
        appendGeneratedItem(item, to: &save, state: &state)
    }

    private static func applyUnlock(
        _ combatantID: String,
        save: inout PlayerSave,
        result: inout MysteryEffectApplyResult,
    ) {
        let didUnlock: Bool = if GameContent.heroes.contains(where: { $0.id == combatantID }) {
            save.roster.unlockHero(id: combatantID)
        } else if GameContent.companions.contains(where: { $0.id == combatantID }) {
            save.roster.unlockCompanion(id: combatantID)
        } else {
            false
        }
        if didUnlock {
            result.unlockedCombatantIDs.append(combatantID)
        }
    }

    private static func appendItem(
        _ item: InventoryItem,
        to save: inout PlayerSave,
        result: inout MysteryEffectApplyResult,
    ) {
        let priorCount = save.inventory.items.count
        save.inventory.appendUniqueItem(item)
        guard save.inventory.items.count > priorCount else { return }
        result.grantedItems.append(item)
    }

    private static func appendGeneratedItem(
        _ item: InventoryItem,
        to save: inout PlayerSave,
        state: inout ApplyState,
    ) {
        state.itemOrdinal += 1
        appendItem(item, to: &save, result: &state.result)
    }

    private struct RewardOwnership {
        let ownedTrinketIDs: Set<String>
        let ownedUniqueIDs: Set<String>
        let eligibleTrinketIDs: Set<String>?

        init(_ inventory: PlayerInventoryState, eligibleTrinketIDs: Set<String>?) {
            ownedTrinketIDs = inventory.ownedTrinketIDs
            ownedUniqueIDs = inventory.ownedUniqueIDs
            self.eligibleTrinketIDs = eligibleTrinketIDs
        }
    }

    private static func makeGeneratedItem(
        baseTypeID: String,
        guaranteedAffixIDs: [String],
        ordinal: Int,
        context: GeneratedItemContext,
        ownership: RewardOwnership,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> InventoryItem? {
        guard let baseType = context.baseTypes.first(where: { $0.id == baseTypeID }) else {
            return nil
        }
        if baseType.slot == .trinket {
            return GameContent.trinketItems.first { $0.templateID == baseTypeID }
        }
        let tier = MysteryItemRarity.roll(
            astralChanceBonusPercent: context.astralChanceBonusPercent,
            using: &randomNumberGenerator,
        )
        let itemID =
            "\(context.stageID)-\(context.choiceID)-\(ordinal)-\(baseTypeID)-\(tier.rawValue)"
        return ItemRewardGenerator.generate(
            id: itemID,
            tier: tier,
            ownedTrinketIDs: ownership.ownedTrinketIDs,
            ownedUniqueIDs: ownership.ownedUniqueIDs,
            eligibleTrinketIDs: ownership.eligibleTrinketIDs,
            fallbackBaseType: baseType,
            guaranteedAffixIDs: guaranteedAffixIDs,
            baseTypes: context.baseTypes,
            itemGenerator: context.itemGenerator,
            using: &randomNumberGenerator,
        )
    }
}
