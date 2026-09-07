import TrinketContent
import TrinketCore

package struct DamageTargetStatus {
    public var isFrozen = false
    public var isStunned = false
    public var isBurning = false
    public var isPoisoned = false
    public var isBleeding = false

    init() {}

    init(for combatant: Combatant, in context: BattleState) {
        for active in context.roster.activeEffects(for: combatant) {
            switch active.effect.keyword {
            case .burn: isBurning = true
            case .poison: isPoisoned = true
            case .bleed: isBleeding = true
            case .freeze where active.effect.isActionSkipPending: isFrozen = true
            case .stun where active.effect.isActionSkipPending: isStunned = true
            default: break
            }
        }
    }
}

package struct DamageResolutionState {
    public let amount: Int
    public let combatant: Combatant
    public let sourceActorID: String?
    public let damageKeyword: Keyword?

    func partySource(in context: BattleState) -> CombatantRuntime? {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy else { return nil }
        return source
    }

    public let options: DamageOptions

    public var remaining: Int = 0

    public var dealt: Int = 0

    public var buildupDamage: Int = 0

    public var statBonus: Int = 0
    public var itemBonus: Int = 0

    public var activeEffects: [ActiveEffect] = []

    public var healthLost: Int = 0

    public var damageEvents: [ActionEvent] = []

    var heroCardBlockIgnore = 0
    var heroCardBlockBroken = false
    var uniqueOutgoingDamage = 0
    var uniqueEnemyBlock = 0
    public var blockedAmount: Int = 0

    public var targetStatus = DamageTargetStatus()

    public var isDodged: Bool = false

    public var isCritical: Bool = false

    public var markedBonusApplied: Bool = false

    public init(
        amount: Int,
        combatant: Combatant,
        sourceActorID: String?,
        damageKeyword: Keyword?,
        options: DamageOptions,
    ) {
        self.amount = amount
        self.combatant = combatant
        self.sourceActorID = sourceActorID
        self.damageKeyword = damageKeyword
        self.options = options
    }
}
