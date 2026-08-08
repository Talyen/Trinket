import Foundation
import TrinketCore

public struct ItemBaseType: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let slot: ItemSlot
    public let keywordAffinities: Set<Keyword>

    public init(id: String, name: String, slot: ItemSlot, keywordAffinities: Set<Keyword>) {
        self.id = id
        self.name = name
        self.slot = slot
        self.keywordAffinities = keywordAffinities
    }
}

public extension ItemBaseType {
    /// Neutral base-item preview used before a generated reward's rarity is rolled.
    var previewArtReference: ItemArtReference? {
        ArtCatalog.itemArtByID["\(id)-basic"]
    }
}

public struct ItemAffix: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let keywords: Set<Keyword>

    public init(id: String, title: String, description: String, keywords: Set<Keyword>) {
        self.id = id
        self.title = title
        self.description = description
        self.keywords = keywords
    }
}

public extension ItemAffix {
    static let placeholder = ItemAffix(
        id: "placeholder",
        title: "Placeholder",
        description: "No effect yet.",
        keywords: []
    )
}

public struct ItemAffixPower: Codable, Equatable, Hashable, Sendable {
    public let description: String
    public let modifiers: [AffixModifier]
    public let triggers: CombatTraitTriggers

    public init(
        description: String,
        modifiers: [AffixModifier],
        triggers: CombatTraitTriggers = CombatTraitTriggers()
    ) {
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }
}

public struct ItemAffixDefinition: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let slot: ItemSlot
    public let keywords: Set<Keyword>
    public let weight: Int
    public let basic: ItemAffixPower
    public let astral: ItemAffixPower

    public init(
        id: String,
        title: String,
        slot: ItemSlot,
        keywords: Set<Keyword>,
        weight: Int,
        basic: ItemAffixPower,
        astral: ItemAffixPower
    ) {
        self.id = id
        self.title = title
        self.slot = slot
        self.keywords = keywords
        self.weight = weight
        self.basic = basic
        self.astral = astral
    }

    public func power(for rarity: Rarity) -> ItemAffixPower {
        switch rarity {
        case .basic:
            basic
        case .astral:
            astral
        }
    }

    /// Utility affixes with no damage-type keywords (mitigation / restoration / resource).
    /// Safe to equip on any build without creating a keyword mismatch.
    public var isBuildGeneric: Bool {
        keywords.allSatisfy { $0.category != .damageType }
    }

    /// `true` when every damage type in this affix is present in `bias`, or the
    /// affix is build-generic. Hybrid damage affixes cannot introduce a
    /// damage type outside the selected build.
    public func isAligned(withBuildKeywords bias: Set<Keyword>) -> Bool {
        if isBuildGeneric {
            return true
        }
        guard !bias.isEmpty else { return true }
        let damageKeywords = keywords.filter { $0.category == .damageType }
        return damageKeywords.isSubset(of: bias)
    }

    public func resolved(for rarity: Rarity) -> ItemAffix {
        let power = power(for: rarity)
        return ItemAffix(
            id: id,
            title: title,
            description: power.description,
            keywords: keywords
        )
    }
}
