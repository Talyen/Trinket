import Foundation

/// Ability predicates. Evaluation lives in
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
    case enemyHasBlock
    case enemyFullHealth
    case actorHasTwoBlock
    case firstTurn

    /// Full sentence fragment used in card text (single home for condition copy).
    /// Status conditions derive from `Keyword.statusAlias` so glossary renames
    /// flow through automatically; non-status conditions keep literal copy.
    public var sentenceFragment: String {
        switch self {
        case .enemyBleeding: Self.statusFragment(for: .bleed)
        case .enemyBurning: Self.statusFragment(for: .burn)
        case .enemyNotBurning: "the enemy is not \(Keyword.burn.statusName)"
        case .enemyPoisoned: Self.statusFragment(for: .poison)
        case .enemyFrozen: Self.statusFragment(for: .freeze)
        case .enemyStunned: Self.statusFragment(for: .stun)
        case .enemyStunnedOrFrozen: "the enemy is \(Keyword.stun.statusName) or \(Keyword.freeze.statusName)"
        case .enemyMarked: "the enemy is Marked"
        case .enemyLowerHealthThanActor: "the enemy has less Health than you"
        case .allyBelowHalfHealth: "your Hero or Companion is below half Health"
        case .enemyHasBuff: "the enemy has a buff"
        case .enemyHasBlock: "the enemy has Block"
        case .enemyFullHealth: "the enemy is at full Health"
        case .actorHasTwoBlock: "you have at least 2 Block"
        case .firstTurn: "played on the first turn"
        }
    }

    private static func statusFragment(for keyword: Keyword) -> String {
        "the enemy is \(keyword.statusName)"
    }
}
