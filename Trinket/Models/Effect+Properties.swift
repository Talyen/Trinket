import Foundation

/// One-to-one categorization of every `Effect` case. Used by handler dispatch
/// tables and per-effect summary builders instead of pattern-matching on the
/// enum directly.
enum EffectKind: Hashable {
    case burn
    case poison
    case bleed
    case prevention
    case preventionBuildup
    case shield
    case mitigation
    case instantHeal
    case leech
    case resourceGain
    case cleanse
    case cleanseRandom
    case dealDamage
    case halveMitigation
    case dodge
}

extension Effect {
    /// Discriminator for dispatch tables. New `Effect` cases must add a
    /// matching `EffectKind` case and extend this switch.
    var kind: EffectKind {
        switch self {
        case .burn: return .burn
        case .poison: return .poison
        case .bleed: return .bleed
        case .prevention: return .prevention
        case .preventionBuildup: return .preventionBuildup
        case .shield: return .shield
        case .mitigation: return .mitigation
        case .instantHeal: return .instantHeal
        case .leech: return .leech
        case .resourceGain: return .resourceGain
        case .cleanse: return .cleanse
        case .cleanseRandom: return .cleanseRandom
        case .dealDamage: return .dealDamage
        case .halveMitigation: return .halveMitigation
        case .dodge: return .dodge
        }
    }

    /// True when this effect represents a debuff that `cleanse` is allowed to
    /// strip. Mirrors the prior `BattleState.isRemovableDebuff(_:)` definition
    /// so the existing tests continue to pass.
    var isRemovableDebuff: Bool {
        switch self {
        case .burn, .poison, .bleed, .prevention, .preventionBuildup:
            return true
        case .shield, .mitigation, .leech, .cleanse, .dodge,
             .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation:
            return false
        }
    }

    /// True when this effect occupies a slot on the combatant and ticks down
    /// its `remainingTicks` over time. Used by the "decrement duration" pass
    /// in `tickEffects`. Mirrors the prior `BattleState.isEffectType(_:)`
    /// definition.
    var isTickable: Bool {
        switch self {
        case .burn, .poison, .bleed, .prevention, .preventionBuildup,
             .shield, .mitigation, .leech, .cleanse, .dodge:
            return true
        case .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation:
            return false
        }
    }

    /// True when this effect resolves immediately and never occupies a slot
    /// on the combatant. Mirrors the prior `Effect.isInstant` definition.
    var isInstant: Bool {
        switch self {
        case .instantHeal, .resourceGain, .dealDamage, .cleanseRandom, .halveMitigation:
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

    /// True for a dodge-granting effect.
    var isDodge: Bool {
        if case .dodge = self { return true }
        return false
    }
}
