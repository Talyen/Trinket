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
        .shield: DefensePoolBuffHandler(pool: .shield),
        .mitigation: DefensePoolBuffHandler(pool: .mitigation),
        .instantHeal: InstantHealHandler(),
        .leech: LeechHandler(),
        .resourceGain: ResourceGainHandler(),
        .drawCards: DrawCardsHandler(),
        .cleanse: CleansePurgeHandler(mode: .cleanse),
        .cleanseRandom: CleansePurgeHandler(mode: .cleanseRandom),
        .purge: CleansePurgeHandler(mode: .purge),
        .purgeRandom: CleansePurgeHandler(mode: .purgeRandom),
        .halveMitigation: HalveMitigationHandler(),
        .deathsDoor: DeathsDoorHandler(),
        .haste: HasteHandler(),
        .thorns: ThornsHandler(),
        .marked: MarkedHandler(),
        .criticalChanceBonus: CriticalChanceBonusHandler(),
        .restoreManaOnHit: RestoreManaOnHitHandler(),
        .damageKeywordOverride: DamageKeywordOverrideHandler(),
        .nextHolyStrike: NextHolyStrikeHandler()
    ]

    public static func handler(for kind: EffectKind) -> (any BattleEffectHandler)? {
        all[kind]
    }
}
