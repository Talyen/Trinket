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

/// Command-local output shared by nested rules, never retained by a completed state.
final class BattleCommandOutput {
    private(set) var events: [ActionEvent] = []
    private(set) var playedCards: [BattleCard] = []
    private(set) var resolvedActions: [BattleResolvedAction] = []
    private let recordsActions: Bool
    private var cards: [(card: BattleCard, hasAction: Bool)] = []
    private var actions: [BattleResolvedAction] = []

    init(recordActions: Bool) {
        recordsActions = recordActions
    }

    var result: BattleCommandResult {
        BattleCommandResult(events: events, playedCards: playedCards, actions: resolvedActions)
    }

    func append(_ event: ActionEvent) {
        events.append(event)
        guard !actions.isEmpty else { return }
        actions[actions.count - 1].eventIDs.append(event.id)
    }

    func beginCard(_ card: BattleCard) {
        guard recordsActions else { return }
        cards.append((card, false))
        playedCards.append(card)
    }

    func endCard() {
        _ = cards.popLast()
    }

    func beginAction(id: Int, actorID: String, abilityID: String, isAttack: Bool, afterEventID: Int) {
        guard recordsActions else { return }
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
