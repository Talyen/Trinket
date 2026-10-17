import TrinketCore

enum CombatCheckpoint {
    case preparedAction(String)
    case payment(ManaPayment)
    case attackEligibility(String)
    case controlRecovery(String, Keyword)
    case cardCompletion(String)

    func allowsContinuation(in context: borrowing BattleState) -> Bool {
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
        case let .controlRecovery(actorID, keyword):
            if let actor = context.roster.combatant(for: actorID) {
                actor.isAlive && !context.roster.hasPendingActionSkip(for: actor.combatant, keyword: keyword)
            } else {
                false
            }
        }
    }
}
