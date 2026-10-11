import TrinketCore

/// Completed combat output. Action recording is optional; consumers never run
/// inside rule resolution or retain an intermediate engine state.
public struct BattleCommandResult: Equatable, Sendable {
    public let events: [ActionEvent]
    public let playedCards: [BattleCard]
    /// Nested actions finish before their parent, preserving resolution order.
    public let actions: [BattleResolvedAction]

    static let empty = Self(events: [], playedCards: [], actions: [])
}

final class BattleCommandRecording {
    private(set) var playedCards: [BattleCard] = []
    private(set) var resolvedActions: [BattleResolvedAction] = []
    private var cards: [(card: BattleCard, hasAction: Bool)] = []
    private var actions: [BattleResolvedAction] = []

    func append(_ event: ActionEvent) {
        guard !actions.isEmpty else { return }
        actions[actions.count - 1].eventIDs.append(event.id)
    }

    func beginCard(_ card: BattleCard) {
        cards.append((card, false))
        playedCards.append(card)
    }

    func endCard() {
        _ = cards.popLast()
    }

    func beginAction(id: Int, actorID: String, abilityID: String, isAttack: Bool, afterEventID: Int) {
        let cardID = cards.last.flatMap { $0.hasAction ? nil : $0.card.id }
        if !cards.isEmpty {
            cards[cards.count - 1].hasAction = true
        }
        actions.append(BattleResolvedAction(
            id: id, actorID: actorID, abilityID: abilityID, cardID: cardID,
            isAttack: isAttack, eventIDs: [], startedAfterEventID: afterEventID,
        ))
    }

    func endAction() {
        guard let action = actions.popLast() else { return }
        resolvedActions.append(action)
    }

    func recordDamage(_ damage: BattleResolvedDamage) {
        guard !actions.isEmpty else { return }
        actions[actions.count - 1].damage.append(damage)
    }
}
