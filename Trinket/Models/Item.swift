struct ItemBaseType: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let slot: ItemSlot
    let keywordAffinities: Set<Keyword>
}

struct ItemAffix: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let description: String
    let keywords: Set<Keyword>
    let effect: Effect?
}

extension ItemAffix {
    static let placeholder = ItemAffix(
        id: "placeholder",
        title: "Placeholder",
        description: "No effect yet.",
        keywords: [],
        effect: nil
    )

    var sortedKeywords: [Keyword] {
        keywords.sorted { $0.rawValue < $1.rawValue }
    }
}

struct ItemAffixPower: Equatable, Hashable {
    let description: String
    let effect: Effect?
}

struct ItemAffixDefinition: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let slot: ItemSlot
    let keywords: Set<Keyword>
    let weight: Int
    let basic: ItemAffixPower
    let astral: ItemAffixPower

    func resolved(for rarity: Rarity) -> ItemAffix {
        let power: ItemAffixPower
        switch rarity {
        case .basic:
            power = basic
        case .astral:
            power = astral
        }

        return ItemAffix(
            id: id,
            title: title,
            description: power.description,
            keywords: keywords,
            effect: power.effect
        )
    }
}

struct ItemGenerator {
    var affixDefinitions: [ItemAffixDefinition]

    init(affixDefinitions: [ItemAffixDefinition] = GameContent.itemAffixDefinitions) {
        self.affixDefinitions = affixDefinitions
    }

    func generate<RNG: RandomNumberGenerator>(
        id: String,
        templateID: String? = nil,
        baseType: ItemBaseType,
        rarity: Rarity,
        using randomNumberGenerator: inout RNG
    ) -> InventoryItem {
        let affixCount = Self.affixCount(for: rarity, using: &randomNumberGenerator)
        let eligibleAffixes = affixDefinitions.filter { definition in
            definition.slot == baseType.slot &&
                !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
        }
        let selectedDefinitions = Self.weightedSample(
            eligibleAffixes,
            count: affixCount,
            using: &randomNumberGenerator
        )

        return InventoryItem(
            id: id,
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: baseType.name,
            affixes: selectedDefinitions.map { $0.resolved(for: rarity) }
        )
    }

    static func affixCount<RNG: RandomNumberGenerator>(
        for rarity: Rarity,
        using randomNumberGenerator: inout RNG
    ) -> Int {
        let roll = Int.random(in: 1 ... 100, using: &randomNumberGenerator)

        switch rarity {
        case .basic:
            return roll <= 80 ? 1 : 2
        case .astral:
            return roll <= 75 ? 3 : 4
        }
    }

    private static func weightedSample<RNG: RandomNumberGenerator>(
        _ definitions: [ItemAffixDefinition],
        count: Int,
        using randomNumberGenerator: inout RNG
    ) -> [ItemAffixDefinition] {
        var pool = definitions
        var selected: [ItemAffixDefinition] = []

        while selected.count < count, !pool.isEmpty {
            let totalWeight = pool.reduce(0) { $0 + max(0, $1.weight) }
            guard totalWeight > 0 else { break }

            var roll = Int.random(in: 1 ... totalWeight, using: &randomNumberGenerator)
            let selectedIndex = pool.firstIndex { definition in
                roll -= max(0, definition.weight)
                return roll <= 0
            } ?? 0

            selected.append(pool.remove(at: selectedIndex))
        }

        return selected
    }
}

struct InventoryItem: Identifiable, Equatable, Hashable {
    let id: String
    let templateID: String
    let baseType: ItemBaseType
    let rarity: Rarity
    let displayName: String
    let affixes: [ItemAffix]

    init(
        id: String,
        templateID: String? = nil,
        baseType: ItemBaseType,
        rarity: Rarity,
        displayName: String,
        affixes: [ItemAffix]
    ) {
        self.id = id
        self.templateID = templateID ?? id
        self.baseType = baseType
        self.rarity = rarity
        self.displayName = displayName
        self.affixes = affixes
    }

    func rewardInstance(for stageID: String) -> InventoryItem {
        InventoryItem(
            id: "\(stageID)-\(templateID)",
            templateID: templateID,
            baseType: baseType,
            rarity: rarity,
            displayName: displayName,
            affixes: affixes
        )
    }
}

struct EquipmentLoadout: Equatable, Hashable {
    var itemIDsBySlot: [ItemSlot: String]

    init(itemIDsBySlot: [ItemSlot: String] = [:]) {
        self.itemIDsBySlot = itemIDsBySlot
    }

    func itemID(for slot: ItemSlot) -> String? {
        itemIDsBySlot[slot]
    }

    mutating func equip(_ item: InventoryItem, in slot: ItemSlot? = nil) {
        itemIDsBySlot[slot ?? item.baseType.slot] = item.id
    }

    mutating func unequip(_ slot: ItemSlot) {
        itemIDsBySlot[slot] = nil
    }
}
