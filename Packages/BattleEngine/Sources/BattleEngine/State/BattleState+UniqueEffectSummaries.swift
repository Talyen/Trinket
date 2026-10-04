import TrinketContent
import TrinketCore

extension BattleState {
    func uniqueEffectSummaries(of combatant: Combatant) -> [EffectSummary] {
        guard let owner = roster.participant(for: combatant),
              let state = uniques.owners[owner] else { return [] }
        var summaries: [EffectSummary] = []
        if state.wrenflightDodge > 0 {
            summaries.append(EffectSummary(
                keyword: .dodge,
                text: "Wrenflight: +\(Int((state.wrenflightDodge * 100).rounded()))% Dodge chance until your next turn.",
            ))
        }
        if state.viperReady {
            summaries.append(EffectSummary(
                keyword: .poison,
                text: "Viper’s Courtesy: Your next hit that removes Health deals additional Poison and Bleed damage, each equal to half its damage.",
            ))
        }
        if state.wildheartReady {
            summaries.append(EffectSummary(
                keyword: .poison,
                text: "Wildheart’s Favor: Your next Poison card’s damage Critically Hits.",
            ))
        }
        if state.goldDamage > 0 {
            summaries.append(EffectSummary(
                keyword: .holy,
                text: "The Golden Crucible: Your next Holy hit from a manually played card deals \(state.goldDamage) additional damage.",
            ))
        }
        return summaries
    }
}
