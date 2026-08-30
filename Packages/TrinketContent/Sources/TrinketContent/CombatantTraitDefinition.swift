import Foundation
import TrinketCore

public struct CombatantTraitDefinition: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let modifiers: [AffixModifier]
    public let triggers: CombatTraitTriggers

    public init(
        id: String,
        name: String,
        description: String,
        modifiers: [AffixModifier] = [],
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }
}
