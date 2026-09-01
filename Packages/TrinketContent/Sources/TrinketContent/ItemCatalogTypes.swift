import Foundation
import TrinketCore

public struct ItemBaseType: Identifiable, Equatable, Hashable, Sendable {
    public enum WeaponKind: Equatable, Hashable, Sendable {
        case oneHanded
        case twoHanded
        case offHand
    }

    public let id: String
    public let name: String
    public let slot: ItemSlot
    public let weaponKind: WeaponKind?
    public let keywordAffinities: Set<Keyword>

    public init(
        id: String,
        name: String,
        slot: ItemSlot,
        weaponKind: WeaponKind? = nil,
        keywordAffinities: Set<Keyword>,
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.weaponKind = weaponKind
        self.keywordAffinities = keywordAffinities
    }

    public var affixPowerMultiplier: Int {
        weaponKind == .twoHanded ? 2 : 1
    }

    public func canEquip(in slot: ItemSlot) -> Bool {
        switch weaponKind {
        case .oneHanded:
            slot == .weapon || slot == .secondaryWeapon
        case .twoHanded:
            slot == .weapon
        case .offHand:
            slot == .secondaryWeapon
        case nil:
            slot.accepts(self.slot)
        }
    }

    public var defaultEquipmentSlot: ItemSlot {
        weaponKind == .offHand ? .secondaryWeapon : slot
    }

    public var isRanged: Bool {
        Self.rangedBaseIDs.contains(id)
    }

    public var isQuiver: Bool {
        id == "quiver"
    }

    private static let rangedBaseIDs: Set<String> = [
        "crossbow",
        "longbow",
        "recurve_bow",
        "shortbow",
    ]
}

public extension ItemBaseType {
    var previewArtReference: ItemArtReference? {
        ArtCatalog.itemArtByID["\(id)-basic"] ?? ArtCatalog.itemArtByID[id]
    }
}

public struct ItemAffix: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let keywords: Set<Keyword>
    public let isCorrupted: Bool

    public init(
        id: String,
        title: String,
        description: String,
        keywords: Set<Keyword>,
        isCorrupted: Bool = false,
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.keywords = keywords
        self.isCorrupted = isCorrupted
    }
}

public struct ItemAffixPower: Codable, Equatable, Hashable, Sendable {
    public let description: String
    public let modifiers: [AffixModifier]
    public var triggers: CombatTraitTriggers {
        get { triggerBox.value }
        set {
            if isKnownUniquelyReferenced(&triggerBox) {
                triggerBox.value = newValue
            } else {
                triggerBox = TriggerBox(newValue)
            }
        }
    }

    // Concurrency-Safety: `@unchecked Sendable` — COW box is mutated only while
    private final class TriggerBox: @unchecked Sendable {
        var value: CombatTraitTriggers
        init(_ value: CombatTraitTriggers) {
            self.value = value
        }
    }

    private var triggerBox: TriggerBox

    public init(
        description: String,
        modifiers: [AffixModifier],
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
    ) {
        self.description = description
        self.modifiers = modifiers
        triggerBox = TriggerBox(triggers)
    }

    private enum CodingKeys: String, CodingKey {
        case description
        case modifiers
        case triggers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decode(String.self, forKey: .description)
        modifiers = try container.decode([AffixModifier].self, forKey: .modifiers)
        triggerBox = try TriggerBox(container.decode(CombatTraitTriggers.self, forKey: .triggers))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(triggers, forKey: .triggers)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.description == rhs.description
            && lhs.modifiers == rhs.modifiers
            && lhs.triggerBox.value == rhs.triggerBox.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
        hasher.combine(modifiers)
        hasher.combine(triggerBox.value)
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
        astral: ItemAffixPower,
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
        case .astral, .unique:
            astral
        }
    }

    public var isBuildGeneric: Bool {
        keywords.allSatisfy { $0.category != .damageType }
    }

    public func isEligible(for baseType: ItemBaseType) -> Bool {
        slot == baseType.slot && !keywords.isDisjoint(with: baseType.keywordAffinities)
    }

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
            keywords: keywords,
        )
    }
}
