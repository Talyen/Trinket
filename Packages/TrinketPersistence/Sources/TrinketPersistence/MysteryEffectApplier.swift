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

    public init(
        grantedGold: Int = 0,
        grantedMaterials: [ResourceAmount] = [],
        grantedExperience: Int = 0,
        grantedItems: [InventoryItem] = [],
        chooseItemCandidates: [InventoryItem] = []
    ) {
        self.grantedGold = grantedGold
        self.grantedMaterials = grantedMaterials
        self.grantedExperience = grantedExperience
        self.grantedItems = grantedItems
        self.chooseItemCandidates = chooseItemCandidates
    }

    public var isEmpty: Bool {
        grantedGold == 0
            && grantedMaterials.isEmpty
            && grantedExperience == 0
            && grantedItems.isEmpty
            && chooseItemCandidates.isEmpty
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
        var result = MysteryEffectApplyResult()
        var materialTotals: [HomesteadResource: Int] = [:]
        var itemOrdinal = 0

        for effect in effects {
            switch effect {
            case let .gainGold(amount):
                guard amount > 0 else { continue }
                save.roster.grantGold(amount)
                result.grantedGold += amount

            case let .gainMaterial(resource, amount):
                guard amount > 0, resource != .gold else { continue }
                materialTotals[resource, default: 0] += amount

            case let .gainExperience(amount):
                guard amount > 0 else { continue }
                save.roster.grantExperience(amount, to: hero)
                result.grantedExperience += amount

            case let .gainGeneratedItem(baseTypeID, guaranteedAffixIDs):
                guard let item = makeGeneratedItem(
                    baseTypeID: baseTypeID,
                    guaranteedAffixIDs: guaranteedAffixIDs,
                    stageID: stageID,
                    choiceID: choiceID,
                    ordinal: itemOrdinal,
                    itemGenerator: itemGenerator,
                    baseTypes: baseTypes,
                    using: &randomNumberGenerator
                ) else {
                    continue
                }
                itemOrdinal += 1
                appendItem(item, to: &save, result: &result)

            case .gainRandomItem:
                guard let baseType = baseTypes.randomElement(using: &randomNumberGenerator) else {
                    continue
                }
                guard let item = makeGeneratedItem(
                    baseTypeID: baseType.id,
                    guaranteedAffixIDs: [],
                    stageID: stageID,
                    choiceID: choiceID,
                    ordinal: itemOrdinal,
                    itemGenerator: itemGenerator,
                    baseTypes: baseTypes,
                    using: &randomNumberGenerator
                ) else {
                    continue
                }
                itemOrdinal += 1
                appendItem(item, to: &save, result: &result)

            case .chooseItem:
                var candidates: [InventoryItem] = []
                for candidateIndex in 0 ..< chooseItemCandidateCount {
                    guard let baseType = baseTypes.randomElement(using: &randomNumberGenerator) else {
                        continue
                    }
                    guard let item = makeGeneratedItem(
                        baseTypeID: baseType.id,
                        guaranteedAffixIDs: [],
                        stageID: stageID,
                        choiceID: choiceID,
                        ordinal: itemOrdinal + candidateIndex,
                        idSuffix: "choice-\(candidateIndex)",
                        itemGenerator: itemGenerator,
                        baseTypes: baseTypes,
                        using: &randomNumberGenerator
                    ) else {
                        continue
                    }
                    candidates.append(item)
                }
                result.chooseItemCandidates = candidates
            }
        }

        let materials = materialTotals.map { ResourceAmount($0.key, $0.value) }
            .sorted { $0.resource.rawValue < $1.resource.rawValue }
        if !materials.isEmpty {
            save.homestead.grant(materials)
            result.grantedMaterials = materials
        }

        return result
    }

    public static func grantChosenItem(
        _ item: InventoryItem,
        save: inout PlayerSave
    ) {
        guard !save.inventory.items.contains(where: { $0.id == item.id }) else { return }
        save.inventory.items.append(item)
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
        stageID: String,
        choiceID: String,
        ordinal: Int,
        idSuffix: String? = nil,
        itemGenerator: ItemGenerator,
        baseTypes: [ItemBaseType],
        using randomNumberGenerator: inout RNG
    ) -> InventoryItem? {
        guard let baseType = baseTypes.first(where: { $0.id == baseTypeID }) else {
            return nil
        }
        let rarity = MysteryItemRarity.roll(using: &randomNumberGenerator)
        let suffix = idSuffix.map { "-\($0)" } ?? ""
        let itemID = "\(stageID)-\(choiceID)-\(ordinal)-\(baseTypeID)-\(rarity.rawValue)\(suffix)"
        return itemGenerator.generate(
            id: itemID,
            templateID: "\(baseTypeID)-\(rarity.rawValue)",
            baseType: baseType,
            rarity: rarity,
            guaranteedAffixIDs: guaranteedAffixIDs,
            using: &randomNumberGenerator
        )
    }
}
