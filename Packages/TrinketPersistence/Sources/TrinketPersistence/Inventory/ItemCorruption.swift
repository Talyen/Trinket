import Foundation
import TrinketContent
import TrinketCore

enum CorruptionEffectKind: String, CaseIterable, Equatable {
    case addAffix
    case replaceAffix
    case bumpUp
    case bumpDown
    case upgradeRarity
}

public enum CorruptionEffectSummary: Equatable, Sendable {
    case addedAffix(title: String)
    case replacedAffix(from: String, to: String)
    case bumpedUp(affixTitle: String)
    case bumpedDown(affixTitle: String)
    case upgradedRarity
}

public struct ItemCorruptionDetail: Equatable, Sendable {
    public var originalItem: InventoryItem
    public var item: InventoryItem
    public var effects: [CorruptionEffectSummary]

    public init(originalItem: InventoryItem, item: InventoryItem, effects: [CorruptionEffectSummary]) {
        self.originalItem = originalItem
        self.item = item
        self.effects = effects
    }
}

public enum ItemCorruptionResult: Equatable, Sendable {
    case success(ItemCorruptionDetail)
    case itemNotFound
    case alreadyCorrupted
    case ineligible
}

public enum ItemCorruption {
    public static let maxAffixCount = 5
    public static let addChancePercent = 50
    public static let replaceChancePercent = 30
    public static let bumpUpChancePercent = 40
    public static let bumpDownChancePercent = 20
    public static let upgradeRarityChancePercent = 50

    public static func isEligibleTarget(_ item: InventoryItem) -> Bool {
        !item.isTrinket
            && item.rarity != .unique
            && !(item.isCorrupted || item.hasCorruptedAffix)
            && !item.affixes.isEmpty
            && item.affixes.allSatisfy { GameContent.itemAffixDefinition(matching: $0.id) != nil }
    }

    public static func eligibleTargets(in inventory: PlayerInventoryState) -> [InventoryItem] {
        inventory.items.filter(isEligibleTarget)
    }

    public static func corrupt(
        _ item: InventoryItem,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemCorruptionDetail? {
        guard isEligibleTarget(item) else { return nil }

        let kinds = rollEffectKinds(for: item, using: &randomNumberGenerator)
        return apply(kinds: kinds, to: item, using: &randomNumberGenerator)
    }

    static func rollEffectKinds(
        for item: InventoryItem,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Set<CorruptionEffectKind> {
        let eligibleKinds = eligibleKinds(for: item)
        let eligible = CorruptionEffectKind.allCases.filter(eligibleKinds.contains)
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
        if item.affixes.count < maxAffixCount {
            kinds.insert(.addAffix)
        }
        if !item.affixes.isEmpty {
            kinds.insert(.replaceAffix)
        }
        if item.rarity == .basic {
            kinds.insert(.upgradeRarity)
        }
        let powers = item.affixes.indices.compactMap { index in
            item.affixPowers.flatMap { $0.indices.contains(index) ? $0[index] : nil }
                ?? GameContent.itemAffixDefinition(matching: item.affixes[index].id)?.power(for: item.rarity)
        }
        if ItemAffixPower.hasBumpableField(in: powers, direction: .up) {
            kinds.insert(.bumpUp)
        }
        if ItemAffixPower.hasBumpableField(in: powers, direction: .down) {
            kinds.insert(.bumpDown)
        }
        return kinds
    }

    private static func chancePercent(for kind: CorruptionEffectKind) -> Int {
        switch kind {
        case .addAffix: addChancePercent
        case .replaceAffix: replaceChancePercent
        case .bumpUp: bumpUpChancePercent
        case .bumpDown: bumpDownChancePercent
        case .upgradeRarity: upgradeRarityChancePercent
        }
    }

    private enum CorruptionMarkPriority: Int {
        case added, replaced, empowered, weakened
    }

    private struct CorruptibleAffix {
        let definition: ItemAffixDefinition
        var power: ItemAffixPower
        var mark: CorruptionMarkPriority?

        var isNew: Bool {
            mark == .added || mark == .replaced
        }
    }

    static func apply(
        kinds: Set<CorruptionEffectKind>,
        to item: InventoryItem,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemCorruptionDetail? {
        let rarity: Rarity = item.rarity == .basic && kinds.contains(.upgradeRarity) ? .astral : item.rarity
        var affixes: [CorruptibleAffix] = []
        for (index, affix) in item.affixes.enumerated() {
            // Saved affixes survive catalog removal. Never partially rebuild such an item.
            guard let definition = GameContent.itemAffixDefinition(matching: affix.id) else { return nil }
            let stored = item.affixPowers.flatMap { $0.indices.contains(index) ? $0[index] : nil }
            affixes.append(CorruptibleAffix(
                definition: definition,
                power: rarity == item.rarity ? stored ?? definition.power(for: rarity) : definition.power(for: rarity),
            ))
        }
        var summaries: [CorruptionEffectSummary] = []
        applyStructuralEffects(
            kinds: kinds, baseType: item.baseType, rarity: rarity,
            affixes: &affixes, summaries: &summaries, using: &randomNumberGenerator,
        )
        if rarity != item.rarity {
            summaries.append(.upgradedRarity)
        }

        applyBumpEffects(kinds: kinds, affixes: &affixes, summaries: &summaries, using: &randomNumberGenerator)

        let markedIndex = affixes.indices.filter { affixes[$0].mark != nil }.min {
            (affixes[$0].mark?.rawValue ?? Int.max) < (affixes[$1].mark?.rawValue ?? Int.max)
        } ?? affixes.indices.randomElement(using: &randomNumberGenerator)
        let mutated = InventoryItem(
            id: item.id,
            templateID: item.templateID,
            baseType: item.baseType,
            rarity: rarity,
            displayName: item.displayName,
            affixes: affixes.enumerated().map { index, affix in
                ItemAffix(
                    id: affix.definition.id, title: affix.definition.title,
                    description: affix.power.description, keywords: affix.definition.keywords,
                    isCorrupted: index == markedIndex,
                )
            },
            isCorrupted: true,
            affixPowers: affixes.map(\.power),
        )
        return ItemCorruptionDetail(originalItem: item, item: mutated, effects: summaries)
    }

    private static func applyStructuralEffects(
        kinds: Set<CorruptionEffectKind>,
        baseType: ItemBaseType,
        rarity: Rarity,
        affixes: inout [CorruptibleAffix],
        summaries: inout [CorruptionEffectSummary],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) {
        let catalog = GameContent.itemAffixDefinitions.filter { $0.isEligible(for: baseType) }
        for kind in [CorruptionEffectKind.replaceAffix, .addAffix] where kinds.contains(kind) {
            let index: Int
            if kind == .replaceAffix {
                guard !affixes.isEmpty else { continue }
                index = Int.random(in: affixes.indices, using: &randomNumberGenerator)
            } else {
                guard affixes.count < maxAffixCount else { continue }
                index = affixes.count
            }
            let pool = catalog.filter { candidate in !affixes.contains { $0.definition.id == candidate.id } }
            guard let definition = weightedPick(from: pool, using: &randomNumberGenerator) else { continue }
            let newAffix = CorruptibleAffix(
                definition: definition, power: definition.power(for: rarity),
                mark: kind == .addAffix ? .added : .replaced,
            )
            if kind == .replaceAffix {
                summaries.append(.replacedAffix(from: affixes[index].definition.title, to: definition.title))
                affixes[index] = newAffix
            } else {
                summaries.append(.addedAffix(title: definition.title))
                affixes.append(newAffix)
            }
        }
    }

    private static func applyBumpEffects(
        kinds: Set<CorruptionEffectKind>,
        affixes: inout [CorruptibleAffix],
        summaries: inout [CorruptionEffectSummary],
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) {
        for index in affixes.indices where affixes[index].isNew {
            guard let direction = bumpNewAffix(power: &affixes[index].power, using: &randomNumberGenerator) else { continue }
            let title = affixes[index].definition.title
            summaries.append(direction == .up ? .bumpedUp(affixTitle: title) : .bumpedDown(affixTitle: title))
        }
        // Flatten eligible fields in affix order, retaining the existing roll weights.
        // New affixes already received their bump and cannot be selected again.
        let effects: [(CorruptionEffectKind, ItemAffixPowerBumpDirection, CorruptionMarkPriority)] = [
            (.bumpUp, .up, .empowered), (.bumpDown, .down, .weakened),
        ]
        for (kind, direction, priority) in effects where kinds.contains(kind) {
            let candidates = affixes.indices.filter { !affixes[$0].isNew }.flatMap { index in
                affixes[index].power.bumpCandidates(direction: direction).map { (index, $0) }
            }
            guard let (index, target) = candidates.randomElement(using: &randomNumberGenerator) else { continue }
            affixes[index].power = affixes[index].power.bumped(target: target, direction: direction)
            if priority.rawValue < (affixes[index].mark?.rawValue ?? Int.max) {
                affixes[index].mark = priority
            }
            let title = affixes[index].definition.title
            summaries.append(direction == .up ? .bumpedUp(affixTitle: title) : .bumpedDown(affixTitle: title))
        }
    }

    static func bumpNewAffix(
        power: inout ItemAffixPower,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemAffixPowerBumpDirection? {
        guard power.hasBumpableField(direction: .up) else { return nil }
        let ticket = Int.random(
            in: 1 ... (bumpUpChancePercent + bumpDownChancePercent),
            using: &randomNumberGenerator,
        )
        var direction: ItemAffixPowerBumpDirection = ticket <= bumpUpChancePercent ? .up : .down
        if !power.hasBumpableField(direction: direction) {
            direction = .up
        }
        guard let target = power.bumpCandidates(direction: direction)
            .randomElement(using: &randomNumberGenerator) else { return nil }
        power = power.bumped(target: target, direction: direction)
        return direction
    }

    private static func weightedPick(
        from pool: [ItemAffixDefinition],
        using randomNumberGenerator: inout some RandomNumberGenerator,
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
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemCorruptionResult {
        guard let index = save.inventory.items.firstIndex(where: { $0.id == itemID }) else {
            return .itemNotFound
        }
        let item = save.inventory.items[index]
        guard !item.isCorrupted, !item.hasCorruptedAffix else { return .alreadyCorrupted }
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

@MainActor
public extension PlayerSaveStore {
    func corruptItem(
        id: String,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemCorruptionResult? {
        var result: ItemCorruptionResult = .itemNotFound
        guard persistBatch(logging: "Failed to corrupt item \(id)", { save in
            result = ItemCorruptionApplier.corrupt(itemID: id, save: &save, using: &randomNumberGenerator)
        }) else {
            return nil
        }
        return result
    }
}
