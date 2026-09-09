import Foundation

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
    case panacea
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
    case nextBurnBonus
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
    case detonateDoT
    case recurringDamage
    case avatar
    case revive
    case damageReductionPercent
    case damageReductionFlat
    case healingReductionPercent
    case hemorrhage
}

public extension EffectKind {
    var isRemovableDebuff: Bool {
        behavior.isRemovableDebuff
    }

    var isRemovableBuff: Bool {
        behavior.isRemovableBuff
    }

    var advancesEachTurn: Bool {
        behavior.advancesEachTurn
    }

    var isInstant: Bool {
        behavior.isInstant
    }

    var isDecayingDoT: Bool {
        behavior.isDecayingDoT
    }

    var isBleed: Bool {
        behavior.isBleed
    }

    private var behavior: (
        isRemovableDebuff: Bool,
        isRemovableBuff: Bool,
        advancesEachTurn: Bool,
        isInstant: Bool,
        isDecayingDoT: Bool,
        isBleed: Bool,
    ) {
        switch self {
        case .burn, .poison:
            (true, false, true, false, true, false)
        case .bleed:
            (true, false, true, false, false, true)
        case .controlMeter:
            (true, false, true, false, false, false)
        case .shield:
            (false, true, false, false, false, false)
        case .instantHeal, .resourceGain, .drawCards, .drawAndPlayCards,
             .cleanse, .cleanseHealPerDebuff, .panacea, .cleanseRandom,
             .purge, .purgeRandom, .halveShield,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold,
             .multiplyDoT, .detonateDoT, .revive:
            (false, false, false, true, false, false)
        case .deathsDoor:
            (false, false, true, false, false, false)
        case .thorns, .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
             .nextStrikeCritical, .freezeNextAttacker, .onHitDamage:
            (false, true, false, false, false, false)
        case .maximumManaBonus:
            (false, true, false, true, false, false)
        case .marked, .recurringDamage, .damageReductionPercent,
             .damageReductionFlat, .healingReductionPercent:
            (true, false, true, false, false, false)
        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .avatar:
            (false, true, true, false, false, false)
        case .hemorrhage:
            (true, false, false, false, false, false)
        }
    }

    static func requiredBattleSummaryPhrase(for kind: EffectKind) -> String {
        guard let phrase = battleSummaryPhrase(for: kind) else {
            preconditionFailure("Every flag effect needs a battle summary phrase; missing \(kind)")
        }
        return phrase
    }

    static func battleSummaryPhrase(for kind: EffectKind) -> String? {
        switch kind {
        case .nextHolyStrike:
            "Holy Strike: Next attack deals double Holy damage and applies Burning."
        case .nextStrikeDouble:
            "Double Strike: Next attack deals double damage."
        case .evadeNextHit:
            "Evasion: Dodges the next attack."
        case .nextStrikeCritical:
            "Critical Focus: Next attack is a guaranteed Critical Hit."
        case .freezeNextAttacker:
            "Glacial Ward: Freezes the next attacker."
        default:
            nil
        }
    }
}

public extension Effect {
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
        case .panacea: .panacea
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
        case .nextBurnBonus: .nextBurnBonus
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
        case .detonateDoT: .detonateDoT
        case .recurringDamage: .recurringDamage
        case .avatar: .avatar
        case .revive: .revive
        case .damageReductionPercent: .damageReductionPercent
        case .damageReductionFlat: .damageReductionFlat
        case .healingReductionPercent: .healingReductionPercent
        case .hemorrhage: .hemorrhage
        }
    }

    var isRemovableDebuff: Bool {
        kind.isRemovableDebuff
    }

    var isRemovableBuff: Bool {
        kind.isRemovableBuff
    }

    var advancesEachTurn: Bool {
        kind.advancesEachTurn
    }

    var isInstant: Bool {
        kind.isInstant
    }

    var isDecayingDoT: Bool {
        kind.isDecayingDoT
    }

    var isBleed: Bool {
        kind.isBleed
    }

    var controlMeterValues: (amount: Int, threshold: Int)? {
        guard case let .controlMeter(_, amount, threshold) = self else { return nil }
        return (amount, threshold)
    }

    var isActionSkipPending: Bool {
        guard let values = controlMeterValues else { return false }
        return values.threshold > 0 && values.amount >= values.threshold
    }

    var canApplyToDefeatedTarget: Bool {
        switch self {
        case .resourceGain(.gold, _), .drawCards, .revive:
            true
        default:
            false
        }
    }
}
