import Foundation
import TrinketCore
import TrinketContent

/// Lookup table of every `BattleEffectHandler`, keyed by `EffectKind`.
/// `performAction` resolves each targeted effect through this table instead
/// of a single inline switch.
public enum EffectHandlers {
    private static let handlerByKind: [EffectKind: any BattleEffectHandler] = [
        .burn: DecayingDoTHandler(keyword: .burn),
        .poison: DecayingDoTHandler(keyword: .poison),
        .bleed: BleedHandler(),
        .prevention: PreventionHandler(),
        .preventionBuildup: PreventionBuildupHandler(),
        .shield: ShieldHandler(),
        .mitigation: MitigationHandler(),
        .instantHeal: InstantHealHandler(),
        .leech: LeechHandler(),
        .resourceGain: ResourceGainHandler(),
        .cleanse: CleanseHandler(),
        .cleanseRandom: CleanseRandomHandler(),
        .purge: PurgeHandler(),
        .purgeRandom: PurgeRandomHandler(),
        .halveMitigation: HalveMitigationHandler(),
        .dodge: DodgeHandler()
    ]

    public static let all: [EffectKind: any BattleEffectHandler] = handlerByKind

    public static func handler(for kind: EffectKind) -> any BattleEffectHandler {
        handlerByKind[kind]!
    }

    private static let allHandlers: [any BattleEffectHandler] = EffectKind.allCases.compactMap { handlerByKind[$0] }
}
