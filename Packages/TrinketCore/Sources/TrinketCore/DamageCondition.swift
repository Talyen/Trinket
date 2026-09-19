import Foundation

/// Bonus-damage predicates. Evaluation lives in
/// `BattleEngine.BattleConditionEvaluator`; keep new cases in sync with its switch.
public enum DamageCondition: CaseIterable, Hashable, Sendable {
    case enemyBleeding
    case enemyBurning
    case enemyNotBurning
    case enemyPoisoned
    case enemyFrozen
    case enemyStunned
    case enemyStunnedOrFrozen
    case enemyMarked
    case enemyLowerHealthThanActor
    case allyBelowHalfHealth
    case enemyHasBuff
    case firstTurn

    /// Full sentence fragment used in card text (single home for condition copy).
    /// Status conditions derive from `Keyword.statusAlias` so glossary renames
    /// flow through automatically; non-status conditions keep literal copy.
    public var sentenceFragment: String {
        switch self {
        case .enemyBleeding: Self.statusFragment(for: .bleed)
        case .enemyBurning: Self.statusFragment(for: .burn)
        case .enemyNotBurning: "the enemy is not \(Keyword.burn.statusAlias ?? Keyword.burn.rawValue)"
        case .enemyPoisoned: Self.statusFragment(for: .poison)
        case .enemyFrozen: Self.statusFragment(for: .freeze)
        case .enemyStunned: Self.statusFragment(for: .stun)
        case .enemyStunnedOrFrozen: "the enemy is \(Keyword.stun.statusAlias ?? Keyword.stun.rawValue) or \(Keyword.freeze.statusAlias ?? Keyword.freeze.rawValue)"
        case .enemyMarked: "the enemy is Marked"
        case .enemyLowerHealthThanActor: "the enemy has less Health than you"
        case .allyBelowHalfHealth: "your Hero or Companion is below half Health"
        case .enemyHasBuff: "the enemy has a buff"
        case .firstTurn: "played on the first turn"
        }
    }

    private static func statusFragment(for keyword: Keyword) -> String {
        "the enemy is \(keyword.statusAlias ?? keyword.rawValue)"
    }
}
