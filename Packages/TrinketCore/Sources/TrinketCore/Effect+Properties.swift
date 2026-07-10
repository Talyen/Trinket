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
    case mitigation
    case instantHeal
    case leech
    case resourceGain
    case drawCards
    case cleanse
    case cleanseRandom
    case purge
    case purgeRandom
    case halveMitigation
    case deathsDoor
    case haste
    case thorns
    case marked
    case criticalChanceBonus
    case restoreManaOnHit
    case damageKeywordOverride
}

public extension Effect {
    /// Discriminator for dispatch tables. New `Effect` cases must add a
    /// matching `EffectKind` case and extend this switch.
    var kind: EffectKind {
        switch self {
        case .burn: return .burn
        case .poison: return .poison
        case .bleed: return .bleed
        case .controlMeter: return .controlMeter
        case .shield: return .shield
        case .mitigation: return .mitigation
        case .instantHeal: return .instantHeal
        case .leech: return .leech
        case .resourceGain: return .resourceGain
        case .drawCards: return .drawCards
        case .cleanse: return .cleanse
        case .cleanseRandom: return .cleanseRandom
        case .purge: return .purge
        case .purgeRandom: return .purgeRandom
        case .halveMitigation: return .halveMitigation
        case .deathsDoor: return .deathsDoor
        case .haste: return .haste
        case .thorns: return .thorns
        case .marked: return .marked
        case .criticalChanceBonus: return .criticalChanceBonus
        case .restoreManaOnHit: return .restoreManaOnHit
        case .damageKeywordOverride: return .damageKeywordOverride
        }
    }

    /// True when this effect represents a debuff that `cleanse` is allowed to
    /// strip from allies.
    var isRemovableDebuff: Bool {
        switch self {
        case .burn, .poison, .bleed, .controlMeter, .marked:
            return true
        case .shield, .mitigation, .leech, .cleanse, .purge,
             .instantHeal, .resourceGain, .drawCards, .cleanseRandom, .purgeRandom, .halveMitigation, .deathsDoor,
             .haste, .thorns, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride:
            return false
        }
    }

    /// True when this effect represents a buff that `purge` is allowed to
    /// strip from enemies.
    var isRemovableBuff: Bool {
        switch self {
        case .shield, .mitigation, .leech, .haste, .thorns, .criticalChanceBonus, .restoreManaOnHit,
             .damageKeywordOverride:
            return true
        default:
            return false
        }
    }

    /// True when this effect occupies a slot on the combatant and ticks down
    /// its `remainingTicks` over time. Used by the "decrement duration" pass
    /// in `tickEffects`.
    var isTickable: Bool {
        switch self {
        case .burn, .poison, .bleed, .controlMeter,
             .shield, .mitigation, .leech, .deathsDoor,
             .haste, .thorns, .marked, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride:
            return true
        case .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveMitigation:
            return false
        }
    }

    /// True when this effect resolves immediately and never occupies a slot
    /// on the combatant.
    var isInstant: Bool {
        switch self {
        case .instantHeal, .resourceGain, .drawCards, .cleanse, .cleanseRandom,
             .purge, .purgeRandom, .halveMitigation:
            return true
        default:
            return false
        }
    }

    /// True for burn and poison, which decay their potency each tick instead
    /// of consuming duration.
    var isDecayingDoT: Bool {
        switch self {
        case .burn, .poison:
            return true
        default:
            return false
        }
    }

    /// True for bleed, which tracks its own duration.
    var isBleed: Bool {
        if case .bleed = self { return true }
        return false
    }

    /// Amount and threshold for `.controlMeter`, if applicable.
    var controlMeterValues: (amount: Int, threshold: Int)? {
        guard case let .controlMeter(_, amount, threshold) = self else { return nil }
        return (amount, threshold)
    }

    /// True when the control meter is full and the target's next action will
    /// be skipped (Stunned / Frozen).
    var isActionSkipPending: Bool {
        guard let values = controlMeterValues else { return false }
        return values.threshold > 0 && values.amount >= values.threshold
    }
}
