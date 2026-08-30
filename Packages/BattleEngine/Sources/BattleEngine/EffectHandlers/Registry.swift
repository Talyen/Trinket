import Foundation
import TrinketContent
import TrinketCore

public enum EffectHandlers {
    public static let all: [EffectKind: any BattleEffectHandler] = [
        .burn: DecayingDoTHandler(keyword: .burn, kind: .burn),
        .poison: DecayingDoTHandler(keyword: .poison, kind: .poison),
        .bleed: BleedHandler(),
        .controlMeter: ControlMeterHandler(),
        .shield: BlockBuffHandler(),
        .instantHeal: InstantHealHandler(),
        .resourceGain: ResourceGainHandler(),
        .drawCards: DrawCardsHandler(),
        .drawAndPlayCards: DrawAndPlayCardsHandler(),
        .cleanse: CleansePurgeHandler(mode: .cleanse, kind: .cleanse),
        .cleanseHealPerDebuff: CleansePurgeHandler(mode: .cleanse, kind: .cleanseHealPerDebuff),
        .cleanseRandom: CleansePurgeHandler(mode: .cleanseRandom, kind: .cleanseRandom),
        .purge: CleansePurgeHandler(mode: .purge, kind: .purge),
        .purgeRandom: CleansePurgeHandler(mode: .purgeRandom, kind: .purgeRandom),
        .halveShield: HalveShieldHandler(),
        .deathsDoor: DeathsDoorHandler(),
        .thorns: ThornsHandler(),
        .marked: MarkedHandler(),
        .criticalChanceBonus: CriticalChanceBonusHandler(),
        .restoreManaOnHit: RestoreManaOnHitHandler(),
        .damageKeywordOverride: DamageKeywordOverrideHandler(),
        .nextHolyStrike: FlagEffectHandler(
            flag: .nextHolyStrike,
            appliedEffectKind: .nextHolyStrikeApplied,
            amount: 0,
            keyword: .holy,
            summaryText: EffectMetadata.requiredBattleSummaryPhrase(for: .nextHolyStrike),
        ),
        .nextStrikeDouble: FlagEffectHandler(
            flag: .nextStrikeDouble,
            appliedEffectKind: .nextStrikeDoubleApplied,
            amount: 0,
            keyword: .physical,
            summaryText: EffectMetadata.requiredBattleSummaryPhrase(for: .nextStrikeDouble),
        ),
        .evadeNextHit: FlagEffectHandler(
            flag: .evadeNextHit,
            appliedEffectKind: .evadeNextHitApplied,
            amount: 0,
            keyword: .dodge,
            summaryText: EffectMetadata.requiredBattleSummaryPhrase(for: .evadeNextHit),
        ),
        .convertManaToBlock: ShieldFromResourceHandler(mode: .convertManaToBlock, kind: .convertManaToBlock),
        .shieldFromMana: ShieldFromResourceHandler(mode: .shieldFromMana, kind: .shieldFromMana),
        .shieldFromHalfMana: ShieldFromResourceHandler(mode: .shieldFromHalfMana, kind: .shieldFromHalfMana),
        .shieldFromGold: ShieldFromResourceHandler(mode: .shieldFromGold, kind: .shieldFromGold),
        .maximumManaBonus: MaximumManaBonusHandler(),
        .nextStrikeCritical: FlagEffectHandler(
            flag: .nextStrikeCritical,
            appliedEffectKind: .criticalChanceApplied,
            amount: 100,
            keyword: .physical,
            summaryText: EffectMetadata.requiredBattleSummaryPhrase(for: .nextStrikeCritical),
        ),
        .freezeNextAttacker: FlagEffectHandler(
            flag: .freezeNextAttacker,
            appliedEffectKind: .controlApplied,
            amount: 0,
            keyword: .freeze,
            summaryText: EffectMetadata.requiredBattleSummaryPhrase(for: .freezeNextAttacker),
        ),
        .onHitDamage: OnHitDamageHandler(),
        .multiplyDoT: MultiplyDoTHandler(),
        .recurringDamage: RecurringDamageHandler(),
        .avatar: AvatarHandler(),
        .revive: ReviveHandler(),
        .damageReductionPercent: TimedDebuffHandler(kind: .damageReductionPercent),
        .damageReductionFlat: TimedDebuffHandler(kind: .damageReductionFlat),
        .strengthReduction: TimedDebuffHandler(kind: .strengthReduction),
        .hemorrhage: HemorrhageHandler(),
    ]

    public static func handler(for kind: EffectKind) -> (any BattleEffectHandler)? {
        all[kind]
    }
}
