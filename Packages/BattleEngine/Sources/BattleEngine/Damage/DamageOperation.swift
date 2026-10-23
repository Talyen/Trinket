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

    private enum StatusTick: Equatable, Hashable, Sendable {
        case secondary, natural
    }

    private enum CardRepeatRole: Equatable, Hashable, Sendable {
        case none, capture, replay
    }

    private enum ElementalPayoff: Equatable, Hashable, Sendable {
        case immediate, afterAttachment
    }

    private enum Kind: Equatable, Hashable, Sendable {
        case attack(AbilityTier, AttackOrigin)
        case effect
        case periodic(StatusTick)
        case reaction(ReactionCause)
        case copiedReaction
        case redirected
        case elementalReaction
        case healthCost
    }

    private let kind: Kind
    private let scaling: Scaling
    private let accuracy: Accuracy
    public var abilityCriticalChanceBonus: Double = 0
    public var guaranteedCriticalIfEnemyBuffed = false
    public var guaranteedCritical = false
    public var abilityHasLeech = false
    package var isThornsDamage = false
    private var elementalPayoff: ElementalPayoff = .immediate
    private var cardRepeatRole: CardRepeatRole = .none

    var settlesElementalImmediately: Bool {
        elementalPayoff == .immediate
    }

    var isNaturalStatusTick: Bool {
        kind == .periodic(.natural)
    }

    var isCopiedDamage: Bool {
        kind == .copiedReaction
    }

    var isRedirected: Bool {
        kind == .redirected
    }

    static let elementalReaction = Self(kind: .elementalReaction, scaling: .resolved, accuracy: .unavoidable)

    var isElementalReaction: Bool {
        kind == .elementalReaction
    }

    var canInitiateElementalReaction: Bool {
        switch kind {
        case .attack(_, .ability), .attack(_, .card), .attack(_, .ordinaryCard): true
        default: false
        }
    }

    var partnerFirstAttackBonus = 0
    var capturesCardRepeat: Bool {
        cardRepeatRole != .none
    }

    var isResolvedCardRepeat: Bool {
        cardRepeatRole == .replay
    }

    func capturingCardRepeat(_ capture: Bool) -> Self {
        var operation = self
        operation.cardRepeatRole = capture ? (usesResolvedOutgoingDamage ? .replay : .capture) : .none
        return operation
    }

    func replayingCardDamage(critical: Bool) -> Self {
        var operation = repeated(origin: .cardRepeat, scaling: .resolved, guaranteedCritical: critical)
        operation.cardRepeatRole = .replay
        return operation
    }

    func settlingElementalAfterAttachment() -> Self {
        var operation = self
        operation.elementalPayoff = .afterAttachment
        return operation
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

    static let copiedReaction = Self(kind: .copiedReaction, scaling: .resolved, accuracy: .unavoidable)
    static let redirected = Self(kind: .redirected, scaling: .resolved, accuracy: .unavoidable)

    public static let periodic = Self(kind: .periodic(.secondary), scaling: .statsAndItems, accuracy: .unavoidable)
    static let resolvedPeriodic = Self(kind: .periodic(.secondary), scaling: .resolved, accuracy: .unavoidable)

    static func statusTick(scaling: Scaling, natural: Bool) -> Self {
        Self(kind: .periodic(natural ? .natural : .secondary), scaling: scaling, accuracy: .unavoidable)
    }

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
        if case .periodic = kind {
            true
        } else {
            false
        }
    }

    var isHealthCost: Bool {
        kind == .healthCost
    }

    var causedByDodge: Bool {
        kind == .reaction(.dodge)
    }

    var isRetaliation: Bool {
        switch kind {
        case .elementalReaction, .reaction, .copiedReaction, .redirected, .periodic: true
        case .attack(_, .counterattack), .attack(_, .repeatedAttack),
             .attack(_, .cardRepeat), .attack(_, .criticalRepeat): true
        default: false
        }
    }

    var isPrimaryAttack: Bool {
        isAttackHit && !isRetaliation
    }

    var allowsDamageRewards: Bool {
        !isRetaliation || isCounterattack
    }

    func allowsKeywordReactions(for keyword: Keyword?) -> Bool {
        allowsDamageRewards || keyword == .freeze
            || (isThornsDamage && keyword == .holy) || (isPeriodic && keyword == .burn)
    }

    var isCounterattack: Bool {
        if case .attack(_, .counterattack) = kind {
            return true
        }
        return false
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
        let repeatedKind: Kind = switch kind {
        case let .attack(tier, _): .attack(tier, origin)
        case .periodic: .periodic(.secondary)
        default: kind
        }
        return Self(
            kind: repeatedKind, scaling: scaling ?? self.scaling, accuracy: accuracy,
            abilityCriticalChanceBonus: abilityCriticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: guaranteedCriticalIfEnemyBuffed,
            guaranteedCritical: guaranteedCritical ?? self.guaranteedCritical,
            abilityHasLeech: abilityHasLeech, isThornsDamage: isThornsDamage,
            elementalPayoff: elementalPayoff,
        )
    }
}
