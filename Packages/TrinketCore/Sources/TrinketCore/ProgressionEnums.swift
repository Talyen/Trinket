import Foundation

public enum EnemyFaction: String, CaseIterable, Identifiable, Hashable, Sendable {
    case mortal
    case beast
    case elemental
    case construct
    case undead
    case corrupted

    public var id: String {
        rawValue
    }
}

public enum Rarity: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case basic
    case astral
    case unique

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .basic: "Basic"
        case .astral: "Astral"
        case .unique: "Unique"
        }
    }
}

public enum AbilityTier: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case basic = "Basic"
    case skill = "Skill"
    case ultimate = "Ultimate"

    public var id: String {
        rawValue
    }

    public var cadenceTurns: Int {
        switch self {
        case .basic:
            1
        case .skill:
            3
        case .ultimate:
            6
        }
    }
}
