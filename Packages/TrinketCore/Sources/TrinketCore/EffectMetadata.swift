import Foundation

public struct EffectBehaviorMetadata: Sendable, Equatable {
    let isRemovableDebuff: Bool
    let isRemovableBuff: Bool
    let advancesEachTurn: Bool
    let isInstant: Bool
    let isDecayingDoT: Bool
    let isBleed: Bool
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
        .burn: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: true,
            isBleed: false
        ),
        .poison: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: true,
            isBleed: false
        ),
        .bleed: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: true
        ),
        .controlMeter: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .shield: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .instantHeal: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .resourceGain: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .drawCards: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .drawAndPlayCards: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .cleanse: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .cleanseRandom: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .purge: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .purgeRandom: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .halveShield: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .deathsDoor: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .thorns: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .marked: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .criticalChanceBonus: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .restoreManaOnHit: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .damageKeywordOverride: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .nextHolyStrike: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .nextStrikeDouble: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .evadeNextHit: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .convertManaToBlock: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .shieldFromMana: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .shieldFromHalfMana: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .shieldFromGold: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .maximumManaBonus: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .nextStrikeCritical: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .freezeNextAttacker: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .onHitDamage: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .multiplyDoT: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .recurringDamage: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .avatar: .init(
            isRemovableDebuff: false,
            isRemovableBuff: true,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .revive: .init(
            isRemovableDebuff: false,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: true,
            isDecayingDoT: false,
            isBleed: false
        ),
        .damageReductionPercent: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .damageReductionFlat: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .strengthReduction: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: true,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
        .hemorrhage: .init(
            isRemovableDebuff: true,
            isRemovableBuff: false,
            advancesEachTurn: false,
            isInstant: false,
            isDecayingDoT: false,
            isBleed: false
        ),
    ]

    private static let battleSummaryPhrases: [EffectKind: String] = [
        .nextHolyStrike: "Holy Strike: next attack deals double Holy damage and applies Burning.",
        .nextStrikeDouble: "Double Strike: next attack deals double damage.",
        .evadeNextHit: "Evasion: dodge the next attack.",
        .nextStrikeCritical: "Critical Focus: next attack is a guaranteed Critical Hit.",
        .freezeNextAttacker: "Glacial Ward: freeze the next attacker.",
    ]
}
