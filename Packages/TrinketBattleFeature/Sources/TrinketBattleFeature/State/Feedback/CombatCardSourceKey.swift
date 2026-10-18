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

    /// Card-ability keys present in one event batch. Passive reactions share a
    /// group with the card that triggered them, so only a matching `.ability`
    /// event proves an effect is card output.
    static func cardSources(in events: [ActionEvent]) -> Set<Self> {
        Set(events.lazy.filter { $0.kind == .ability }.compactMap(Self.init))
    }
}
