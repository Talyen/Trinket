import TrinketCore

enum CombatCheckpoint {
    case preparedAction(String)
    case payment(ManaPayment)
    case attackEligibility(String)
    case committedDamage
    case controlRecovery(String, Keyword)
    case cardCompletion(String)

    typealias Reaction = (inout BattleState) -> [ActionEvent]

    func allowsContinuation(in context: BattleState) -> Bool {
        switch self {
        case let .preparedAction(actorID), let .cardCompletion(actorID):
            context.roster.combatant(for: actorID)?.isAlive == true
        case let .payment(payment):
            payment.amountSpent > 0 && context.roster.combatant(for: payment.payerID)?.isAlive == true
        case let .attackEligibility(actorID):
            if let actor = context.roster.combatant(for: actorID) {
                !context.isBattleOver && actor.isAlive && !context.roster.hasPendingActionSkip(for: actor.combatant)
            } else {
                false
            }
        case .committedDamage:
            true
        case let .controlRecovery(actorID, keyword):
            if let actor = context.roster.combatant(for: actorID) {
                actor.isAlive && !context.roster.hasPendingActionSkip(for: actor.combatant, keyword: keyword)
            } else {
                false
            }
        }
    }

    func resolve(_ reactions: [Reaction], in context: inout BattleState) -> [ActionEvent] {
        var events: [ActionEvent] = []
        for reaction in reactions {
            guard allowsContinuation(in: context) else { break }
            events.append(contentsOf: reaction(&context))
        }
        return events
    }

    func perform(in context: inout BattleState, _ reaction: (inout BattleState) -> Void) {
        guard allowsContinuation(in: context) else { return }
        reaction(&context)
    }
}
