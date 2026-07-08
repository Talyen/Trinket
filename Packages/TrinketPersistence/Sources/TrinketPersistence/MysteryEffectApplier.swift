import Foundation
import TrinketContent
import TrinketCore

public struct MysteryEffectApplyResult: Equatable, Sendable {
    public var grantedGold: Int
    public var grantedMaterials: [ResourceAmount]
    public var grantedExperience: Int
    public var grantedItems: [InventoryItem]
    /// Populated when a choice includes `.chooseItem`; caller presents options then grants one.
    public var chooseItemCandidates: [InventoryItem]
    /// Combatant IDs newly unlocked by this apply (heroes and pets).
    public var unlockedCombatantIDs: [String]

    public init(
        grantedGold: Int = 0,
        grantedMaterials: [ResourceAmount] = [],
        grantedExperience: Int = 0,
        grantedItems: [InventoryItem] = [],
        chooseItemCandidates: [InventoryItem] = [],
        unlockedCombatantIDs: [String] = []
    ) {
        self.grantedGold = grantedGold
        self.grantedMaterials = grantedMaterials
        self.grantedExperience = grantedExperience
        self.grantedItems = grantedItems
        self.chooseItemCandidates = chooseItemCandidates
        self.unlockedCombatantIDs = unlockedCombatantIDs
    }

    public var isEmpty: Bool {
        grantedGold == 0
            && grantedMaterials.isEmpty
            && grantedExperience == 0
            && grantedItems.isEmpty
            && chooseItemCandidates.isEmpty
            && unlockedCombatantIDs.isEmpty
    }
}

public enum MysteryEffectApplier {
    public static let chooseItemCandidateCount = 3

    public static func apply<RNG: RandomNumberGenerator>(
        _ effects: [MysteryEffect],
        stageID: String,
        choiceID: String,
        hero: Combatant,
        save: inout PlayerSave,
        using randomNumberGenerator: inout RNG,
        itemGenerator: ItemGenerator = ItemGenerator(),
        baseTypes: [ItemBaseType] = GameContent.itemBaseTypes
    ) -> MysteryEffectApplyResult {
        var state = ApplyState()
        let itemContext = GeneratedItemContext(
            stageID: stageID,
            choiceID: choiceID,
            itemGenerator: itemGenerator,
            baseTypes: baseTypes
        )

        for effect in effects {
            apply(
                effect,
                hero: hero,
                save: &save,
                state: &state,
                itemContext: itemContext,
                using: &randomNumberGenerator
            )
        }

        let materials = state.materialTotals.map { ResourceAmount($0.key, $0.value) }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }
        if !materials.isEmpty {
            save.homestead.grant(materials)
            state.result.grantedMaterials = materials
        }

        return state.result
    }

    public static func grantChosenItem(
        _ item: InventoryItem,
        save: inout PlayerSave
    ) {
        guard !save.inventory.items.contains(where: { $0.id == item.id }) else { return }
        save.inventory.items.append(item)
    }

    private struct GeneratedItemContext {
        let stageID: String
        let choiceID: String
        let itemGenerator: ItemGenerator
        let baseTypes: [ItemBaseType]
    }

    private struct ApplyState {
        var result = MysteryEffectApplyResult()
        var materialTotals: [HomesteadResource: Int] = [:]
        var itemOrdinal = 0
    }

    private static func apply<RNG: RandomNumberGenerator>(
        _ effect: MysteryEffect,
        hero: Combatant,
        save: inout PlayerSave,
        state: inout ApplyState,
        itemContext: GeneratedItemContext,
        using randomNumberGenerator: inout RNG
    ) {
        switch effect {
        case let .gainGold(amount):
            guard amount > 0 else { return }
            save.roster.grantGold(amount)
            state.result.grantedGold += amount

        case let .gainMaterial(resource, amount):
            guard amount > 0, resource != .gold else { return }
            state.materialTotals[resource, default: 0] += amount

        case let .gainExperience(amount):
            guard amount > 0 else { return }
            save.roster.grantExperience(amount, to: hero)
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

        case .chooseItem:
            state.result.chooseItemCandidates = makeChooseItemCandidates(
                startingOrdinal: state.itemOrdinal,
                context: itemContext,
                using: &randomNumberGenerator
            )

        case let .unlockCombatant(combatantID):
            applyUnlock(combatantID, save: &save, result: &state.result)
        }
    }

    private static func applyUnlock(
        _ combatantID: String,
        save: inout PlayerSave,
        result: inout MysteryEffectApplyResult
    ) {
        let didUnlock: Bool
        if GameContent.heroes.contains(where: { $0.id == combatantID }) {
            didUnlock = save.roster.unlockHero(id: combatantID)
        } else if GameContent.pets.contains(where: { $0.id == combatantID }) {
            didUnlock = save.roster.unlockPet(id: combatantID)
        } else {
            didUnlock = false
        }
        if didUnlock {
            result.unlockedCombatantIDs.append(combatantID)
        }
    }

    private static func makeChooseItemCandidates<RNG: RandomNumberGenerator>(
        startingOrdinal: Int,
        context: GeneratedItemContext,
        using randomNumberGenerator: inout RNG
    ) -> [InventoryItem] {
        var candidates: [InventoryItem] = []
        for candidateIndex in 0 ..< chooseItemCandidateCount {
            guard let baseType = context.baseTypes.randomElement(using: &randomNumberGenerator) else {
                continue
            }
            guard let item = makeGeneratedItem(
                baseTypeID: baseType.id,
                guaranteedAffixIDs: [],
                ordinal: startingOrdinal + candidateIndex,
                idSuffix: "choice-\(candidateIndex)",
                context: context,
                using: &randomNumberGenerator
            ) else {
                continue
            }
            candidates.append(item)
        }
        return candidates
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

    private static func makeGeneratedItem<RNG: RandomNumberGenerator>(
        baseTypeID: String,
        guaranteedAffixIDs: [String],
        ordinal: Int,
        idSuffix: String? = nil,
        context: GeneratedItemContext,
        using randomNumberGenerator: inout RNG
    ) -> InventoryItem? {
        guard let baseType = context.baseTypes.first(where: { $0.id == baseTypeID }) else {
            return nil
        }
        let rarity = MysteryItemRarity.roll(using: &randomNumberGenerator)
        let suffix = idSuffix.map { "-\($0)" } ?? ""
        let itemID =
            "\(context.stageID)-\(context.choiceID)-\(ordinal)-\(baseTypeID)-\(rarity.rawValue)\(suffix)"
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
