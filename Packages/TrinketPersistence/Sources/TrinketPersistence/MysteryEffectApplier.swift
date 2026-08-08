import Foundation
import TrinketContent
import TrinketCore

public struct MysteryEffectApplyResult: Equatable, Sendable {
    public var grantedGold: Int
    public var grantedMaterials: [ResourceAmount]
    public var grantedExperience: Int
    public var heroProgressionBefore: CombatantProgression?
    public var heroProgressionAfter: CombatantProgression?
    public var companionProgressionBefore: CombatantProgression?
    public var companionProgressionAfter: CombatantProgression?
    public var grantedItems: [InventoryItem]
    /// Combatant IDs newly unlocked by this apply (heroes and companions).
    public var unlockedCombatantIDs: [String]

    public init(
        grantedGold: Int = 0,
        grantedMaterials: [ResourceAmount] = [],
        grantedExperience: Int = 0,
        heroProgressionBefore: CombatantProgression? = nil,
        heroProgressionAfter: CombatantProgression? = nil,
        companionProgressionBefore: CombatantProgression? = nil,
        companionProgressionAfter: CombatantProgression? = nil,
        grantedItems: [InventoryItem] = [],
        unlockedCombatantIDs: [String] = []
    ) {
        self.grantedGold = grantedGold
        self.grantedMaterials = grantedMaterials
        self.grantedExperience = grantedExperience
        self.heroProgressionBefore = heroProgressionBefore
        self.heroProgressionAfter = heroProgressionAfter
        self.companionProgressionBefore = companionProgressionBefore
        self.companionProgressionAfter = companionProgressionAfter
        self.grantedItems = grantedItems
        self.unlockedCombatantIDs = unlockedCombatantIDs
    }

    public var isEmpty: Bool {
        grantedGold == 0
            && grantedMaterials.isEmpty
            && grantedExperience == 0
            && grantedItems.isEmpty
            && unlockedCombatantIDs.isEmpty
    }
}

public enum MysteryEffectApplier {
    /// Fixed, deterministic material grant per level (L1 4 → L50 18).
    public static func materialQuantity(forLevel level: Int) -> Int {
        let clamped = max(1, level)
        return 4 + (clamped * 14) / 49
    }

    /// Mystery reward level: chapter base level for journey stages, Labyrinth node depth otherwise.
    public static func resolvedEncounterLevel(
        stage: Stage,
        labyrinthNodeID: String?,
        save: PlayerSave
    ) -> Int {
        if let labyrinthNodeID, let node = save.labyrinth.nodes[labyrinthNodeID] {
            return LabyrinthCompletion.enemyLevel(for: node)
        }
        return StageCompletion.resolvedEncounterLevel(for: stage, in: GameContent.chapters)
    }

    public static func apply(
        _ effects: [MysteryEffect],
        stageID: String,
        choiceID: String,
        encounterLevel: Int,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        itemGenerator: ItemGenerator = ItemGenerator(),
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes
    ) -> MysteryEffectApplyResult {
        var state = ApplyState(materialQuantity: materialQuantity(forLevel: encounterLevel))
        let hero = save.roster.activeHero
        let companion = save.roster.activeCompanion
        let heroProgressionBefore = save.roster.progression(for: hero)
        let companionProgressionBefore = save.roster.progression(for: companion)
        let itemContext = GeneratedItemContext(
            stageID: stageID,
            choiceID: choiceID,
            itemGenerator: itemGenerator,
            baseTypes: baseTypes,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent
        )

        for effect in effects {
            apply(
                effect,
                hero: hero,
                companion: companion,
                save: &save,
                state: &state,
                itemContext: itemContext,
                using: &randomNumberGenerator
            )
        }

        let materials = state.materialTotals.map { ResourceAmount($0.key, $0.value) }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }
        if !materials.isEmpty {
            state.result.grantedMaterials = save.grantMaterials(materials)
        }

        if state.result.grantedExperience > 0 {
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
    }

    private struct ApplyState {
        var result = MysteryEffectApplyResult()
        var materialTotals: [HomesteadResource: Int] = [:]
        var itemOrdinal = 0
        let materialQuantity: Int
    }

    private static func apply(
        _ effect: MysteryEffect,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
        state: inout ApplyState,
        itemContext: GeneratedItemContext,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) {
        switch effect {
        case let .gainGold(amount):
            guard amount > 0 else { return }
            let granted = save.grantGold(save.homestead.effects.adjustedGold(amount))
            state.result.grantedGold += granted

        case let .gainMaterial(resource):
            guard resource != .gold else { return }
            state.materialTotals[resource, default: 0] += state.materialQuantity

        case let .gainExperience(amount):
            guard amount > 0 else { return }
            save.roster.grantExperience(amount, to: hero)
            save.roster.grantExperience(amount, to: companion)
            state.result.grantedExperience += amount

        case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs):
            guard let item = makeGeneratedItem(
                baseTypeID: baseTypeID,
                guaranteedAffixIDs: guaranteedAffixIDs,
                ordinal: state.itemOrdinal,
                context: itemContext,
                using: &randomNumberGenerator
            ) else {
                return
            }
            state.itemOrdinal += 1
            appendItem(item, to: &save, result: &state.result)

        case .gainRandomItem:
            guard let baseType = itemContext.baseTypes.randomElement(using: &randomNumberGenerator) else {
                return
            }
            guard let item = makeGeneratedItem(
                baseTypeID: baseType.id,
                guaranteedAffixIDs: [],
                ordinal: state.itemOrdinal,
                context: itemContext,
                using: &randomNumberGenerator
            ) else {
                return
            }
            state.itemOrdinal += 1
            appendItem(item, to: &save, result: &state.result)

        case let .unlockCombatant(combatantID):
            applyUnlock(combatantID, save: &save, result: &state.result)

        case .corruptItem, .leave:
            break
        }
    }

    private static func applyUnlock(
        _ combatantID: String,
        save: inout PlayerSave,
        result: inout MysteryEffectApplyResult
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
        result: inout MysteryEffectApplyResult
    ) {
        guard !save.inventory.items.contains(where: { $0.id == item.id }) else { return }
        save.inventory.items.append(item)
        result.grantedItems.append(item)
    }

    private static func makeGeneratedItem(
        baseTypeID: String,
        guaranteedAffixIDs: [String],
        ordinal: Int,
        context: GeneratedItemContext,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> InventoryItem? {
        guard let baseType = context.baseTypes.first(where: { $0.id == baseTypeID }) else {
            return nil
        }
        let rarity = MysteryItemRarity.roll(
            astralChanceBonusPercent: context.astralChanceBonusPercent,
            using: &randomNumberGenerator
        )
        let itemID =
            "\(context.stageID)-\(context.choiceID)-\(ordinal)-\(baseTypeID)-\(rarity.rawValue)"
        return context.itemGenerator.generate(
            id: itemID,
            templateID: "\(baseTypeID)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            guaranteedAffixIDs: guaranteedAffixIDs,
            using: &randomNumberGenerator
        )
    }
}
