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
        behavior.contains(.removableDebuff)
    }

    var isRemovableBuff: Bool {
        behavior.contains(.removableBuff)
    }

    var advancesEachTurn: Bool {
        behavior.contains(.advancesEachTurn)
    }

    var isInstant: Bool {
        behavior.contains(.instant)
    }

    var isDecayingDoT: Bool {
        behavior.contains(.decayingDoT)
    }

    var isBleed: Bool {
        behavior.contains(.bleed)
    }

    /// Bitmask flag bundle for one effect kind. The single exhaustive switch keeps
    /// the compiler checking newly added kinds while queries compile down to bitwise operations.
    private struct Behavior: OptionSet {
        let rawValue: UInt8

        static let removableDebuff = Self(rawValue: 1 << 0)
        static let removableBuff = Self(rawValue: 1 << 1)
        static let advancesEachTurn = Self(rawValue: 1 << 2)
        static let instant = Self(rawValue: 1 << 3)
        static let decayingDoT = Self(rawValue: 1 << 4)
        static let bleed = Self(rawValue: 1 << 5)
    }

    private var behavior: Behavior {
        switch self {
        case .burn, .poison:
            [.removableDebuff, .advancesEachTurn, .decayingDoT]
        case .bleed:
            [.removableDebuff, .advancesEachTurn, .bleed]
        case .controlMeter:
            [.removableDebuff, .advancesEachTurn]
        case .shield:
            [.removableBuff]
        case .instantHeal, .resourceGain, .drawCards, .drawAndPlayCards,
             .cleanse, .cleanseHealPerDebuff, .panacea, .cleanseRandom,
             .purge, .purgeRandom, .halveShield,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold,
             .multiplyDoT, .detonateDoT, .revive, .blessedAegis:
            [.instant]
        case .deathsDoor:
            [.advancesEachTurn]
        case .thorns, .nextHolyStrike, .nextStrikeDouble, .nextBurnBonus, .evadeNextHit,
             .nextStrikeCritical, .nextStrikeLeech, .partyPhysicalBonus, .freezeNextAttacker, .onHitDamage:
            [.removableBuff]
        case .maximumManaBonus:
            [.removableBuff, .instant]
        case .marked, .recurringDamage, .damageReductionPercent,
             .damageReductionFlat, .healingReductionPercent:
            [.removableDebuff, .advancesEachTurn]
        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .avatar:
            [.removableBuff, .advancesEachTurn]
        case .hemorrhage:
            [.removableDebuff]
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
