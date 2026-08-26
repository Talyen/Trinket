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
        isBleed: Bool = false
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
        guard let metadata = behaviorTable[kind] else {
            preconditionFailure("Every EffectKind needs behavior metadata; missing \(kind)")
        }
        return metadata
    }

    /// Battle log summaries for flag-style effects. Parameterized effects build
    /// summaries from runtime values instead.
    public static func requiredBattleSummaryPhrase(for kind: EffectKind) -> String {
        guard let phrase = battleSummaryPhrases[kind] else {
            preconditionFailure("Every flag effect needs a battle summary phrase; missing \(kind)")
        }
        return phrase
    }

    private static let behaviorTable: [EffectKind: EffectBehaviorMetadata] = [
        .burn: .init(isRemovableDebuff: true, advancesEachTurn: true, isDecayingDoT: true),
        .poison: .init(isRemovableDebuff: true, advancesEachTurn: true, isDecayingDoT: true),
        .bleed: .init(isRemovableDebuff: true, advancesEachTurn: true, isBleed: true),
        .controlMeter: .init(isRemovableDebuff: true, advancesEachTurn: true),
        .shield: .init(isRemovableBuff: true),
        .instantHeal: .init(isInstant: true),
        .resourceGain: .init(isInstant: true),
        .drawCards: .init(isInstant: true),
        .drawAndPlayCards: .init(isInstant: true),
        .cleanse: .init(isInstant: true),
        .cleanseHealPerDebuff: .init(isInstant: true),
        .cleanseRandom: .init(isInstant: true),
        .purge: .init(isInstant: true),
        .purgeRandom: .init(isInstant: true),
        .halveShield: .init(isInstant: true),
        .deathsDoor: .init(advancesEachTurn: true),
        .thorns: .init(isRemovableBuff: true),
        .marked: .init(isRemovableDebuff: true, advancesEachTurn: true),
        .criticalChanceBonus: .init(isRemovableBuff: true, advancesEachTurn: true),
        .restoreManaOnHit: .init(isRemovableBuff: true, advancesEachTurn: true),
        .damageKeywordOverride: .init(isRemovableBuff: true, advancesEachTurn: true),
        .nextHolyStrike: .init(isRemovableBuff: true),
        .nextStrikeDouble: .init(isRemovableBuff: true),
        .evadeNextHit: .init(isRemovableBuff: true),
        .convertManaToBlock: .init(isInstant: true),
        .shieldFromMana: .init(isInstant: true),
        .shieldFromHalfMana: .init(isInstant: true),
        .shieldFromGold: .init(isInstant: true),
        .maximumManaBonus: .init(isRemovableBuff: true, isInstant: true),
        .nextStrikeCritical: .init(isRemovableBuff: true),
        .freezeNextAttacker: .init(isRemovableBuff: true),
        .onHitDamage: .init(isRemovableBuff: true),
        .multiplyDoT: .init(isInstant: true),
        .recurringDamage: .init(isRemovableDebuff: true, advancesEachTurn: true),
        .avatar: .init(isRemovableBuff: true, advancesEachTurn: true),
        .revive: .init(isInstant: true),
        .damageReductionPercent: .init(isRemovableDebuff: true, advancesEachTurn: true),
        .damageReductionFlat: .init(isRemovableDebuff: true, advancesEachTurn: true),
        .strengthReduction: .init(isRemovableDebuff: true, advancesEachTurn: true),
        .hemorrhage: .init(isRemovableDebuff: true),
    ]

    private static let battleSummaryPhrases: [EffectKind: String] = [
        .nextHolyStrike: "Holy Strike: next attack deals double Holy damage and applies Burning.",
        .nextStrikeDouble: "Double Strike: next attack deals double damage.",
        .evadeNextHit: "Evasion: dodge the next attack.",
        .nextStrikeCritical: "Critical Focus: next attack is a guaranteed Critical Hit.",
        .freezeNextAttacker: "Glacial Ward: freeze the next attacker.",
    ]
}
