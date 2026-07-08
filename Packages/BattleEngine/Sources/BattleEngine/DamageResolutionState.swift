import Foundation
import TrinketContent
import TrinketCore

/// Working state threaded through the named damage-resolution steps in
/// `BattleEngineContext.resolveDamage`. Each step mutates this struct in place; the
/// orchestrator reads the final `healthLost` and `damageEvents` once the
/// pipeline completes.
package struct DamageResolutionState {
    public let amount: Int
    public let combatant: Combatant
    public let sourceActorID: String?
    public let damageKeyword: Keyword?
    public let applyStatBonus: Bool
    public let applyItemBonus: Bool
    public let applyDodge: Bool
    public let abilityCriticalChanceBonus: Double
    public let guaranteedCriticalIfEnemyBuffed: Bool
    public let isRetaliation: Bool
    public let qualifiesForAmbush: Bool

    /// Damage remaining after each step. `BonusStep` initializes this to
    /// `amount + statBonus + itemBonus`; each subsequent step decrements it.
    public var remaining: Int = 0

    /// Total damage after stat + item bonuses, before shields and mitigation.
    public var dealt: Int = 0

    /// Post-mitigation (and post-crit) damage before shields. Control-meter
    /// buildup uses this value so fully blocked hits still charge stun/freeze.
    public var buildupDamage: Int = 0

    /// Stat and item bonus components used by the control-meter buildup step.
    public var statBonus: Int = 0
    public var itemBonus: Int = 0

    /// Working copy of the target's active effects. Shield absorption mutates
    /// this copy after mitigation and item reduction; take-damage commits it
    /// back to the roster.
    public var activeEffects: [ActiveEffect] = []

    /// Health actually subtracted by the take-damage step.
    public var healthLost: Int = 0

    /// Accumulated events emitted by the dodge, shield, and control-meter steps.
    public var damageEvents: [ActionEvent] = []

    /// Set to `true` by the dodge gate when the incoming attack is dodged;
    /// the orchestrator then short-circuits and returns `(0, damageEvents)`.
    public var isDodged: Bool = false

    /// Set to `true` by the critical gate when the hit critically strikes.
    public var isCritical: Bool = false

    /// Set to `true` when marked bonus damage is applied.
    public var markedBonusApplied: Bool = false

    public init(
        amount: Int,
        combatant: Combatant,
        sourceActorID: String?,
        damageKeyword: Keyword?,
        applyStatBonus: Bool,
        applyItemBonus: Bool,
        applyDodge: Bool,
        abilityCriticalChanceBonus: Double = 0,
        guaranteedCriticalIfEnemyBuffed: Bool = false,
        isRetaliation: Bool = false,
        qualifiesForAmbush: Bool = false
    ) {
        self.amount = amount
        self.combatant = combatant
        self.sourceActorID = sourceActorID
        self.damageKeyword = damageKeyword
        self.applyStatBonus = applyStatBonus
        self.applyItemBonus = applyItemBonus
        self.applyDodge = applyDodge
        self.abilityCriticalChanceBonus = abilityCriticalChanceBonus
        self.guaranteedCriticalIfEnemyBuffed = guaranteedCriticalIfEnemyBuffed
        self.isRetaliation = isRetaliation
        self.qualifiesForAmbush = qualifiesForAmbush
    }
}
