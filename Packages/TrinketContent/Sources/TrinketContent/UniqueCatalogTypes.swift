import Foundation
import TrinketCore

public enum UniqueAffixSource: Sendable {
    case catalog(id: String)
    case bespoke(ItemAffixDefinition)
}

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
