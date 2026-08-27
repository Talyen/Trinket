import Foundation

/// One-to-one categorization of every `Effect` case. Used by handler dispatch
/// tables and per-effect summary builders instead of pattern-matching on the
/// enum directly.
public enum EffectKind: Hashable, CaseIterable, Sendable {
    case burn
    case poison
    case bleed
    case controlMeter
    case shield
    case instantHeal
    case resourceGain
    case drawCards
    case drawAndPlayCards
    case cleanse
    case cleanseHealPerDebuff
    case cleanseRandom
    case purge
    case purgeRandom
    case halveShield
    case deathsDoor
    case thorns
    case marked
    case criticalChanceBonus
    case restoreManaOnHit
    case damageKeywordOverride
    case nextHolyStrike
    case nextStrikeDouble
    case evadeNextHit
    case convertManaToBlock
    case shieldFromMana
    case shieldFromHalfMana
    case shieldFromGold
    case maximumManaBonus
    case nextStrikeCritical
    case freezeNextAttacker
    case onHitDamage
    case multiplyDoT
    case recurringDamage
    case avatar
    case revive
    case damageReductionPercent
    case damageReductionFlat
    case strengthReduction
    case hemorrhage
}

public extension Effect {
    /// Discriminator for dispatch tables. New `Effect` cases must add a
    /// matching `EffectKind` case and extend this switch.
    var kind: EffectKind {
        switch self {
        case .burn: .burn
        case .poison: .poison
        case .bleed: .bleed
        case .controlMeter: .controlMeter
        case .shield: .shield
        case .instantHeal: .instantHeal
        case .resourceGain: .resourceGain
        case .drawCards: .drawCards
        case .drawAndPlayCards: .drawAndPlayCards
        case .cleanse: .cleanse
        case .cleanseHealPerDebuff: .cleanseHealPerDebuff
        case .cleanseRandom: .cleanseRandom
        case .purge: .purge
        case .purgeRandom: .purgeRandom
        case .halveShield: .halveShield
        case .deathsDoor: .deathsDoor
        case .thorns: .thorns
        case .marked: .marked
        case .criticalChanceBonus: .criticalChanceBonus
        case .restoreManaOnHit: .restoreManaOnHit
        case .damageKeywordOverride: .damageKeywordOverride
        case .nextHolyStrike: .nextHolyStrike
        case .nextStrikeDouble: .nextStrikeDouble
        case .evadeNextHit: .evadeNextHit
        case .convertManaToBlock: .convertManaToBlock
        case .shieldFromMana: .shieldFromMana
        case .shieldFromHalfMana: .shieldFromHalfMana
        case .shieldFromGold: .shieldFromGold
        case .maximumManaBonus: .maximumManaBonus
        case .nextStrikeCritical: .nextStrikeCritical
        case .freezeNextAttacker: .freezeNextAttacker
        case .onHitDamage: .onHitDamage
        case .multiplyDoT: .multiplyDoT
        case .recurringDamage: .recurringDamage
        case .avatar: .avatar
        case .revive: .revive
        case .damageReductionPercent: .damageReductionPercent
        case .damageReductionFlat: .damageReductionFlat
        case .strengthReduction: .strengthReduction
        case .hemorrhage: .hemorrhage
        }
    }

    private var behaviorMetadata: EffectBehaviorMetadata {
        EffectMetadata.behavior(for: kind)
    }

    /// True when this effect represents a debuff that `cleanse` is allowed to
    /// strip from allies.
    var isRemovableDebuff: Bool {
        behaviorMetadata.isRemovableDebuff
    }

    /// True when this effect represents a buff that `purge` is allowed to
    /// strip from enemies.
    var isRemovableBuff: Bool {
        behaviorMetadata.isRemovableBuff
    }

    /// True when this effect occupies a slot on the combatant and advances
    /// its `remainingTurns` over time.
    var advancesEachTurn: Bool {
        behaviorMetadata.advancesEachTurn
    }

    /// True when this effect resolves immediately and never occupies a slot
    /// on the combatant.
    var isInstant: Bool {
        behaviorMetadata.isInstant
    }

    /// True for burn and poison, which decay their potency each turn instead
    /// of consuming duration.
    var isDecayingDoT: Bool {
        behaviorMetadata.isDecayingDoT
    }

    /// True for bleed, which tracks its own duration.
    var isBleed: Bool {
        behaviorMetadata.isBleed
    }

    /// Amount and threshold for `.controlMeter`, if applicable.
    var controlMeterValues: (amount: Int, threshold: Int)? {
        guard case let .controlMeter(_, amount, threshold) = self else { return nil }
        return (amount, threshold)
    }

    /// True when the control meter is full (Stunned / Frozen status).
    ///
    /// A full meter shows status overlays and enables Shatter/Dazed-style
    /// conditions. Whether the next action is still queued to skip depends on
    /// `ActiveEffect.remainingTurns` — see `ActiveEffect.isAwaitingActionSkip`.
    var isActionSkipPending: Bool {
        guard let values = controlMeterValues else { return false }
        return values.threshold > 0 && values.amount >= values.threshold
    }

    /// True when the effect can target and apply to a defeated (0 HP) combatant.
    var canApplyToDefeatedTarget: Bool {
        switch self {
        case .resourceGain(.gold, _), .drawCards, .revive:
            true
        default:
            false
        }
    }
}
