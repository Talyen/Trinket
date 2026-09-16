import BattleEngine
import Foundation

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
    var stage: Int
    let present: ([ActionEvent], [BattleResolvedDamage], Date, Int) -> Void

    var nextDate: Date {
        switch stage {
        case 0: startAt
        case 1: swingAt
        case 2: impactAt
        default: impactAt.addingTimeInterval(CombatFeedbackAttackRecipes.lungeCardAttack.recoverDuration)
        }
    }
}

extension BattleFeedbackLane {
    func scheduleActions(
        _ playback: BattleTransitionPlayback,
        preparedCardID: Int?,
        playedCardID: Int? = nil,
        at date: Date,
        cardPlayback: BattleCardPlaybackState,
        present: @escaping ([ActionEvent], [BattleResolvedDamage], Date, Int) -> Void,
    ) {
        advance(to: date)
        automaticPlayback = cardPlayback
        let attackingActors = Set(playback.actions.filter(\.isAttack).map(\.actorID))
        acceleratePendingActions(for: attackingActors, at: date)
        let groups = orderedActionGroups(playback)
        var automaticCards = playback.automaticCards
        for group in groups {
            let action = group.action
            let automaticIndex = automaticCards.firstIndex { $0.id == action?.cardID }
            let card = automaticIndex.map { automaticCards.remove(at: $0) }
            guard !group.events.isEmpty || card != nil else { continue }
            let actorID = action.flatMap { $0.isAttack ? $0.actorID : nil }
            let isManual = playedCardID != nil && action?.cardID == playedCardID
            let isPrepared = action?.cardID != nil && action?.cardID == preparedCardID
            if isPrepared, let action, !action.isAttack {
                previewAttack(.cancel, for: action.actorID, at: date)
            }
            if let actorID {
                previewActors.remove(actorID)
            }
            let previousImpact = scheduledActions.lazy.filter { $0.stage <= 2 }.map(\.impactAt).max()
            let isBurst = actorID.map { actorID in
                attackOwners[actorID] != nil || scheduledActions.contains { $0.actorID == actorID && $0.stage <= 2 }
            } == true
            let recipe = CombatFeedbackAttackRecipes.lungeCardAttack
            let windUp = actorID == nil || isPrepared ? 0 : (isBurst ? 0.08 : (isManual ? 0.10 : recipe.windUpDuration))
            let revealAt = max(date, previousImpact ?? date)
            let startAt = card == nil ? revealAt : revealAt.addingTimeInterval(BattleMotion.cardDealDuration)
            let swingAt = startAt.addingTimeInterval(windUp)
            let impactAt = max(
                swingAt.addingTimeInterval(actorID == nil ? 0 : recipe.swingDuration),
                previousImpact?.addingTimeInterval(recipe.swingDuration) ?? date,
            )
            let castID = card.map {
                cardPlayback.append(
                    $0,
                    at: revealAt,
                    activationAt: actorID == nil
                        ? max(impactAt, revealAt.addingTimeInterval(BattleMotion.automaticCardRevealDuration)) : swingAt,
                )
            }
            nextActionBeatID -= 1
            scheduledActions.append(BattleScheduledAction(
                id: nextActionBeatID, actorID: actorID, events: group.events, damage: action?.damage ?? [], castID: castID,
                deliversResultsImmediately: isManual,
                startAt: startAt, swingAt: swingAt,
                impactAt: actorID == nil && card != nil
                    ? max(impactAt, revealAt.addingTimeInterval(BattleMotion.automaticCardRevealDuration)) : impactAt,
                stage: actorID == nil ? 2 : (isPrepared ? 1 : 0), present: present,
            ))
            if isManual {
                present(group.events, action?.damage ?? [], date, nextActionBeatID)
            }
        }
        for card in automaticCards {
            let start = max(date, scheduledActions.lazy.map(\.impactAt).max() ?? date)
            cardPlayback.append(card, at: start, activationAt: start.addingTimeInterval(BattleMotion.automaticCardRevealDuration))
        }
        advance(to: date)
    }

    func advance(to date: Date) {
        guard suspendedAt == nil else { return }
        while let index = scheduledActions.indices.min(by: {
            scheduledActions[$0].nextDate < scheduledActions[$1].nextDate
        }), scheduledActions[index].nextDate <= date {
            let action = scheduledActions[index]
            scheduledActions[index].stage += 1
            switch action.stage {
            case 0:
                if let actorID = action.actorID {
                    attackOwners[actorID] = action.id
                    publishAttack(
                        .windUp,
                        for: actorID,
                        at: action.startAt,
                        duration: action.swingAt.timeIntervalSince(action.startAt),
                    )
                }
            case 1:
                if let actorID = action.actorID {
                    attackOwners[actorID] = action.id
                    publishAttack(
                        .swing,
                        for: actorID,
                        at: action.swingAt,
                        duration: action.impactAt.timeIntervalSince(action.swingAt),
                    )
                }
            case 2:
                if !action.deliversResultsImmediately {
                    action.present(action.events, action.damage, action.impactAt, action.id)
                }
                if let actorID = action.actorID, attackOwners[actorID] == action.id {
                    publishAttack(.recover, for: actorID, at: action.impactAt)
                    if previewActors.contains(actorID) {
                        publishAttack(.windUp, for: actorID, at: action.impactAt)
                    }
                }
            default:
                scheduledActions.remove(at: index)
                if let actorID = action.actorID, attackOwners[actorID] == action.id {
                    attackOwners.removeValue(forKey: actorID)
                    if !previewActors.contains(actorID) {
                        publishAttack(.rest, for: actorID, at: action.nextDate)
                    }
                }
            }
        }
        pruneExpired(at: date)
    }

    func previewAttack(_ phase: CombatantAttackPhase, for actorID: String, at date: Date = .now) {
        if phase == .windUp {
            previewActors.insert(actorID)
        }
        if phase == .cancel {
            previewActors.remove(actorID)
        }
        if phase == .windUp || phase == .cancel, scheduledActions.contains(where: {
            $0.actorID == actorID && $0.stage <= 2
        }) {
            return
        }
        publishAttack(phase, for: actorID, at: date)
    }

    func publishAttack(
        _ phase: CombatantAttackPhase, for actorID: String, at date: Date,
        duration: TimeInterval? = nil,
    ) {
        nextAttackReactionID += 1
        attackReactionsByCombatantID[actorID] = CombatantAttackReaction(
            id: nextAttackReactionID, phase: phase,
            startedAt: date, duration: duration,
        )
        noteAttackReactionsChanged(for: actorID)
    }

    var pendingFeedbackEnd: Date? {
        scheduledActions.filter { $0.stage <= 2 }.map {
            $0.impactAt.addingTimeInterval(BattleMotion.chipDisplayDuration)
        }.max()
    }

    func setSuspended(_ suspended: Bool, at date: Date = .now) {
        guard suspended != (suspendedAt != nil) else { return }
        if suspended {
            advance(to: date)
            suspendedAt = date
            scheduler?.cancel()
        } else if let paused = suspendedAt {
            let delay = date.timeIntervalSince(paused)
            for index in scheduledActions.indices {
                scheduledActions[index].startAt += delay
                scheduledActions[index].swingAt += delay
                scheduledActions[index].impactAt += delay
            }
            for index in activeItems.indices {
                activeItems[index].availableAt += delay
                activeItems[index].firstScheduledAt += delay
                activeItems[index].expiresAt += delay
                activeItems[index].lastUpdatedAt = activeItems[index].lastUpdatedAt?.addingTimeInterval(delay)
                activeItems[index].retiringAt = activeItems[index].retiringAt?.addingTimeInterval(delay)
                activeItems[index].criticalAt = activeItems[index].criticalAt?.addingTimeInterval(delay)
            }
            for actorID in recordedHitExpirations.keys {
                recordedHitExpirations[actorID]?.date += delay
            }
            for actorID in celebrateReactionExpiresAt.keys {
                celebrateReactionExpiresAt[actorID]? += delay
            }
            suspendedAt = nil
            noteItemsChanged()
            updatePruneDate()
        }
        for actorID in attackReactionsByCombatantID.keys {
            if suspended {
                attackReactionsByCombatantID[actorID]?.pausedAt = date
            } else if let paused = attackReactionsByCombatantID[actorID]?.pausedAt {
                attackReactionsByCombatantID[actorID]?.startedAt += date.timeIntervalSince(paused)
                attackReactionsByCombatantID[actorID]?.pausedAt = nil
            }
            noteAttackReactionsChanged(for: actorID)
        }
    }

    private func orderedActionGroups(
        _ playback: BattleTransitionPlayback,
    ) -> [(action: BattleResolvedAction?, events: [ActionEvent])] {
        let eventsByID = Dictionary(uniqueKeysWithValues: playback.events.map { ($0.id, $0) })
        let assignedIDs = Set(playback.actions.flatMap(\.eventIDs))
        var groups = playback.actions.map { action in
            (action: Optional(action), events: action.eventIDs.compactMap { eventsByID[$0] })
        }
        let remaining = playback.events.filter { !assignedIDs.contains($0.id) && $0.kind != .milestone }
        for group in Dictionary(grouping: remaining, by: \.feedbackGroupID).values {
            groups.append((nil, group))
        }
        groups.sort {
            let lhs = $0.action.map { $0.startedAfterEventID + 1 } ?? $0.events.first?.id ?? Int.max
            let rhs = $1.action.map { $0.startedAfterEventID + 1 } ?? $1.events.first?.id ?? Int.max
            return lhs == rhs ? ($0.action?.id ?? Int.max) < ($1.action?.id ?? Int.max) : lhs < rhs
        }
        return groups
    }

    private func acceleratePendingActions(for actorIDs: Set<String>, at date: Date) {
        var previousImpact: Date?
        for index in scheduledActions.indices where scheduledActions[index].stage <= 2 {
            let action = scheduledActions[index]
            if action.stage == 2 || action.actorID.map({ !actorIDs.contains($0) }) != false {
                previousImpact = action.impactAt
                continue
            }
            let start = max(date, previousImpact ?? date, action.castID == nil ? date : action.startAt)
            let swing = min(action.swingAt, start.addingTimeInterval(0.08))
            let impact = swing.addingTimeInterval(CombatFeedbackAttackRecipes.lungeCardAttack.swingDuration)
            scheduledActions[index].startAt = min(action.startAt, start)
            scheduledActions[index].swingAt = swing
            scheduledActions[index].impactAt = impact
            if let castID = action.castID {
                automaticPlayback?.retime(id: castID, activationAt: swing)
            }
            if action.stage == 1, let actorID = action.actorID {
                publishAttack(.windUp, for: actorID, at: date, duration: max(0, swing.timeIntervalSince(date)))
            }
            previousImpact = impact
        }
    }
}
