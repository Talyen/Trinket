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
    public static let placeholder = ItemAffix(
        id: "placeholder",
        title: "Placeholder",
        description: "No effect yet.",
        keywords: []
    )

    public var sortedKeywords: [Keyword] {
        keywords.sorted { $0.rawValue < $1.rawValue }
    }
}

public struct ItemAffixPower: Equatable, Hashable, Sendable {
    public let description: String
    public let modifiers: [AffixModifier]

    public init(description: String, modifiers: [AffixModifier]) {
        self.description = description
        self.modifiers = modifiers
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
            return basic
        case .astral:
            return astral
        }
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
