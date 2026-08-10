import Foundation
import TrinketContent
import TrinketCore

/// Lookup table of every `BattleEffectHandler`, keyed by `EffectKind`.
/// `performAction` resolves each targeted effect through this table instead
/// of a single inline switch.
public enum EffectHandlers {
    public static let all: [EffectKind: any BattleEffectHandler] = [
        .burn: DecayingDoTHandler(keyword: .burn),
        .poison: DecayingDoTHandler(keyword: .poison),
        .bleed: BleedHandler(),
        .controlMeter: ControlMeterHandler(),
        .shield: DefensePoolBuffHandler(pool: .block),
        .instantHeal: InstantHealHandler(),
        .leech: LeechHandler(),
        .resourceGain: ResourceGainHandler(),
        .drawCards: DrawCardsHandler(),
        .cleanse: CleansePurgeHandler(mode: .cleanse),
        .cleanseRandom: CleansePurgeHandler(mode: .cleanseRandom),
        .purge: CleansePurgeHandler(mode: .purge),
        .purgeRandom: CleansePurgeHandler(mode: .purgeRandom),
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
            summaryText: "Next Holy Strike ready."
        ),
        .nextStrikeDouble: FlagEffectHandler(
            flag: .nextStrikeDouble,
            appliedEffectKind: .nextStrikeDoubleApplied,
            amount: 0,
            keyword: .physical,
            summaryText: "Next attack deals double damage."
        ),
        .evadeNextHit: FlagEffectHandler(
            flag: .evadeNextHit,
            appliedEffectKind: .evadeNextHitApplied,
            amount: 0,
            keyword: .dodge,
            summaryText: "Dodge the next attack."
        ),
        .convertManaToBlock: ShieldFromResourceHandler(mode: .convertManaToBlock),
        .shieldFromMana: ShieldFromResourceHandler(mode: .shieldFromMana),
        .shieldFromHalfMana: ShieldFromResourceHandler(mode: .shieldFromHalfMana),
        .shieldFromGold: ShieldFromResourceHandler(mode: .shieldFromGold),
        .maximumManaBonus: MaximumManaBonusHandler(),
        .nextStrikeCritical: FlagEffectHandler(
            flag: .nextStrikeCritical,
            appliedEffectKind: .criticalChanceApplied,
            amount: 100,
            keyword: .physical,
            summaryText: "Next attack is a guaranteed Critical Hit."
        ),
        .freezeNextAttacker: FlagEffectHandler(
            flag: .freezeNextAttacker,
            appliedEffectKind: .controlApplied,
            amount: 0,
            keyword: .freeze,
            summaryText: "Freeze the next attacker."
        ),
        .freezeOnHit: FreezeOnHitHandler(),
        .multiplyDoT: MultiplyDoTHandler(),
        .recurringDamage: RecurringDamageHandler(),
        .revive: ReviveHandler(),
    ]

    public static func handler(for kind: EffectKind) -> (any BattleEffectHandler)? {
        all[kind]
    }
}
