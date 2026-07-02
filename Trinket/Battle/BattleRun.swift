import SwiftUI

@MainActor
@Observable
final class BattleRun {
    private(set) var state: BattleState
    var activeFeedbackEvents: [ActionEvent] = []

    let configuration: ActiveBattleConfiguration

    init(configuration: ActiveBattleConfiguration) {
        self.configuration = configuration
        state = BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers
        )
    }

    var log: [LogEntry] { state.log }
    var hero: Combatant { state.hero }
    var pet: Combatant { state.pet }
    var enemy: Combatant { state.enemy }
    var heroHealth: Int { state.heroHealth }
    var petHealth: Int { state.petHealth }
    var enemyHealth: Int { state.enemyHealth }
    var earnedGold: Int { state.earnedGold }
    var isBattleOver: Bool { state.isBattleOver }
    var isEnemyDefeated: Bool { state.isEnemyDefeated }
    var isPartyDefeated: Bool { state.isPartyDefeated }

    func reset(from configuration: ActiveBattleConfiguration) {
        state = BattleState(
            hero: configuration.hero,
            pet: configuration.pet,
            enemy: configuration.enemy,
            heroModifiers: configuration.heroModifiers,
            petModifiers: configuration.petModifiers
        )
        activeFeedbackEvents = []
    }

    func removeFeedbackEvent(_ id: Int) {
        activeFeedbackEvents.removeAll { $0.id == id }
    }

    @discardableResult
    func advanceOneStep() -> BattleStep {
        let step = state.advanceOneStep()
        step.events
            .filter { $0.kind != .milestone }
            .forEach { activeFeedbackEvents.append($0) }
        return step
    }

    func effectSummaries(for combatant: Combatant) -> [EffectSummary] {
        state.effectSummaries(of: combatant)
    }

    func health(for combatant: Combatant) -> Int {
        state.health(of: combatant)
    }
}
