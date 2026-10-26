import Foundation
import TrinketCore

public struct CombatantTraitDefinition: Equatable, Hashable, Sendable, Identifiable {
    public enum Polarity: String, Hashable, Sendable {
        case positive, negative
    }

    public let id: String
    public let name: String
    public let polarity: Polarity
    public let description: String
    public let modifiers: [AffixModifier]
    public let triggers: CombatTraitTriggers

    public init(
        id: String,
        name: String,
        description: String,
        polarity: Polarity = .positive,
        modifiers: [AffixModifier] = [],
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
    ) {
        self.id = id
        self.name = name
        self.polarity = polarity
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }
}
