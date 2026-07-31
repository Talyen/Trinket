import Foundation

/// Stable navigation context shared by app orchestration and collection views.
///
/// This value is intentionally independent of the save-backed adapter target so
/// deep-link routing can describe a destination without constructing a view.
public struct CombatantDetailContext: Identifiable, Hashable {
    public enum Kind: Hashable {
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
