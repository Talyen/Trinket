import Foundation
import TrinketCore

/// Where a Unique's affix comes from.
public enum UniqueAffixSource: Sendable {
    /// An existing affix definition pinned at its Astral values.
    case catalog(id: String)
    /// A definition authored solely for one unique; never enters the random roll pool.
    case bespoke(ItemAffixDefinition)
}

/// Authored definition of a Unique item: one per base type, fixed name,
/// fixed affix list, exact powers resolved at build time into `affixPowers`.
public struct UniqueItemDefinition: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let baseTypeID: String
    public let affixes: [UniqueAffixSource]

    public init(
        id: String,
        displayName: String,
        baseTypeID: String,
        affixes: [UniqueAffixSource]
    ) {
        self.id = id
        self.displayName = displayName
        self.baseTypeID = baseTypeID
        self.affixes = affixes
    }
}
