import TrinketCore

public enum RewardModifier: Hashable, Codable, CaseIterable, Sendable, RawRepresentable {
    case gold, experience, materials
    case wood, stone, iron, food, herbs, hide, gems
    case astral, trinket, unique
    case armsHoard, armorHoard, ringHoard, amuletHoard
    case astralHoard, trinketHoard, uniqueHoard
    case keyword(Keyword)

    public static let allCases: [Self] = [
        .gold, .experience, .materials, .wood, .stone, .iron, .food, .herbs, .hide, .gems, .astral, .trinket, .unique,
        .armsHoard, .armorHoard, .ringHoard, .amuletHoard, .astralHoard, .trinketHoard, .uniqueHoard,
    ] + Keyword.allCases.map(Self.keyword)

    private static let keywordsBySuffix: [String: Keyword] = {
        var map: [String: Keyword] = ["deathsDoor": .deathsDoor]
        for keyword in Keyword.allCases {
            map[keyword.rawValue.lowercased()] = keyword
        }
        return map
    }()

    public var rawValue: String {
        switch self {
        case .gold: "gold"
        case .experience: "experience"
        case .materials: "materials"
        case .wood: "wood"
        case .stone: "stone"
        case .iron: "iron"
        case .food: "food"
        case .herbs: "herbs"
        case .hide: "hide"
        case .gems: "gems"
        case .astral: "astral"
        case .trinket: "trinket"
        case .unique: "unique"
        case .armsHoard: "hoard.arms"
        case .armorHoard: "hoard.armor"
        case .ringHoard: "hoard.ring"
        case .amuletHoard: "hoard.amulet"
        case .astralHoard: "hoard.astral"
        case .trinketHoard: "hoard.trinket"
        case .uniqueHoard: "hoard.unique"
        case let .keyword(keyword): "keyword." + (keyword == .deathsDoor ? "deathsDoor" : keyword.rawValue.lowercased())
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "gold": self = .gold
        case "experience": self = .experience
        case "materials": self = .materials
        case "wood": self = .wood
        case "stone": self = .stone
        case "iron": self = .iron
        case "food": self = .food
        case "herbs": self = .herbs
        case "hide": self = .hide
        case "gems": self = .gems
        case "astral": self = .astral
        case "trinket": self = .trinket
        case "unique": self = .unique
        case "hoard.arms": self = .armsHoard
        case "hoard.armor": self = .armorHoard
        case "hoard.ring": self = .ringHoard
        case "hoard.amulet": self = .amuletHoard
        case "hoard.astral": self = .astralHoard
        case "hoard.trinket": self = .trinketHoard
        case "hoard.unique": self = .uniqueHoard
        default:
            if rawValue.hasPrefix("keyword.") {
                let suffix = String(rawValue.dropFirst("keyword.".count))
                guard let keyword = Self.keywordsBySuffix[suffix] else { return nil }
                self = .keyword(keyword)
            } else {
                return nil
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(String.self)
        guard let value = Self(rawValue: id) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown reward modifier: \(id)")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var requiredKeyword: Keyword? {
        if case let .keyword(keyword) = self {
            keyword
        } else {
            nil
        }
    }

    public var goldBonusPercent: Int {
        self == .gold ? Self.bonusPercent : 0
    }

    public var materialsBonusPercent: Int {
        self == .materials || materialFocus != nil ? Self.bonusPercent : 0
    }

    public static let bonusPercent = 25
    public static let rareTierWeightBonusPercent = 100

    public var title: String {
        switch self {
        case .gold: "Bounty Mark"
        case .experience: "Scholar's Toll"
        case .materials: "Scavenger's Luck"
        case .wood: "Timber Writ"
        case .stone: "Quarry Writ"
        case .iron: "Iron Commission"
        case .food: "Harvest Pact"
        case .herbs: "Herbalist's Request"
        case .hide: "Hunter's Due"
        case .gems: "Jeweler's Favor"
        case .astral: "Astral Omen"
        case .trinket: "Relic Seeker"
        case .unique: "Lost Legacy"
        case .armsHoard: "Arms Hoard"
        case .armorHoard: "Armor Hoard"
        case .ringHoard: "Ring Hoard"
        case .amuletHoard: "Amulet Hoard"
        case .astralHoard: "Astral Hoard"
        case .trinketHoard: "Trinket Hoard"
        case .uniqueHoard: "Unique Hoard"
        case let .keyword(keyword):
            switch keyword {
            case .physical: "Iron Writ"
            case .burn: "Ember Writ"
            case .stun: "Thunder Writ"
            case .block: "Bulwark Writ"
            case .health: "Vital Pact"
            case .gold: "Gilded Writ"
            case .holy: "Sacred Writ"
            case .poison: "Serpent Writ"
            case .bleed: "Crimson Writ"
            case .leech: "Blood Pact"
            case .freeze: "Rime Writ"
            case .dodge: "Shadow Writ"
            case .purge: "Unbinding Writ"
            case .cleanse: "Absolution"
            case .mana: "Arcane Writ"
            case .deathsDoor: "Last Rites"
            case .thorns: "Briar Writ"
            }
        }
    }

    public var description: String {
        switch self {
        case .gold: "Bonus Gold"
        case .experience: "Bonus XP"
        case .materials: "Bonus Materials"
        case .wood: "Bonus Wood"
        case .stone: "Bonus Stone"
        case .iron: "Bonus Iron"
        case .food: "Bonus Food"
        case .herbs: "Bonus Herbs"
        case .hide: "Bonus Hide"
        case .gems: "Bonus Gems"
        case .astral: "Better Astral Odds"
        case .trinket: "Better Trinket Odds"
        case .unique: "Better Unique Odds"
        case .armsHoard: "Drops a Weapon"
        case .armorHoard: "Drops Armor"
        case .ringHoard: "Drops a Ring"
        case .amuletHoard: "Drops an Amulet"
        case .astralHoard: "Drops an Astral item"
        case .trinketHoard: "Drops a Trinket"
        case .uniqueHoard: "Drops a Unique item"
        case let .keyword(keyword): "Drops \(keyword.rawValue) items"
        }
    }

    public var materialFocus: HomesteadResource? {
        switch self {
        case .wood: .wood
        case .stone: .stone
        case .iron: .iron
        case .food: .food
        case .herbs: .herbs
        case .hide: .hide
        case .gems: .gems
        default: nil
        }
    }

    public var favoredItemTier: ItemDropTier? {
        switch self {
        case .astral: .astral
        case .trinket: .trinket
        case .unique: .unique
        default: nil
        }
    }

    public var requiredItemTier: ItemDropTier? {
        switch self {
        case .astralHoard: .astral
        case .trinketHoard: .trinket
        case .uniqueHoard: .unique
        default: nil
        }
    }

    public var requiredBaseTypeIDs: Set<String>? {
        let eligible: [ItemBaseType]
        switch self {
        case .armsHoard:
            eligible = GameContent.itemBaseTypes.filter { $0.slot == .weapon }
        case .armorHoard:
            eligible = GameContent.itemBaseTypes.filter { $0.slot == .armor }
        case .ringHoard:
            eligible = GameContent.itemBaseTypes.filter { $0.slot == .accessory && $0.id.hasSuffix("_ring") }
        case .amuletHoard:
            eligible = GameContent.itemBaseTypes.filter { $0.slot == .accessory && $0.id.hasSuffix("_amulet") }
        default:
            return nil
        }
        return Set(eligible.map(\.id))
    }

    public var experienceBonusPercent: Int {
        self == .experience ? Self.bonusPercent : 0
    }

    public var isItemFocused: Bool {
        switch self {
        case .gold, .experience, .materials, .wood, .stone, .iron, .food, .herbs, .hide, .gems: false
        default: true
        }
    }

    public static func eligible(ownedTrinketIDs: Set<String>, ownedUniqueIDs: Set<String>) -> [Self] {
        allCases.filter { modifier in
            switch modifier {
            case .trinket, .trinketHoard: GameContent.trinketItems.contains { !ownedTrinketIDs.contains($0.templateID) }
            case .unique, .uniqueHoard: GameContent.uniqueItems.contains { !ownedUniqueIDs.contains($0.templateID) }
            case .armsHoard, .armorHoard, .ringHoard, .amuletHoard:
                modifier.requiredBaseTypeIDs?.isEmpty == false
            default: true
            }
        }
    }

    public func resolved(ownedTrinketIDs: Set<String>, ownedUniqueIDs: Set<String>) -> Self {
        Self.eligible(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs).contains(self) ? self : .gold
    }
}
