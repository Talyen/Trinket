import Foundation
import TrinketContent
import TrinketCore

/// Target control/affliction flags captured once per damage resolution so
/// bonus/multiplier/shield steps share one effect scan instead of rescanning.
/// Steps that run after on-hit status applications must read live state instead.
package struct DamageTargetStatus {
    public var isFrozen = false
    public var isStunned = false
    public var isBurning = false
    public var isPoisoned = false
    public var isBleeding = false

    /// Empty until `DamagePipeline.run` captures the resolution-time snapshot.
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

/// Reaction depth limits. User-approved safety cap is 10 — chains should be
/// limited by mechanics (once-per-turn guards, isResolving* flags), not an
/// arbitrary shallow cap. Hit at 10 logs and truncates to avoid true infinite
/// recursion.
package enum ReactionScope {
    package static let maxTalentReactionDepth = 10
    package static let maxDotRecursionDepth = 10
    package static let maxDrawAndPlayDepth = 10
}

/// Working state threaded through the named damage-resolution steps in
/// `BattleState.resolveDamage`. Each step mutates this struct in place; the
/// orchestrator reads the final `healthLost` and `damageEvents` once the
/// pipeline completes.
///
/// Invariant: `buildupDamage` is post-mitigation, pre-shield damage captured
/// before `applyShieldAbsorption` so fully blocked hits still charge the
/// control meter. It must equal `remaining` just before shield absorption
/// (asserted in `applyMitigation`).
package struct DamageResolutionState {
    public let amount: Int
    public let combatant: Combatant
    public let sourceActorID: String?
    public let damageKeyword: Keyword?

    /// Party member source for talent-gated damage steps. Returns nil for enemy sources.
    func partySource(in context: BattleState) -> CombatantRuntime? {
        guard let sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              source.role != .enemy else { return nil }
        return source
    }

    /// Requested hit modifiers (bonuses, crit, dodge, reaction gating).
    public let options: DamageOptions

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

    /// Block absorbed by shields during this hit (Vampiric Touch leech base).
    public var blockedAmount: Int = 0

    /// Target status flags captured once before mutation-prone steps run.
    /// Populated by `DamagePipeline.run`; pre-mutation steps read this instead
    /// of rescanning active effects.
    public var targetStatus = DamageTargetStatus()

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
        options: DamageOptions
    ) {
        self.amount = amount
        self.combatant = combatant
        self.sourceActorID = sourceActorID
        self.damageKeyword = damageKeyword
        self.options = options
    }
}
