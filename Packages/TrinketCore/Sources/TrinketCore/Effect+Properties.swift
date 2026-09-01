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
    case hemorrhage
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
        case .hemorrhage: .hemorrhage
        }
    }

    private var behaviorMetadata: EffectBehaviorMetadata {
        EffectMetadata.behavior(for: kind)
    }

    var isRemovableDebuff: Bool {
        behaviorMetadata.isRemovableDebuff
    }

    var isRemovableBuff: Bool {
        behaviorMetadata.isRemovableBuff
    }

    var advancesEachTurn: Bool {
        behaviorMetadata.advancesEachTurn
    }

    var isInstant: Bool {
        behaviorMetadata.isInstant
    }

    var isDecayingDoT: Bool {
        behaviorMetadata.isDecayingDoT
    }

    var isBleed: Bool {
        behaviorMetadata.isBleed
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
