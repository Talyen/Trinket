import Foundation

public struct EffectBehaviorMetadata: Sendable, Equatable {
    let isRemovableDebuff: Bool
    let isRemovableBuff: Bool
    let advancesEachTurn: Bool
    let isInstant: Bool
    let isDecayingDoT: Bool
    let isBleed: Bool

    init(
        isRemovableDebuff: Bool = false,
        isRemovableBuff: Bool = false,
        advancesEachTurn: Bool = false,
        isInstant: Bool = false,
        isDecayingDoT: Bool = false,
        isBleed: Bool = false,
    ) {
        self.isRemovableDebuff = isRemovableDebuff
        self.isRemovableBuff = isRemovableBuff
        self.advancesEachTurn = advancesEachTurn
        self.isInstant = isInstant
        self.isDecayingDoT = isDecayingDoT
        self.isBleed = isBleed
    }
}

public enum EffectMetadata {
    public static func behavior(for kind: EffectKind) -> EffectBehaviorMetadata {
        switch kind {
        case .burn:
            .init(isRemovableDebuff: true, advancesEachTurn: true, isDecayingDoT: true)
        case .poison:
            .init(isRemovableDebuff: true, advancesEachTurn: true, isDecayingDoT: true)
        case .bleed:
            .init(isRemovableDebuff: true, advancesEachTurn: true, isBleed: true)
        case .controlMeter:
            .init(isRemovableDebuff: true, advancesEachTurn: true)
        case .shield:
            .init(isRemovableBuff: true)
        case .instantHeal, .resourceGain, .drawCards, .drawAndPlayCards,
             .cleanse, .cleanseHealPerDebuff, .panacea, .cleanseRandom,
             .purge, .purgeRandom, .halveShield,
             .convertManaToBlock, .shieldFromMana, .shieldFromHalfMana, .shieldFromGold,
             .multiplyDoT, .revive:
            .init(isInstant: true)
        case .deathsDoor:
            .init(advancesEachTurn: true)
        case .thorns, .nextHolyStrike, .nextStrikeDouble, .evadeNextHit,
             .nextStrikeCritical, .freezeNextAttacker, .onHitDamage:
            .init(isRemovableBuff: true)
        case .maximumManaBonus:
            .init(isRemovableBuff: true, isInstant: true)
        case .marked, .recurringDamage, .damageReductionPercent,
             .damageReductionFlat, .strengthReduction:
            .init(isRemovableDebuff: true, advancesEachTurn: true)
        case .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .avatar:
            .init(isRemovableBuff: true, advancesEachTurn: true)
        case .hemorrhage:
            .init(isRemovableDebuff: true)
        }
    }

    public static func requiredBattleSummaryPhrase(for kind: EffectKind) -> String {
        guard let phrase = battleSummaryPhrase(for: kind) else {
            preconditionFailure("Every flag effect needs a battle summary phrase; missing \(kind)")
        }
        return phrase
    }

    public static func battleSummaryPhrase(for kind: EffectKind) -> String? {
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
