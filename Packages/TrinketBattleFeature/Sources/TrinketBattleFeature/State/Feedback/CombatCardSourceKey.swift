import BattleEngine

/// Matches direct effects of automatic cards without treating passive reactions as card output.
struct CombatCardSourceKey: Hashable {
    let feedbackGroupID: Int
    let actorID: String
    let abilityID: String

    init?(_ event: ActionEvent) {
        guard !event.actorID.isEmpty, !event.abilityID.isEmpty else { return nil }
        feedbackGroupID = event.feedbackGroupID
        actorID = event.actorID
        abilityID = event.abilityID
    }
}
