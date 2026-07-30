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
        .nextHolyStrike: NextHolyStrikeHandler(),
        .nextStrikeDouble: NextStrikeDoubleHandler(),
        .evadeNextHit: EvadeNextHitHandler(),
        .convertManaToBlock: ConvertManaToBlockHandler(),
        .shieldFromMana: ShieldFromManaHandler(),
        .shieldFromHalfMana: ShieldFromHalfManaHandler(),
        .shieldFromGold: ShieldFromGoldHandler(),
        .maximumManaBonus: MaximumManaBonusHandler(),
        .nextStrikeCritical: NextStrikeCriticalHandler(),
        .freezeNextAttacker: FreezeNextAttackerHandler(),
        .freezeOnHit: FreezeOnHitHandler(),
        .multiplyDoT: MultiplyDoTHandler(),
        .recurringDamage: RecurringDamageHandler(),
        .holyDamageBonusFromBlock: HolyDamageBonusFromBlockHandler(),
        .revive: ReviveHandler(),
    ]

    public static func handler(for kind: EffectKind) -> (any BattleEffectHandler)? {
        all[kind]
    }
}
