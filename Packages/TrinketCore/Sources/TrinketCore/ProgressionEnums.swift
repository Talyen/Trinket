import Foundation

/// Small progression-domain enums grouped by size, not theme: each is a closed
/// set with no behavior beyond identity (plus `Rarity.label` display copy and
/// `AbilityTier.cadenceTurns` tuning). Split if any grows its own logic.
/// Raw values are persisted; never rename without a save migration.
public enum EnemyFaction: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
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

    /// Explicit switch (not `rawValue.capitalized`) so display copy stays
    /// reviewable for localization.
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
