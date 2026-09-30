import TrinketCore

public struct DamageOperation: Equatable, Hashable, Sendable {
    public enum AttackOrigin: Equatable, Hashable, Sendable {
        case ability, card, ordinaryCard, counterattack, repeatedAttack, cardRepeat, criticalRepeat
    }

    public enum Scaling: Equatable, Hashable, Sendable {
        case statsAndItems, items, flat, resolved
    }

    public enum Accuracy: Equatable, Hashable, Sendable {
        case normal, unavoidable
    }

    public enum ReactionCause: Equatable, Hashable, Sendable {
        case talent, dodge
    }

    private enum Kind: Equatable, Hashable, Sendable {
        case attack(AbilityTier, AttackOrigin)
        case effect
        case periodic
        case reaction(ReactionCause)
        case healthCost
    }

    private var kind: Kind
    private var scaling: Scaling
    private let accuracy: Accuracy
    public var abilityCriticalChanceBonus: Double = 0
    public var guaranteedCriticalIfEnemyBuffed = false
    public var guaranteedCritical = false
    public var abilityHasLeech = false
    var suppressLeech = false
    var partnerFirstAttackBonus = 0
    var capturesCardRepeat = false

    var isResolvedCardRepeat: Bool {
        capturesCardRepeat && usesResolvedOutgoingDamage
    }

    public static func attack(
        tier: AbilityTier = .skill,
        origin: AttackOrigin = .ability,
        scaling: Scaling = .statsAndItems,
        accuracy: Accuracy = .normal,
        abilityCriticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        guaranteedCritical: Bool = false,
        abilityHasLeech: Bool = false,
    ) -> Self {
        var operation = Self(kind: .attack(tier, origin), scaling: scaling, accuracy: accuracy)
        operation.abilityCriticalChanceBonus = abilityCriticalChanceBonus
        operation.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        operation.guaranteedCritical = guaranteedCritical
        operation.abilityHasLeech = abilityHasLeech
        return operation
    }

    public static func effect(
        scaling: Scaling = .statsAndItems,
        accuracy: Accuracy = .unavoidable,
        abilityCriticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        guaranteedCritical: Bool = false,
        abilityHasLeech: Bool = false,
    ) -> Self {
        var operation = Self(kind: .effect, scaling: scaling, accuracy: accuracy)
        operation.abilityCriticalChanceBonus = abilityCriticalChanceBonus
        operation.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        operation.guaranteedCritical = guaranteedCritical
        operation.abilityHasLeech = abilityHasLeech
        return operation
    }

    public static func reaction(
        cause: ReactionCause = .talent,
        scaling: Scaling = .flat,
        accuracy: Accuracy = .unavoidable,
    ) -> Self {
        Self(kind: .reaction(cause), scaling: scaling, accuracy: accuracy)
    }

    static let redirected = Self(kind: .reaction(.talent), scaling: .resolved, accuracy: .unavoidable)

    public static let periodic = Self(kind: .periodic, scaling: .statsAndItems, accuracy: .unavoidable)
    static let resolvedPeriodic = Self(kind: .periodic, scaling: .resolved, accuracy: .unavoidable)
    public static let healthCost = Self(kind: .healthCost, scaling: .flat, accuracy: .unavoidable)

    var applyStatBonus: Bool {
        scaling == .statsAndItems
    }

    var applyItemBonus: Bool {
        scaling == .statsAndItems || scaling == .items
    }

    var applyDodge: Bool {
        accuracy == .normal
    }

    var usesResolvedOutgoingDamage: Bool {
        scaling == .resolved
    }

    var isPeriodic: Bool {
        kind == .periodic
    }

    var isHealthCost: Bool {
        kind == .healthCost
    }

    var causedByDodge: Bool {
        kind == .reaction(.dodge)
    }

    var isRetaliation: Bool {
        switch kind {
        case .reaction, .periodic, .attack(_, .counterattack), .attack(_, .cardRepeat), .attack(_, .criticalRepeat): true
        default: false
        }
    }

    var isAttackHit: Bool {
        if case .attack = kind {
            return true
        }
        return false
    }

    var isBasicAttackHit: Bool {
        if case .attack(.basic, _) = kind {
            return true
        }
        return false
    }

    var isCardAttack: Bool {
        switch kind {
        case .attack(_, .card), .attack(_, .ordinaryCard), .attack(_, .cardRepeat): true
        default: false
        }
    }

    var isOrdinaryUniqueCardDamage: Bool {
        if case .attack(_, .ordinaryCard) = kind {
            return true
        }
        return false
    }

    /// Repeats retain their operation kind and accuracy, including periodic pulses.
    func repeated(
        origin: AttackOrigin = .repeatedAttack,
        scaling: Scaling? = nil,
        guaranteedCritical: Bool? = nil,
    ) -> Self {
        var repeated = self
        if case let .attack(tier, _) = kind {
            repeated.kind = .attack(tier, origin)
        }
        repeated.scaling = scaling ?? self.scaling
        repeated.guaranteedCritical = guaranteedCritical ?? self.guaranteedCritical
        repeated.partnerFirstAttackBonus = 0
        repeated.capturesCardRepeat = false
        return repeated
    }
}
