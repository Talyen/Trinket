package enum DoTApplication: Equatable {
    case ability
    case reaction
    case afterHit
    case attached
    case reflection

    var dealsImmediateDamage: Bool {
        self == .ability || self == .reaction
    }

    var triggersApplicationReactions: Bool {
        self == .ability || self == .afterHit
    }
}
