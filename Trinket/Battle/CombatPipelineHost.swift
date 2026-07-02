import Foundation

/// Shared mutation surface used by `CombatPipeline` and battle effect handlers.
protocol CombatPipelineHost {
    var roster: BattleRoster { get set }
    var rng: SeededRandomNumberGenerator { get set }
    var nextEffectID: Int { get set }
    var nextEventID: Int { get set }
    var events: [ActionEvent] { get set }

    func modifiers(for combatantID: String) -> CombatModifierProfile
    mutating func nextEvent(
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind?,
        actorName: String,
        abilityName: String,
        target: Combatant,
        amount: Int,
        keyword: Keyword,
        appliedEffectSummaries: [String],
        milestone: ActionEvent.Milestone?
    ) -> ActionEvent
    func runtime(for combatant: Combatant) -> CombatantRuntime
    mutating func updateRuntime(_ runtime: CombatantRuntime)
    func hasActivePrevention(actor: Combatant) -> Bool
}

extension BattleState: CombatPipelineHost {
    func modifiers(for combatantID: String) -> CombatModifierProfile {
        combatBuild.modifiers(for: combatantID)
    }
}
