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
    public var triggers: CombatTraitTriggers
    let triggerRollRanges: [CombatTriggerField: ClosedRange<Double>]
    let modifierRollRanges: [Int: ClosedRange<Double>]

    public init(
        description: String,
        modifiers: [AffixModifier] = [],
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
        triggerRollRanges: [CombatTriggerField: ClosedRange<Double>] = [:],
    ) {
        self.init(
            description: description,
            modifiers: modifiers,
            triggers: triggers,
            triggerRollRanges: triggerRollRanges,
            modifierRollRanges: [:],
        )
    }

    init(
        description: String,
        modifiers: [AffixModifier] = [],
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
        triggerRollRanges: [CombatTriggerField: ClosedRange<Double>] = [:],
        modifierRollRanges: [Int: ClosedRange<Double>],
    ) {
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
        self.triggerRollRanges = triggerRollRanges
        self.modifierRollRanges = modifierRollRanges
    }

    private enum CodingKeys: String, CodingKey {
        case description
        case modifiers
        case triggers
        case triggerRollRanges
        case modifierRollRanges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decode(String.self, forKey: .description)
        struct Failable: Decodable {
            let value: AffixModifier?
            init(from decoder: Decoder) {
                value = try? AffixModifier(from: decoder)
            }
        }
        // Unknown cases are discarded individually; keep range indices aligned with surviving modifiers.
        let decodedModifiers = (try? container.decode([Failable].self, forKey: .modifiers)) ?? []
        var survivingIndices: [Int: Int] = [:]
        var survivingModifiers: [AffixModifier] = []
        for (index, decoded) in decodedModifiers.enumerated() {
            guard let value = decoded.value else { continue }
            survivingIndices[index] = survivingModifiers.count
            survivingModifiers.append(value)
        }
        modifiers = survivingModifiers
        triggers = try container.decode(CombatTraitTriggers.self, forKey: .triggers)
        let ranges = try container.decodeIfPresent([String: ClosedRange<Double>].self, forKey: .triggerRollRanges) ?? [:]
        triggerRollRanges = Dictionary(uniqueKeysWithValues: ranges.lazy.compactMap { key, range in
            CombatTriggerField(rawValue: key).map { ($0, range) }
        })
        let modifierRanges = try container.decodeIfPresent([String: ClosedRange<Double>].self, forKey: .modifierRollRanges) ?? [:]
        modifierRollRanges = Dictionary(uniqueKeysWithValues: modifierRanges.lazy.compactMap { key, range in
            guard let index = Int(key), index >= 0, String(index) == key,
                  let survivingIndex = survivingIndices[index] else { return nil }
            return (survivingIndex, range)
        })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(triggers, forKey: .triggers)
        if !triggerRollRanges.isEmpty {
            let ranges = Dictionary(uniqueKeysWithValues: triggerRollRanges.lazy.map { ($0.key.rawValue, $0.value) })
            try container.encode(ranges, forKey: .triggerRollRanges)
        }
        if !modifierRollRanges.isEmpty {
            let ranges = Dictionary(uniqueKeysWithValues: modifierRollRanges.lazy.map { (String($0.key), $0.value) })
            try container.encode(ranges, forKey: .modifierRollRanges)
        }
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
        guard !bias.isEmpty else { return true }
        return keywords.allSatisfy { $0.category != .damageType || bias.contains($0) }
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

public enum ItemAffixPowerCoding {
    public static func encode(_ powers: [ItemAffixPower]) throws -> Data {
        try JSONEncoder().encode(powers)
    }

    public static func decode(_ data: Data) throws -> [ItemAffixPower] {
        try JSONDecoder().decode([ItemAffixPower].self, from: data)
    }
}
