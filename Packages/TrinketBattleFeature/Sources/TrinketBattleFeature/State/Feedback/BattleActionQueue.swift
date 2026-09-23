import BattleEngine
import Foundation

enum BattleActionCue {
    case windUp
    case swing
    case impact
    case recovery
}

struct BattleScheduledAction {
    let id: Int
    let actorID: String?
    let events: [ActionEvent]
    let damage: [BattleResolvedDamage]
    let castID: UUID?
    let deliversResultsImmediately: Bool
    var startAt: Date
    var swingAt: Date
    var impactAt: Date
    var nextCue: BattleActionCue
    let present: ([ActionEvent], [BattleResolvedDamage], Date, Int) -> Void

    var nextDate: Date {
        switch nextCue {
        case .windUp: startAt
        case .swing: swingAt
        case .impact: impactAt
        case .recovery: impactAt.addingTimeInterval(CombatFeedbackAttackRecipes.lungeCardAttack.recoverDuration)
        }
    }

    var hasPendingImpact: Bool {
        nextCue != .recovery
    }

    var canAccelerate: Bool {
        nextCue == .windUp || nextCue == .swing
    }

    mutating func consumeNextCue() -> BattleActionCue {
        let cue = nextCue
        switch cue {
        case .windUp: nextCue = .swing
        case .swing: nextCue = .impact
        case .impact: nextCue = .recovery
        case .recovery: break
        }
        return cue
    }

    mutating func shift(by delay: TimeInterval) {
        startAt += delay
        swingAt += delay
        impactAt += delay
    }
}

struct BattleActionAcceleration {
    let castID: UUID?
    let actorID: String
    let swingAt: Date
    let needsWindUpUpdate: Bool
}

struct BattleActionQueue {
    private(set) var actions: [BattleScheduledAction] = []
    private var nextID = 0

    var nextDate: Date? {
        actions.lazy.map(\.nextDate).min()
    }

    var latestImpact: Date? {
        actions.lazy.map(\.impactAt).max()
    }

    var latestPendingImpact: Date? {
        actions.lazy.filter(\.hasPendingImpact).map(\.impactAt).max()
    }

    func hasPendingImpact(for actorID: String) -> Bool {
        actions.contains { $0.actorID == actorID && $0.hasPendingImpact }
    }

    mutating func append(_ makeAction: (Int) -> BattleScheduledAction) -> Int {
        nextID -= 1
        actions.append(makeAction(nextID))
        return nextID
    }

    mutating func consumeNextCue(at date: Date) -> (action: BattleScheduledAction, cue: BattleActionCue)? {
        guard let index = actions.indices.min(by: { actions[$0].nextDate < actions[$1].nextDate }),
              actions[index].nextDate <= date
        else { return nil }
        let action = actions[index]
        let cue = actions[index].consumeNextCue()
        if cue == .recovery {
            actions.remove(at: index)
        }
        return (action, cue)
    }

    mutating func shift(by delay: TimeInterval) {
        for index in actions.indices {
            actions[index].shift(by: delay)
        }
    }

    mutating func accelerate(for actorIDs: Set<String>, at date: Date) -> [BattleActionAcceleration] {
        var previousImpact: Date?
        var changes: [BattleActionAcceleration] = []
        for index in actions.indices where actions[index].hasPendingImpact {
            let action = actions[index]
            guard action.canAccelerate, let actorID = action.actorID, actorIDs.contains(actorID) else {
                previousImpact = action.impactAt
                continue
            }
            let start = max(date, previousImpact ?? date, action.castID == nil ? date : action.startAt)
            let swing = min(action.swingAt, start.addingTimeInterval(0.08))
            let impact = swing.addingTimeInterval(CombatFeedbackAttackRecipes.lungeCardAttack.swingDuration)
            actions[index].startAt = min(action.startAt, start)
            actions[index].swingAt = swing
            actions[index].impactAt = impact
            changes.append(BattleActionAcceleration(
                castID: action.castID, actorID: actorID, swingAt: swing,
                needsWindUpUpdate: action.nextCue == .swing,
            ))
            previousImpact = impact
        }
        return changes
    }

    mutating func clear() {
        actions.removeAll()
    }
}
