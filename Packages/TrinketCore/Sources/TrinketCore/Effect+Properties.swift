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
    case nextStrikeLeech
    case partyPhysicalBonus
    case freezeNextAttacker
    case onHitDamage
    case multiplyDoT
    case detonateDoT
    case recurringDamage
    case avatar
    case blessedAegis
    case revive
    case damageReductionPercent
    case damageReductionFlat
    case healingReductionPercent
    case hemorrhage
}

public extension EffectKind {
    /// Lifecycle matrix: `Effect.durationTurns == 0` covers both instant effects
    /// (resolved immediately, never stored) and indefinite effects (stored until
    /// removed or consumed). Disambiguate with `isInstant`, `advancesEachTurn`,
    /// and the removability flags below.
    ///
    /// Known quirks, documented here rather than reclassified, pending battle-owner review:
    /// - `.hemorrhage` is a removable debuff with zero duration that never advances.
    /// - `.maximumManaBonus` is both instant and a removable buff.
    /// - `.blessedAegis` is instant with neither buff nor debuff flag, unlike the
    ///   otherwise similar `thorns`/`onHitDamage` wards.
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

    /// Flag bundle for one effect kind. Members default to false so each case below
    /// names only the flags it sets; the single exhaustive switch keeps the compiler
    /// checking newly added kinds.
    private struct Behavior {
        var isRemovableDebuff = false
        var isRemovableBuff = false
        var advancesEachTurn = false
        var isInstant = false
        var isDecayingDoT = false
        var isBleed = false
    }

    private var behavior: Behavior {
        switch self {
        case .burn, .poison:
            Behavior(isRemovableDebuff: true, advancesEachTurn: true, isDecayingDoT: true)
        case .bleed:
            Behavior(isRemovableDebuff: true, advancesEachTurn: true, isBleed: true)
        case .controlMeter:
            Behavior(isRemovableDebuff: true, advancesEachTurn: true)
        case .shield:
            Behavior(isRemovableBuff: true)
        case .instantHeal, .resourceGain, .drawCards, .drawAndPlayCards,
             .cleanse, .cleanseHealPerDebuff, .panacea, .cleanseRandom,
             .purge, .purgeRandom, .halveShield,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold,
             .multiplyDoT, .detonateDoT, .revive, .blessedAegis:
            Behavior(isInstant: true)
        case .deathsDoor:
            Behavior(advancesEachTurn: true)
        case .thorns, .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
             .nextStrikeCritical, .nextStrikeLeech, .partyPhysicalBonus, .freezeNextAttacker, .onHitDamage:
            Behavior(isRemovableBuff: true)
        case .maximumManaBonus:
            Behavior(isRemovableBuff: true, isInstant: true)
        case .marked, .recurringDamage, .damageReductionPercent,
             .damageReductionFlat, .healingReductionPercent:
            Behavior(isRemovableDebuff: true, advancesEachTurn: true)
        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .avatar:
            Behavior(isRemovableBuff: true, advancesEachTurn: true)
        case .hemorrhage:
            Behavior(isRemovableDebuff: true)
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
        case .nextStrikeLeech:
            "Leech Focus: Next attack Leeches."
        case .partyPhysicalBonus:
            "Sniff Out: Party's next attack deals additional Physical damage."
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
        case .nextStrikeLeech: .nextStrikeLeech
        case .partyPhysicalBonus: .partyPhysicalBonus
        case .freezeNextAttacker: .freezeNextAttacker
        case .onHitDamage: .onHitDamage
        case .multiplyDoT: .multiplyDoT
        case .detonateDoT: .detonateDoT
        case .recurringDamage: .recurringDamage
        case .avatar: .avatar
        case .blessedAegis: .blessedAegis
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
