import Foundation
import TrinketContent
import TrinketCore

public enum CorruptionEffectKind: String, CaseIterable, Equatable, Sendable {
    case addAffix
    case removeAffix
    case replaceAffix
    case bumpUp
    case bumpDown
    case upgradeRarity
}

public enum CorruptionEffectSummary: Equatable, Sendable {
    case addedAffix(title: String)
    case removedAffix(title: String)
    case replacedAffix(from: String, to: String)
    case bumpedUp(affixTitle: String)
    case bumpedDown(affixTitle: String)
    case upgradedRarity
}

public struct ItemCorruptionResult: Equatable, Sendable {
    public var item: InventoryItem
    public var effects: [CorruptionEffectSummary]

    public init(item: InventoryItem, effects: [CorruptionEffectSummary]) {
        self.item = item
        self.effects = effects
    }
}

public enum ItemCorruptionApplyResult: Equatable, Sendable {
    case success(ItemCorruptionResult)
    case itemNotFound
    case alreadyCorrupted
    case ineligible
}

/// Chaos mutation rules for the Corruption Altar mystery event.
public enum ItemCorruption {
    public static let maxAffixCount = 5
    public static let addChancePercent = 35
    public static let removeChancePercent = 35
    public static let replaceChancePercent = 30
    public static let bumpUpChancePercent = 40
    public static let bumpDownChancePercent = 40
    public static let upgradeRarityChancePercent = 25

    public static func isEligibleTarget(_ item: InventoryItem) -> Bool {
        !item.isTrinket && !item.isCorrupted && !item.affixes.isEmpty
    }

    public static func eligibleTargets(in inventory: PlayerInventoryState) -> [InventoryItem] {
        inventory.items.filter(isEligibleTarget)
    }

    public static func corrupt(
        _ item: InventoryItem,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> ItemCorruptionResult? {
        guard isEligibleTarget(item) else { return nil }

        let kinds = rollEffectKinds(for: item, using: &randomNumberGenerator)
        return apply(kinds: kinds, to: item, using: &randomNumberGenerator)
    }

    static func rollEffectKinds(
        for item: InventoryItem,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Set<CorruptionEffectKind> {
        let eligible = eligibleKinds(for: item)
        var selected = Set<CorruptionEffectKind>()
        for kind in eligible {
            let chance = chancePercent(for: kind)
            if Int.random(in: 1 ... 100, using: &randomNumberGenerator) <= chance {
                selected.insert(kind)
            }
        }
        if selected.isEmpty, let forced = eligible.randomElement(using: &randomNumberGenerator) {
            selected.insert(forced)
        }
        return selected
    }

    static func eligibleKinds(for item: InventoryItem) -> Set<CorruptionEffectKind> {
        var kinds: Set<CorruptionEffectKind> = []
        if item.affixes.count >= 2 {
            kinds.insert(.removeAffix)
        }
        if item.affixes.count < maxAffixCount {
            kinds.insert(.addAffix)
        }
        if !item.affixes.isEmpty {
            kinds.insert(.replaceAffix)
        }
        if item.rarity == .basic {
            kinds.insert(.upgradeRarity)
        }
        let powers = resolvedPowers(for: item)
        if AffixPowerBump.hasBumpableField(in: powers, direction: .up) {
            kinds.insert(.bumpUp)
        }
        if AffixPowerBump.hasBumpableField(in: powers, direction: .down) {
            kinds.insert(.bumpDown)
        }
        return kinds
    }

    private static func chancePercent(for kind: CorruptionEffectKind) -> Int {
        switch kind {
        case .addAffix: addChancePercent
        case .removeAffix: removeChancePercent
        case .replaceAffix: replaceChancePercent
        case .bumpUp: bumpUpChancePercent
        case .bumpDown: bumpDownChancePercent
        case .upgradeRarity: upgradeRarityChancePercent
        }
    }

    static func apply(
        kinds: Set<CorruptionEffectKind>,
        to item: InventoryItem,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> ItemCorruptionResult {
        var affixIDs = item.affixes.map(\.id)
        var summaries: [CorruptionEffectSummary] = []
        var rarity = item.rarity

        applyStructuralEffects(
            kinds: kinds,
            affixIDs: &affixIDs,
            summaries: &summaries,
            using: &randomNumberGenerator
        )

        if rarity == .basic, kinds.contains(.upgradeRarity) || affixIDs.count >= 3 {
            rarity = .astral
            summaries.append(.upgradedRarity)
        }

        var powers: [ItemAffixPower] = affixIDs.compactMap { id in
            GameContent.itemAffixDefinition(matching: id)?.power(for: rarity)
        }
        applyBumpEffects(
            kinds: kinds,
            powers: &powers,
            affixIDs: affixIDs,
            summaries: &summaries,
            using: &randomNumberGenerator
        )

        let affixes: [ItemAffix] = zip(affixIDs, powers).compactMap { id, power in
            guard let definition = GameContent.itemAffixDefinition(matching: id) else { return nil }
            return ItemAffix(
                id: definition.id,
                title: definition.title,
                description: power.description,
                keywords: definition.keywords
            )
        }

        let mutated = InventoryItem(
            id: item.id,
            templateID: item.templateID,
            baseType: item.baseType,
            rarity: rarity,
            displayName: item.displayName,
            affixes: affixes,
            isCorrupted: true,
            affixPowers: powers
        )
        return ItemCorruptionResult(item: mutated, effects: summaries)
    }

    private static func applyStructuralEffects(
        kinds: Set<CorruptionEffectKind>,
        affixIDs: inout [String],
        summaries: inout [CorruptionEffectSummary],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) {
        let catalog = GameContent.itemAffixDefinitions
        if kinds.contains(.removeAffix), affixIDs.count >= 2 {
            let index = Int.random(in: 0 ..< affixIDs.count, using: &randomNumberGenerator)
            let removedID = affixIDs.remove(at: index)
            let title = GameContent.itemAffixDefinition(matching: removedID)?.title ?? removedID
            summaries.append(.removedAffix(title: title))
        }

        if kinds.contains(.replaceAffix), !affixIDs.isEmpty {
            let index = Int.random(in: 0 ..< affixIDs.count, using: &randomNumberGenerator)
            let fromID = affixIDs[index]
            let fromTitle = GameContent.itemAffixDefinition(matching: fromID)?.title ?? fromID
            let pool = catalog.filter { !affixIDs.contains($0.id) }
            if let replacement = weightedPick(from: pool, using: &randomNumberGenerator) {
                affixIDs[index] = replacement.id
                summaries.append(.replacedAffix(from: fromTitle, to: replacement.title))
            }
        }

        if kinds.contains(.addAffix), affixIDs.count < maxAffixCount {
            let pool = catalog.filter { !affixIDs.contains($0.id) }
            if let added = weightedPick(from: pool, using: &randomNumberGenerator) {
                affixIDs.append(added.id)
                summaries.append(.addedAffix(title: added.title))
            }
        }
    }

    private static func applyBumpEffects(
        kinds: Set<CorruptionEffectKind>,
        powers: inout [ItemAffixPower],
        affixIDs: [String],
        summaries: inout [CorruptionEffectSummary],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) {
        if kinds.contains(.bumpUp),
           let bump = AffixPowerBump.apply(
               direction: .up,
               to: &powers,
               affixIDs: affixIDs,
               using: &randomNumberGenerator
           ) {
            summaries.append(.bumpedUp(affixTitle: bump))
        }
        if kinds.contains(.bumpDown),
           let bump = AffixPowerBump.apply(
               direction: .down,
               to: &powers,
               affixIDs: affixIDs,
               using: &randomNumberGenerator
           ) {
            summaries.append(.bumpedDown(affixTitle: bump))
        }
    }

    private static func resolvedPowers(for item: InventoryItem) -> [ItemAffixPower] {
        if let powers = item.affixPowers, powers.count == item.affixes.count {
            return powers
        }
        return item.affixes.compactMap { affix in
            GameContent.itemAffixDefinition(matching: affix.id)?.power(for: item.rarity)
        }
    }

    private static func weightedPick(
        from pool: [ItemAffixDefinition],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> ItemAffixDefinition? {
        guard !pool.isEmpty else { return nil }
        let total = pool.reduce(0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return pool.randomElement(using: &randomNumberGenerator) }
        var ticket = Int.random(in: 1 ... total, using: &randomNumberGenerator)
        for definition in pool {
            ticket -= max(0, definition.weight)
            if ticket <= 0 {
                return definition
            }
        }
        return pool.last
    }
}

public enum ItemCorruptionApplier {
    public static func corrupt(
        itemID: String,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> ItemCorruptionApplyResult {
        guard let index = save.inventory.items.firstIndex(where: { $0.id == itemID }) else {
            return .itemNotFound
        }
        let item = save.inventory.items[index]
        guard !item.isCorrupted else { return .alreadyCorrupted }
        guard ItemCorruption.isEligibleTarget(item) else { return .ineligible }
        guard let result = ItemCorruption.corrupt(item, using: &randomNumberGenerator) else {
            return .ineligible
        }
        save.inventory.items[index] = result.item
        return .success(result)
    }

    public static func recordCorruptionAltarEncounter(save: inout PlayerSave) {
        save.corruptionAltarCooldownRemaining = PlayerSave.corruptionAltarCooldownAfterEncounter
    }

    public static func noteMysteryCompleted(save: inout PlayerSave) {
        if save.corruptionAltarCooldownRemaining > 0 {
            save.corruptionAltarCooldownRemaining -= 1
        }
    }
}
