import Foundation

/// Lookup table of every `BattleEffectHandler`, keyed by `EffectKind`.
/// `performAction` resolves each targeted effect through this table instead
/// of a single inline switch.
enum EffectHandlers {
    static let all: [EffectKind: any BattleEffectHandler] = Dictionary(
        uniqueKeysWithValues: allHandlers.map { ($0.kind, $0) }
    )

    /// Compiler-checked dispatch for a single `EffectKind`.
    static func handler(for kind: EffectKind) -> any BattleEffectHandler {
        switch kind {
        case .burn: DecayingDoTHandler(keyword: .burn)
        case .poison: DecayingDoTHandler(keyword: .poison)
        case .bleed: BleedHandler()
        case .prevention: PreventionHandler()
        case .preventionBuildup: PreventionBuildupHandler()
        case .shield: ShieldHandler()
        case .mitigation: MitigationHandler()
        case .instantHeal: InstantHealHandler()
        case .leech: LeechHandler()
        case .resourceGain: ResourceGainHandler()
        case .cleanse: CleanseHandler()
        case .cleanseRandom: CleanseRandomHandler()
        case .purge: PurgeHandler()
        case .purgeRandom: PurgeRandomHandler()
        case .halveMitigation: HalveMitigationHandler()
        case .dodge: DodgeHandler()
        }
    }

    private static let allHandlers: [any BattleEffectHandler] = EffectKind.allCases.map(handler(for:))
}
