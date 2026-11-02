import TrinketCore

/// Completed combat output. Action recording is optional; consumers never run
/// inside rule resolution or retain an intermediate engine state.
public struct BattleCommandResult: Equatable, Sendable {
    public let events: [ActionEvent]
    public let playedCards: [BattleCard]
    /// Nested actions finish before their parent, preserving resolution order.
    public let actions: [BattleResolvedAction]
    public let combatantChanges: [BattleCombatantChange]

    public init(
        events: [ActionEvent] = [],
        playedCards: [BattleCard] = [],
        actions: [BattleResolvedAction] = [],
        combatantChanges: [BattleCombatantChange] = [],
    ) {
        self.events = events
        self.playedCards = playedCards
        self.actions = actions
        self.combatantChanges = combatantChanges
    }

    static let empty = Self()
}

/// Command-local output shared by nested rules, never retained by a completed state.
final class BattleCommandOutput {
    private(set) var events: [ActionEvent] = []
    private(set) var playedCards: [BattleCard] = []
    private(set) var resolvedActions: [BattleResolvedAction] = []
    private var combatantChanges: [BattleCombatantChange] = []
    private var lastCombatants: [BattleCombatantSnapshot] = []
    private let recordsActions: Bool
    private var cards: [(card: BattleCard, hasAction: Bool)] = []
    private var actions: [BattleResolvedAction] = []

    init(recordActions: Bool) {
        recordsActions = recordActions
    }

    var result: BattleCommandResult {
        BattleCommandResult(
            events: events,
            playedCards: playedCards,
            actions: resolvedActions,
            combatantChanges: combatantChanges,
        )
    }

    func recordCombatants(in state: borrowing BattleState, afterEventID: Int? = nil) {
        guard recordsActions else { return }
        let current = [
            BattleCombatantSnapshot(state.roster.hero),
            BattleCombatantSnapshot(state.roster.companion),
            BattleCombatantSnapshot(state.roster.enemy),
        ]
        if let afterEventID {
            for (before, after) in zip(lastCombatants, current) where before != after {
                combatantChanges.append(BattleCombatantChange(eventID: afterEventID, before: before, after: after))
            }
        }
        lastCombatants = current
    }

    func append(_ event: ActionEvent) {
        events.append(event)
        guard let lastIndex = actions.indices.last else { return }
        actions[lastIndex].eventIDs.append(event.id)
    }

    func beginCard(_ card: BattleCard) {
        guard recordsActions else { return }
        cards.append((card, false))
        playedCards.append(card)
    }

    func endCard() {
        guard recordsActions else { return }
        _ = cards.popLast()
    }

    func beginAction(id: Int, actorID: String, abilityID: String, isAttack: Bool, afterEventID: Int) {
        guard recordsActions else { return }
        let cardID: Int?
        if let lastIndex = cards.indices.last {
            cardID = cards[lastIndex].hasAction ? nil : cards[lastIndex].card.id
            cards[lastIndex].hasAction = true
        } else {
            cardID = nil
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
        guard let lastIndex = actions.indices.last else { return }
        actions[lastIndex].damage.append(damage)
    }
}
