import Foundation

public struct CombatantDetailContext: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case hero
        case companion
    }

    public let kind: Kind
    public let combatantID: String

    public var id: String {
        "\(kind)-\(combatantID)"
    }

    public init(kind: Kind, combatantID: String) {
        self.kind = kind
        self.combatantID = combatantID
    }
}
